#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  verify-envelope.sh [--repo <path>] [--task-spec <path>] [--test-status <path>] [--skip-evidence-check] [--record-violation]

Deterministic pre-Gate 2 guardrail:
  1. Fails (10) if current branch is main or master.
  2. Fails (12) if operational SpecGuard files are staged in Git.
  3. Fails (11) if modified/untracked files exceed TASK_SPEC ef:paths.
  4. Fails (13/14) if test-status.json reports SECRET_IN_LOG or passed != true.
USAGE
}

repo="."; task_spec=""; test_status=""; skip_evidence=0; record_violation=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:?--repo requires a value}"; shift 2 ;;
    --task-spec) task_spec="${2:?--task-spec requires a value}"; shift 2 ;;
    --test-status) test_status="${2:?--test-status requires a value}"; shift 2 ;;
    --skip-evidence-check) skip_evidence=1; shift ;;
    --record-violation) record_violation=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" || { echo "FAIL [1]: Not a git repository: $repo" >&2; exit 1; }
TASK_SPEC="${task_spec:-$REPO_ROOT/.agent-pack/.runtime/TASK_SPEC.md}"
TEST_STATUS="${test_status:-$REPO_ROOT/.agent-pack/.runtime/test-status.json}"

fail_envelope() {
  local code="$1" msg="$2"
  if [ "$record_violation" -eq 1 ] && [ -f "$SCRIPT_DIR/session-state.sh" ]; then
    bash "$SCRIPT_DIR/session-state.sh" update --repo "$REPO_ROOT" --increment-envelope-violation >/dev/null 2>&1 || true
  fi
  echo "ENVELOPE_VIOLATION [$code]: $msg" >&2
  exit "$code"
}

branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  fail_envelope 10 "Current branch '$branch' is protected. Work must happen on a card branch (feat/... or fix/...)."
fi

op_regex='^(\.agent-pack/|\.agents/|\.grok/|docs/engineering-flow/|docs/ai/|prompts/|Planejamento/|planejamento/|\.engineering-flow-evidence/|\.ai-memory\.toml$)|\.agent-pack\.new$|\.agent-pack\.backup-'
leaked="$(git -C "$REPO_ROOT" diff --cached --name-only 2>/dev/null | grep -E "$op_regex" || true)"
if [ -n "$leaked" ]; then
  fail_envelope 12 "Operational SpecGuard files staged in Git (must stay gitignored): $(printf '%s' "$leaked" | tr '\n' ', ')"
fi

[ -f "$TASK_SPEC" ] || fail_envelope 11 "TASK_SPEC.md not found at '$TASK_SPEC'."

allowed_list="$(awk '
  /<!--[[:space:]]*ef:paths:begin[[:space:]]*-->/ { inb=1; next }
  /<!--[[:space:]]*ef:paths:end[[:space:]]*-->/ { inb=0; exit }
  inb {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "")
    if ($0 == "" || substr($0, 1, 1) == "#") next
    sub(/^[-*][[:space:]]+/, "")
    gsub(/`/, "")
    gsub(/^[[:space:]]+|[[:space:]]+$/, "")
    sub(/^\.\//, "")
    if ($0 != "") print $0
  }
' "$TASK_SPEC")"

[ -n "$allowed_list" ] || fail_envelope 11 "No files declared inside <!-- ef:paths:begin --> ... <!-- ef:paths:end --> in '$TASK_SPEC'."

while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  case "$entry" in
    */|*"*"*|".") fail_envelope 11 "Invalid ef:paths entry '$entry' (directories/globs are forbidden; list individual files only)." ;;
  esac
done <<< "$allowed_list"

changed_count=0
out_of_env=""
while IFS= read -r line; do
  [ -n "$line" ] || continue
  raw="${line:3}"
  raw="${raw##* -> }"
  raw="${raw#\"}"
  raw="${raw%\"}"
  raw="${raw#./}"
  [ -n "$raw" ] || continue
  changed_count=$((changed_count + 1))
  if ! printf '%s\n' "$allowed_list" | grep -Fxq "$raw"; then
    out_of_env="${out_of_env}${out_of_env:+, }$raw"
  fi
done < <(git -C "$REPO_ROOT" status --porcelain --untracked-files=all 2>/dev/null)

if [ -n "$out_of_env" ]; then
  fail_envelope 11 "Modified/untracked files outside authorized ef:paths envelope: $out_of_env"
fi

if [ "$skip_evidence" -eq 0 ]; then
  [ -f "$TEST_STATUS" ] || fail_envelope 14 "test-status.json not found at '$TEST_STATUS'. Run Tester validation before Gate 2."
  if ! command -v python3 >/dev/null 2>&1; then
    fail_envelope 14 "python3 is required to validate test-status.json."
  fi
  set +e
  check_msg="$(python3 - "$TEST_STATUS" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    ts = json.load(fh)
reason = str(ts.get("reason") or "")
secret_status = str((ts.get("secretScan") or {}).get("status") or "")
if reason == "SECRET_IN_LOG" or (secret_status and secret_status != "clean"):
    print(f"13|Secret scan is not clean (reason='{reason}', secretScan.status='{secret_status}'). Gate 2 is blocked.")
    sys.exit(13)
passed = ts.get("passed") is True
allow_unval = ts.get("allowUnvalidated") is True and bool(str(ts.get("allowUnvalidatedReason") or "").strip())
if not passed and not allow_unval:
    print(f"14|Validation has not passed in test-status.json (passed={ts.get('passed')}, reason='{reason}').")
    sys.exit(14)
sys.exit(0)
PY
)"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    fail_envelope "$rc" "${check_msg#*|}"
  fi
fi

allowed_count="$(printf '%s\n' "$allowed_list" | wc -l | tr -d ' ')"
ev_label="verified"; [ "$skip_evidence" -eq 1 ] && ev_label="skipped"
echo "ENVELOPE_OK: branch=$branch | files_changed=${changed_count}/${allowed_count} | operational_leaks=0 | evidence=$ev_label"
exit 0
