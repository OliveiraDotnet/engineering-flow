#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
HARNESS_DIR="$PACK_ROOT/repo-template/.agents/skills/harness-cycle/scripts"
SUPERVISOR="${EF_TEST_SUPERVISOR:-$HARNESS_DIR/supervise-harness.sh}"
IMPLEMENTOR="${EF_TEST_IMPLEMENTOR:-$HARNESS_DIR/run-implementor.sh}"
TESTER="${EF_TEST_TESTER:-$HARNESS_DIR/run-tester.sh}"
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
  local branch="${2:-fix/AB-500-calc}"
  mkdir -p "$repo"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email "ci@example.com"
  git -C "$repo" config user.name "CI Runner"
  printf '0\n' > "$repo/value.txt"
  git -C "$repo" add value.txt
  git -C "$repo" commit -q -m "initial"
  if [ "$branch" != "main" ]; then
    git -C "$repo" checkout -q -b "$branch"
  fi
}

assert_no_literal() {
  local needle="$1"
  shift
  local dir
  for dir in "$@"; do
    if [ -d "$dir" ] && grep -rFq -- "$needle" "$dir"; then
      fail "Found unmasked literal secret in $dir"
    fi
  done
}

# ==============================================================================
# B0: Real CLI closed loop (R0-RED -> Implementor -> R0-GREEN -> Gate 2 + lock)
# ==============================================================================
REPO1="$TEMP_ROOT/repo-b0-pass"
init_repo "$REPO1" "fix/AB-500-fix-calculation"
bash "$LOCK_TOOL" acquire --task AB-500 --repo "$REPO1" --bot "repo-lead" --harness "default" >/dev/null

bash "$SUPERVISOR" \
  --repo "$REPO1" \
  --card-id "AB-500" \
  --demand-type "Bug" \
  --implementor-cmd "printf '1\n' > value.txt" \
  --test-cmd "grep -Fxq '1' value.txt" \
  --r0-red-cmd "grep -Fxq '1' value.txt" \
  --max-retries 3 >/dev/null

[ -f "$REPO1/.agent-pack/.runtime/test-status.json" ] || fail "B0: test-status.json was not generated"
grep -Eq '"passed"[[:space:]]*:[[:space:]]*true' "$REPO1/.agent-pack/.runtime/test-status.json" || fail "B0: Expected passed=true in test-status.json"
[ -f "$REPO1/.agent-pack/evidencias/AB-500/EVIDENCIA.md" ] || fail "B0: EVIDENCIA.md was not generated"
grep -q "R0-RED" "$REPO1/.agent-pack/evidencias/AB-500/EVIDENCIA.md" || fail "B0: Missing R0-RED evidence"
grep -q "APROVADO (GREEN)" "$REPO1/.agent-pack/evidencias/AB-500/EVIDENCIA.md" || fail "B0: Missing APROVADO (GREEN) in EVIDENCIA.md"

bash "$IMPLEMENTOR" \
  --repo "$REPO1" \
  --card-id "AB-500" \
  --commit-gate2 \
  --paths "value.txt" \
  --commit-message "fix(AB-500): fix calculation" >/dev/null

[ "$(git -C "$REPO1" log -1 --pretty=%s)" = "fix(AB-500): fix calculation" ] || fail "B0: Gate 2 commit was not created"
[ ! -f "$REPO1/.agent-pack/.runtime/task.lock" ] || fail "B0: task.lock was not released after Gate 2 commit"

# B0 Retry loop via EF_ATTEMPT
REPO2="$TEMP_ROOT/repo-b0-retry"
init_repo "$REPO2" "feat/AB-501-retry"
bash "$SUPERVISOR" \
  --repo "$REPO2" \
  --card-id "AB-501" \
  --demand-type "Feature" \
  --implementor-cmd "if [ \"\$EF_ATTEMPT\" = '2' ]; then printf '1\n' > value.txt; fi" \
  --test-cmd "grep -Fxq '1' value.txt" \
  --max-retries 3 >/dev/null

grep -Eq '"passed"[[:space:]]*:[[:space:]]*true' "$REPO2/.agent-pack/.runtime/test-status.json" || fail "B0: Expected passed=true after retry"

# B0 Circuit breaker: fails 3 attempts -> exit 1 + UNABLE_TO_VALIDATE on stderr
REPO3="$TEMP_ROOT/repo-b0-fail"
init_repo "$REPO3" "feat/AB-502-broken"
cb_err="$TEMP_ROOT/cb.err"
rc=0
bash "$SUPERVISOR" \
  --repo "$REPO3" \
  --card-id "AB-502" \
  --demand-type "Feature" \
  --implementor-cmd "printf 'still-broken\n' > value.txt" \
  --test-cmd "grep -Fxq '1' value.txt" \
  --max-retries 3 >/dev/null 2>"$cb_err" || rc=$?

[ "$rc" -eq 1 ] || fail "B0: Expected exit code 1 on circuit breaker, got $rc"
grep -q "UNABLE_TO_VALIDATE" "$cb_err" || fail "B0: Expected UNABLE_TO_VALIDATE on stderr"

# ==============================================================================
# S1: run-tester masking, commandSha256, delimited EVIDENCIA block
# ==============================================================================
REPO_S1="$TEMP_ROOT/repo-s1"
init_repo "$REPO_S1" "fix/AB-510-s1"

