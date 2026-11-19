#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
INSTALLER="$SCRIPT_DIR/install-agent-pack.sh"
TEMPLATE="$PACK_ROOT/repo-template"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotnet-agents-pack.XXXXXX")"
REPO="$TEMP_ROOT/target"

cleanup() {
  case "$TEMP_ROOT" in "${TMPDIR:-/tmp}"/dotnet-agents-pack.*) rm -rf -- "$TEMP_ROOT" ;; *) echo 'Unsafe test cleanup path' >&2; return 1 ;; esac
}
trap cleanup EXIT

mkdir -p "$REPO"
git -C "$REPO" init -q

bash "$INSTALLER" "$REPO" --dry-run
[ ! -e "$REPO/AGENTS.md" ]
[ ! -e "$REPO/.agent-pack" ]

GROK_ONLY="$TEMP_ROOT/grok-only"
mkdir -p "$GROK_ONLY"
git -C "$GROK_ONLY" init -q
bash "$INSTALLER" "$GROK_ONLY" --integration grok --profile web,sqlserver,quality
bash "$INSTALLER" "$GROK_ONLY"
[ -f "$GROK_ONLY/.grok/config.toml" ]
[ -f "$GROK_ONLY/.grok/agents/repo-explorer.md" ]
[ -f "$GROK_ONLY/.grok/agents/frontend-web.md" ]
[ ! -e "$GROK_ONLY/.codex" ]
[ ! -e "$GROK_ONLY/.claude/agents" ]
[ -f "$GROK_ONLY/.claude/skills/harness-cycle/SKILL.md" ]
[ -f "$GROK_ONLY/.claude/skills/role-tech-lead/SKILL.md" ]
[ ! -e "$GROK_ONLY/CLAUDE.md" ]
[ -z "$(find "$GROK_ONLY/.agents" -name openai.yaml -print)" ]
[ ! -e "$GROK_ONLY/.agent-pack/state.txt" ]
if bash "$INSTALLER" "$GROK_ONLY" --integration codex,grok; then
  echo 'Installer accepted Codex integration.' >&2
  exit 1
fi

for linked_relative in .agents .agent-pack AGENTS.md.agent-pack.new; do
  linked_repo="$(mktemp -d "$TEMP_ROOT/linked.XXXXXX")"
  outside="$(mktemp -d "$TEMP_ROOT/outside.XXXXXX")"
  git -C "$linked_repo" init -q
  ln -s "$outside" "$linked_repo/$linked_relative"
  if [ -L "$linked_repo/$linked_relative" ]; then
    if bash "$INSTALLER" "$linked_repo" --profile core; then echo 'Installer accepted linked path' >&2; exit 1; fi
    [ -z "$(find "$outside" -mindepth 1 -print)" ]
    [ ! -e "$linked_repo/AGENTS.md" ]
  else
    echo 'SKIP: platform did not create a real symbolic link.'
  fi
done

bash "$INSTALLER" "$REPO" --dry-run
[ ! -e "$REPO/.grok" ]
[ ! -e "$REPO/.agents/skills/delegate-to-grok-build" ]

bash "$INSTALLER" "$REPO"
[ -f "$REPO/AGENTS.md" ]
[ -f "$REPO/.agents/skills/bootstrap-dotnet-repo/SKILL.md" ]
[ -f "$REPO/.agents/skills/agents-md-generator/references/agents-md-checklist.md" ]
[ -f "$REPO/.agents/skills/dotnet-xunit-tests/references/xunit-test-checklist.md" ]
[ ! -e "$REPO/.agents/skills/flutter-tests/SKILL.md" ]
[ ! -e "$REPO/.agents/skills/update-engineering-flow/SKILL.md" ]
[ ! -e "$REPO/.agent-pack/state.txt" ]
[ -f "$REPO/.agents/skills/harness-cycle/SKILL.md" ]
[ -f "$REPO/.agents/skills/harness-cycle/scripts/run-implementor.sh" ]
[ -f "$REPO/.agents/skills/harness-cycle/scripts/run-tester.sh" ]
[ -f "$REPO/.agents/skills/harness-cycle/scripts/supervise-harness.sh" ]
[ -f "$REPO/.grok/skills/harness-cycle/SKILL.md" ]
[ -f "$REPO/prompts/12-implementor-harness.md" ]
[ -f "$REPO/prompts/13-tester-harness.md" ]
[ -f "$REPO/.agents/skills/update-agent-pack/SKILL.md" ]
[ -f "$REPO/.agents/skills/check-text-encoding/scripts/check-mojibake.ps1" ]
[ -f "$REPO/.agents/skills/check-text-encoding/scripts/check-mojibake.sh" ]
[ -f "$REPO/prompts/08-update-agent-pack.md" ]
[ ! -e "$REPO/prompts/09-migrate-claude-to-codex-grok.md" ]
[ ! -e "$REPO/.codex" ]
[ ! -e "$REPO/CLAUDE.md" ]
[ ! -e "$REPO/.claude/agents" ]
[ -f "$REPO/.claude/skills/bootstrap-dotnet-repo/SKILL.md" ]
[ -f "$REPO/.claude/skills/role-tech-lead/SKILL.md" ]
[ -f "$REPO/.grok/config.toml" ]
[ -f "$REPO/.grok/agents/repo-explorer.md" ]
[ -f "$REPO/.grok/agents/implementer.md" ]
[ -f "$REPO/.agents/skills/delegate-to-grok-build/SKILL.md" ]
[ -f "$REPO/.grok/skills/delegate-to-grok-build/SKILL.md" ]
[ ! -e "$REPO/.grok/skills/execute-codex-work-order" ]
[ ! -e "$REPO/.codex/agents/frontend-web.toml" ]

