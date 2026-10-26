---
name: agent-work-order
description: Coordinate or execute a bounded handoff between coding agents using shared scope, isolated work, and evidence-based review. Use only for actual delegation or receipt of a work order; standalone work needs no handoff.
---

## Engineering Flow 3.0 execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# Agent work order

The implementer (currently Grok Build; an example, not a requirement) can be coordinator or worker, and so can the reviewer/delivery role (currently the project bot). The current task and user authorization determine roles; see the Roles section of docs/engineering-flow/workflow.md. In standalone mode complete the task normally; do not require another provider.

## Coordinator

1. Reuse applicable AGENTS.md and the actual authorized execution envelope. Clarify only missing material decisions; do not ask for approval already provided.
2. Choose an independent bounded task. Check that the intended agent/tool exists and accepts the proposed inputs. If unavailable, perform the work locally when possible; a user-required handoff needs an honest blocker instead of an invented API.
3. Supply: Objective; Context and evidence; Human-approved scope; Non-goals; Base ref/working-tree context; Allowed read areas; Allowed modification areas; Architecture constraints; Contracts unchanged; Acceptance criteria; Verified commands (or explicitly inferred commands to verify); Forbidden actions; Decision boundaries; Escalation conditions; Return contract.
4. Include required uncommitted context safely. Concurrent writers use isolated worktrees/checkouts and distinct ownership. Do not change existing Git state to force delegation.
5. Use available native tools or documented CLI. A handoff document can be passed through the user's chosen session when no direct integration exists; do not create a tracked coordination framework.
6. Review actual diff/new files and verify relevant results independently. Apply reviewed work only within the authorized scope, preserving concurrent user edits.
7. Report READY_FOR_MANUAL_VALIDATION, REVISE, DISCARD, or USER_DECISION_REQUIRED as appropriate. These are recommendations, not permission for publication or production changes.

## Worker

1. Verify the order is coherent and the target environment fits. Missing noncritical context can be discovered; a material unresolved choice returns BLOCKED_BY_DECISION before that change.
2. Execute the authorized task with relevant project skills and validation. Do not broaden scope or weaken assertions. Do not invoke the coordinator again recursively.
3. Do not commit, push, deploy, migrate production, modify production data, or land into another checkout without separate applicable authorization.
4. Return COMPLETED, COMPLETED_WITH_CONCERNS, BLOCKED_BY_DECISION, or UNABLE_TO_VALIDATE with worktree/location, changed files, decisions, commands/results, deviations, risks, assumptions, and remaining work.
5. For a decision blocker include evidence, violated constraint, options/trade-offs, recommendation, and confirmation that the material change was not performed.

A worker summary never replaces the coordinator's inspection. A plan or report request does not authorize implementation; execute implementation only within the human-approved plan; testing additionally needs its approved envelope. Existing applicable authorization persists.
