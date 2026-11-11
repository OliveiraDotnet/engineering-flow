#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'USAGE'
Usage:
  run-tester.sh --card-id <AB-ID> [--demand-type Bug|Feature|Refactor] [--phase r0-red|validate] --test-cmd <cmd> [--repo <path>]
USAGE
}

card_id=""
demand_type="Feature"
phase="validate"
test_cmd="${EF_TEST_CMD:-}"
repo="."

while [ "$#" -gt 0 ]; do
  case "$1" in
    --card-id) card_id="${2:?--card-id requires a value}"; shift 2 ;;
    --demand-type) demand_type="${2:?--demand-type requires a value}"; shift 2 ;;
    --phase) phase="${2:?--phase requires a value}"; shift 2 ;;
    --test-cmd) test_cmd="${2:?--test-cmd requires a value}"; shift 2 ;;
    --repo) repo="${2:?--repo requires a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "$card_id" ] || { echo "Error: --card-id is required." >&2; exit 2; }
case "$demand_type" in Bug|Feature|Refactor) ;; *) echo "Error: Invalid --demand-type '$demand_type'." >&2; exit 2 ;; esac
case "$phase" in r0-red|validate) ;; *) echo "Error: Invalid --phase '$phase'." >&2; exit 2 ;; esac
[ -n "$test_cmd" ] || { echo "Error: --test-cmd is required." >&2; exit 2; }

REPO_ROOT="$(cd "$repo" && pwd -P)"
EVIDENCE_DIR="$REPO_ROOT/.agent-pack/evidencias/$card_id"
RUNTIME_DIR="$REPO_ROOT/.agent-pack/.runtime"
mkdir -p "$EVIDENCE_DIR" "$RUNTIME_DIR"

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "==> [TESTER] Validando Card $card_id (Tipo: $demand_type, Fase: $phase)..."

test_output="$(cd "$REPO_ROOT" && bash -c "$test_cmd" 2>&1)"
test_exit_code=$?

if [ "$phase" = "r0-red" ]; then
  r0_red_file="$EVIDENCE_DIR/r0-red.log"
  printf '%s\n' "$test_output" > "$r0_red_file"
  if [ "$test_exit_code" -ne 0 ]; then
    echo "==> [TESTER] R0-RED confirmado (teste falhou antes da correcao com exit $test_exit_code)."
    exit 0
  else
    echo "==> [TESTER] ERRO R0-RED: o teste de regressao passou antes da correcao (exit 0). O R0 deve falhar antes do fix." >&2
    exit 2
  fi
fi

passed=false
status_label="FALHA (RED)"
if [ "$test_exit_code" -eq 0 ]; then
  passed=true
  status_label="APROVADO (GREEN)"
fi

evidence_file="$EVIDENCE_DIR/EVIDENCIA.md"
r0_section=""
if [ "$demand_type" = "Bug" ]; then
  if [ -f "$EVIDENCE_DIR/r0-red.log" ]; then
    r0_section="## Comprovacao R0-RED (Falha Antes do Fix)"$'\n```text\n'"$(cat "$EVIDENCE_DIR/r0-red.log")"$'\n```\n\n'
  else
    r0_section="## Comprovacao R0-RED"$'\n- Status: Nao registrado ou dispensado explicitamente no Gate 1.\n\n'
  fi
fi

{
  printf '# Evidencia de Testes — Card %s\n\n' "$card_id"
  printf -- '- **Tipo de Demanda:** %s\n' "$demand_type"
  printf -- '- **Data/Hora (UTC):** %s\n' "$timestamp"
  printf -- '- **Comando Executado:** `%s`\n' "$test_cmd"
  printf -- '- **Codigo de Saida:** `%d`\n' "$test_exit_code"
  printf -- '- **Status Final:** %s\n\n' "$status_label"
  [ -n "$r0_section" ] && printf '%s' "$r0_section"
  printf '## Output da Validacao (%s)\n```text\n%s\n```\n' "$phase" "$test_output"
} > "$evidence_file"

status_file="$RUNTIME_DIR/test-status.json"
{
  printf '{\n'
  printf '  "cardId": "%s",\n' "$card_id"
  printf '  "demandType": "%s",\n' "$demand_type"
  printf '  "phase": "%s",\n' "$phase"
  printf '  "passed": %s,\n' "$passed"
  printf '  "exitCode": %d,\n' "$test_exit_code"
  printf '  "evidencePath": "%s",\n' ".agent-pack/evidencias/$card_id/EVIDENCIA.md"
  printf '  "timestamp": "%s"\n' "$timestamp"
  printf '}\n'
} > "$status_file"

if [ "$passed" = true ]; then
  echo "==> [TESTER] Testes passaram com sucesso. Evidencia pronta para Gate 2 em $evidence_file."
  exit 0
else
  echo "==> [TESTER] Testes falharam (exit $test_exit_code). Feedback salvo para o Implementor." >&2
  exit 2
fi