ts_ns="$(date +%s%N)"
fake1="EFFAKE""${ts_ns}""SecOne"
fake2="EFFAKE""${ts_ns}""BearTwo"
fake_gh="gh""p_""xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

(
  export OSGT_API_KEY="$fake1"
  rc=0
  bash "$TESTER" --repo "$REPO_S1" --card-id "AB-510" --demand-type "Bug" --phase r0-red \
    --test-cmd "echo password=$fake1; echo Authorization: Bearer $fake2; echo token=$fake_gh; exit 1" >/dev/null || rc=$?
  [ "$rc" -eq 0 ] || fail "S1-a: r0-red failed unexpectedly (rc=$rc)"

  bash "$TESTER" --repo "$REPO_S1" --card-id "AB-510" --demand-type "Bug" --phase validate \
    --test-cmd "echo password=$fake1; echo Authorization: Bearer $fake2; echo token=$fake_gh; exit 0" >/dev/null
)

assert_no_literal "$fake1" "$REPO_S1/.agent-pack/evidencias" "$REPO_S1/.agent-pack/.runtime" "$REPO_S1/.agent-pack/logs"
assert_no_literal "$fake2" "$REPO_S1/.agent-pack/evidencias" "$REPO_S1/.agent-pack/.runtime" "$REPO_S1/.agent-pack/logs"
assert_no_literal "$fake_gh" "$REPO_S1/.agent-pack/evidencias" "$REPO_S1/.agent-pack/.runtime" "$REPO_S1/.agent-pack/logs"

ev_s1="$REPO_S1/.agent-pack/evidencias/AB-510/EVIDENCIA.md"
# S1-b: literal test-cmd must NOT appear; commandSha256 must appear
if grep -Fq "Authorization: Bearer" "$ev_s1" || grep -Fq "echo password=" "$ev_s1"; then
  fail "S1-b: Literal --test-cmd appeared in EVIDENCIA.md"
fi
grep -q "commandSha256" "$ev_s1" || fail "S1-b: commandSha256 missing from EVIDENCIA.md"

# S1-e: test-output.log exists and contains [EF-MASKED]
out_log_s1="$REPO_S1/.agent-pack/evidencias/AB-510/test-output.log"
[ -f "$out_log_s1" ] || fail "S1-e: test-output.log missing"
grep -Fq "[EF-MASKED]" "$out_log_s1" || fail "S1-e: [EF-MASKED] missing in test-output.log"

# S1-c: pre-created EVIDENCIA with BOM, CRLF, table, and sentinel stays byte-identical outside block across 2 runs
REPO_S1C="$TEMP_ROOT/repo-s1c"
init_repo "$REPO_S1C" "feat/AB-511-s1c"
ev_s1c_dir="$REPO_S1C/.agent-pack/evidencias/AB-511"
mkdir -p "$ev_s1c_dir"
ev_s1c="$ev_s1c_dir/EVIDENCIA.md"
perl -e '
  binmode STDOUT;
  print "\xEF\xBB\xBF";
  print "# Custom Header\r\n\r\n| ID | Critério | Status |\r\n|---|---|---|\r\n| C1 | Ok | pendente |\r\n\r\n";
  print "<!-- runner:begin -->\r\nold-content\r\n<!-- runner:end -->\r\n\r\n";
  print "SENTINELA-FINAL-PRESERVADA\r\n";
' > "$ev_s1c"

extract_outside() {
  perl -e '
    local $/ = undef;
    open my $fh, "<:raw", $ARGV[0] or die;
    my $d = <$fh>;
    my $bp = index($d, "<!-- runner:begin -->");
    my $ep = index($d, "<!-- runner:end -->");
    print substr($d, 0, $bp), "|||", substr($d, $ep + length("<!-- runner:end -->"));
  ' "$1"
}
outside_before="$(extract_outside "$ev_s1c" | sha256sum | cut -d' ' -f1)"

bash "$TESTER" --repo "$REPO_S1C" --card-id "AB-511" --demand-type "Feature" --phase validate --test-cmd "echo ok1" >/dev/null
bash "$TESTER" --repo "$REPO_S1C" --card-id "AB-511" --demand-type "Feature" --phase validate --test-cmd "echo ok2" >/dev/null

outside_after="$(extract_outside "$ev_s1c" | sha256sum | cut -d' ' -f1)"
[ "$outside_before" = "$outside_after" ] || fail "S1-c: Bytes outside runner block changed"
[ "$(grep -c "<!-- runner:begin -->" "$ev_s1c")" -eq 1 ] || fail "S1-c: Expected exactly 1 runner:begin"
[ "$(grep -c "<!-- runner:end -->" "$ev_s1c")" -eq 1 ] || fail "S1-c: Expected exactly 1 runner:end"

# S1-d: orphan runner:begin causes exit 2 and leaves file unchanged
printf '\n<!-- runner:begin -->\norphan\n' > "$ev_s1c"
hash_before="$(sha256sum "$ev_s1c" | cut -d' ' -f1)"
rc=0
bash "$TESTER" --repo "$REPO_S1C" --card-id "AB-511" --demand-type "Feature" --phase validate --test-cmd "echo ok3" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "S1-d: Expected exit 2 for orphan marker, got $rc"
hash_after="$(sha256sum "$ev_s1c" | cut -d' ' -f1)"
[ "$hash_before" = "$hash_after" ] || fail "S1-d: File was modified despite malformed markers"

