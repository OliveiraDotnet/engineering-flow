---
name: harness-cycle
description: Orchestrate or execute the local pre-Gate 2 closed loop between Implementor (coder) and Tester (QA validator) using any configured CLI harness or standalone agent.
---

## Engineering Flow 5.1 execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# Harness Cycle (Implementor + Tester)

Engineering Flow 5.1 is role-based and tool-agnostic. A single standalone harness can accumulate roles and execute both sequentially, whereas in multi-role operation the reviewer/delivery role writes `TASK_SPEC.md` (with `ef:paths`), reviews the diff and evidence, and handles push, PR, and merge — **only the harness (Implementor/Tester) runs the runners** (`supervise-harness`, `run-implementor`, `run-tester`, and `--commit-gate2`) to execute the closed loop (maximum 3 attempts) before requesting **Gate 2** approval from the human approver.

## Roles in the Local Harness

1. **Implementor (`prompts/12-implementor-harness.md`):**
   - Modifies only files authorized in the Gate 1 envelope on the card branch (`feat/AB-<ID>-<slug>` or `fix/AB-<ID>-<slug>`).
   - Reads `.agent-pack/.runtime/test-status.json` and `.agent-pack/evidencias/<CardId>/EVIDENCIA.md` when retrying after a test failure.
   - Never pushes. Does not create or validate `.agent-pack/.runtime/task.lock` (whoever opens the task acquires it beforehand via `tools/task-lock.{sh,ps1} acquire`); executes `git commit` only after explicit human approval at **Gate 2** (`--commit-gate2` / `-CommitGate2`), removing the lock only after a successful Gate 2 commit.
2. **Tester (`prompts/13-tester-harness.md`):**
   - Never modifies application business code.
   - In bugs, verifies `r0-red` (the regression test must fail before the fix) and `validate` (`R0-GREEN` + approved suites must pass after the fix).
   - Writes `.agent-pack/evidencias/<CardId>/EVIDENCIA.md` and `.agent-pack/.runtime/test-status.json` (both ignored by Git so no operational noise is versioned).
3. **Harness Supervisor (`supervise-harness.sh` / `supervise-harness.ps1`):**
   - Enforces the `r0-red` check on bugs (unless explicitly waived by the human approver in Gate 1) and runs up to 3 iterations of `run-implementor` followed by `run-tester --phase validate`.
   - Stops immediately on success (`PASSED`) to present evidence for Gate 2, or aborts after 3 failed attempts with `UNABLE_TO_VALIDATE` (`exit 1`).

## Headless Scripts (Bash and PowerShell)

All scripts are tool-agnostic and support `--harness <agy|claude|grok>` (with optional `--harness-args "<flags>"`, or env `EF_HARNESS` / `EF_HARNESS_ARGS`), legacy `--harness-cmd` / `-HarnessCommand` (or `EF_IMPLEMENTOR_CMD` / `EF_TESTER_CMD`), and `--test-cmd` / `-TestCommand` (or `EF_TEST_CMD`):

```bash
# 1. Closed-loop supervision (up to 3 attempts, R0-RED -> Implementor -> R0-GREEN)
bash ./.agents/skills/harness-cycle/scripts/supervise-harness.sh \
  --card-id AB-1042 \
  --demand-type Bug \
  --r0-red-cmd "<command-that-reproduces-bug-failure>" \
  --harness agy \
  --test-cmd "<approved-test-command>"

# 2. Post-Gate 2 atomic commit by Implementor (after human approver OK; explicit --paths or TASK_SPEC ef:paths)
bash ./.agents/skills/harness-cycle/scripts/run-implementor.sh \
  --card-id AB-1042 \
  --commit-gate2 \
  --paths "src/File.cs,tests/FileTests.cs" \
  --commit-message "fix(AB-1042): corrigir validacao do formulario"
```

