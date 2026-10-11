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
[ ! -e "$GROK_ONLY/.codex" ]
[ -z "$(find "$GROK_ONLY/.agents" -name openai.yaml -print)" ]
grep -q '^integration|grok$' "$GROK_ONLY/.agent-pack/state.txt"
! grep -q '^integration|codex$' "$GROK_ONLY/.agent-pack/state.txt"
bash "$INSTALLER" "$GROK_ONLY" --integration codex,grok
[ -f "$GROK_ONLY/.codex/agents/frontend-web.toml" ]

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

bash "$INSTALLER" "$REPO" --include-claude --dry-run
[ ! -e "$REPO/CLAUDE.md" ]
[ ! -e "$REPO/.claude" ]

bash "$INSTALLER" "$REPO" --include-grok-build --dry-run
[ ! -e "$REPO/.grok" ]
[ ! -e "$REPO/.agents/skills/delegate-to-grok-build" ]

bash "$INSTALLER" "$REPO"
[ -f "$REPO/AGENTS.md" ]
[ -f "$REPO/.agents/skills/bootstrap-dotnet-repo/SKILL.md" ]
[ -f "$REPO/.agents/skills/agents-md-generator/references/agents-md-checklist.md" ]
[ -f "$REPO/.agents/skills/dotnet-xunit-tests/references/xunit-test-checklist.md" ]
[ ! -e "$REPO/.agents/skills/flutter-tests/SKILL.md" ]
[ -f "$REPO/.agent-pack/state.txt" ]
grep -Fxq "version|$(tr -d '\r\n' < "$PACK_ROOT/pack-version.txt")" "$REPO/.agent-pack/state.txt"
grep -q '^profile|core$' "$REPO/.agent-pack/state.txt"
[ -f "$REPO/.agents/skills/update-agent-pack/SKILL.md" ]
[ -f "$REPO/.agents/skills/check-text-encoding/scripts/check-mojibake.ps1" ]
[ -f "$REPO/.agents/skills/check-text-encoding/scripts/check-mojibake.sh" ]
[ -f "$REPO/prompts/08-update-agent-pack.md" ]
[ ! -e "$REPO/.codex/agents/frontend-web.toml" ]
[ ! -e "$REPO/CLAUDE.md" ]
[ ! -e "$REPO/.claude" ]
[ ! -e "$REPO/.grok" ]

bash "$INSTALLER" "$REPO"
[ ! -e "$REPO/AGENTS.md.agent-pack.new" ]

bash "$INSTALLER" "$REPO" --profile web,sqlserver,quality
[ -f "$REPO/.codex/agents/frontend-web.toml" ]
[ -f "$REPO/.agents/skills/web-dotnet/SKILL.md" ]
[ -f "$REPO/.agents/skills/db-change-sqlserver/SKILL.md" ]
[ -f "$REPO/.agents/skills/db-change-sqlserver/references/sqlserver-change-gates.md" ]
[ -f "$REPO/.agents/skills/sqlserver-structure-review/scripts/sqlserver-metadata-map.sql" ]
[ ! -e "$REPO/.agents/skills/flutter-tests/SKILL.md" ]
[ -f "$REPO/.agents/skills/security-review-dotnet/SKILL.md" ]
[ ! -e "$REPO/CLAUDE.md" ]
[ ! -e "$REPO/.grok" ]

bash "$INSTALLER" "$REPO" --include-claude
[ -f "$REPO/CLAUDE.md" ]
[ -f "$REPO/.claude/agents/repo-explorer.md" ]
[ -f "$REPO/.claude/skills/bootstrap-dotnet-repo/SKILL.md" ]
[ -f "$REPO/.claude/skills/bootstrap-dotnet-repo/scripts/inspect-dotnet-repo.sh" ]
[ -f "$REPO/.claude/skills/update-agent-pack/SKILL.md" ]
[ -f "$REPO/.claude/skills/check-text-encoding/scripts/check-mojibake.ps1" ]
[ -f "$REPO/.claude/skills/check-text-encoding/scripts/check-mojibake.sh" ]
[ -f "$REPO/.claude/agents/frontend-web.md" ]
[ -f "$REPO/.claude/agents/database-sqlserver.md" ]
[ -f "$REPO/.claude/agents/security-reviewer.md" ]
cmp -s "$REPO/.agents/skills/bootstrap-dotnet-repo/SKILL.md" "$REPO/.claude/skills/bootstrap-dotnet-repo/SKILL.md"