# ==============================================================================
# S2: run-implementor context masking
# ==============================================================================
REPO_S2="$TEMP_ROOT/repo-s2"
init_repo "$REPO_S2" "feat/AB-520-s2"
fake3="EFFAKE""${ts_ns}""ConnThree"
fake4="EFFAKE""${ts_ns}""EnvFour"
spec_s2="$TEMP_ROOT/spec-s2.md"
cat > "$spec_s2" <<EOF
# Task Spec
connection: Server=x;User ID=sa;Password=$fake3;
extra: $fake4
EOF

(
  export EF_TEST_SECRET="$fake4"
  bash "$IMPLEMENTOR" --repo "$REPO_S2" --card-id "AB-520" --task-spec "$spec_s2" --harness-cmd "echo ok" >/dev/null
)

assert_no_literal "$fake3" "$REPO_S2/.agent-pack/.runtime" "$REPO_S2/.agent-pack/evidencias" "$REPO_S2/.agent-pack/logs"
assert_no_literal "$fake4" "$REPO_S2/.agent-pack/.runtime" "$REPO_S2/.agent-pack/evidencias" "$REPO_S2/.agent-pack/logs"
prompt_s2="$REPO_S2/.agent-pack/.runtime/implementor-prompt-AB-520.md"
[ -f "$prompt_s2" ] || fail "S2-a: implementor-prompt missing"
grep -Fq "[EF-MASKED]" "$prompt_s2" || fail "S2-a: [EF-MASKED] missing in implementor prompt"

# ==============================================================================
# S3: Gate 2 explicit staging, protected branches, --allow-unvalidated --reason
# ==============================================================================
REPO_S3="$TEMP_ROOT/repo-s3"
init_repo "$REPO_S3" "main"
printf 'a0\n' > "$REPO_S3/a.txt"
printf 'b0\n' > "$REPO_S3/b.txt"
printf 'c0\n' > "$REPO_S3/c.txt"
git -C "$REPO_S3" add a.txt b.txt c.txt
git -C "$REPO_S3" commit -q -m "add abc"
git -C "$REPO_S3" checkout -q -b "feat/AB-530-s3"

bash "$TESTER" --repo "$REPO_S3" --card-id "AB-530" --demand-type "Feature" --phase validate --test-cmd "echo pass" >/dev/null

# S3-a: a.txt (listed) and b.txt (unlisted) both modified; --paths a.txt
printf 'a1\n' > "$REPO_S3/a.txt"
printf 'b1\n' > "$REPO_S3/b.txt"
out_s3a="$(bash "$IMPLEMENTOR" --repo "$REPO_S3" --card-id "AB-530" --commit-gate2 --paths "a.txt" --commit-message "feat(AB-530): commit a only")"
committed_files="$(git -C "$REPO_S3" show --name-only --pretty="" HEAD)"
[ "$committed_files" = "a.txt" ] || fail "S3-a: Expected only a.txt committed, got: $committed_files"
grep -Fxq "b1" "$REPO_S3/b.txt" || fail "S3-a: b.txt should stay modified"
git -C "$REPO_S3" diff --quiet -- b.txt && fail "S3-a: b.txt should remain unstaged/dirty"
printf '%s\n' "$out_s3a" | grep -Fq "UNSTAGED_OUT_OF_SCOPE: b.txt" || fail "S3-a: Expected UNSTAGED_OUT_OF_SCOPE: b.txt"

# S3-b: No --paths and no TASK_SPEC -> exit 5, HEAD unchanged
head_before="$(git -C "$REPO_S3" rev-parse HEAD)"
rc=0
bash "$IMPLEMENTOR" --repo "$REPO_S3" --card-id "AB-530" --commit-gate2 --commit-message "feat(AB-530): should fail" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 5 ] || fail "S3-b: Expected exit 5 without paths/spec, got $rc"
[ "$(git -C "$REPO_S3" rev-parse HEAD)" = "$head_before" ] || fail "S3-b: HEAD changed"

# S3-c: Forbidden paths ../x and .agent-pack/x -> exit 5
for badp in "../x" ".agent-pack/x" ".agents/x" "prompts/x" "docs/engineering-flow/x"; do
  rc=0
  bash "$IMPLEMENTOR" --repo "$REPO_S3" --card-id "AB-530" --commit-gate2 --paths "$badp" --commit-message "feat(AB-530): bad path" >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 5 ] || fail "S3-c: Expected exit 5 for forbidden path '$badp', got $rc"
done

# S3-d: Paths from TASK_SPEC ef:paths markers
printf 'c1\n' > "$REPO_S3/c.txt"
mkdir -p "$REPO_S3/.agent-pack/.runtime"
cat > "$REPO_S3/.agent-pack/.runtime/TASK_SPEC.md" <<'EOF'
## Staging
<!-- ef:paths:begin -->
- `c.txt`
<!-- ef:paths:end -->
EOF
bash "$IMPLEMENTOR" --repo "$REPO_S3" --card-id "AB-530" --commit-gate2 --commit-message "feat(AB-530): commit c from spec" >/dev/null
[ "$(git -C "$REPO_S3" show --name-only --pretty="" HEAD)" = "c.txt" ] || fail "S3-d: Expected c.txt from TASK_SPEC"
rm -f -- "$REPO_S3/.agent-pack/.runtime/TASK_SPEC.md"

