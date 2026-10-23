---
name: dotnet-xunit-tests
description: Create, improve, or repair xUnit tests for .NET projects, including focused regressions, fixtures, and integration or API test architecture.
---

## Engineering Flow 3.0 execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# .NET xUnit tests

1. Read applicable project instructions, Git status and relevant diffs; preserve pre-existing changes. Identify the target project and installed SDK, target frameworks, xUnit major version, test runner, and central package conventions.
2. Follow existing naming, assertions, mocks, fixtures, and dependencies. Do not migrate a different test framework or upgrade packages merely to add a test.
3. State a short strategy: behavior, test type, relevant scenarios, files, and any necessary dependencies. For a tiny unambiguous regression, keep this to one sentence.
4. Test public observable outcomes with deterministic inputs and isolated state. Await asynchronous work; avoid shared mutable fixtures and order-dependent assertions. Read [test checklist](references/xunit-test-checklist.md) before creating projects, integration/API tests, or changing architecture.
5. A request only for tests does not authorize a production fix. Reproduce and report a production failure without changing its behavior; implement a minimal fix only when the enclosing task authorizes it. Do not weaken assertions to make a failure disappear or use production services/data.
6. Run the narrowest confirmed command. If undocumented, derive a candidate from the actual SDK/runner configuration and available help, identify it as inferred, and run when suitable. Verify tests were discovered and executed; zero tests is not a passing validation.
7. Report changed files, behavior covered, commands, actual results, and gaps. Distinguish assertion failure, setup failure, and unexecuted tests; do not claim measured coverage unless collected.

Use the testing role mapped by project instructions when delegation helps. Grok Build can execute this workflow directly; no named agent is a prerequisite.
