#!/usr/bin/env bash
set -euo pipefail

repo_path="."
generate_repo_map=0
force_repo_map=0
while [ $# -gt 0 ]; do
  case "$1" in
    --generate-repo-map) generate_repo_map=1; shift ;;
    --force-repo-map) force_repo_map=1; generate_repo_map=1; shift ;;
    *) repo_path="$1"; shift ;;
  esac
done
repo_path="$(cd "$repo_path" && pwd -P)"

# Enumerate once, pruning generated/tool directories before descending. Do not follow links.
scoped_files="$(find "$repo_path" \
  -type d \( -iname '.git' -o -iname 'bin' -o -iname 'obj' -o -iname 'node_modules' -o -iname 'packages' -o -iname '.vs' -o -iname '.agents' -o -iname '.claude' -o -iname '.grok' -o -iname '.codex' -o -iname '.agent-pack' -o -iname '.dart_tool' -o -iname '.gradle' -o -iname 'Pods' -o -iname 'DerivedData' -o -iname '.venv' -o -iname '.next' \) -prune -o \
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
if [ "$(count_pattern '\.(cshtml|razor|aspx|asp|html?|css|js|ts|tsx|jsx)$|(^|/)[Ww]eb\.config$|(^|/)wwwroot/')" -gt 0 ]; then profiles+=(web); fi
mobile_evidence="$(while IFS= read -r project; do
  case "$project" in *.csproj|*.fsproj|*.vbproj)
    if grep -E -i -q '<UseMaui>[[:space:]]*true|net[0-9.]+-(android|ios)|Microsoft\.Maui|Xamarin' "$project"; then printf mobile; break; fi ;;
    *.pbxproj) if grep -E -q 'SDKROOT[[:space:]]*=[[:space:]]*iphoneos|SUPPORTED_PLATFORMS[[:space:]]*=.*iphoneos|IPHONEOS_DEPLOYMENT_TARGET' "$project"; then printf mobile; break; fi ;;
    */package.json) if grep -E -q '"(react-native|@capacitor/core|@ionic/react|@ionic/angular|expo)"[[:space:]]*:' "$project"; then printf mobile; break; fi ;;
  esac
done <<< "$scoped_files")"
if [ "$(count_pattern '(^|/)(pubspec\.ya?ml|AndroidManifest\.xml)$')" -gt 0 ] || [ -n "$mobile_evidence" ]; then
  profiles+=(mobile)
fi
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

printf '# Engineering Flow repository fingerprint\n\n'
mode=existing
[ -n "$scoped_files" ] || mode=empty
printf -- '- Discovery mode: %s\n' "$mode"
printf -- '- Shape: %s\n' "$shape"
printf -- '- Git root: %s\n' "${git_root:-[none]}"
printf -- '- Solutions:\n%s\n' "${solution_files:-[none]}"
printf -- '- Projects:\n%s\n' "${project_files:-[none]}"
printf -- '- Target frameworks:\n%s\n' "${tfms:-[unreadable-or-not-found]}"
printf -- '- Suggested profiles: %s\n' "${profiles[*]:-[none]}"
printf -- '- CI or build files:\n'
list_pattern '(^|/)(\.github/workflows/.*\.ya?ml|azure-pipelines.*\.ya?ml|\.gitlab-ci\.ya?ml|(build|test)\.(ps1|sh|cmd|bat))$' || true
printf -- '- Manifests (inspect versions/commands separately):\n'
list_pattern '(^|/)(package\.json|.*lock.*|pubspec\.ya?ml|Cargo\.toml|go\.mod|pom\.xml|build\.gradle(\.kts)?|requirements.*\.txt|pyproject\.toml|composer\.json|Gemfile)$' || true
printf -- '- Runtime/platform evidence:\n'
list_pattern '(^|/)(Dockerfile.*|compose.*\.ya?ml|.*\.tf|AndroidManifest\.xml)$|\.xcodeproj/|\.(asp|html?|css|js|ts|tsx|jsx|swift|kt|dart)$' || true
printf -- '- Available tools (host-local, compatibility unverified):'
for tool in git dotnet node npm pwsh bash flutter dart java adb xcodebuild python docker sqlcmd; do
  if command -v "$tool" >/dev/null 2>&1; then printf ' %s' "$tool"; fi