# S3-e: Protected branches from AGENTS.md, main, and EF_PROTECTED_BRANCHES
# First reset leftover dirty b.txt from S3-a, then test main without AGENTS.md
git -C "$REPO_S3" checkout -q -- b.txt
git -C "$REPO_S3" checkout -q main
head_main="$(git -C "$REPO_S3" rev-parse HEAD)"
printf 'm1\n' > "$REPO_S3/a.txt"
rc=0
bash "$IMPLEMENTOR" --repo "$REPO_S3" --card-id "AB-530" --commit-gate2 --paths "a.txt" --commit-message "feat(AB-530): main" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 3 ] || fail "S3-e: Expected exit 3 on main without config, got $rc"
[ "$(git -C "$REPO_S3" rev-parse HEAD)" = "$head_main" ] || fail "S3-e: main HEAD changed"
git -C "$REPO_S3" checkout -q -- a.txt

# Test EF_PROTECTED_BRANCHES=new-hom without AGENTS.md
git -C "$REPO_S3" checkout -q -b new-hom
head_nh="$(git -C "$REPO_S3" rev-parse HEAD)"
printf 'nh1\n' > "$REPO_S3/a.txt"
rc=0
EF_PROTECTED_BRANCHES="new-hom" bash "$IMPLEMENTOR" --repo "$REPO_S3" --card-id "AB-530" --commit-gate2 --paths "a.txt" --commit-message "feat(AB-530): nh" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 3 ] || fail "S3-e: Expected exit 3 with EF_PROTECTED_BRANCHES=new-hom, got $rc"
[ "$(git -C "$REPO_S3" rev-parse HEAD)" = "$head_nh" ] || fail "S3-e: new-hom HEAD changed"
git -C "$REPO_S3" checkout -q -- a.txt

# Test AGENTS.md protected branches: develop, demarchi, hom-demarchi, new-hom
git -C "$REPO_S3" checkout -q feat/AB-530-s3
cat > "$REPO_S3/AGENTS.md" <<'EOF'
# Repo
## Convenções do projeto
- Branches protegidas (harness): develop, demarchi, hom-demarchi, new-hom
EOF
git -C "$REPO_S3" add AGENTS.md
git -C "$REPO_S3" commit -q -m "add AGENTS.md"

for pb in develop demarchi hom-demarchi new-hom; do
  git -C "$REPO_S3" checkout -q -B "$pb"
  hb="$(git -C "$REPO_S3" rev-parse HEAD)"
  printf 'pb\n' > "$REPO_S3/a.txt"
  rc=0
  bash "$IMPLEMENTOR" --repo "$REPO_S3" --card-id "AB-530" --commit-gate2 --paths "a.txt" --commit-message "feat(AB-530): pb" >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 3 ] || fail "S3-e: Expected exit 3 on protected branch '$pb', got $rc"
  [ "$(git -C "$REPO_S3" rev-parse HEAD)" = "$hb" ] || fail "S3-e: HEAD changed on '$pb'"
  git -C "$REPO_S3" checkout -q -- a.txt
done

# S3-f: --allow-unvalidated requires --reason (>=10 chars)
git -C "$REPO_S3" checkout -q feat/AB-530-s3
rm -f -- "$REPO_S3/.agent-pack/.runtime/test-status.json"
printf 'u1\n' > "$REPO_S3/a.txt"

rc=0
bash "$IMPLEMENTOR" --repo "$REPO_S3" --card-id "AB-530" --commit-gate2 --paths "a.txt" --allow-unvalidated --commit-message "feat(AB-530): missing reason" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "S3-f: Expected exit 2 without --reason, got $rc"

rc=0
bash "$IMPLEMENTOR" --repo "$REPO_S3" --card-id "AB-530" --commit-gate2 --paths "a.txt" --allow-unvalidated --reason "curto" --commit-message "feat(AB-530): short reason" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "S3-f: Expected exit 2 for short --reason, got $rc"

bash "$IMPLEMENTOR" --repo "$REPO_S3" --card-id "AB-530" --commit-gate2 --paths "a.txt" --allow-unvalidated --reason "Hotfix emergencial aprovado pelo TL" --commit-message "feat(AB-530): allow unvalidated" >/dev/null
grep -Eq '"allowUnvalidated"[[:space:]]*:[[:space:]]*true' "$REPO_S3/.agent-pack/.runtime/test-status.json" || fail "S3-f: allowUnvalidated=true missing"
grep -Fq "Hotfix emergencial aprovado pelo TL" "$REPO_S3/.agent-pack/.runtime/test-status.json" || fail "S3-f: allowUnvalidatedReason missing"
grep -Fq "allowUnvalidated: true" "$REPO_S3/.agent-pack/evidencias/AB-530/EVIDENCIA.md" || fail "S3-f: allowUnvalidated line missing in EVIDENCIA.md"

# ==============================================================================
# S4: Harness capture, EF_SECRET_VALUES_FILE, ef_scan (exit 6), EF_SECRET_NAMES, recovery
# ==============================================================================
REPO_S4="$TEMP_ROOT/repo-s4"
init_repo "$REPO_S4" "fix/AB-540-s4"
mkdir -p "$REPO_S4/db"