bash "$INSTALLER" "$REPO" --include-grok-build
[ -f "$REPO/.grok/config.toml" ]
[ -f "$REPO/.grok/agents/repo-explorer.md" ]
[ -f "$REPO/.grok/skills/bootstrap-dotnet-repo/SKILL.md" ]
[ -f "$REPO/.agents/skills/delegate-to-grok-build/SKILL.md" ]
[ -f "$REPO/.grok/skills/execute-codex-work-order/SKILL.md" ]
[ -f "$REPO/prompts/09-migrate-claude-to-codex-grok.md" ]
[ -f "$REPO/.grok/agents/frontend-web.md" ]
[ -f "$REPO/.grok/agents/database-sqlserver.md" ]
[ -f "$REPO/.grok/agents/security-reviewer.md" ]
cmp -s "$REPO/.agents/skills/bootstrap-dotnet-repo/SKILL.md" "$REPO/.grok/skills/bootstrap-dotnet-repo/SKILL.md"

bash "$INSTALLER" "$REPO" --include-grok-build
[ ! -e "$REPO/.grok/config.toml.agent-pack.new" ]

bash "$INSTALLER" "$REPO" --include-claude
[ ! -e "$REPO/CLAUDE.md.agent-pack.new" ]

bash "$INSTALLER" "$REPO" --profile web,sqlserver,quality --include-claude
[ -f "$REPO/.claude/agents/frontend-web.md" ]
[ -f "$REPO/.claude/agents/database-sqlserver.md" ]
[ -f "$REPO/.claude/agents/security-reviewer.md" ]
[ -f "$REPO/.claude/skills/db-change-sqlserver/SKILL.md" ]
[ -f "$REPO/.claude/skills/sqlserver-structure-review/references/sqlserver-review-checklist.md" ]
[ -f "$REPO/.claude/skills/web-dotnet/SKILL.md" ]
[ ! -e "$REPO/.claude/skills/flutter-tests/SKILL.md" ]
[ -f "$REPO/.claude/skills/security-review-dotnet/SKILL.md" ]

bash "$INSTALLER" "$REPO" --profile web,sqlserver,quality --include-grok-build
[ -f "$REPO/.grok/agents/frontend-web.md" ]
[ -f "$REPO/.grok/agents/database-sqlserver.md" ]
[ -f "$REPO/.grok/agents/security-reviewer.md" ]
[ -f "$REPO/.grok/skills/db-change-sqlserver/SKILL.md" ]
[ -f "$REPO/.grok/skills/sqlserver-structure-review/scripts/find-sqlserver-references.ps1" ]
[ -f "$REPO/.grok/skills/web-dotnet/SKILL.md" ]
[ ! -e "$REPO/.grok/skills/flutter-tests/SKILL.md" ]
[ -f "$REPO/.grok/skills/security-review-dotnet/SKILL.md" ]
[ -f "$REPO/CLAUDE.md" ]

echo "# local change" >> "$REPO/AGENTS.md"
bash "$INSTALLER" "$REPO"
[ -f "$REPO/AGENTS.md.agent-pack.new" ]

echo '# local customization' >> "$REPO/.agents/skills/bugfix-dotnet/SKILL.md"
bash "$INSTALLER" "$REPO"
bash "$INSTALLER" "$REPO"
grep -Eq '^artifact\|[^|]+\|\.agents/skills/bugfix-dotnet/SKILL.md\|[^|]+\|-\|-\|keep-local\|' "$REPO/.agent-pack/state.txt"
grep -q 'local customization' "$REPO/.agents/skills/bugfix-dotnet/SKILL.md"

bash "$INSTALLER" "$REPO" --force
cmp -s "$REPO/AGENTS.md" "$TEMPLATE/AGENTS.md"
find "$REPO" -maxdepth 1 -type f -name 'AGENTS.md.agent-pack.backup-*' | grep -q .

echo "# local Claude change" >> "$REPO/CLAUDE.md"
bash "$INSTALLER" "$REPO" --include-claude
[ -f "$REPO/CLAUDE.md.agent-pack.new" ]

bash "$INSTALLER" "$REPO" --include-claude --force
cmp -s "$REPO/CLAUDE.md" "$TEMPLATE/CLAUDE.md"
find "$REPO" -maxdepth 1 -type f -name 'CLAUDE.md.agent-pack.backup-*' | grep -q .

CODEX_HOME="$TEMP_ROOT/custom-codex-home" bash "$INSTALLER" "$REPO" --install-global
[ -f "$TEMP_ROOT/custom-codex-home/AGENTS.md" ]

echo "Installer smoke test passed."
