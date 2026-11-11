#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  run-implementor.sh --card-id <AB-ID> [--skill <skill>] [--task-spec <file>] [--harness-cmd <cmd>] [--repo <path>]
  run-implementor.sh --card-id <AB-ID> --commit-gate2 --commit-message <msg> [--allow-unvalidated] [--repo <path>]
USAGE
}

card_id=""
skill='$bugfix'
task_spec=""
harness_cmd="${EF_IMPLEMENTOR_CMD:-}"
repo="."
commit_gate2=false
commit_message=""
allow_unvalidated=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --card-id) card_id="${2:?--card-id requires a value}"; shift 2 ;;
    --skill) skill="${2:?--skill requires a value}"; shift 2 ;;
    --task-spec) task_spec="${2:?--task-spec requires a value}"; shift 2 ;;
    --harness-cmd) harness_cmd="${2:?--harness-cmd requires a value}"; shift 2 ;;
    --repo) repo="${2:?--repo requires a value}"; shift 2 ;;
    --commit-gate2) commit_gate2=true; shift ;;
    --commit-message) commit_message="${2:?--commit-message requires a value}"; shift 2 ;;
    --allow-unvalidated) allow_unvalidated=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "$card_id" ] || { echo "Error: --card-id is required." >&2; exit 2; }
REPO_ROOT="$(cd "$repo" && pwd -P)"
RUNTIME_DIR="$REPO_ROOT/.agent-pack/.runtime"
STATUS_FILE="$RUNTIME_DIR/test-status.json"
LOCK_FILE="$RUNTIME_DIR/task.lock"

if [ "$commit_gate2" = true ]; then
  [ -n "$commit_message" ] || { echo "Error: --commit-message is required with --commit-gate2." >&2; exit 2; }
  branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  case "$branch" in
    main|master|"")
      echo "Error: Gate 2 commit is forbidden on branch '$branch'. Use a card branch (feat/$card_id-... or fix/$card_id-...)." >&2
      exit 3
      ;;
  esac
  if [ "$allow_unvalidated" != true ]; then
    [ -f "$STATUS_FILE" ] || { echo "Error: Missing test status file ($STATUS_FILE). Run Tester before Gate 2 commit." >&2; exit 4; }
    grep -Eq '"passed"[[:space:]]*:[[:space:]]*true' "$STATUS_FILE" || {
      echo "Error: Tester report does not indicate passed=true. Gate 2 commit aborted." >&2
      exit 4
    }
  fi
  git -C "$REPO_ROOT" add -A
  git -C "$REPO_ROOT" commit -m "$commit_message"
  rm -f -- "$LOCK_FILE"
  echo "[IMPLEMENTOR] Gate 2 commit completed on branch '$branch' and task.lock released."
  exit 0
fi

mkdir -p "$RUNTIME_DIR"
prompt_file="$REPO_ROOT/prompts/12-implementor-harness.md"
base_prompt=""
if [ -f "$prompt_file" ]; then
  base_prompt="$(cat "$prompt_file")"
fi

spec_content=""
if [ -n "$task_spec" ] && [ -f "$task_spec" ]; then
  spec_content="$(cat "$task_spec")"
fi

feedback_section=""
if [ -f "$STATUS_FILE" ] && grep -Eq '"passed"[[:space:]]*:[[:space:]]*false' "$STATUS_FILE"; then
  evidence_file="$REPO_ROOT/.agent-pack/evidencias/$card_id/EVIDENCIA.md"
  if [ -f "$evidence_file" ]; then
    feedback_section=$'\n[CORRECAO NECESSARIA - FALHA REPORTADA PELO TESTER]\n'"$(cat "$evidence_file")"
  else
    feedback_section=$'\n[CORRECAO NECESSARIA - FALHA REPORTADA PELO TESTER]\n'"$(cat "$STATUS_FILE")"
  fi
fi

context_file="$RUNTIME_DIR/implementor-prompt-$card_id.md"
{
  printf '# Contexto de Execucao — Implementor\n'
  printf -- '- Card: %s\n' "$card_id"
  printf -- '- Skill: %s\n\n' "$skill"
  [ -n "$base_prompt" ] && printf '%s\n\n' "$base_prompt"
  [ -n "$spec_content" ] && printf '## Especificacao da Tarefa\n%s\n\n' "$spec_content"
  [ -n "$feedback_section" ] && printf '%s\n' "$feedback_section"
} > "$context_file"

[ -n "$harness_cmd" ] || {
  echo "Error: No harness command provided. Pass --harness-cmd or set EF_IMPLEMENTOR_CMD." >&2
  exit 2
}

echo "==> [IMPLEMENTOR] Executando para o Card $card_id ($skill)..."
export EF_CARD_ID="$card_id"
export EF_SKILL="$skill"
export EF_PROMPT_FILE="$context_file"
(cd "$REPO_ROOT" && bash -c "$harness_cmd")
