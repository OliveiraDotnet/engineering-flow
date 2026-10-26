#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SKILLS_ROOT="$PACK_ROOT/repo-template/.agents/skills"
OUTPUT="$PACK_ROOT/SKILLS-INDEX.md"

[ -d "$SKILLS_ROOT" ] || { echo "Missing skills root: $SKILLS_ROOT" >&2; exit 1; }

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

escape_cell() {
  local value="$1"
  value="${value//|/\\|}"
  printf '%s' "$value"
}

rows=()
while IFS= read -r skill; do
  folder="$(basename "$(dirname "$skill")")"
  name=""
  description=""
  required_input=""
  in_frontmatter=false
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    if [ "$in_frontmatter" = false ]; then
      [ "$line" = "---" ] || continue
      in_frontmatter=true
      continue
    fi
    [ "$line" = "---" ] && break
    key="${line%%:*}"
    value="${line#*:}"
    key="$(trim "$key")"
    value="$(trim "$value")"
    case "$key" in
      name) name="$value" ;;
      description) description="$value" ;;
      input|entrada|required-input|required_input) required_input="$value" ;;
    esac
  done < "$skill"
  [ -n "$name" ] || name="$folder"
  [ -n "$description" ] || description="ver SKILL.md"
  [ -n "$required_input" ] || required_input="ver SKILL.md"
  rows+=("$(printf '%s\t%s\t%s' "$name" "$description" "$required_input")")
done < <(find "$SKILLS_ROOT" -mindepth 2 -maxdepth 2 -type f -name SKILL.md | sort)

{
  printf '%s\n' '# Índice de skills — Engineering Flow 3.1'
  printf '\n'
  printf '%s\n' 'Gerado por `tools/generate-skills-index.sh` a partir do frontmatter `name`/`description` de `repo-template/.agents/skills/*/SKILL.md`. O implementador lê este índice e carrega apenas a skill escolhida.'
  printf '\n'
  printf '%s\n' '| Nome | Quando usar | Entrada exigida |'
  printf '%s\n' '|---|---|---|'
  IFS=$'\n'
  sorted="$(printf '%s\n' "${rows[@]}" | LC_ALL=C sort)"
  while IFS=$'\t' read -r name description required_input; do
    printf '| %s | %s | %s |\n' "$(escape_cell "$name")" "$(escape_cell "$description")" "$(escape_cell "$required_input")"
  done <<< "$sorted"
  printf '\n'
} > "$OUTPUT"

echo "Wrote $OUTPUT ($(grep -c '^|' "$OUTPUT" | awk '{print $1-2}') skills)."
