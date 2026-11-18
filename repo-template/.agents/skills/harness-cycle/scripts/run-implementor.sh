#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=ef-secrets.sh
source "$SCRIPT_DIR/ef-secrets.sh"

usage() {
  cat <<'USAGE'
Usage:
  run-implementor.sh --card-id <AB-ID> [--skill <skill>] [--task-spec <file>] \
    [--harness <agy|claude|grok>] [--harness-args <flags>] [--harness-cmd <cmd>] [--repo <path>]
  run-implementor.sh --card-id <AB-ID> --commit-gate2 --commit-message <msg> \
    [--paths <p1,p2,...>] [--task-spec <file>] [--allow-unvalidated --reason <text>] [--repo <path>]
USAGE
}

card_id=""
skill='$bugfix'
task_spec=""
harness="${EF_HARNESS:-}"
harness_args="${EF_HARNESS_ARGS:-}"
harness_cmd="${EF_IMPLEMENTOR_CMD:-}"
repo="."
commit_gate2=false
commit_message=""
paths_raw=""
allow_unvalidated=false
reason=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --card-id) card_id="${2:?--card-id requires a value}"; shift 2 ;;
    --skill) skill="${2:?--skill requires a value}"; shift 2 ;;
    --task-spec) task_spec="${2:?--task-spec requires a value}"; shift 2 ;;
    --harness) harness="${2:?--harness requires a value}"; shift 2 ;;
    --harness-args) harness_args="${2:?--harness-args requires a value}"; shift 2 ;;
    --harness-cmd) harness_cmd="${2:?--harness-cmd requires a value}"; shift 2 ;;
    --repo) repo="${2:?--repo requires a value}"; shift 2 ;;
    --commit-gate2) commit_gate2=true; shift ;;
    --commit-message) commit_message="${2:?--commit-message requires a value}"; shift 2 ;;
    --paths)
      if [ -n "$paths_raw" ]; then
        paths_raw="$paths_raw,${2:?--paths requires a value}"
      else
        paths_raw="${2:?--paths requires a value}"
      fi
      shift 2
      ;;
    --allow-unvalidated) allow_unvalidated=true; shift ;;
    --reason) reason="${2:?--reason requires a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "$card_id" ] || { echo "Error: --card-id is required." >&2; exit 2; }
REPO_ROOT="$(cd "$repo" && pwd -P)"
RUNTIME_DIR="$REPO_ROOT/.agent-pack/.runtime"
EVIDENCE_DIR="$REPO_ROOT/.agent-pack/evidencias/$card_id"
HARNESS_LOG_DIR="${EF_HARNESS_LOG_DIR:-$REPO_ROOT/.agent-pack/logs/$card_id}"
STATUS_FILE="$RUNTIME_DIR/test-status.json"
LOCK_FILE="$RUNTIME_DIR/task.lock"
EVIDENCE_FILE="$EVIDENCE_DIR/EVIDENCIA.md"

ef_load_secrets "$REPO_ROOT" "$HARNESS_LOG_DIR" || exit $?

collect_protected_branches() {
  perl -e '
    use strict; use warnings;
    my ($repo, $env_branches) = @ARGV;
    my %prot = map { $_ => 1 } ("main", "master", "HEAD", "");
    my $add = sub {
      my ($raw) = @_;
      return unless defined $raw;
      for my $item (split /,/, $raw) {
        $item =~ s/^\s+|\s+$//g;
        $item =~ s/^\[|\]$//g;
        $item =~ s/^`|`$//g;
        $item =~ s/^\s+|\s+$//g;
        next unless length($item);
        next if $item eq "...";
        $prot{$item} = 1;
      }
    };
    $add->($env_branches);
    my $agents = "$repo/AGENTS.md";
    if (-f $agents) {
      if (open my $fh, "<:raw", $agents) {
        while (my $line = <$fh>) {
          $line =~ s/\r?\n$//;
          if ($line =~ /^\s*-\s*Branches\s+protegidas\s+\(harness\)\s*:\s*(.+)$/i) {
            $add->($1);
          }
        }
        close $fh;
      }
    }
    print "$_\n" for sort keys %prot;
  ' "$REPO_ROOT" "${EF_PROTECTED_BRANCHES:-}"
}

