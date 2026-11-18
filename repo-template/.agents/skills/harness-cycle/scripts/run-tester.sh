#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=ef-secrets.sh
source "$SCRIPT_DIR/ef-secrets.sh"

usage() {
  cat <<'USAGE'
Usage:
  run-tester.sh --card-id <AB-ID> [--demand-type Bug|Feature|Refactor] [--phase r0-red|validate] \
    --test-cmd <cmd> [--test-label <label>] [--harness <agy|claude|grok>] [--harness-args <flags>] \
    [--harness-cmd <cmd>] [--repo <path>]
USAGE
}

card_id=""
demand_type="Feature"
phase="validate"
test_cmd="${EF_TEST_CMD:-}"
test_label=""
harness="${EF_HARNESS:-}"
harness_args="${EF_HARNESS_ARGS:-}"
harness_cmd="${EF_TESTER_CMD:-}"
repo="."

while [ "$#" -gt 0 ]; do
  case "$1" in
    --card-id) card_id="${2:?--card-id requires a value}"; shift 2 ;;
    --demand-type) demand_type="${2:?--demand-type requires a value}"; shift 2 ;;
    --phase) phase="${2:?--phase requires a value}"; shift 2 ;;
    --test-cmd) test_cmd="${2:?--test-cmd requires a value}"; shift 2 ;;
    --test-label) test_label="${2:?--test-label requires a value}"; shift 2 ;;
    --harness) harness="${2:?--harness requires a value}"; shift 2 ;;
    --harness-args) harness_args="${2:?--harness-args requires a value}"; shift 2 ;;
    --harness-cmd) harness_cmd="${2:?--harness-cmd requires a value}"; shift 2 ;;
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
HARNESS_LOG_DIR="${EF_HARNESS_LOG_DIR:-$REPO_ROOT/.agent-pack/logs/$card_id}"
evidence_file="$EVIDENCE_DIR/EVIDENCIA.md"

ef_load_secrets "$REPO_ROOT" "$HARNESS_LOG_DIR" || exit $?

if [ "$phase" = "validate" ]; then
  ef_validate_evidence_markers "$evidence_file" || exit 2
fi

parsed_hargs=()
if [ -n "$harness_args" ]; then
  while IFS= read -r tok; do
    [ -n "$tok" ] && parsed_hargs+=("$tok")
  done < <(ef_split_args "$harness_args")
fi
harness_flag_names="$(ef_extract_flag_names "${parsed_hargs[@]+"${parsed_hargs[@]}"}")"

if [ -n "$harness" ]; then
  case "$harness" in
    agy)
      ef_check_agy_effort "${parsed_hargs[@]+"${parsed_hargs[@]}"}" || exit 2
      ;;
    claude) ;;
    grok)
      if [ "${#parsed_hargs[@]}" -eq 0 ]; then
        echo "Error: --harness grok requires explicit --harness-args." >&2
        exit 2
      fi
      ;;
    *)
      echo "Error: Unknown --harness '$harness'. Allowed: agy, claude, grok." >&2
      exit 2
      ;;
  esac
fi

mkdir -p "$EVIDENCE_DIR" "$RUNTIME_DIR" "$HARNESS_LOG_DIR"