fake5_partA="EFFAKE""${ts_ns}""Sql"
fake5="${fake5_partA}/\"Five"
fake5_escaped="${fake5_partA}\\/\\\"Five"
fake6="EFFAKE""${ts_ns}""HdrSix"

cat > "$REPO_S4/db/consolidado.sql" <<EOF
INSERT INTO cfg(val) VALUES ('$fake5');
EOF
git -C "$REPO_S4" add db/consolidado.sql
git -C "$REPO_S4" commit -q -m "add sql"

secret_vals_outside="$TEMP_ROOT/outside-secrets.txt"
printf '%s\n' "$fake5" > "$secret_vals_outside"

fake_bin="$TEMP_ROOT/fake-bin"
mkdir -p "$fake_bin"
effort_marker="$TEMP_ROOT/agy-saw-effort-high"
cat > "$fake_bin/agy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
saw_effort=false
prev=""
for a in "$@"; do
  if [ "$prev" = "--effort" ] && [ "$a" = "high" ]; then
    saw_effort=true
  fi
  prev="$a"
done
if [ "$saw_effort" != true ]; then
  echo "missing --effort high" >&2
  exit 11
fi
[ -n "${EF_FAKE_MARKER:-}" ] && touch "$EF_FAKE_MARKER"
if [ -n "${EF_FAKE_XAPI:-}" ]; then
  printf '{"type":"init"}\n'
  printf '{"type":"header","content":"X-Api-Key: %s"}\n' "$EF_FAKE_XAPI"
  printf '{"type":"result","status":"ok"}\n'
else
  sql_line="$(sed -n '1p' db/consolidado.sql)"
  escaped="${sql_line//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  escaped="${escaped//\//\\/}"
  printf '{"type":"init"}\n'
  printf '{"type":"tool_result","content":"%s"}\n' "$escaped"
  printf '{"type":"result","status":"ok"}\n'
fi
EOF
chmod +x "$fake_bin/agy"

# S4-a: agy profile captures masked stream-json and receives --effort high
(
  export PATH="$fake_bin:$PATH"
  export EF_SECRET_VALUES_FILE="$secret_vals_outside"
  export EF_FAKE_MARKER="$effort_marker"
  bash "$IMPLEMENTOR" --repo "$REPO_S4" --card-id "AB-540" --harness agy >/dev/null
)

[ -f "$effort_marker" ] || fail "S4-a: fake agy did not receive --effort high"
log_s4a="$REPO_S4/.agent-pack/logs/AB-540/AB-540_implementor_attempt1.jsonl"
[ -f "$log_s4a" ] || fail "S4-a: captured .jsonl log missing"
grep -Fq "[EF-MASKED]" "$log_s4a" || fail "S4-a: [EF-MASKED] missing in .jsonl log"
assert_no_literal "$fake5" "$REPO_S4/.agent-pack/logs" "$REPO_S4/.agent-pack/evidencias" "$REPO_S4/.agent-pack/.runtime"
assert_no_literal "$fake5_escaped" "$REPO_S4/.agent-pack/logs" "$REPO_S4/.agent-pack/evidencias" "$REPO_S4/.agent-pack/.runtime"

# S4-c: EF_SECRET_VALUES_FILE inside repo -> exit 2
cp "$secret_vals_outside" "$REPO_S4/inside-secrets.txt"
rc=0
EF_SECRET_VALUES_FILE="$REPO_S4/inside-secrets.txt" bash "$IMPLEMENTOR" --repo "$REPO_S4" --card-id "AB-540" --harness-cmd "echo ok" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "S4-c: Expected exit 2 when EF_SECRET_VALUES_FILE is inside repo, got $rc"
rm -f -- "$REPO_S4/inside-secrets.txt"

# S4-d: agy with --effort medium -> exit 2; grok without --harness-args -> exit 2
rc=0
bash "$IMPLEMENTOR" --repo "$REPO_S4" --card-id "AB-540" --harness agy --harness-args "--effort medium" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "S4-d: Expected exit 2 for agy --effort medium, got $rc"

rc=0
bash "$IMPLEMENTOR" --repo "$REPO_S4" --card-id "AB-540" --harness grok >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "S4-d: Expected exit 2 for grok without --harness-args, got $rc"

# S4-e: EF_SECRET_NAMES=X-Api-Key masks X-Api-Key: <fake6>
(
  export PATH="$fake_bin:$PATH"
  export EF_SECRET_NAMES="X-Api-Key"
  export EF_FAKE_XAPI="$fake6"
  export EF_ATTEMPT=2
  bash "$IMPLEMENTOR" --repo "$REPO_S4" --card-id "AB-540" --harness agy >/dev/null
)
log_s4e="$REPO_S4/.agent-pack/logs/AB-540/AB-540_implementor_attempt2.jsonl"
grep -Fq "X-Api-Key: [EF-MASKED]" "$log_s4e" || fail "S4-e: Expected X-Api-Key: [EF-MASKED] in log"
assert_no_literal "$fake6" "$REPO_S4/.agent-pack/logs" "$REPO_S4/.agent-pack/evidencias" "$REPO_S4/.agent-pack/.runtime"

# S4-b: adhoc.jsonl bypasses capture -> scan exits 6, masks adhoc.jsonl, blocks --commit-gate2 & supervisor
adhoc_log="$REPO_S4/.agent-pack/logs/AB-540/adhoc.jsonl"
printf '{"type":"tool_result","content":"%s"}\n' "$fake5" > "$adhoc_log"

rc=0
EF_SECRET_VALUES_FILE="$secret_vals_outside" bash "$TESTER" --repo "$REPO_S4" --card-id "AB-540" --demand-type "Feature" --phase validate --test-cmd "echo ok" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 6 ] || fail "S4-b: Expected exit 6 on SECRET_IN_LOG in run-tester, got $rc"
grep -Eq '"passed"[[:space:]]*:[[:space:]]*false' "$REPO_S4/.agent-pack/.runtime/test-status.json" || fail "S4-b: Expected passed=false"
grep -Eq '"reason"[[:space:]]*:[[:space:]]*"SECRET_IN_LOG"' "$REPO_S4/.agent-pack/.runtime/test-status.json" || fail "S4-b: Expected reason=SECRET_IN_LOG"
grep -Fq "[EF-MASKED]" "$adhoc_log" || fail "S4-b: adhoc.jsonl should be masked in place"
assert_no_literal "$fake5" "$REPO_S4/.agent-pack/logs" "$REPO_S4/.agent-pack/evidencias" "$REPO_S4/.agent-pack/.runtime"

