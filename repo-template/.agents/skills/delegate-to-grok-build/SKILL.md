---
name: delegate-to-grok-build
description: Hand a bounded task to an available Grok Build session or native subagent with explicit scope and independent diff review. Use when Grok delegation is requested or useful, not as a prerequisite for standalone work.
---

## Engineering Flow 2.0 execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# Delegate to Grok Build

Read the shared [agent work order](../agent-work-order/SKILL.md) and follow its coordinator contract. Codex, Grok Build, or another authorized agent can coordinate; user authorization establishes the execution envelope.

If already running in Grok Build, prefer its available native subagent mechanism for a useful independent task rather than recursively starting another coordinator. A missing Grok CLI does not block ordinary standalone work.

For a cross-tool CLI handoff, verify the installed version and supported help, then use a scoped isolated worktree only when the task needs it. A typical supported invocation is:

```text
grok --no-auto-update --worktree=<task-label> --ref <base-ref> -p "<work-order>" --output-format json
```

Pass the actual work order using the shell's safe argument handling; the placeholders are not literal commands. Verify base ref and uncommitted context first. Do not default to always-approve/yolo or broad tool permissions. Delegate no secrets or unrelated data.

Follow agent-work-order for all return statuses, escalation, diff review, and landing. Before cleanup, inspect remaining worktrees and preserve unmerged or user-owned changes.