attempt="${EF_ATTEMPT:-1}"
if [ -n "$harness" ] || [ -n "$harness_cmd" ]; then
  prompt_file="$REPO_ROOT/prompts/13-tester-harness.md"
  base_prompt=""
  [ -f "$prompt_file" ] && base_prompt="$(cat "$prompt_file")"
  raw_tester_prompt="# Contexto de Execucao — Tester"$'\n'"- Card: $card_id"$'\n'"- DemandType: $demand_type"$'\n'"- Phase: $phase"$'\n\n'"$base_prompt"$'\n'
  masked_tester_prompt="$(ef_mask_string "$raw_tester_prompt")"
  tester_prompt_file="$RUNTIME_DIR/tester-prompt-$card_id.md"
  printf '%s' "$masked_tester_prompt" > "$tester_prompt_file"

  export EF_CARD_ID="$card_id"
  export EF_PHASE="$phase"
  export EF_PROMPT_FILE="$tester_prompt_file"

  stdout_log="$HARNESS_LOG_DIR/${card_id}_tester_attempt${attempt}.jsonl"
  stderr_log="$HARNESS_LOG_DIR/${card_id}_tester_attempt${attempt}.err"
  : > "$stdout_log"
  : > "$stderr_log"

  cmd_argv=()
  if [ -n "$harness" ]; then
    case "$harness" in
      agy)
        has_effort=false
        for tok in "${parsed_hargs[@]+"${parsed_hargs[@]}"}"; do
          case "$tok" in --effort|--effort=*) has_effort=true ;; esac
        done
        cmd_argv=(agy -p "$masked_tester_prompt" --model gemini-4-hydrogen-high)
        [ "$has_effort" = false ] && cmd_argv+=(--effort high)
        cmd_argv+=(--output-format stream-json)
        [ "${#parsed_hargs[@]}" -gt 0 ] && cmd_argv+=("${parsed_hargs[@]}")
        ;;
      claude)
        cmd_argv=(claude -p "$masked_tester_prompt" --output-format stream-json --verbose)
        [ "${#parsed_hargs[@]}" -gt 0 ] && cmd_argv+=("${parsed_hargs[@]}")
        ;;
      grok)
        cmd_argv=(grok "${parsed_hargs[@]}")
        ;;
    esac
  else
    cmd_argv=(bash -c "$harness_cmd")
  fi

  fifo_dir="$(mktemp -d "${TMPDIR:-/tmp}/ef-tester-fifo.XXXXXX")"
  mkfifo "$fifo_dir/out" "$fifo_dir/err"
  out_cnt_file="$fifo_dir/out.cnt"
  err_cnt_file="$fifo_dir/err.cnt"

  ef_mask --count-file "$out_cnt_file" < "$fifo_dir/out" | tee "$stdout_log" &
  pid_out=$!
  ef_mask --count-file "$err_cnt_file" < "$fifo_dir/err" | tee "$stderr_log" >&2 &
  pid_err=$!

  (cd "$REPO_ROOT" && "${cmd_argv[@]}") > "$fifo_dir/out" 2> "$fifo_dir/err"
  harness_rc=$?

  wait "$pid_out" "$pid_err"
  rm -rf -- "$fifo_dir"

  if [ "$harness_rc" -ne 0 ]; then
    ef_scan "$REPO_ROOT" "$card_id" "$HARNESS_LOG_DIR"
    scan_rc=$?
    if [ "$scan_rc" -eq 6 ]; then
      timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      ef_write_test_status "$RUNTIME_DIR/test-status.json" scan_fail \
        cardId "$card_id" \
        evidencePath ".agent-pack/evidencias/$card_id/EVIDENCIA.md" \
        timestamp "$timestamp"
      exit 6
    fi
    exit "$harness_rc"
  fi
fi

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "==> [TESTER] Validando Card $card_id (Tipo: $demand_type, Fase: $phase)..."

cmd_sha256="$(printf '%s' "$test_cmd" | sha256sum | cut -c1-12)"
masked_label=""
if [ -n "$test_label" ]; then
  masked_label="$(ef_mask_string "$test_label")"
fi

raw_output="$(cd "$REPO_ROOT" && bash -c "$test_cmd" 2>&1; rc=$?; printf '\001'; exit "$rc")"
test_exit_code=$?
raw_output="${raw_output%$'\001'}"

masked_output="$(ef_mask_string "$raw_output")"
mask_count="${_EF_LAST_MASK_COUNT:-0}"
if [ -n "$masked_output" ] && [ "${masked_output: -1}" != $'\n' ]; then
  masked_output+=$'\n'
fi

if [ "$phase" = "r0-red" ]; then
  r0_red_file="$EVIDENCE_DIR/r0-red.log"
  r0_tmp="$EVIDENCE_DIR/.r0-red.tmp.$$"
  printf '%s' "$masked_output" > "$r0_tmp"
  mv -f -- "$r0_tmp" "$r0_red_file"

  ef_scan "$REPO_ROOT" "$card_id" "$HARNESS_LOG_DIR"
  scan_rc=$?
  if [ "$scan_rc" -eq 6 ]; then
    ef_write_test_status "$RUNTIME_DIR/test-status.json" scan_fail \
      cardId "$card_id" \
      evidencePath ".agent-pack/evidencias/$card_id/EVIDENCIA.md" \
      timestamp "$timestamp"
    echo "==> [TESTER] ERRO CRITICO: SECRET_IN_LOG detectado durante r0-red." >&2
    exit 6
  fi

  if [ "$test_exit_code" -ne 0 ]; then
    echo "==> [TESTER] R0-RED confirmado (teste falhou antes da correcao com exit $test_exit_code)."
    exit 0
  else
    echo "==> [TESTER] ERRO R0-RED: o teste de regressao passou antes da correcao (exit 0). O R0 deve falhar antes do fix." >&2
    exit 2
  fi