# Gate 2 commit blocked even with --allow-unvalidated --reason
printf 'fix\n' > "$REPO_S4/value.txt"
head_s4="$(git -C "$REPO_S4" rev-parse HEAD)"
rc=0
EF_SECRET_VALUES_FILE="$secret_vals_outside" bash "$IMPLEMENTOR" --repo "$REPO_S4" --card-id "AB-540" --commit-gate2 --paths "value.txt" --commit-message "fix(AB-540): blocked" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 6 ] || fail "S4-b: Expected exit 6 on --commit-gate2, got $rc"
[ "$(git -C "$REPO_S4" rev-parse HEAD)" = "$head_s4" ] || fail "S4-b: HEAD changed during blocked Gate 2"

rc=0
EF_SECRET_VALUES_FILE="$secret_vals_outside" bash "$IMPLEMENTOR" --repo "$REPO_S4" --card-id "AB-540" --commit-gate2 --paths "value.txt" --allow-unvalidated --reason "Tentativa de contornar SECRET_IN_LOG" --commit-message "fix(AB-540): blocked2" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 6 ] || fail "S4-b: Expected exit 6 on --commit-gate2 --allow-unvalidated, got $rc"
[ "$(git -C "$REPO_S4" rev-parse HEAD)" = "$head_s4" ] || fail "S4-b: HEAD changed with --allow-unvalidated"

# Supervisor aborts immediately with exit 6 without retrying
printf '{"type":"tool_result","content":"%s"}\n' "$fake5" > "$adhoc_log"
sup_attempts="$TEMP_ROOT/sup-attempts.txt"
rc=0
EF_SECRET_VALUES_FILE="$secret_vals_outside" bash "$SUPERVISOR" \
  --repo "$REPO_S4" \
  --card-id "AB-540" \
  --demand-type "Feature" \
  --implementor-cmd "echo attempt >> '$sup_attempts'" \
  --test-cmd "echo ok" \
  --max-retries 3 >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 6 ] || fail "S4-b: Expected supervisor exit 6, got $rc"
[ "$(wc -l < "$sup_attempts" | tr -d '[:space:]')" -eq 1 ] || fail "S4-b: Supervisor should not retry after exit 6"

# S4-f: Clean run-tester --phase validate after adhoc.jsonl is masked unblocks Gate 2 without human override
EF_SECRET_VALUES_FILE="$secret_vals_outside" bash "$TESTER" --repo "$REPO_S4" --card-id "AB-540" --demand-type "Feature" --phase validate --test-cmd "echo clean" >/dev/null
grep -Eq '"passed"[[:space:]]*:[[:space:]]*true' "$REPO_S4/.agent-pack/.runtime/test-status.json" || fail "S4-f: Expected passed=true after clean validate"
grep -Eq '"reason"[[:space:]]*:[[:space:]]*null' "$REPO_S4/.agent-pack/.runtime/test-status.json" || fail "S4-f: Expected reason=null after clean validate"
grep -Eq '"status"[[:space:]]*:[[:space:]]*"clean"' "$REPO_S4/.agent-pack/.runtime/test-status.json" || fail "S4-f: Expected secretScan.status=clean"

EF_SECRET_VALUES_FILE="$secret_vals_outside" bash "$IMPLEMENTOR" --repo "$REPO_S4" --card-id "AB-540" --commit-gate2 --paths "value.txt" --commit-message "fix(AB-540): clean gate2 commit" >/dev/null
[ "$(git -C "$REPO_S4" log -1 --pretty=%s)" = "fix(AB-540): clean gate2 commit" ] || fail "S4-f: Gate 2 commit failed after clean validate"

