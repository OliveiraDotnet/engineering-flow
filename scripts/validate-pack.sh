#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TEMPLATE_ROOT="$PACK_ROOT/repo-template"
MANIFEST="$PACK_ROOT/pack-manifest.txt"
PACK_VERSION_FILE="$PACK_ROOT/pack-version.txt"
ARTIFACT_METADATA="$PACK_ROOT/pack-artifacts.txt"
COMPATIBILITY_ROOT="$PACK_ROOT/compat/releases"
errors=0

fail() { echo "ERROR: $*" >&2; errors=$((errors + 1)); }

[ -f "$MANIFEST" ] || fail "Missing pack manifest."

manifest_components=()
manifest_sources=()
manifest_destinations=()
while IFS='|' read -r component source_relative destination_relative extra; do
  component="${component//[[:space:]]/}"
  source_relative="${source_relative# }"
  destination_relative="${destination_relative# }"
  source_relative="${source_relative%$'\r'}"
  destination_relative="${destination_relative%$'\r'}"
  [ -n "$component" ] || continue
  [[ "$component" = \#* ]] && continue
  [ -z "$extra" ] || { fail "Invalid manifest line with too many fields: $component"; continue; }
  case "$component" in
    core|web|sqlserver|quality|mobile) ;;
    *) fail "Unknown component in manifest: $component"; continue ;;
  esac
  [ -n "$source_relative" ] || { fail "Empty manifest source."; continue; }
  [ -n "$destination_relative" ] || destination_relative="$source_relative"
  [ -f "$TEMPLATE_ROOT/$source_relative" ] || fail "Manifest source is missing: $source_relative"
  for listed in "${manifest_destinations[@]}"; do
    [ "$listed" != "$destination_relative" ] || fail "Manifest destination appears more than once: $destination_relative"
  done
  manifest_components+=("$component")
  manifest_sources+=("$source_relative")
  manifest_destinations+=("$destination_relative")
done < "$MANIFEST"

if [ ! -f "$PACK_VERSION_FILE" ]; then
  fail "Missing pack version file."
