#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SUPERVISOR="$PACK_ROOT/repo-template/.agents/skills/harness-cycle/scripts/supervise-harness.sh"
IMPLEMENTOR="$PACK_ROOT/repo-template/.agents/skills/harness-cycle/scripts/run-implementor.sh"
LOCK_TOOL="$PACK_ROOT/tools/task-lock.sh"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/harness-cycle-tests.XXXXXX")"

cleanup() {
  case "$TEMP_ROOT" in
    "${TMPDIR:-/tmp}"/harness-cycle-tests.*) rm -rf -- "$TEMP_ROOT" ;;
    *) echo "Refusing to remove unexpected temp path: $TEMP_ROOT" >&2; return 1 ;;
  esac
}
trap cleanup EXIT

fail() {
  echo "TEST FAILURE: $*" >&2
  exit 1
}

init_repo() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email "ci@example.com"
  git -C "$repo" config user.name "CI Runner"
  printf '0\n' > "$repo/value.txt"
  git -C "$repo" add value.txt
  git -C "$repo" commit -q -m "initial"
}

# 1. Closed-loop R0-RED -> Implementor -> R0-GREEN -> FULL -> Gate 2 commit
REPO1="$TEMP_ROOT/repo-pass"
init_repo "$REPO1"
bash "$LOCK_TOOL" acquire --task AB-500 --repo "$REPO1" --bot "repo-lead" --harness "default" >/dev/null

bash "$SUPERVISOR" \
  --repo "$REPO1" \
  --card "AB-500" \
  --slug "fix-calculation" \
  --type "bug" \
  --harness-cmd "printf '1\n' > value.txt" \
  --test-cmd "grep -Fxq '1' value.txt" \
  --r0-cmd "grep -Fxq '1' value.txt" \
  --max-attempts 3 >/dev/null

[ -f "$REPO1/.agent-pack/.runtime/test-status.json" ] || fail "test-status.json was not generated"
grep -q '"status": "PASSED"' "$REPO1/.agent-pack/.runtime/test-status.json" || fail "Expected PASSED in test-status.json"
[ -f "$REPO1/.agent-pack/evidencias/AB-500/EVIDENCIA.md" ] || fail "EVIDENCIA.md was not generated"
grep -q "R0-RED" "$REPO1/.agent-pack/evidencias/AB-500/EVIDENCIA.md" || fail "Missing R0-RED evidence"
grep -q "R0-GREEN" "$REPO1/.agent-pack/evidencias/AB-500/EVIDENCIA.md" || fail "Missing R0-GREEN evidence"
grep -q "READY_FOR_GATE_2" "$REPO1/.agent-pack/.runtime/harness-cycle-summary.md" || fail "Expected READY_FOR_GATE_2 in summary"

# Verify Gate 2 commit and lock release
bash "$IMPLEMENTOR" \
  --repo "$REPO1" \
  --card "AB-500" \
  --slug "fix-calculation" \
  --type "bug" \
  --commit-gate2 \
  --commit-message "fix(AB-500): fix calculation" >/dev/null

[ "$(git -C "$REPO1" log -1 --pretty=%s)" = "fix(AB-500): fix calculation" ] || fail "Gate 2 commit was not created"
[ ! -f "$REPO1/.agent-pack/.runtime/task.lock" ] || fail "task.lock was not released after Gate 2 commit"

# 2. Retry loop: fails attempt 1, succeeds attempt 2
REPO2="$TEMP_ROOT/repo-retry"
init_repo "$REPO2"
bash "$SUPERVISOR" \
  --repo "$REPO2" \
  --card "AB-501" \
  --slug "retry-feature" \
  --type "feature" \
  --harness-cmd "if [ \"\$HARNESS_ATTEMPT\" = '2' ]; then printf '1\n' > value.txt; fi" \
  --test-cmd "grep -Fxq '1' value.txt" \
  --max-attempts 3 >/dev/null

grep -q '"status": "PASSED"' "$REPO2/.agent-pack/.runtime/test-status.json" || fail "Expected PASSED after retry"

# 3. 3-strike circuit breaker: fails 3 attempts -> exits 4
REPO3="$TEMP_ROOT/repo-fail"
init_repo "$REPO3"
rc=0
bash "$SUPERVISOR" \
  --repo "$REPO3" \
  --card "AB-502" \
  --slug "broken-feature" \
  --type "feature" \
  --harness-cmd "printf 'still-broken\n' > value.txt" \
  --test-cmd "grep -Fxq '1' value.txt" \
  --max-attempts 3 >/dev/null 2>&1 || rc=$?

[ "$rc" -eq 4 ] || fail "Expected exit code 4 on 3-strike circuit breaker, got $rc"
grep -q "UNABLE_TO_VALIDATE" "$REPO3/.agent-pack/.runtime/harness-cycle-summary.md" || fail "Expected UNABLE_TO_VALIDATE in summary"

echo "Harness cycle Bash tests passed: R0-RED/GREEN, FULL evidence, retry loop, 3-strike circuit breaker, and Gate 2 commit + lock expiration."
