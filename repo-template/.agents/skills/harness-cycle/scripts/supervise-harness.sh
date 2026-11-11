#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  supervise-harness.sh --card-id <AB-ID> [--demand-type Bug|Feature|Refactor] [--max-retries 3] \
    --implementor-cmd <cmd> --test-cmd <cmd> [--r0-red-cmd <cmd>] [--skip-r0-red] [--task-spec <file>] [--repo <path>]
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
card_id=""
demand_type="Bug"
max_retries=3
implementor_cmd="${EF_IMPLEMENTOR_CMD:-}"
test_cmd="${EF_TEST_CMD:-}"
r0_red_cmd=""
skip_r0_red=false
task_spec=""
repo="."

while [ "$#" -gt 0 ]; do
  case "$1" in
    --card-id) card_id="${2:?--card-id requires a value}"; shift 2 ;;
    --demand-type) demand_type="${2:?--demand-type requires a value}"; shift 2 ;;
    --max-retries) max_retries="${2:?--max-retries requires a value}"; shift 2 ;;
    --implementor-cmd) implementor_cmd="${2:?--implementor-cmd requires a value}"; shift 2 ;;
    --test-cmd) test_cmd="${2:?--test-cmd requires a value}"; shift 2 ;;
    --r0-red-cmd) r0_red_cmd="${2:?--r0-red-cmd requires a value}"; shift 2 ;;
    --skip-r0-red) skip_r0_red=true; shift ;;
    --task-spec) task_spec="${2:?--task-spec requires a value}"; shift 2 ;;
    --repo) repo="${2:?--repo requires a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "$card_id" ] || { echo "Error: --card-id is required." >&2; exit 2; }
[ -n "$implementor_cmd" ] || { echo "Error: --implementor-cmd is required." >&2; exit 2; }
[ -n "$test_cmd" ] || { echo "Error: --test-cmd is required." >&2; exit 2; }

REPO_ROOT="$(cd "$repo" && pwd -P)"
rm -f -- "$REPO_ROOT/.agent-pack/.runtime/test-status.json"

if [ "$demand_type" = "Bug" ] && [ "$skip_r0_red" != true ]; then
  effective_r0_cmd="${r0_red_cmd:-$test_cmd}"
  echo "========================================================"
  echo "Fase Pre-Fix: Validando R0-RED para o Card $card_id"
  echo "========================================================"
  bash "$SCRIPT_DIR/run-tester.sh" \
    --card-id "$card_id" \
    --demand-type "$demand_type" \
    --phase r0-red \
    --test-cmd "$effective_r0_cmd" \
    --repo "$REPO_ROOT"
fi

skill_name='$feature-slice'
case "$demand_type" in
  Bug) skill_name='$bugfix' ;;
  Refactor) skill_name='$refactor' ;;
esac

attempt=1
success=false
while [ "$attempt" -le "$max_retries" ]; do
  echo "========================================================"
  echo "Ciclo de Harness: Tentativa $attempt de $max_retries (Card: $card_id)"
  echo "========================================================"
  export EF_ATTEMPT="$attempt"

  imp_args=(--card-id "$card_id" --skill "$skill_name" --harness-cmd "$implementor_cmd" --repo "$REPO_ROOT")
  [ -n "$task_spec" ] && imp_args+=(--task-spec "$task_spec")
  bash "$SCRIPT_DIR/run-implementor.sh" "${imp_args[@]}"

  set +e
  bash "$SCRIPT_DIR/run-tester.sh" \
    --card-id "$card_id" \
    --demand-type "$demand_type" \
    --phase validate \
    --test-cmd "$test_cmd" \
    --repo "$REPO_ROOT"
  test_rc=$?
  set -e

  if [ "$test_rc" -eq 0 ]; then
    success=true
    break
  fi

  echo "Aviso: Testes falharam na tentativa $attempt. Retornando feedback para o Implementor..." >&2
  attempt=$((attempt + 1))
done

if [ "$success" = true ]; then
  echo ""
  echo "[HARNESS CONCLUIDO COM SUCESSO]"
  echo "Evidencias disponiveis em: .agent-pack/evidencias/$card_id/EVIDENCIA.md"
  echo "Aguardando aprovacao humana (Gate 2) para o Implementor realizar o commit."
  exit 0
else
  echo "" >&2
  echo "[UNABLE_TO_VALIDATE] Limite de $max_retries tentativas atingido sem aprovacao nos testes para o Card $card_id." >&2
  exit 1
fi
