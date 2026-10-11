# Project guidance

> Active template: [UNVERIFIED] text is not repository evidence. Run bootstrap-dotnet-repo before the first substantial change when context is missing; reuse an already verified map. Reload the agent session after persistent instructions change when required by the host.

## Facts to confirm

- Repository shape: [UNVERIFIED]
- Solution/project files and toolchain: [UNVERIFIED]
- Confirmed build, test, and run commands: [UNVERIFIED]
- Test strategy and CI evidence: [UNVERIFIED]
- Data access, integrations, and authorization boundaries: [UNVERIFIED]

Use docs/ai/project-map.md for confirmed context. Project files, CI, scripts, and tests take precedence over unverified template examples.

## Working rules

- Inspect applicable instructions, Git status, relevant diffs, and the affected execution path. Preserve existing user changes.
- Keep changes within the user-authorized scope. Preserve public behavior outside the requested change; separate bugfixes and refactoring.
- Reuse confirmed commands. If none exist, inspect actual tooling and help, identify derived commands as inferred, and validate before recording them as confirmed. Do not fabricate a command or block solely because documentation is absent.
- For bugs, reproduce or characterize the failure when viable; distinguish observed root cause from a working hypothesis.
- Use sqlserver-structure-review for read-only understanding and db-change-sqlserver for authorized change planning/implementation, only when those skills are installed.
- Use web-dotnet for UI inside .NET web projects when installed; follow the actual stack.
- Do not expose secrets, connection strings, credentials, personal data, or sensitive payloads.
- Commit, push, merge, deploy, release, production migration/data changes and destructive operations require explicit applicable user authorization. Task completion alone does not grant it.
- Before completion use the installed check-text-encoding skill on changed text. Preserve confirmed encoding; inspect findings before editing and never strip accents to hide corruption.
- Run focused validation and verify relevant tests actually executed. If unavailable, give the precise gap and a controlled manual scenario.

## Independent and collaborative operation

Codex and Grok Build are peers. Either can independently investigate, plan, implement, test, review, and report. Neither requires the other to be installed, authenticated, or involved. Claude compatibility follows the same project rules.

The user is the sole decision authority. The agent receiving the task owns delivery unless the user assigns another coordinator. Collaboration is optional; roles follow the task, not the provider.

- Gate 1 establishes the execution envelope: objective, scope, material constraints, risks, and validation. For non-trivial work present a concise plan; existing explicit authorization for that work remains valid across turns. Ask again only for a missing material decision or scope expansion, not to repeat approval.
- Routine reversible implementation and tests within the envelope can proceed. Stop for material deviations in behavior, contracts, architecture, production dependencies, security, data, or validation; return BLOCKED_BY_DECISION with evidence, options, and a recommendation.
- In standalone mode the active agent completes all necessary roles itself. A missing companion tool is not a blocker.
- For an actual handoff use the shared agent-work-order skill. Either tool can coordinate or execute. Use only available native delegation tools or verified CLI capabilities; never invent a cross-provider API.
- Delegate only independent bounded work when useful. Concurrent modifying agents need isolated worktrees/checkouts and non-overlapping ownership; a single standalone agent can use the authorized working tree.
- Preserve uncommitted context: do not delegate from a clean ref that omits required local changes. Include the needed context safely or keep that work local.
- The receiving agent may implement within the envelope; a delegated task does not authorize committing, publishing, or applying to the caller's checkout.
- The coordinator reviews the actual diff, new files, and validation evidence before integrating within scope. In standalone mode perform that review yourself; no mandatory second provider.
- Gate 2 separates validated work from separately authorized integration/production actions. Report results and remaining gaps; do not wait for another provider to approve. Prior user authorization for a specific action remains valid unless its target or material conditions changed.
- Keep transient sessions, handoffs, and worktrees outside tracked source. Store only durable verified knowledge in docs/ai.

## Native discovery and role names

Shared skills use the same names and content. Codex discovers .agents/skills; Grok uses the mirrored .grok/skills; Claude uses .claude/skills. Resolve scripts/references relative to the skill actually loaded. A copied prompt's $skill-name means use the named skill through the active tool's native invocation, not a shell command.

| Role | Codex | Grok Build / Claude |
| --- | --- | --- |
| Explore | repo_explorer | repo-explorer |
| Implement | dotnet_implementer | dotnet-implementer |
| Tests | test_guardian | test-guardian |
| Review | change_reviewer | change-reviewer |
| Web | frontend_web | frontend-web |
| SQL | database_sqlserver | database-sqlserver |
| Security | security_reviewer | security-reviewer |
| Performance | performance_reviewer | performance-reviewer |
| Release | release_reviewer | release-reviewer |

Use only installed roles supported by the active tool. If a role is unavailable, perform the bounded work yourself. Do not launch every reviewer.

## Context and completion

Search before opening files; read relevant context once, summarize large output, and expand only for actual risk or uncertainty. Read docs/ai when relevant; revalidate stale facts against their sources. Use maintain-agent-memory for durable lessons, not transcripts.

Return motivation/root cause, changed files, actual validation, manual checks when needed, and residual risk. State uncertainty and unexecuted checks; never claim passing tests from code inspection.