bash "$INSTALLER" "$REPO"
[ ! -e "$REPO/AGENTS.md.agent-pack.new" ]
[ ! -e "$REPO/.grok/config.toml.agent-pack.new" ]

bash "$INSTALLER" "$REPO" --profile web,sqlserver,quality
[ -f "$REPO/.grok/agents/frontend-web.md" ]
[ -f "$REPO/.agents/skills/web-dotnet/SKILL.md" ]
[ -f "$REPO/.grok/skills/web-dotnet/SKILL.md" ]
[ -f "$REPO/.agents/skills/db-change-sqlserver/SKILL.md" ]
[ -f "$REPO/.agents/skills/db-change-sqlserver/references/sqlserver-change-gates.md" ]
[ -f "$REPO/.agents/skills/sqlserver-structure-review/scripts/sqlserver-metadata-map.sql" ]
[ ! -e "$REPO/.agents/skills/flutter-tests/SKILL.md" ]
[ -f "$REPO/.agents/skills/security-review-dotnet/SKILL.md" ]
[ -f "$REPO/.grok/agents/database-sqlserver.md" ]
[ -f "$REPO/.grok/agents/security-reviewer.md" ]
[ ! -e "$REPO/CLAUDE.md" ]
[ ! -e "$REPO/.codex" ]
cmp -s "$REPO/.agents/skills/bootstrap-dotnet-repo/SKILL.md" "$REPO/.claude/skills/bootstrap-dotnet-repo/SKILL.md"
cmp -s "$REPO/.agents/skills/bootstrap-dotnet-repo/SKILL.md" "$REPO/.grok/skills/bootstrap-dotnet-repo/SKILL.md"
[ -f "$REPO/.grok/skills/db-change-sqlserver/SKILL.md" ]
[ -f "$REPO/.grok/skills/sqlserver-structure-review/scripts/find-sqlserver-references.ps1" ]
[ ! -e "$REPO/.grok/skills/flutter-tests/SKILL.md" ]
[ -f "$REPO/.grok/skills/security-review-dotnet/SKILL.md" ]

echo "# local change" >> "$REPO/AGENTS.md"
bash "$INSTALLER" "$REPO"
[ -f "$REPO/AGENTS.md.agent-pack.new" ]

echo '# local customization' >> "$REPO/.agents/skills/bugfix-dotnet/SKILL.md"
bash "$INSTALLER" "$REPO"
bash "$INSTALLER" "$REPO"
[ ! -e "$REPO/.agent-pack/state.txt" ]
grep -q 'local customization' "$REPO/.agents/skills/bugfix-dotnet/SKILL.md"

# I5: --force on AGENTS.md merges managed blocks, preserves outside content, removes sidecar, keeps backup
bash "$INSTALLER" "$REPO" --force
grep -Fq "# local change" "$REPO/AGENTS.md"
[ ! -e "$REPO/AGENTS.md.agent-pack.new" ]
find "$REPO" -maxdepth 1 -type f -name 'AGENTS.md.agent-pack.backup-*' | grep -q .

echo "# local Grok change" >> "$REPO/.grok/config.toml"
bash "$INSTALLER" "$REPO"
[ -f "$REPO/.grok/config.toml.agent-pack.new" ]

