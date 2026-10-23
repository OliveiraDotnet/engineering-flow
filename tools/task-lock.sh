#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  task-lock.sh acquire --task <id> [--harness <name>] [--branch <name>] [--bot <name>] [--repo <path>]
  task-lock.sh release [--task <id>] [--force] [--repo <path>]
  task-lock.sh status [--repo <path>]

Lock file: <repo>/.agent-pack/.runtime/task.lock
The lock expires when HEAD differs from the recorded HEAD (a commit happened).
USAGE
}

[ $# -ge 1 ] || { usage >&2; exit 2; }
command="$1"; shift
case "$command" in acquire|release|status) ;; -h|--help) usage; exit 0 ;; *) echo "Unknown command: $command" >&2; usage >&2; exit 2 ;; esac

task=""; harness="Grok Build"; branch=""; bot=""; repo="."; force=false
while [ $# -gt 0 ]; do
  case "$1" in
    --task) task="${2:?--task requires a value}"; shift 2 ;;
    --harness) harness="${2:?--harness requires a value}"; shift 2 ;;
    --branch) branch="${2:?--branch requires a value}"; shift 2 ;;
    --bot) bot="${2:?--bot requires a value}"; shift 2 ;;
    --repo) repo="${2:?--repo requires a value}"; shift 2 ;;
    --force) force=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" || { echo "Not a git repository: $repo" >&2; exit 1; }
LOCK_DIR="$REPO_ROOT/.agent-pack/.runtime"
LOCK_FILE="$LOCK_DIR/task.lock"
current_head="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo none)"

read_field() {
  local key="$1" line
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    if [ "${line%%=*}" = "$key" ]; then printf '%s' "${line#*=}"; return 0; fi
  done < "$LOCK_FILE"
  printf ''
}

lock_state() {
  # prints: none | active | expired
  if [ ! -f "$LOCK_FILE" ]; then echo none; return; fi
  if [ "$(read_field head)" = "$current_head" ]; then echo active; else echo expired; fi
}

print_lock() {
  local state="$1"
  echo "Lock: $LOCK_FILE ($state)"
  for key in harness task branch bot acquired_at head; do
    printf '  %-12s %s\n' "$key:" "$(read_field "$key")"
  done
  if [ "$state" = expired ]; then echo "  HEAD changed to $current_head; lock expired by commit."; fi
}

case "$command" in
  status)
    state="$(lock_state)"
    if [ "$state" = none ]; then echo "no lock"; else print_lock "$state"; fi
    ;;
  acquire)
    [ -n "$task" ] || { echo "acquire requires --task <id>" >&2; exit 2; }
    if [ -z "$branch" ]; then branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"; fi
    state="$(lock_state)"
    if [ "$state" = active ]; then
      held_task="$(read_field task)"; held_harness="$(read_field harness)"
      if [ "$held_task" = "$task" ] && [ "$held_harness" = "$harness" ]; then
        echo "Lock already held by '$harness' for task '$task' (no change)."
        exit 0
      fi
      echo "Task lock conflict: held by harness '$held_harness' for task '$held_task' (branch '$(read_field branch)', since $(read_field acquired_at))." >&2
      echo "Wait for release, or have the demand bot run: task-lock.sh release --force" >&2
      exit 3
    fi
    [ "$state" = expired ] && echo "Previous lock expired (HEAD changed); overwriting."
    mkdir -p "$LOCK_DIR"
    tmp="$LOCK_FILE.tmp.$$"
    {
      printf 'harness=%s\n' "$harness"
      printf 'task=%s\n' "$task"
      printf 'branch=%s\n' "$branch"
      printf 'bot=%s\n' "$bot"
      printf 'acquired_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      printf 'head=%s\n' "$current_head"
    } > "$tmp"
    mv -f -- "$tmp" "$LOCK_FILE"
    echo "Lock acquired by '$harness' for task '$task' on branch '$branch' at HEAD $current_head."
    ;;
  release)
    state="$(lock_state)"
    if [ "$state" = none ]; then echo "no lock"; exit 0; fi
    held_task="$(read_field task)"
    if [ "$force" = false ] && [ "$state" = active ] && { [ -z "$task" ] || [ "$task" != "$held_task" ]; }; then
      echo "Lock belongs to task '$held_task'. Pass --task $held_task, or use --force to release a forgotten lock." >&2
      exit 4
    fi
    rm -f -- "$LOCK_FILE"
    echo "Lock released (task '$held_task')."
    ;;
esac
