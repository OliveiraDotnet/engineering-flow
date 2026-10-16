#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
INSPECTOR="$PACK_ROOT/repo-template/.agents/skills/bootstrap-repo/scripts/inspect-repo.sh"
INSTALLER="$SCRIPT_DIR/install-engineering-flow.sh"
UPDATER="$SCRIPT_DIR/update-engineering-flow.sh"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/engineering-flow-tests.XXXXXX")"
cleanup() {
  case "$TEMP_ROOT" in "${TMPDIR:-/tmp}"/engineering-flow-tests.*) rm -rf -- "$TEMP_ROOT" ;; *) echo 'Unsafe test cleanup' >&2; return 1 ;; esac
}
trap cleanup EXIT
fail() { echo "TEST FAILURE: $*" >&2; exit 1; }
new_repo() { mkdir -p "$1"; git -C "$1" init -q; }
empty="$TEMP_ROOT/empty"
new_repo "$empty"
output="$(bash "$INSPECTOR" "$empty")"
[[ "$output" = *'Discovery mode: empty'* ]] || fail 'Empty mode lost'
[[ "$output" = *'Suggested profiles: [none]'* ]] || fail 'Empty selected unrelated modules'
bash "$INSTALLER" "$empty" --integration grok --profile core
[ -f "$empty/.grok/skills/new-project/SKILL.md" ] || fail 'Empty new-project missing'
[ ! -e "$empty/.codex" ] || fail 'Independent Grok installed Codex'
[ ! -e "$empty/.agents/skills/mobile-app" ] || fail 'Core installed mobile'
mixed="$TEMP_ROOT/mixed"
new_repo "$mixed"
mkdir -p "$mixed/web" "$mixed/api" "$mixed/ui"
printf '<%% Response.Write "fixture" %%>\n' > "$mixed/web/default.asp"
printf '<Project><TargetFrameworkVersion>v4.8</TargetFrameworkVersion><PackageReference Include="System.Data.SqlClient" /></Project>\n' > "$mixed/api/Legacy.csproj"
printf '{"scripts":{"test":"echo synthetic-secret-script-body"}}\n' > "$mixed/ui/package.json"
output="$(bash "$INSPECTOR" "$mixed")"
[[ "$output" = *'Suggested profiles: web sqlserver'* ]] || fail 'Mixed ASP/.NET/SQL detection lost'
[[ "$output" = *'v4.8'* && "$output" = *'ui/package.json'* ]] || fail 'Mixed evidence lost'
[[ "$output" != *'synthetic-secret-script-body'* ]] || fail 'Source payload leaked'
bash "$INSTALLER" "$mixed" --integration codex
[ -f "$mixed/.agents/skills/web-app/SKILL.md" ] || fail 'ASP web profile missing'
unknown="$TEMP_ROOT/unknown"
new_repo "$unknown"
printf opaque > "$unknown/engine.customlang"
printf 'class BackendOnly\n' > "$unknown/Main.kt"
printf 'print("fixture-only")\n' > "$unknown/main.swift"
printf 'SELECT 1;\n' > "$unknown/schema.sql"
output="$(bash "$INSPECTOR" "$unknown")"
[[ "$output" = *'Discovery mode: existing'* && "$output" = *'Suggested profiles: [none]'* ]] || fail 'Unknown stack invented support'
[[ "$output" = *'.customlang 1'* ]] || fail 'Unknown extension evidence lost'
mobile="$TEMP_ROOT/mobile"
new_repo "$mobile"
printf '<manifest />\n' > "$mobile/AndroidManifest.xml"
printf 'class Main\n' > "$mobile/Main.kt"
output="$(bash "$INSPECTOR" "$mobile")"
[[ "$output" = *'Suggested profiles: mobile'* ]] || fail 'Native mobile not detected'
bash "$INSTALLER" "$mobile" --integration grok
[ -f "$mobile/.grok/skills/mobile-app/SKILL.md" ] || fail 'Mobile independent install missing'
[ ! -e "$mobile/.agents/skills/web-app" ] || fail 'Native mobile installed web'
hybrid="$TEMP_ROOT/hybrid"
new_repo "$hybrid"
printf 'name: fixture_only\n' > "$hybrid/pubspec.yaml"
printf '<html></html>\n' > "$hybrid/index.html"
output="$(bash "$INSPECTOR" "$hybrid")"
[[ "$output" = *'Suggested profiles: web mobile'* ]] || fail 'Mixed cross-platform detection lost'

old="$TEMP_ROOT/old"
new_repo "$old"
cp -R "$PACK_ROOT/tests/fixtures/installed-1.7.0/repo/." "$old/"
mkdir -p "$old/.agent-pack"
cp "$PACK_ROOT/tests/fixtures/installed-1.7.0/state.txt" "$old/.agent-pack/state.txt"
printf '\nLocal recurring rule: preserve me.\n' >> "$old/.agents/skills/bugfix-dotnet/SKILL.md"
printf '\nLocal project guidance: preserve me.\n' >> "$old/AGENTS.md"
printf 'Verified local commands: fixture only.\n' > "$old/docs/ai/runbook.md"
before="$(sha256sum "$old/AGENTS.md" "$old/.agents/skills/bugfix-dotnet/SKILL.md" "$old/docs/ai/runbook.md")"
check_status=0
bash "$UPDATER" "$old" --check || check_status=$?
[ "$check_status" -eq 2 ] || fail 'Expected check-mode conflict exit code 2'
[ "$before" = "$(sha256sum "$old/AGENTS.md" "$old/.agents/skills/bugfix-dotnet/SKILL.md" "$old/docs/ai/runbook.md")" ] || fail 'Check changed content'
if bash "$UPDATER" "$old" --apply; then fail 'Custom migration bypassed conflict'; fi
[ "$before" = "$(sha256sum "$old/AGENTS.md" "$old/.agents/skills/bugfix-dotnet/SKILL.md" "$old/docs/ai/runbook.md")" ] || fail 'Conflict was not atomic'
bash "$UPDATER" "$old" --apply --keep-local guidance.agents --keep-local skill.shared.bugfix-dotnet --accept-pack config.grok.project
[ "$before" = "$(sha256sum "$old/AGENTS.md" "$old/.agents/skills/bugfix-dotnet/SKILL.md" "$old/docs/ai/runbook.md")" ] || fail 'Migration lost managed/merge/seed customizations'
grep -Fxq "version|$(tr -d '\r\n' < "$PACK_ROOT/pack-version.txt")" "$old/.agent-pack/state.txt" || fail 'Version not advanced'
grep -q '^integration|grok$' "$old/.agent-pack/state.txt" || fail 'Integration selection lost'
grep -q '^profile|web$' "$old/.agent-pack/state.txt" || fail 'Web selection lost'
if grep -Eq '^profile\|(mobile|quality)$|^integration\|codex$' "$old/.agent-pack/state.txt"; then fail 'Migration expanded selection'; fi
[ -f "$old/.grok/skills/complete-task/SKILL.md" ] || fail 'Selected workflow not migrated'
[ ! -e "$old/.grok/skills/mobile-app" ] || fail 'Migration installed unrelated mobile'
grep -q 'Engineering Flow 2.0 execution gate' "$old/.grok/skills/web-dotnet/SKILL.md" || fail 'Trusted 1.7 managed file not updated'
echo 'Engineering Flow Bash script regressions passed: empty, unknown, classic ASP/mixed, native/hybrid, independent selection, actual 1.7 bytes, conflict atomicity and customization. No agent/browser/device behavior claimed.'