bash "$INSTALLER" "$REPO" --force
cmp -s "$REPO/.grok/config.toml" "$TEMPLATE/.grok/config.toml"
find "$REPO/.grok" -maxdepth 1 -type f -name 'config.toml.agent-pack.backup-*' | grep -q .

GROK_HOME="$TEMP_ROOT/custom-grok-home" bash "$INSTALLER" "$REPO" --install-global
[ -f "$TEMP_ROOT/custom-grok-home/AGENTS.md" ]

fail() { echo "FAIL: $1" >&2; exit 1; }
sha256_file() { sha256sum "$1" | cut -d' ' -f1; }

# I5-a: without --force, AGENTS.md hash stays identical and sidecar is created
repo_i5a="$TEMP_ROOT/repo-i5a"
mkdir -p "$repo_i5a" && git -C "$repo_i5a" init -q
bash "$INSTALLER" "$repo_i5a" >/dev/null
printf '\n- Sentinel I5-a: keep untouched\n' >> "$repo_i5a/AGENTS.md"
hash_i5a_before="$(sha256_file "$repo_i5a/AGENTS.md")"
bash "$INSTALLER" "$repo_i5a" >/dev/null
[ "$(sha256_file "$repo_i5a/AGENTS.md")" = "$hash_i5a_before" ] || fail "I5-a: AGENTS.md changed without --force"
[ -f "$repo_i5a/AGENTS.md.agent-pack.new" ] || fail "I5-a: sidecar missing"

# I5-b: --force with managed markers preserves outside bytes (BOM/CRLF/EOF) and updates blocks
pack_copy="$TEMP_ROOT/pack-copy"
mkdir -p "$pack_copy"
tar -C "$PACK_ROOT" --exclude='.git' -cf - . | tar -C "$pack_copy" -xf -
repo_i5b="$TEMP_ROOT/repo-i5b"
mkdir -p "$repo_i5b" && git -C "$repo_i5b" init -q
bash "$pack_copy/scripts/install-agent-pack.sh" "$repo_i5b" >/dev/null

# Add BOM, CRLF, Sentinel A outside blocks (Convenções), Sentinel B inside contract block, and strip trailing newline at EOF
perl -i -0777 -pe '
  s/\r?\n/\r\n/g;
  s/## Convenções do projeto\r\n/## Convenções do projeto\r\n- Sentinel A: projeto preservado\r\n/;
  s/(<!-- ef:managed:begin:contract -->\r\n)/$1Sentinel B: old managed line\r\n/;
  s/\r\n\z//;
  $_ = "\xEF\xBB\xBF" . $_;
' "$repo_i5b/AGENTS.md"

# Also add new line C inside contract block of the template copy
perl -i -0777 -pe '
  s/(<!-- ef:managed:end:contract -->)/Sentinel C: new managed line\n$1/;
' "$pack_copy/repo-template/AGENTS.md"

outside_hash_before="$(perl -0777 -pe 's/<!--\s*ef:managed:begin:[A-Za-z0-9_-]+\s*-->.*?<!--\s*ef:managed:end:[A-Za-z0-9_-]+\s*-->//sg' "$repo_i5b/AGENTS.md" | sha256sum | cut -d' ' -f1)"
full_hash_before="$(sha256_file "$repo_i5b/AGENTS.md")"

dry_i5b_out="$(bash "$pack_copy/scripts/install-agent-pack.sh" "$repo_i5b" --force --dry-run)"
printf '%s\n' "$dry_i5b_out" | grep -q 'WOULD-MERGE' || fail "I5-b: dry-run missing WOULD-MERGE"
[ "$(sha256_file "$repo_i5b/AGENTS.md")" = "$full_hash_before" ] || fail "I5-b: dry-run modified AGENTS.md"

merge_out="$(bash "$pack_copy/scripts/install-agent-pack.sh" "$repo_i5b" --force)"
printf '%s\n' "$merge_out" | grep -q 'MERGE AGENTS.md (blocks: header,contract,memory)' || fail "I5-b: missing MERGE summary"
grep -Fq 'Sentinel A: projeto preservado' "$repo_i5b/AGENTS.md" || fail "I5-b: Sentinel A lost"
! grep -Fq 'Sentinel B: old managed line' "$repo_i5b/AGENTS.md" || fail "I5-b: Sentinel B still present"
grep -Fq 'Sentinel C: new managed line' "$repo_i5b/AGENTS.md" || fail "I5-b: Sentinel C missing"
outside_hash_after="$(perl -0777 -pe 's/<!--\s*ef:managed:begin:[A-Za-z0-9_-]+\s*-->.*?<!--\s*ef:managed:end:[A-Za-z0-9_-]+\s*-->//sg' "$repo_i5b/AGENTS.md" | sha256sum | cut -d' ' -f1)"
[ "$outside_hash_after" = "$outside_hash_before" ] || fail "I5-b: bytes outside managed blocks changed"
find "$repo_i5b" -maxdepth 1 -type f -name 'AGENTS.md.agent-pack.backup-*' | grep -q . || fail "I5-b: backup missing"
[ ! -e "$repo_i5b/AGENTS.md.agent-pack.new" ] || fail "I5-b: sidecar was not removed after merge"