fi

output_log_file="$EVIDENCE_DIR/test-output.log"
output_tmp="$EVIDENCE_DIR/.test-output.tmp.$$"
printf '%s' "$masked_output" > "$output_tmp"
mv -f -- "$output_tmp" "$output_log_file"
line_count="$(wc -l < "$output_log_file" | tr -d '[:space:]')"
[ -n "$line_count" ] || line_count=0

ef_scan "$REPO_ROOT" "$card_id" "$HARNESS_LOG_DIR"
scan_rc=$?

passed=false
reason=""
status_label="FALHA (RED)"
final_exit=2
if [ "$scan_rc" -eq 6 ]; then
  passed=false
  reason="SECRET_IN_LOG"
  status_label="BLOQUEADO (SECRET_IN_LOG)"
  final_exit=6
elif [ "$test_exit_code" -eq 0 ]; then
  passed=true
  status_label="APROVADO (GREEN)"
  final_exit=0
fi

findings_summary=""
if [ "${#_EF_SCAN_FINDINGS[@]}" -gt 0 ]; then
  for entry in "${_EF_SCAN_FINDINGS[@]}"; do
    f_rel="${entry%%$'\t'*}"
    f_cnt="${entry#*$'\t'}"
    [ -n "$findings_summary" ] && findings_summary+=", "
    findings_summary+="$f_rel ($f_cnt)"
  done
fi
unscanned_summary=""
if [ "${#_EF_SCAN_UNSCANNED[@]}" -gt 0 ]; then
  local_ifs="$IFS"
  IFS=", "
  unscanned_summary="${_EF_SCAN_UNSCANNED[*]}"
  IFS="$local_ifs"
fi

runner_block="- **Fase:** $phase
- **Tipo de Demanda:** $demand_type
- **Data/Hora (UTC):** $timestamp
- **Codigo de Saida:** \`$test_exit_code\`
- **Status Final:** $status_label
- **commandSha256:** \`$cmd_sha256\`"
[ -n "$masked_label" ] && runner_block+=$'\n'"- **testLabel:** $masked_label"
if [ -n "$harness" ]; then
  runner_block+=$'\n'"- **harness:** \`$harness\`"
  [ -n "$harness_flag_names" ] && runner_block+=" (flags: \`$harness_flag_names\`)"
fi
if [ "$demand_type" = "Bug" ]; then
  if [ -f "$EVIDENCE_DIR/r0-red.log" ]; then
    runner_block+=$'\n'"- **R0-RED:** \`.agent-pack/evidencias/$card_id/r0-red.log\`"
  else
    runner_block+=$'\n'"- **R0-RED:** Nao registrado ou dispensado explicitamente no Gate 1"
  fi
fi
runner_block+=$'\n'"- **Log de Saida:** \`.agent-pack/evidencias/$card_id/test-output.log\` (lines: $line_count, masked: $mask_count)"
scan_line="- **Secret Scan:** $_EF_SCAN_STATUS"
[ -n "$findings_summary" ] && scan_line+="; findings: $findings_summary"
[ -n "$unscanned_summary" ] && scan_line+="; unscanned: $unscanned_summary"
runner_block+=$'\n'"$scan_line"

ef_update_evidence_block "$evidence_file" "$card_id" "replace" "$runner_block" || exit 2

ef_write_test_status "$RUNTIME_DIR/test-status.json" tester \
  cardId "$card_id" \
  demandType "$demand_type" \
  phase "$phase" \
  passed "$passed" \
  exitCode "$test_exit_code" \
  evidencePath ".agent-pack/evidencias/$card_id/EVIDENCIA.md" \
  timestamp "$timestamp" \
  reason "$reason" \
  scanStatus "$_EF_SCAN_STATUS"

if [ "$final_exit" -eq 6 ]; then
  echo "==> [TESTER] ERRO CRITICO: SECRET_IN_LOG detectado. Gate 2 bloqueado." >&2
  exit 6
elif [ "$passed" = true ]; then
  echo "==> [TESTER] Testes passaram com sucesso. Evidencia pronta para Gate 2 em $evidence_file."
  exit 0
else
  echo "==> [TESTER] Testes falharam (exit $test_exit_code). Feedback salvo para o Implementor." >&2
  exit 2
fi