else
  pack_version="$(tr -d '\r\n' < "$PACK_VERSION_FILE")"
  [[ "$pack_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Invalid semantic version in pack-version.txt: $pack_version"
  IFS= read -r manifest_header < "$MANIFEST" || true
  manifest_header="${manifest_header%$'\r'}"
  [ "$manifest_header" = "# Engineering Flow manifest v$pack_version" ] || fail "Manifest header version does not match pack-version.txt"
fi

artifact_ids=()
artifact_destinations=()
artifact_destinations_lower=()
artifact_ownership=()
if [ ! -f "$ARTIFACT_METADATA" ]; then
  fail "Missing artifact metadata."
else
  while IFS='|' read -r artifact_id destination ownership extra; do
    artifact_id="${artifact_id%$'\r'}"
    destination="${destination%$'\r'}"
    ownership="${ownership%$'\r'}"
    [ -n "$artifact_id" ] || continue
    [[ "$artifact_id" = \#* ]] && continue
    [ -z "${extra:-}" ] || { fail "Invalid artifact metadata line for $artifact_id"; continue; }
    [[ "$artifact_id" =~ ^[a-z0-9][a-z0-9.-]*$ ]] || fail "Invalid artifact id: $artifact_id"
    case "$destination" in ""|/*|*\\*|..|../*|*/..|*/../*) fail "Invalid artifact destination: $destination" ;; esac
    case "$ownership" in managed|merge|seed) ;; *) fail "Invalid ownership '$ownership' for '$artifact_id'" ;; esac
    for existing in "${artifact_ids[@]}"; do [ "$existing" != "$artifact_id" ] || fail "Artifact id appears more than once: $artifact_id"; done
    destination_lower="$(printf '%s' "$destination" | tr '[:upper:]' '[:lower:]')"
    for existing_lower in "${artifact_destinations_lower[@]}"; do
      [ "$existing_lower" != "$destination_lower" ] || fail "Artifact destination appears more than once: $destination"
    done
    artifact_ids+=("$artifact_id")
    artifact_destinations+=("$destination")
    artifact_destinations_lower+=("$destination_lower")
    artifact_ownership+=("$ownership")
  done < "$ARTIFACT_METADATA"
fi

for destination in "${manifest_destinations[@]}"; do
  count=0
  for candidate in "${artifact_destinations[@]}"; do [ "$candidate" != "$destination" ] || count=$((count + 1)); done
  [ "$count" -eq 1 ] || fail "Manifest destination must have exactly one artifact metadata entry: $destination"
done
for destination in "${artifact_destinations[@]}"; do
  count=0
  for candidate in "${manifest_destinations[@]}"; do [ "$candidate" != "$destination" ] || count=$((count + 1)); done
  [ "$count" -eq 1 ] || fail "Artifact metadata destination is not present once in the manifest: $destination"
done
for index in "${!artifact_destinations[@]}"; do
  destination="${artifact_destinations[$index]}"
  ownership="${artifact_ownership[$index]}"
  case "$destination" in
    AGENTS.md) [ "$ownership" = merge ] || fail "$destination must use merge ownership" ;;
    docs/ai/*) [ "$ownership" = seed ] || fail "Repository memory must use seed ownership: $destination" ;;
  esac
done

if [ ! -d "$COMPATIBILITY_ROOT" ]; then
  fail "Missing compatibility catalog directory."
else
  for catalog in "$COMPATIBILITY_ROOT"/*.txt; do
    [ -f "$catalog" ] || continue
    catalog_ids=()
    while IFS='|' read -r artifact_id destination hash extra; do
      artifact_id="${artifact_id%$'\r'}"
      destination="${destination%$'\r'}"
      hash="${hash%$'\r'}"
      [ -n "$artifact_id" ] || continue
      [[ "$artifact_id" = \#* ]] && continue
      [ -z "${extra:-}" ] || { fail "Invalid compatibility line in $(basename "$catalog")"; continue; }
      [[ "$artifact_id" =~ ^[a-z0-9][a-z0-9.-]*$ ]] || fail "Invalid compatibility artifact id: $artifact_id"
      case "$destination" in ""|/*|*\\*|..|../*|*/..|*/../*) fail "Invalid compatibility destination: $destination" ;; esac
      [[ "$hash" =~ ^[a-f0-9]{64}$ ]] || fail "Invalid compatibility hash for $artifact_id"
      for existing in "${catalog_ids[@]}"; do [ "$existing" != "$artifact_id" ] || fail "Compatibility catalog repeats artifact id: $artifact_id"; done
      catalog_ids+=("$artifact_id")
    done < "$catalog"
  done
fi

agents_governance="$TEMPLATE_ROOT/AGENTS.md"
work_order_contract="$TEMPLATE_ROOT/.agents/skills/agent-work-order/SKILL.md"
delegation_contract="$TEMPLATE_ROOT/.agents/skills/delegate-to-harness/SKILL.md"
for governance_file in "$agents_governance" "$work_order_contract" "$delegation_contract"; do
  [ -f "$governance_file" ] || fail "Missing governance artifact: $governance_file"
done
if [ -f "$agents_governance" ] && [ -f "$delegation_contract" ]; then
  for required in "sole decision authority" "Gate 1" "execution envelope" "Gate 2" "ok explícito do aprovador humano" "nunca force push" "BLOCKED_BY_DECISION" "apenas AGENTS.md"; do
    grep -Fq "$required" "$agents_governance" || fail "AGENTS.md is missing governance marker '$required'"
  done
  for required in "Human-approved scope" "Allowed read areas" "Allowed modification areas" "Decision boundaries" "Escalation conditions" "READY_FOR_MANUAL_VALIDATION" "USER_DECISION_REQUIRED"; do
    grep -Fq "$required" "$work_order_contract" || fail "Shared agent work-order contract is missing '$required'"
  done
  for required in "COMPLETED" "COMPLETED_WITH_CONCERNS" "BLOCKED_BY_DECISION" "UNABLE_TO_VALIDATE" "material change was not performed"; do
    grep -Fq "$required" "$work_order_contract" || fail "Shared agent work-order contract is missing '$required'"
  done
  grep -Fq "agent work order" "$delegation_contract" || fail "Harness delegation entrypoint must reference the shared agent work-order contract"
fi

harness_skill="$TEMPLATE_ROOT/.agents/skills/harness-cycle/SKILL.md"
if [ ! -f "$harness_skill" ]; then
  fail "Missing harness-cycle skill: $harness_skill"
else
  grep -Fq "only the harness (Implementor/Tester) runs the runners" "$harness_skill" || fail "harness-cycle/SKILL.md must state 'only the harness (Implementor/Tester) runs the runners'"
fi

for c10_rel in \
  "prompts/12-implementor-harness.md" \
  "prompts/13-tester-harness.md" \
  ".agents/skills/harness-cycle/SKILL.md"; do
  c10_file="$TEMPLATE_ROOT/$c10_rel"
  if [ ! -f "$c10_file" ]; then
    fail "Missing C10 harness contract file: $c10_rel"
  else
    for c10_marker in "docs/ai/decisions-and-pendencies.md" "docs/ai/external-boundaries.md" "BLOCKED_BY_DECISION"; do
      grep -Fq "$c10_marker" "$c10_file" || fail "$c10_rel must reference '$c10_marker'"
    done
  fi
done

while IFS= read -r file; do
  relative="${file#"$TEMPLATE_ROOT"/}"
  found=false
  for listed in "${manifest_sources[@]}"; do [ "$listed" = "$relative" ] && found=true; done
  [ "$found" = true ] || fail "Template file is not listed as a manifest source: $relative"
done < <(find "$TEMPLATE_ROOT" -type f)

agent_root="$TEMPLATE_ROOT/.agents/agents"
if [ ! -d "$agent_root" ]; then
  fail "Missing shared agents directory: .agents/agents"
else
  agent_count=0
  while IFS= read -r agent; do
    agent_count=$((agent_count + 1))
    name="$(sed -n 's/^name:[[:space:]]*//p' "$agent" | head -n 1 | tr -d '\"' | tr -d "'")"
    description="$(sed -n 's/^description:[[:space:]]*//p' "$agent" | head -n 1)"
    filename="$(basename "$agent" .md)"
    [ -n "$name" ] || fail "Agent $filename is missing name"
    [ -n "$description" ] || fail "Agent $filename is missing description"
    [[ "$name" =~ ^[a-z0-9-]+$ ]] || fail "Agent $filename has invalid name: $name"
    [ "$name" = "$filename" ] || fail "Agent name $name does not match file $filename.md"
    agent_rel=".agents/agents/$filename.md"
    match_count=0
    for index in "${!manifest_destinations[@]}"; do
      if [ "${manifest_sources[$index]}" = "$agent_rel" ] &&
         [ "${manifest_destinations[$index]}" = "$agent_rel" ]; then
        match_count=$((match_count + 1))
      fi
    done
    [ "$match_count" -eq 1 ] || fail "Agent $filename.md must be listed once in pack-manifest.txt"
  done < <(find "$agent_root" -type f -name '*.md')
  [ "$agent_count" -eq 10 ] || fail "Expected 10 specialist agents in .agents/agents, found $agent_count"
fi

[ ! -e "$TEMPLATE_ROOT/.grok" ] || fail "Vendor-specific .grok directory must not exist in repo-template"

while IFS= read -r skill; do
  folder="$(basename "$(dirname "$skill")")"
  name="$(sed -n 's/^name:[[:space:]]*//p' "$skill" | head -n 1)"
  description="$(sed -n 's/^description:[[:space:]]*//p' "$skill" | head -n 1)"
  [ -n "$name" ] || fail "Skill $folder is missing name"
  [ -n "$description" ] || fail "Skill $folder is missing description"
  [ "$name" = "$folder" ] || fail "Skill $folder name does not match folder"
  [[ "$name" =~ ^[a-z0-9-]+$ ]] || fail "Skill $name violates naming rules"
done < <(find "$TEMPLATE_ROOT/.agents/skills" -type f -name SKILL.md)

if grep -RInE 'Aptos|M & Y TECH|Portal de Vendas|projetos/' "$TEMPLATE_ROOT" "$PACK_ROOT/README.md" "$PACK_ROOT/MANUAL_DE_USO.md" "$PACK_ROOT/INSTRUCOES_DETALHADAS.md" "$PACK_ROOT/global/AGENTS.md" >/dev/null 2>&1; then
  fail "Obsolete organization-specific references found"
fi

stale_version_hits=""
while IFS= read -r rel_file; do
  case "$rel_file" in
    CHANGELOG.md|compat/*|tests/*|scripts/update-agent-pack.sh|scripts/update-agent-pack.ps1) continue ;;
  esac
  if perl -e '
    use strict; use warnings; use utf8;
    open my $fh, "<:raw", $ARGV[0] or exit 1;
    local $/ = undef;
    my $data = <$fh>;
    close $fh;
    exit 1 if !defined($data) || index($data, "\0") >= 0;
    utf8::decode($data);
    if ($data =~ /(?:Engineering Flow [345]\.[01]|\bv5\.[01]\b(?!\.)|padr[aã]o 5\.[01]\b(?!\.)|pack 5\.[01]\b(?!\.)|instala[cç][aã]o limpa(?: da)? v?5\.[01]\b(?!\.))/i) {
      exit 0;
    }
    exit 1;
  ' "$PACK_ROOT/$rel_file"; then
    stale_version_hits="${stale_version_hits}${stale_version_hits:+, }$rel_file"
  fi
done < <(cd "$PACK_ROOT" && find . -path './.git' -prune -o -type f -print | sed 's|^\./||' | sort)
if [ -n "$stale_version_hits" ]; then
  fail "Obsolete version title (3.0/4.0/5.0/5.1) found in: $stale_version_hits"
fi

encoding_checker="$TEMPLATE_ROOT/.agents/skills/check-text-encoding/scripts/check-mojibake.sh"
if [ -f "$encoding_checker" ]; then
  bash "$encoding_checker" --repo "$PACK_ROOT" --all || fail "Text encoding validation failed"
else
  fail "Missing shell text encoding checker"
fi

[ "$errors" -eq 0 ] || exit 1
echo "Pack validation passed: manifest, shared skills, specialist agents and generic-content checks are valid."