done
printf '\n- Limits: detection is evidence, not runtime validation; unknown stacks require further investigation.\n'
printf -- '- File extension inventory:\n'
find_files | awk 'NF { name=$0; sub(/^.*\//,"",name); ext="(no-extension)"; if (name ~ /\./) { sub(/^.*\./,"",name); ext="." tolower(name) }; count[ext]++ } END { for (ext in count) print ext, count[ext] }' | sort

if [ "$generate_repo_map" -eq 1 ]; then
  runtime_dir="$repo_path/.agent-pack/.runtime"
  repo_map_path="$runtime_dir/repo-map.txt"
  head_hash="no-git"
  is_dirty=1
  if [ -n "$git_root" ]; then
    head_hash="$(git -C "$repo_path" rev-parse --short HEAD 2>/dev/null || echo empty-head)"
    if [ -z "$(git -C "$repo_path" status --porcelain 2>/dev/null || true)" ]; then is_dirty=0; fi
  fi
  cache_key="$head_hash"
  [ "$is_dirty" -eq 1 ] && cache_key="${head_hash}-dirty"
  repo_map_status="generated"
  if [ "$force_repo_map" -eq 0 ] && [ "$is_dirty" -eq 0 ] && [ -f "$repo_map_path" ] && grep -Fxq "cache_key: $cache_key" "$repo_map_path"; then
    repo_map_status="cache-hit"
  else
    mkdir -p "$runtime_dir"
    now_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    tmp_entries="$(mktemp)"
    indexed=0
    while IFS= read -r src_file; do
      [ -n "$src_file" ] || continue
      [ "$indexed" -lt 120 ] || break
      lower="$(printf '%s' "$src_file" | tr '[:upper:]' '[:lower:]')"
      case "$lower" in
        *.cs|*.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.java|*.kt|*.sql) ;;
        *) continue ;;
      esac
      rel="$(relative "$src_file")"
      syms="$(grep -E '^[[:space:]]*(public|internal)[[:space:]]+((sealed|abstract|static|partial)[[:space:]]+)*(class|interface|record|struct|enum)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*|^[[:space:]]*export[[:space:]]+(default[[:space:]]+)?(async[[:space:]]+)?(class|interface|type|function|const)[[:space:]]+[A-Za-z_$][A-Za-z0-9_$]*|^(async[[:space:]]+)?(class|def)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*|^(type|func)[[:space:]]+(\([^)]+\)[[:space:]]+)?[A-Z][A-Za-z0-9_]*|^[[:space:]]*[Cc][Rr][Ee][Aa][Tt][Ee][[:space:]]+([Oo][Rr][[:space:]]+[Aa][Ll][Tt][Ee][Rr][[:space:]]+)?([Tt][Aa][Bb][Ll][Ee]|[Vv][Ii][Ee][Ww]|[Pp][Rr][Oo][Cc]([Ee][Dd][Uu][Rr][Ee])?|[Ff][Uu][Nn][Cc][Tt][Ii][Oo][Nn])[[:space:]]+[A-Za-z0-9_\[\]\.]+' "$src_file" 2>/dev/null | head -n 12 | sed -E 's/^[[:space:]]+//; s/[[:space:]]*\{.*$//; s/[[:space:]]*\(.*$//' | paste -sd ', ' - || true)"
      if [ -n "$syms" ]; then
        printf '%s: %s\n' "$rel" "$syms" >> "$tmp_entries"
        indexed=$((indexed + 1))
      fi
    done <<< "$(printf '%s\n' "$scoped_files" | sort)"
    {
      printf '# SpecGuard 6 Repo Map (auto-generated structural cache — gitignored)\n'
      printf 'cache_key: %s\n' "$cache_key"
      printf 'generated_at: %s | files_indexed: %s\n\n' "$now_utc" "$indexed"
      cat "$tmp_entries"
    } > "$repo_map_path"
    rm -f "$tmp_entries"
  fi
  printf -- '- Repo map: .agent-pack/.runtime/repo-map.txt (%s)\n' "$repo_map_status"
fi