# ==============================================================================
# B1: Fixed-pattern-only and EF_SECRET_NAMES-only scan/count (no EF_SECRET_VALUES_FILE)
# ==============================================================================
REPO_B1="$TEMP_ROOT/repo-b1"
init_repo "$REPO_B1" "feat/AB-541-b1"
printf 'a0\n' > "$REPO_B1/a.txt"
git -C "$REPO_B1" add a.txt
git -C "$REPO_B1" commit -q -m "add a"

fake_b1_a="EFFAKE""${ts_ns}""B1PatA"
fake_b1_b="EFFAKE""${ts_ns}""B1PatB"
fake_b1_c="EFFAKE""${ts_ns}""B1ScanC"
fake_b1_d="EFFAKE""${ts_ns}""B1NameD"

(
  unset EF_SECRET_VALUES_FILE || true
  source "$HARNESS_DIR/ef-secrets.sh"
  ef_load_secrets "$REPO_B1" "$REPO_B1/.agent-pack/logs/AB-541"
  b1_mout_file="$TEMP_ROOT/b1-mout.txt"
  ef_mask_string "password=$fake_b1_a" > "$b1_mout_file"
  [ "$_EF_LAST_MASK_COUNT" -gt 0 ] || fail "B1: ef_mask count must be > 0 for fixed-pattern-only line (got $_EF_LAST_MASK_COUNT)"
  m_out="$(cat "$b1_mout_file")"
  [ "$m_out" = "password=[EF-MASKED]" ] || fail "B1: unexpected ef_mask_string output: $m_out"
)

(
  unset EF_SECRET_VALUES_FILE || true
  bash "$TESTER" --repo "$REPO_B1" --card-id "AB-541" --demand-type "Feature" --phase validate \
    --test-cmd "echo password=$fake_b1_a; echo Authorization: Bearer $fake_b1_b" >/dev/null
)
ev_b1="$REPO_B1/.agent-pack/evidencias/AB-541/EVIDENCIA.md"
grep -Fq "masked: 2)" "$ev_b1" || fail "B1: Expected masked: 2 in EVIDENCIA.md for fixed-pattern-only output"
assert_no_literal "$fake_b1_a" "$REPO_B1/.agent-pack/evidencias" "$REPO_B1/.agent-pack/.runtime" "$REPO_B1/.agent-pack/logs"
assert_no_literal "$fake_b1_b" "$REPO_B1/.agent-pack/evidencias" "$REPO_B1/.agent-pack/.runtime" "$REPO_B1/.agent-pack/logs"

b1_log_dir="$TEMP_ROOT/b1-ext-logs"
mkdir -p "$b1_log_dir"
b1_adhoc="$b1_log_dir/adhoc.jsonl"
printf 'a1\n' > "$REPO_B1/a.txt"
head_b1="$(git -C "$REPO_B1" rev-parse HEAD)"

printf '{"content":"password=%s"}\n{"content":"X-Api-Key: %s"}\n' "$fake_b1_c" "$fake_b1_d" > "$b1_adhoc"
rc=0
(
  unset EF_SECRET_VALUES_FILE || true
  export EF_HARNESS_LOG_DIR="$b1_log_dir"
  export EF_SECRET_NAMES="X-Api-Key"
  bash "$IMPLEMENTOR" --repo "$REPO_B1" --card-id "AB-541" --commit-gate2 --paths "a.txt" --commit-message "feat(AB-541): should fail b1" >/dev/null 2>&1
) || rc=$?
[ "$rc" -eq 6 ] || fail "B1: Expected exit 6 on --commit-gate2 with fixed/name adhoc log, got $rc"
[ "$(git -C "$REPO_B1" rev-parse HEAD)" = "$head_b1" ] || fail "B1: HEAD changed during blocked Gate 2"
assert_no_literal "$fake_b1_c" "$b1_log_dir" "$REPO_B1/.agent-pack"
assert_no_literal "$fake_b1_d" "$b1_log_dir" "$REPO_B1/.agent-pack"

# Reset test-status.json to passed=true and test again with --allow-unvalidated --reason
(
  unset EF_SECRET_VALUES_FILE || true
  bash "$TESTER" --repo "$REPO_B1" --card-id "AB-541" --demand-type "Feature" --phase validate --test-cmd "echo ok" >/dev/null
)
printf '{"content":"password=%s"}\n{"content":"X-Api-Key: %s"}\n' "$fake_b1_c" "$fake_b1_d" > "$b1_adhoc"
rc=0
(
  unset EF_SECRET_VALUES_FILE || true
  export EF_HARNESS_LOG_DIR="$b1_log_dir"
  export EF_SECRET_NAMES="X-Api-Key"
  bash "$IMPLEMENTOR" --repo "$REPO_B1" --card-id "AB-541" --commit-gate2 --paths "a.txt" \
    --allow-unvalidated --reason "Tentativa de contornar B1" --commit-message "feat(AB-541): should fail b1 allow" >/dev/null 2>&1
) || rc=$?
[ "$rc" -eq 6 ] || fail "B1: Expected exit 6 with --allow-unvalidated on fixed/name adhoc log, got $rc"
[ "$(git -C "$REPO_B1" rev-parse HEAD)" = "$head_b1" ] || fail "B1: HEAD changed with --allow-unvalidated"
assert_no_literal "$fake_b1_c" "$b1_log_dir" "$REPO_B1/.agent-pack"
assert_no_literal "$fake_b1_d" "$b1_log_dir" "$REPO_B1/.agent-pack"