```powershell
# 1. Closed-loop supervision in PowerShell 7
pwsh -File ./.agents/skills/harness-cycle/scripts/supervise-harness.ps1 `
  -CardId AB-1042 `
  -DemandType Bug `
  -R0RedCommand "<command-that-reproduces-bug-failure>" `
  -Harness agy `
  -TestCommand "<approved-test-command>"

# 2. Post-Gate 2 atomic commit by Implementor (after human approver OK; explicit -Paths or TASK_SPEC ef:paths)
pwsh -File ./.agents/skills/harness-cycle/scripts/run-implementor.ps1 `
  -CardId AB-1042 `
  -CommitGate2 `
  -Paths "src/File.cs","tests/FileTests.cs" `
  -CommitMessage "fix(AB-1042): corrigir validacao do formulario"
```

## Secret Hygiene, Capture, and Gate 2 Staging Rules

- **Runner-managed capture and masking (`ef-secrets.{sh,ps1}`):**
  - Always invoke CLI harnesses (`agy`, `claude`, `grok`) through `run-implementor` / `run-tester` with `--harness` (never via ad hoc wrappers or direct `1>`/`2>` file redirection, which is a documented violation).
  - `agy` runs with `--model gemini-4-hydrogen-high --effort high --output-format stream-json` (any `--effort` other than `high` exits with `2`). `claude` runs with `-p <prompt> --output-format stream-json --verbose`. `grok` requires explicit `--harness-args`. Permission-bypass flags (`--dangerously-skip-permissions`) are off by default and only recorded by flag name when explicitly passed via `--harness-args`.
  - Session stdout/stderr are masked line-by-line in memory before writing to `$EF_HARNESS_LOG_DIR` (default `.agent-pack/logs/<CardId>/`). Test output is masked before writing `.agent-pack/evidencias/<CardId>/test-output.log` and `r0-red.log`; `EVIDENCIA.md` only updates the `<!-- runner:begin -->`...`<!-- runner:end -->` block (never logging raw commands).
  - Harness session logs are sensitive: reading any file that contains a secret (even an authorized file such as consolidated SQL) places that secret in the transcript. Avoid reading secret-bearing files unnecessarily. Old ad hoc wrapper logs must be scanned with `ef_scan` or deleted with Tech Lead approval.
  - Project secret configuration: `EF_SECRET_VALUES_FILE` (outside repo, `EF_HARNESS_LOG_DIR`, `evidencias/`, and `.runtime/`), `EF_SECRET_NAMES`, and `AGENTS.md` line `- Nomes sensíveis (mascaramento): ...`.
  - Post-run `ef_scan` checks logs, `evidencias/<CardId>/`, and `.runtime/`. Any finding masks in-place, sets `test-status.json` `reason="SECRET_IN_LOG"`, and exits `6` (`supervise-harness` aborts immediately). A subsequent clean `run-tester --phase validate` resets `passed=true`, `reason=null`, `secretScan.status="clean"` and unblocks Gate 2.
- **Gate 1 pendencies and external boundaries:**
  - Read `docs/ai/decisions-and-pendencies.md` before changing anything linked to a `Pxx` pendency or a partial Gate 1 release, and do not touch blocked items.
  - Read `docs/ai/external-boundaries.md` before creating any external output (HTTP, CDN, telemetry, upload).
  - Stop with `BLOCKED_BY_DECISION` whenever a decision is missing or an external output is not listed in the inventory.
- **Gate 2 staging and branch protection:**
  - `--commit-gate2` stages only `--paths` or the `<!-- ef:paths:begin -->`...`<!-- ef:paths:end -->` block of `--task-spec` (default `.agent-pack/.runtime/TASK_SPEC.md`); missing/empty/forbidden paths exit `5`.
  - Protected branches (`main`, `master`, `HEAD`, `AGENTS.md` `- Branches protegidas (harness): ...`, and `EF_PROTECTED_BRANCHES`) exit `3`.
  - `--allow-unvalidated` requires `--reason "<text>"` (at least 10 characters; exit `2` otherwise) and never bypasses `SECRET_IN_LOG` (`exit 6`).
