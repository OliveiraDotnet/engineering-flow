#!/usr/bin/env bash
set -euo pipefail

repo_path="${1:-.}"
repo_path="$(cd "$repo_path" && pwd -P)"

# Enumerate once, pruning generated/tool directories before descending. Do not follow links.
scoped_files="$(find "$repo_path" \
  -type d \( -iname '.git' -o -iname 'bin' -o -iname 'obj' -o -iname 'node_modules' -o -iname 'packages' -o -iname '.vs' -o -iname '.agents' -o -iname '.claude' -o -iname '.grok' -o -iname '.codex' -o -iname '.agent-pack' \) -prune -o \
  -type f -print)"
find_files() { printf '%s\n' "$scoped_files"; }

relative() { printf '%s' "${1#"$repo_path"/}"; }

count_pattern() { find_files | grep -E -c "$1" || true; }

list_pattern() {
  find_files | grep -E "$1" | while IFS= read -r file; do
    relative "$file"
    printf '\n'
  done || true
}

git_root=""
if command -v git >/dev/null 2>&1; then
  git_root="$(git -C "$repo_path" rev-parse --show-toplevel 2>/dev/null || true)"
fi

project_files="$(list_pattern '\.(csproj|fsproj|vbproj)$' || true)"
solution_files="$(list_pattern '\.slnx?$' || true)"
tfms="$(find_files | grep -E '\.(csproj|fsproj|vbproj)$' | while IFS= read -r project; do grep -h -E '<TargetFramework(s|Version)?>' "$project" 2>/dev/null || true; done | sed -E 's/.*<TargetFramework(s|Version)?>([^<]+)<.*/\2/' | sort -u || true)"

profiles=()
if [ "$(count_pattern '\.(cshtml|razor|aspx)$|(^|/)Web\.config$|(^|/)wwwroot/')" -gt 0 ]; then profiles+=(web); fi
provider_pattern='(Microsoft\.EntityFrameworkCore\.SqlServer|EntityFramework\.SqlServer|System\.Data\.SqlClient|Microsoft\.Data\.SqlClient)'
tsql_pattern='(SET[[:space:]]+ANSI_NULLS|SET[[:space:]]+QUOTED_IDENTIFIER|\bGO[[:space:]]*$|\bIDENTITY[[:space:]]*\(|\bsys\.(tables|procedures|sql_modules)\b|\bOBJECT_ID[[:space:]]*\()'
# Output only a detection flag, never potentially sensitive source lines.
sql_evidence="$(while IFS= read -r file; do
  lower_file="$(printf '%s' "$file" | tr '[:upper:]' '[:lower:]')"
  case "$lower_file" in
    *.sql) pattern="$tsql_pattern" ;;
    *.csproj|*.fsproj|*.vbproj|*.props|*.targets|*.sqlproj|*/packages.config) pattern="$provider_pattern" ;;
    *) continue ;;
  esac
  if grep -E -i -q "$pattern" "$file"; then printf 'sqlserver'; break; fi
done <<< "$scoped_files")"
if [ -n "$sql_evidence" ]; then
  profiles+=(sqlserver)
fi

shape="non-git-folder"
if [ -n "$git_root" ]; then shape="git-repository"; fi

printf '# .NET repository fingerprint\n\n'
printf -- '- Shape: %s\n' "$shape"
printf -- '- Git root: %s\n' "${git_root:-[none]}"
printf -- '- Solutions:\n%s\n' "${solution_files:-[none]}"
printf -- '- Projects:\n%s\n' "${project_files:-[none]}"
printf -- '- Target frameworks:\n%s\n' "${tfms:-[unreadable-or-not-found]}"
printf -- '- Suggested profiles: %s\n' "${profiles[*]:-[none]}"
printf -- '- CI or build files:\n'
list_pattern '(^|/)(\.github/workflows/.*\.ya?ml|azure-pipelines.*\.ya?ml|\.gitlab-ci\.ya?ml|(build|test)\.(ps1|sh|cmd|bat))$' || true