# ==============================================================================
# B2: JSON \uXXXX escapes (\u003d, \u0026, etc.) in ef_mask and ef_scan
# ==============================================================================
REPO_B2="$TEMP_ROOT/repo-b2"
init_repo "$REPO_B2" "feat/AB-542-b2"
fake_b2_a="EFFAKE""${ts_ns}""JsonU3d"
fake_b2_b_prefix="EFFAKE""${ts_ns}""Eq"
fake_b2_b_mid="Mid"
fake_b2_b_end="AmpEnd"
fake_b2_b="${fake_b2_b_prefix}=${fake_b2_b_mid}&${fake_b2_b_end}"
fake_b2_b_uesc="${fake_b2_b_prefix}\\u003d${fake_b2_b_mid}\\u0026${fake_b2_b_end}"

# (a) password\u003d<fake> -> masked by ef_mask and flagged by ef_scan (exit 6)
(
  unset EF_SECRET_VALUES_FILE || true
  source "$HARNESS_DIR/ef-secrets.sh"
  ef_load_secrets "$REPO_B2" "$REPO_B2/.agent-pack/logs/AB-542"
  b2_line="{\"content\":\"password\\u003d$fake_b2_a\"}"
  b2_mout_file="$TEMP_ROOT/b2-mout.txt"
  ef_mask_string "$b2_line" > "$b2_mout_file"
  [ "$_EF_LAST_MASK_COUNT" -eq 1 ] || fail "B2-a: Expected mask count 1, got $_EF_LAST_MASK_COUNT"
  b2_masked="$(cat "$b2_mout_file")"
  [ "$b2_masked" = '{"content":"password\u003d[EF-MASKED]"}' ] || fail "B2-a: Unexpected masked line: $b2_masked"
)

b2_log_dir="$REPO_B2/.agent-pack/logs/AB-542"
mkdir -p "$b2_log_dir"
printf '{"content":"password\\u003d%s"}\n' "$fake_b2_a" > "$b2_log_dir/adhoc-b2a.jsonl"
rc=0
(
  unset EF_SECRET_VALUES_FILE || true
  bash "$TESTER" --repo "$REPO_B2" --card-id "AB-542" --demand-type "Feature" --phase validate --test-cmd "echo ok" >/dev/null 2>&1
) || rc=$?
[ "$rc" -eq 6 ] || fail "B2-a: Expected exit 6 on \\u003d secret in adhoc log, got $rc"
grep -Fq 'password\u003d[EF-MASKED]' "$b2_log_dir/adhoc-b2a.jsonl" || fail "B2-a: adhoc-b2a.jsonl not masked preserving original escape"
assert_no_literal "$fake_b2_a" "$REPO_B2/.agent-pack/logs" "$REPO_B2/.agent-pack/evidencias" "$REPO_B2/.agent-pack/.runtime"

# (b) values file containing = and & appearing as \u003d/\u0026 in stream -> masked, raw and escaped forms absent
b2_vals_file="$TEMP_ROOT/b2-outside-secrets.txt"
printf '%s\n' "$fake_b2_b" > "$b2_vals_file"
(
  export EF_SECRET_VALUES_FILE="$b2_vals_file"
  export EF_ATTEMPT=1
  bash "$IMPLEMENTOR" --repo "$REPO_B2" --card-id "AB-542" \
    --harness-cmd "printf '{\"type\":\"tool_result\",\"content\":\"%s\"}\n' '$fake_b2_b_uesc'" >/dev/null
)
b2_cap="$REPO_B2/.agent-pack/logs/AB-542/AB-542_implementor_attempt1.jsonl"
grep -Fq '{"type":"tool_result","content":"[EF-MASKED]"}' "$b2_cap" || fail "B2-b: Captured stream-json did not mask \\u003d/\\u0026 value"
assert_no_literal "$fake_b2_b" "$REPO_B2/.agent-pack/logs" "$REPO_B2/.agent-pack/evidencias" "$REPO_B2/.agent-pack/.runtime"
assert_no_literal "$fake_b2_b_uesc" "$REPO_B2/.agent-pack/logs" "$REPO_B2/.agent-pack/evidencias" "$REPO_B2/.agent-pack/.runtime"

printf '{"type":"tool_result","content":"%s"}\n' "$fake_b2_b_uesc" > "$b2_log_dir/adhoc-b2b.jsonl"
rc=0
EF_SECRET_VALUES_FILE="$b2_vals_file" bash "$TESTER" --repo "$REPO_B2" --card-id "AB-542" --demand-type "Feature" --phase validate --test-cmd "echo ok" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 6 ] || fail "B2-b: Expected exit 6 on \\u003d/\\u0026 value in adhoc log, got $rc"
assert_no_literal "$fake_b2_b" "$REPO_B2/.agent-pack/logs" "$REPO_B2/.agent-pack/evidencias" "$REPO_B2/.agent-pack/.runtime"
assert_no_literal "$fake_b2_b_uesc" "$REPO_B2/.agent-pack/logs" "$REPO_B2/.agent-pack/evidencias" "$REPO_B2/.agent-pack/.runtime"

echo "Harness cycle Bash tests passed: B0, B1, B2, S1-a..e, S2-a, S3-a..f, S4-a..f."
