---
name: delegate-to-harness
description: Hand a bounded task to an available native subagent or headless harness session with explicit scope, state persistence on disk, and mandatory return to the delegator.
---

## SpecGuard 6 execution gate

Follow `docs/engineering-flow/workflow.md` and `docs/engineering-flow/roles-and-handoffs.md` in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# Delegate to Harness / Subagent (Tool-Agnostic)

This skill is the tool-agnostic adapter for **Hybrid Delegation** in SpecGuard 6. The method itself is role-based (`Engenheiro-Chefe`, `Tech Lead`, `Implementor`, `Tester`) and works identically with any CLI/IDE harness or standalone session.

1. Read the shared [agent work order](../agent-work-order/SKILL.md) and follow its coordinator contract.
2. Persist operational state to disk first (`TASK_SPEC.md` with `ef:paths`, `.agent-pack/.runtime/session-state.json`, and `.agent-pack/.runtime/NEXT_PROMPT.md`). Follow static-first prompt ordering and compact any error output to 20–40 root-cause lines + log path.
3. **Ask before delegating (when native subagents are available):** unless delegation was already authorized in the current Gate, ask the human whether to delegate now to the target role subagent or let them paste `NEXT_PROMPT.md` manually in another session.
4. **Mandatory return to the top of the chain:** the delegated subagent/session executes strictly its assigned role/skill inside the authorized envelope and **always returns its result to the delegator (`Tech Lead` or `Engenheiro-Chefe`)**. Never bypass Gate 1 or Gate 2, never default to auto-approve/yolo flags, and never delegate secrets or unrelated files.
5. For headless CLI invocations inside the closed loop, use `harness-cycle` runners (`--harness-cmd` or configured harness) so logs are masked in memory via `ef_mask` / `ef_scan`.
