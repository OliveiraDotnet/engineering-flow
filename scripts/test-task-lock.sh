#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
LOCK_TOOL="$PACK_ROOT/tools/task-lock.sh"

scratch="$(mktemp -d "${TMPDIR:-/tmp}/pack-task-lock.XXXXXX")"
cleanup() {
  case "$scratch" in "${TMPDIR:-/tmp}"/pack-task-lock.*) rm -rf -- "$scratch" ;; *) echo 'Unsafe cleanup target' >&2; return 1 ;; esac
}
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }
lock() { bash "$LOCK_TOOL" "$@" --repo "$scratch"; }
commit() { git -C "$scratch" -c user.name=test -c user.email=test@example.invalid commit -q --allow-empty -m "$1"; }

git -C "$scratch" init -q -b work
commit init
lock_file="$scratch/.agent-pack/.runtime/task.lock"

# status without lock
[ "$(lock status)" = "no lock" ] || fail 'status without lock'

# acquire
lock acquire --task T-1 --bot demand-bot >/dev/null || fail 'acquire'
[ -f "$lock_file" ] || fail 'lock file missing'
grep -qx 'harness=Grok Build' "$lock_file" || fail 'default harness'
grep -qx 'task=T-1' "$lock_file" || fail 'task field'
grep -qx 'branch=work' "$lock_file" || fail 'default branch'
grep -qx 'bot=demand-bot' "$lock_file" || fail 'bot field'
grep -qE '^acquired_at=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$lock_file" || fail 'ISO 8601 timestamp'
grep -qx "head=$(git -C "$scratch" rev-parse HEAD)" "$lock_file" || fail 'head field'
out="$(lock status)"; printf "%s\n" "$out" | grep -q '(active)' || fail 'status active'

# idempotent re-acquire
out="$(lock acquire --task T-1)"; printf "%s\n" "$out" | grep -q 'no change' || fail 'idempotent re-acquire'

# conflicts: other task, other harness
if lock acquire --task T-2 >/dev/null 2>&1; then fail 'conflict on other task'; fi
set +e; err="$(lock acquire --task T-1 --harness 'Other Harness' 2>&1 >/dev/null)"; rc=$?; set -e
[ "$rc" -ne 0 ] || fail 'conflict on other harness'
printf '%s\n' "$err" | grep -q 'Task lock conflict' || fail 'conflict message'
grep -qx 'task=T-1' "$lock_file" || fail 'conflict must not overwrite'

# release of another task requires --force
if lock release --task T-2 >/dev/null 2>&1; then fail 'release of other task without --force'; fi
[ -f "$lock_file" ] || fail 'lock removed without --force'
lock release --task T-1 >/dev/null || fail 'release own task'
[ ! -f "$lock_file" ] || fail 'release did not remove lock'
[ "$(lock status)" = "no lock" ] || fail 'status after release'

# release --force
lock acquire --task T-3 --harness 'Harness A' >/dev/null
lock release --force >/dev/null || fail 'release --force'
[ ! -f "$lock_file" ] || fail 'release --force did not remove lock'

# expiration by commit
lock acquire --task T-4 >/dev/null
commit second
out="$(lock status)"; printf "%s\n" "$out" | grep -q '(expired)' || fail 'status expired'
out="$(lock acquire --task T-5 --harness 'Harness B')"; printf "%s\n" "$out" | grep -q 'expired' || fail 'acquire over expired lock'
grep -qx 'task=T-5' "$lock_file" || fail 'expired lock not overwritten'
lock release --force >/dev/null

echo "Task lock tests passed."
