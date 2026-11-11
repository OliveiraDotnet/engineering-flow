---
name: harness-cycle
description: Orchestrate or execute the local pre-Gate 2 closed loop between Implementor (coder) and Tester (QA validator) using any configured CLI harness or standalone agent.
---

## Engineering Flow 5.0 execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# Harness Cycle (Implementor + Tester)

Engineering Flow 5.0 is role-based and tool-agnostic. A single standalone harness can execute both roles sequentially, or a repository reviewer/coordinator can invoke the headless runner scripts to orchestrate a closed loop (maximum 3 attempts) between the **Implementor** and **Tester** roles before requesting **Gate 2** approval from the human approver.

## Roles in the Local Harness

1. **Implementor (`prompts/12-implementor-harness.md`):**
   - Modifies only files authorized in the Gate 1 envelope on the card branch (`feat/AB-<ID>-<slug>` or `fix/AB-<ID>-<slug>`).
   - Reads `.agent-pack/.runtime/test-status.json` and `.agent-pack/evidencias/<CardId>/EVIDENCIA.md` when retrying after a test failure.
   - Never pushes. Executes `git commit` only after explicit human approval at **Gate 2** (`--commit-gate2` / `-CommitGate2`), which also expires `.agent-pack/.runtime/task.lock`.
2. **Tester (`prompts/13-tester-harness.md`):**
   - Never modifies application business code.
   - In bugs, verifies `r0-red` (the regression test must fail before the fix) and `validate` (`R0-GREEN` + approved suites must pass after the fix).
   - Writes `.agent-pack/evidencias/<CardId>/EVIDENCIA.md` and `.agent-pack/.runtime/test-status.json` (both ignored by Git so no operational noise is versioned).
3. **Harness Supervisor (`supervise-harness.sh` / `supervise-harness.ps1`):**
   - Enforces the `r0-red` check on bugs (unless explicitly waived by the human approver in Gate 1) and runs up to 3 iterations of `run-implementor` followed by `run-tester --phase validate`.
   - Stops immediately on success (`PASSED`) to present evidence for Gate 2, or aborts after 3 failed attempts with `UNABLE_TO_VALIDATE` (`exit 1`).

## Headless Scripts (Bash and PowerShell)

All scripts are tool-agnostic and accept any CLI harness command via `--harness-cmd` / `-HarnessCommand` (or environment variables `EF_IMPLEMENTOR_CMD` / `EF_TESTER_CMD`) and any project test runner command via `--test-cmd` / `-TestCommand` (or `EF_TEST_CMD`):

```bash
# 1. Closed-loop supervision (up to 3 attempts, R0-RED -> Implementor -> R0-GREEN)
bash ./.agents/skills/harness-cycle/scripts/supervise-harness.sh \
  --card-id AB-1042 \
  --demand-type Bug \
  --r0-red-cmd "<command-that-reproduces-bug-failure>" \
  --implementor-cmd "<headless-harness-command>" \
  --test-cmd "<approved-test-command>"

# 2. Post-Gate 2 atomic commit by Implementor (after human approver OK)
bash ./.agents/skills/harness-cycle/scripts/run-implementor.sh \
  --card-id AB-1042 \
  --commit-gate2 \
  --commit-message "fix(AB-1042): corrigir validacao do formulario"
```

```powershell
# 1. Closed-loop supervision in PowerShell 7
pwsh -File ./.agents/skills/harness-cycle/scripts/supervise-harness.ps1 `
  -CardId AB-1042 `
  -DemandType Bug `
  -R0RedCommand "<command-that-reproduces-bug-failure>" `
  -ImplementorCommand "<headless-harness-command>" `
  -TestCommand "<approved-test-command>"

# 2. Post-Gate 2 atomic commit by Implementor (after human approver OK)
pwsh -File ./.agents/skills/harness-cycle/scripts/run-implementor.ps1 `
  -CardId AB-1042 `
  -CommitGate2 `
  -CommitMessage "fix(AB-1042): corrigir validacao do formulario"
```