# I5-c: --force on AGENTS.md without markers keeps file, keeps sidecar, warns, exits 7
repo_i5c="$TEMP_ROOT/repo-i5c"
mkdir -p "$repo_i5c" && git -C "$repo_i5c" init -q
printf '# Freeform AGENTS\nProject notes here.\n' > "$repo_i5c/AGENTS.md"
hash_i5c_before="$(sha256_file "$repo_i5c/AGENTS.md")"
dry_i5c_out="$(bash "$INSTALLER" "$repo_i5c" --force --dry-run)"
printf '%s\n' "$dry_i5c_out" | grep -q 'WOULD-SKIP-MERGE' || fail "I5-c: dry-run missing WOULD-SKIP-MERGE"
[ ! -e "$repo_i5c/AGENTS.md.agent-pack.new" ] || fail "I5-c: dry-run wrote sidecar"

set +e
err_i5c="$(bash "$INSTALLER" "$repo_i5c" --force 2>&1 >/dev/null)"
rc_i5c=$?
set -e
[ "$rc_i5c" -eq 7 ] || fail "I5-c: expected exit 7, got $rc_i5c"
printf '%s\n' "$err_i5c" | grep -q 'no ef:managed markers' || fail "I5-c: missing warning message"
[ "$(sha256_file "$repo_i5c/AGENTS.md")" = "$hash_i5c_before" ] || fail "I5-c: AGENTS.md modified"
[ -f "$repo_i5c/AGENTS.md.agent-pack.new" ] || fail "I5-c: sidecar missing"
[ -f "$repo_i5c/.agents/skills/harness-cycle/SKILL.md" ] || fail "I5-c: rest of install did not complete"

# I5-d: --force on AGENTS.md with malformed markers (duplicate id / unclosed begin) exits 7
for bad_kind in dup unclosed; do
  repo_i5d="$TEMP_ROOT/repo-i5d-$bad_kind"
  mkdir -p "$repo_i5d" && git -C "$repo_i5d" init -q
  if [ "$bad_kind" = dup ]; then
    printf '<!-- ef:managed:begin:header -->\na\n<!-- ef:managed:end:header -->\n<!-- ef:managed:begin:header -->\nb\n<!-- ef:managed:end:header -->\n' > "$repo_i5d/AGENTS.md"
  else
    printf '<!-- ef:managed:begin:header -->\na\n' > "$repo_i5d/AGENTS.md"
  fi
  hash_i5d_before="$(sha256_file "$repo_i5d/AGENTS.md")"
  set +e
  err_i5d="$(bash "$INSTALLER" "$repo_i5d" --force 2>&1 >/dev/null)"
  rc_i5d=$?
  set -e
  [ "$rc_i5d" -eq 7 ] || fail "I5-d ($bad_kind): expected exit 7, got $rc_i5d"
  printf '%s\n' "$err_i5d" | grep -q 'malformed ef:managed markers' || fail "I5-d ($bad_kind): missing malformed warning"
  [ "$(sha256_file "$repo_i5d/AGENTS.md")" = "$hash_i5d_before" ] || fail "I5-d ($bad_kind): AGENTS.md modified"
  [ -f "$repo_i5d/AGENTS.md.agent-pack.new" ] || fail "I5-d ($bad_kind): sidecar missing"
done

# I6-a & I6-b: EF 3.0 .gitignore with AGENTS.md, bin/, *.user, BOM+CRLF
repo_i6="$TEMP_ROOT/repo-i6"
mkdir -p "$repo_i6" && git -C "$repo_i6" init -q
perl -e 'print "\xEF\xBB\xBFAGENTS.md\r\nbin/\r\n*.user\r\n"' > "$repo_i6/.gitignore"
gi_prefix_len="$(wc -c < "$repo_i6/.gitignore")"
gi_prefix_hex="$(od -An -tx1 -v "$repo_i6/.gitignore" | tr -d ' \n')"