resolve_gate2_paths() {
  local raw_paths="$1"
  local spec_path="$2"
  EF_INT_PATHS="$raw_paths" perl -MCwd=abs_path -MFile::Spec -e '
    use strict; use warnings;
    my ($repo, $spec) = @ARGV;
    my $repo_abs = abs_path($repo) // File::Spec->rel2abs($repo);
    $repo_abs =~ s/\/+$//;
    my @candidates;
    if (length($ENV{EF_INT_PATHS} // "")) {
      for my $p (split /,/, $ENV{EF_INT_PATHS}) {
        $p =~ s/^\s+|\s+$//g;
        push @candidates, $p if length($p);
      }
    } elsif (length($spec) && -f $spec) {
      open my $fh, "<:raw", $spec or exit 5;
      my $in_block = 0;
      while (my $line = <$fh>) {
        $line =~ s/\r?\n$//;
        if ($line =~ /<!--\s*ef:paths:begin\s*-->/) { $in_block = 1; next; }
        if ($line =~ /<!--\s*ef:paths:end\s*-->/) { $in_block = 0; last; }
        next unless $in_block;
        $line =~ s/^\s+|\s+$//g;
        next if !length($line) || $line =~ /^#/;
        $line =~ s/^-\s+//;
        $line =~ s/^\s+|\s+$//g;
        if ($line =~ /^`([^`]+)`/) {
          $line = $1;
        } else {
          $line =~ s/^`|`$//g;
        }
        $line =~ s/^\s+|\s+$//g;
        push @candidates, $line if length($line);
      }
      close $fh;
    }

    if (!@candidates) {
      print STDERR "Error: Explicit --paths or TASK_SPEC ef:paths block is required for --commit-gate2.\n";
      exit 5;
    }

    my @clean;
    my %seen;
    for my $p (@candidates) {
      $p =~ s/\\/\//g;
      if ($p =~ /^\// || $p =~ /^[A-Za-z]:/ || $p =~ /^\\\\/) {
        print STDERR "Error: Forbidden absolute path in Gate 2 staging: $p\n";
        exit 5;
      }
      my @segs = grep { length($_) } split(/\//, $p);
      for my $seg (@segs) {
        if ($seg eq "..") {
          print STDERR "Error: Forbidden parent traversal (..) in Gate 2 staging: $p\n";
          exit 5;
        }
      }
      $p =~ s/^\.\///;
      $p =~ s/\/+$//;
      if (!length($p)) {
        print STDERR "Error: Empty path in Gate 2 staging.\n";
        exit 5;
      }
      if ($p =~ /^(?:\.agent-pack|\.agents|\.grok|prompts|docs\/engineering-flow)(?:\/|$)/) {
        print STDERR "Error: Forbidden protected path in Gate 2 staging: $p\n";
        exit 5;
      }
      my $full = File::Spec->catfile($repo_abs, $p);
      my $resolved = abs_path($full);
      if (defined $resolved) {
        $resolved =~ s/\/+$//;
        if ($resolved ne $repo_abs && index($resolved, "$repo_abs/") != 0) {
          print STDERR "Error: Path escapes repository root: $p\n";
          exit 5;
        }
      }
      push @clean, $p unless $seen{$p}++;
    }
    print "$_\n" for @clean;
  ' "$REPO_ROOT" "$spec_path"
}

if [ "$commit_gate2" = true ]; then
  [ -n "$commit_message" ] || { echo "Error: --commit-message is required with --commit-gate2." >&2; exit 2; }

  if [ "$allow_unvalidated" = true ]; then
    trimmed_reason="$(printf '%s' "$reason" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [ "${#trimmed_reason}" -lt 10 ]; then
      echo "Error: --allow-unvalidated requires --reason with at least 10 characters." >&2
      exit 2
    fi
  fi

  branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  is_protected=false
  if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then
    is_protected=true
  else
    while IFS= read -r pb; do
      if [ "$pb" = "$branch" ]; then
        is_protected=true
        break
      fi
    done < <(collect_protected_branches)
  fi
  if [ "$is_protected" = true ]; then
    echo "Error: Gate 2 commit is forbidden on protected or detached branch '$branch'." >&2
    exit 3
  fi

  if [ -f "$STATUS_FILE" ] && grep -Eq '"reason"[[:space:]]*:[[:space:]]*"SECRET_IN_LOG"' "$STATUS_FILE"; then
    echo "Error: SECRET_IN_LOG is active in $STATUS_FILE. Run a clean validation cycle before Gate 2 commit." >&2
    exit 6
  fi

  if [ "$allow_unvalidated" != true ]; then
    [ -f "$STATUS_FILE" ] || { echo "Error: Missing test status file ($STATUS_FILE). Run Tester before Gate 2 commit." >&2; exit 4; }
    grep -Eq '"passed"[[:space:]]*:[[:space:]]*true' "$STATUS_FILE" || {
      echo "Error: Tester report does not indicate passed=true. Gate 2 commit aborted." >&2
      exit 4
    }
  fi

  set +e
  ef_scan "$REPO_ROOT" "$card_id" "$HARNESS_LOG_DIR"
  scan_rc=$?
  set -e
  if [ "$scan_rc" -eq 6 ]; then
    now_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    ef_write_test_status "$STATUS_FILE" scan_fail \
      cardId "$card_id" \
      evidencePath ".agent-pack/evidencias/$card_id/EVIDENCIA.md" \
      timestamp "$now_utc"
    findings_msg=""
    for entry in "${_EF_SCAN_FINDINGS[@]+"${_EF_SCAN_FINDINGS[@]}"}"; do
      [ -n "$entry" ] || continue
      f_rel="${entry%%$'\t'*}"
      f_cnt="${entry#*$'\t'}"
      [ -n "$findings_msg" ] && findings_msg+=", "
      findings_msg+="$f_rel ($f_cnt)"
    done
    ef_update_evidence_block "$EVIDENCE_FILE" "$card_id" "append_line" "- **Secret Scan:** SECRET_IN_LOG; findings: $findings_msg" || true
    echo "Error: SECRET_IN_LOG detected during Gate 2 pre-commit scan. Commit aborted." >&2
    exit 6
  fi

  effective_spec="$task_spec"
  if [ -z "$effective_spec" ] && [ -f "$RUNTIME_DIR/TASK_SPEC.md" ]; then
    effective_spec="$RUNTIME_DIR/TASK_SPEC.md"
  fi

  gate2_paths=()
  while IFS= read -r p; do
    [ -n "$p" ] && gate2_paths+=("$p")
  done < <(resolve_gate2_paths "$paths_raw" "$effective_spec")

  [ "${#gate2_paths[@]}" -gt 0 ] || exit 5

  if ! git -C "$REPO_ROOT" add -- "${gate2_paths[@]}"; then
    git -C "$REPO_ROOT" reset -q -- "${gate2_paths[@]}" >/dev/null 2>&1 || true
    echo "Error: Failed to stage authorized paths." >&2
    exit 5
  fi

  staged_files=()
  while IFS= read -r sf; do
    [ -n "$sf" ] && staged_files+=("$sf")
  done < <(git -C "$REPO_ROOT" diff --cached --name-only)

  if [ "${#staged_files[@]}" -eq 0 ]; then
    git -C "$REPO_ROOT" reset -q -- "${gate2_paths[@]}" >/dev/null 2>&1 || true
    echo "Error: No staged changes among authorized paths." >&2
    exit 5
  fi

  for sf in "${staged_files[@]}"; do
    matched=false
    for gp in "${gate2_paths[@]}"; do
      if [ "$sf" = "$gp" ]; then
        matched=true
        break
      fi
    done
    if [ "$matched" = false ]; then
      git -C "$REPO_ROOT" reset -q -- "${gate2_paths[@]}" >/dev/null 2>&1 || true
      echo "Error: Staged file '$sf' is outside authorized Gate 2 paths." >&2
      exit 5
    fi
  done

  while IFS= read -r porcelain_line; do
    [ -n "$porcelain_line" ] || continue
    xy="${porcelain_line:0:2}"
    wt_path="${porcelain_line:3}"
    case "$wt_path" in
      *" -> "*) wt_path="${wt_path##* -> }" ;;
    esac
    wt_path="${wt_path#\"}"
    wt_path="${wt_path%\"}"
    in_scope=false
    for gp in "${gate2_paths[@]}"; do
      if [ "$wt_path" = "$gp" ]; then
        in_scope=true
        break
      fi
    done
    if [ "$in_scope" = false ] && { [ "${xy:1:1}" != " " ] || [ "$xy" = "??" ]; }; then
      printf 'UNSTAGED_OUT_OF_SCOPE: %s\n' "$wt_path"
    fi
  done < <(git -C "$REPO_ROOT" status --porcelain)

  if [ "$allow_unvalidated" = true ]; then
    now_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    masked_reason="$(ef_mask_string "$trimmed_reason")"
    ef_update_evidence_block "$EVIDENCE_FILE" "$card_id" "append_line" "allowUnvalidated: true — reason: $masked_reason — at: $now_utc" || exit 2
    ef_write_test_status "$STATUS_FILE" allow_unvalidated \
      cardId "$card_id" \
      allowUnvalidatedReason "$masked_reason" \
      allowUnvalidatedAt "$now_utc"
  fi

  git -C "$REPO_ROOT" commit -m "$commit_message"
  rm -f -- "$LOCK_FILE"
  echo "[IMPLEMENTOR] Gate 2 commit completed on branch '$branch' and task.lock released."
  exit 0
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
elif [ -z "$harness_cmd" ]; then
  echo "Error: No harness provided. Pass --harness or --harness-cmd (or set EF_HARNESS / EF_IMPLEMENTOR_CMD)." >&2
  exit 2
fi

mkdir -p "$RUNTIME_DIR" "$HARNESS_LOG_DIR"
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
  runner_fb="$(ef_extract_evidence_runner_block "$EVIDENCE_FILE")"
  test_out_log="$EVIDENCE_DIR/test-output.log"
  tail_out=""
  if [ -f "$test_out_log" ]; then
    tail_out="$(tail -n 200 "$test_out_log")"
  fi
  if [ -n "$runner_fb" ] || [ -n "$tail_out" ]; then
    feedback_section=$'\n[CORRECAO NECESSARIA - FALHA REPORTADA PELO TESTER]\n'
    [ -n "$runner_fb" ] && feedback_section+="$runner_fb"$'\n'
    if [ -f "$test_out_log" ]; then
      feedback_section+="Log: .agent-pack/evidencias/$card_id/test-output.log"$'\n```text\n'"$tail_out"$'\n```'
    fi
  else
    feedback_section=$'\n[CORRECAO NECESSARIA - FALHA REPORTADA PELO TESTER]\n'"$(cat "$STATUS_FILE")"
  fi
fi

raw_context="# Contexto de Execucao — Implementor"$'\n'
raw_context+="- Card: $card_id"$'\n'
raw_context+="- Skill: $skill"$'\n\n'
[ -n "$base_prompt" ] && raw_context+="$base_prompt"$'\n\n'
[ -n "$spec_content" ] && raw_context+="## Especificacao da Tarefa"$'\n'"$spec_content"$'\n\n'
[ -n "$feedback_section" ] && raw_context+="$feedback_section"$'\n'

masked_context="$(ef_mask_string "$raw_context")"
context_mask_count="${_EF_LAST_MASK_COUNT:-0}"
context_file="$RUNTIME_DIR/implementor-prompt-$card_id.md"
context_tmp="$RUNTIME_DIR/.implementor-prompt-$card_id.tmp.$$"
printf '%s' "$masked_context" > "$context_tmp"
mv -f -- "$context_tmp" "$context_file"

echo "==> [IMPLEMENTOR] Executando para o Card $card_id ($skill)... (contexto mascarado: $context_mask_count)"
[ -n "$harness_flag_names" ] && echo "==> [IMPLEMENTOR] Harness flags: $harness_flag_names"

export EF_CARD_ID="$card_id"
export EF_SKILL="$skill"
export EF_PROMPT_FILE="$context_file"

attempt="${EF_ATTEMPT:-1}"
stdout_log="$HARNESS_LOG_DIR/${card_id}_implementor_attempt${attempt}.jsonl"
stderr_log="$HARNESS_LOG_DIR/${card_id}_implementor_attempt${attempt}.err"
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
      cmd_argv=(agy -p "$masked_context" --model gemini-4-hydrogen-high)
      [ "$has_effort" = false ] && cmd_argv+=(--effort high)
      cmd_argv+=(--output-format stream-json)
      [ "${#parsed_hargs[@]}" -gt 0 ] && cmd_argv+=("${parsed_hargs[@]}")
      ;;
    claude)
      cmd_argv=(claude -p "$masked_context" --output-format stream-json --verbose)
      [ "${#parsed_hargs[@]}" -gt 0 ] && cmd_argv+=("${parsed_hargs[@]}")
      ;;
    grok)
      cmd_argv=(grok "${parsed_hargs[@]}")
      ;;
  esac
else
  cmd_argv=(bash -c "$harness_cmd")
fi

fifo_dir="$(mktemp -d "${TMPDIR:-/tmp}/ef-imp-fifo.XXXXXX")"
mkfifo "$fifo_dir/out" "$fifo_dir/err"
out_cnt_file="$fifo_dir/out.cnt"
err_cnt_file="$fifo_dir/err.cnt"

ef_mask --count-file "$out_cnt_file" < "$fifo_dir/out" | tee "$stdout_log" &
pid_out=$!
ef_mask --count-file "$err_cnt_file" < "$fifo_dir/err" | tee "$stderr_log" >&2 &
pid_err=$!

set +e
(cd "$REPO_ROOT" && "${cmd_argv[@]}") > "$fifo_dir/out" 2> "$fifo_dir/err"
harness_rc=$?
set -e

wait "$pid_out" "$pid_err"
out_mask_cnt="$(tr -d '[:space:]' < "$out_cnt_file" 2>/dev/null || echo 0)"
err_mask_cnt="$(tr -d '[:space:]' < "$err_cnt_file" 2>/dev/null || echo 0)"
rm -rf -- "$fifo_dir"
echo "==> [IMPLEMENTOR] Log capturado (mascaramentos stdout=$out_mask_cnt, stderr=$err_mask_cnt)"

set +e
ef_scan "$REPO_ROOT" "$card_id" "$HARNESS_LOG_DIR"
scan_rc=$?
set -e

if [ "$scan_rc" -eq 6 ]; then
  now_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ef_write_test_status "$STATUS_FILE" scan_fail \
    cardId "$card_id" \
    evidencePath ".agent-pack/evidencias/$card_id/EVIDENCIA.md" \
    timestamp "$now_utc"
  findings_msg=""
  for entry in "${_EF_SCAN_FINDINGS[@]+"${_EF_SCAN_FINDINGS[@]}"}"; do
    [ -n "$entry" ] || continue
    f_rel="${entry%%$'\t'*}"
    f_cnt="${entry#*$'\t'}"
    [ -n "$findings_msg" ] && findings_msg+=", "
    findings_msg+="$f_rel ($f_cnt)"
  done
  ef_update_evidence_block "$EVIDENCE_FILE" "$card_id" "append_line" "- **Secret Scan:** SECRET_IN_LOG; findings: $findings_msg" || true
  echo "==> [IMPLEMENTOR] ERRO CRITICO: SECRET_IN_LOG detectado." >&2
  exit 6
fi

exit "$harness_rc"
