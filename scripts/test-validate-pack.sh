#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/test-validate-pack.XXXXXX")"
cleanup() {
  case "$TEMP_ROOT" in "${TMPDIR:-/tmp}"/test-validate-pack.*) rm -rf -- "$TEMP_ROOT" ;; *) echo 'Unsafe cleanup path' >&2; return 1 ;; esac
}
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

copy_pack_without_git() {
  local dest="$1"
  mkdir -p "$dest"
  tar -C "$PACK_ROOT" --exclude='.git' -cf - . | tar -C "$dest" -xf -
  [ ! -e "$dest/.git" ] || fail "Temp copy must not contain .git"
}

run_negative_case() {
  local name="$1"
  local mutator="$2"
  local case_dir="$TEMP_ROOT/neg-$name"
  copy_pack_without_git "$case_dir"
  "$mutator" "$case_dir"
  if bash "$case_dir/scripts/validate-pack.sh" >/dev/null 2>&1; then
    fail "Negative case '$name' unexpectedly passed validate-pack.sh"
  fi
}

# Positive baseline: clean copy without .git must pass validate-pack.sh
valid_copy="$TEMP_ROOT/valid"
copy_pack_without_git "$valid_copy"
bash "$valid_copy/scripts/validate-pack.sh" >/dev/null || fail "Valid pack copy failed validate-pack.sh"

# P4 negative: removing the harness-only runner rule from harness-cycle/SKILL.md must fail
mutate_p4_remove_phrase() {
  local root="$1"
  local skill="$root/repo-template/.agents/skills/harness-cycle/SKILL.md"
  perl -i -0777 -pe 's/\Qonly the harness (Implementor\/Tester) runs the runners\E/the coordinator runs the runners/g' "$skill"
}
run_negative_case "p4-missing-harness-only-phrase" mutate_p4_remove_phrase

# C8 negative: injecting an obsolete version title into README.md must fail
mutate_c8_stale_title() {
  local root="$1"
  local stale="Engineering Flow ""4.0"
  printf '\n%s\n' "$stale" >> "$root/README.md"
}
run_negative_case "c8-stale-version-title" mutate_c8_stale_title

# N1 negative: injecting stale clean-install v5 + .0 phrase into a doc must fail
mutate_n1_stale_v50() {
  local root="$1"
  local stale="instalação limpa da v5"".0"
  printf '\n%s\n' "$stale" >> "$root/INSTRUCOES_DETALHADAS.md"
}
run_negative_case "n1-stale-v50-phrase" mutate_n1_stale_v50

# C10 negatives: removing required gate-1/external-boundary/escalation markers must fail
mutate_c10_implementor_decisions() {
  local root="$1"
  local f="$root/repo-template/prompts/12-implementor-harness.md"
  perl -i -0777 -pe 's/\Qdocs\/ai\/decisions-and-pendencies.md\E/docs\/ai\/removed.md/g' "$f"
}
run_negative_case "c10-implementor-missing-decisions" mutate_c10_implementor_decisions

mutate_c10_tester_boundaries() {
  local root="$1"
  local f="$root/repo-template/prompts/13-tester-harness.md"
  perl -i -0777 -pe 's/\Qdocs\/ai\/external-boundaries.md\E/docs\/ai\/removed.md/g' "$f"
}
run_negative_case "c10-tester-missing-boundaries" mutate_c10_tester_boundaries

mutate_c10_skill_blocked() {
  local root="$1"
  local f="$root/repo-template/.agents/skills/harness-cycle/SKILL.md"
  perl -i -0777 -pe 's/\QBLOCKED_BY_DECISION\E/REMOVED_MARKER/g' "$f"
}
run_negative_case "c10-skill-missing-blocked" mutate_c10_skill_blocked

echo "test-validate-pack.sh passed."