i6_out="$(bash "$INSTALLER" "$repo_i6")"
printf '%s\n' "$i6_out" | grep -q 'UNIGNORE' || fail "I6-a: stdout missing UNIGNORE"
if git -C "$repo_i6" check-ignore -q -- AGENTS.md; then fail "I6-a: AGENTS.md still ignored"; fi
git -C "$repo_i6" check-ignore -q -- bin/x || fail "I6-a: bin/x no longer ignored"
git -C "$repo_i6" check-ignore -q -- foo.user || fail "I6-a: foo.user no longer ignored"
new_prefix_hex="$(head -c "$gi_prefix_len" "$repo_i6/.gitignore" | od -An -tx1 -v | tr -d ' \n')"
[ "$new_prefix_hex" = "$gi_prefix_hex" ] || fail "I6-a: original .gitignore bytes were modified"
git -C "$repo_i6" status --porcelain | grep -qE '^\?\? AGENTS\.md$' || fail "I6-a: AGENTS.md not visible in git status"

# I6-b: idempotent reinstall
gi_hash_i6="$(sha256_file "$repo_i6/.gitignore")"
bash "$INSTALLER" "$repo_i6" >/dev/null
[ "$(sha256_file "$repo_i6/.gitignore")" = "$gi_hash_i6" ] || fail "I6-b: .gitignore changed on second install"

# I6-c: --dry-run does not modify .gitignore and prints WOULD-UNIGNORE
repo_i6c="$TEMP_ROOT/repo-i6c"
mkdir -p "$repo_i6c" && git -C "$repo_i6c" init -q
printf 'AGENTS.md\n' > "$repo_i6c/.gitignore"
gi_hash_i6c="$(sha256_file "$repo_i6c/.gitignore")"
dry_i6_out="$(bash "$INSTALLER" "$repo_i6c" --dry-run)"
printf '%s\n' "$dry_i6_out" | grep -q 'WOULD-UNIGNORE' || fail "I6-c: missing WOULD-UNIGNORE"
[ "$(sha256_file "$repo_i6c/.gitignore")" = "$gi_hash_i6c" ] || fail "I6-c: dry-run modified .gitignore"

# I6-d: repo without AGENTS.md ignore rule has no !AGENTS.md
if grep -Fxq '!AGENTS.md' "$REPO/.gitignore"; then fail "I6-d: !AGENTS.md added unexpectedly"; fi

# I6 exit 5: AGENTS.md still ignored after !AGENTS.md
repo_i6_fail="$TEMP_ROOT/repo-i6-fail"
mkdir -p "$repo_i6_fail" && git -C "$repo_i6_fail" init -q
printf 'AGENTS.md\n' > "$repo_i6_fail/.gitignore"
shim_dir="$TEMP_ROOT/shim-i6"
mkdir -p "$shim_dir"
real_git="$(command -v git)"
cat > "$shim_dir/git" <<EOF
#!/usr/bin/env bash
for arg in "\$@"; do
  if [ "\$arg" = "check-ignore" ]; then
    for a in "\$@"; do
      if [ "\$a" = "-v" ]; then
        printf '.git/info/exclude:1:AGENTS.md\tAGENTS.md\n'
        exit 0
      fi
    done
    exit 0
  fi
done
exec "$real_git" "\$@"
EOF
chmod +x "$shim_dir/git"
set +e
err_i6_fail="$(PATH="$shim_dir:$PATH" bash "$INSTALLER" "$repo_i6_fail" 2>&1 >/dev/null)"
rc_i6_fail=$?
set -e
[ "$rc_i6_fail" -eq 5 ] || fail "I6-fail: expected exit 5, got $rc_i6_fail"
printf '%s\n' "$err_i6_fail" | grep -q 'AGENTS.md is still ignored after appending !AGENTS.md' || fail "I6-fail: missing error message"
[ ! -e "$repo_i6_fail/.agents" ] || fail "I6-fail: installer copied files despite preflight failure"

# I7-a & I7-b: .ai-memory.toml is ignored and reinstall is idempotent
git -C "$REPO" check-ignore -q -- .ai-memory.toml || fail "I7-a: .ai-memory.toml is not ignored"
grep -Fq '# Engineering Flow: clean install; only AGENTS.md stays versionable.' "$REPO/.gitignore" || fail "I7: marker comment missing or has version"
gi_hash_i7="$(sha256_file "$REPO/.gitignore")"
bash "$INSTALLER" "$REPO" >/dev/null
[ "$(sha256_file "$REPO/.gitignore")" = "$gi_hash_i7" ] || fail "I7-b: .gitignore changed on reinstall"

echo "Installer smoke test passed."
