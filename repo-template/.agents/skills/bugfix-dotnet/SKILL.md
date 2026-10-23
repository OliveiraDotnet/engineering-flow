---
name: bugfix-dotnet
description: Correct a .NET bug with evidence, a minimal safe change, regression or characterization coverage, and focused validation. Use for modern or legacy .NET bugfixes.
---

## Engineering Flow 3.0 execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# Bugfix .NET

1. Read project guidance and confirmed commands. Bootstrap first when the repository map is unverified.
2. Trace the reported behavior to its actual entry point and capture evidence for the failure.
3. Reproduce the failure with an existing test, focused characterization test, or controlled manual scenario when viable.
4. State the root cause before editing. Keep the fix separate from refactoring.
5. Make the smallest safe change, preserving public behavior outside the defect.
6. Add or update the narrowest regression coverage. Use `test_guardian` only if test discovery or design needs independent work.
7. Run only confirmed relevant validation commands. If unavailable, state the exact blocker and manual validation.

Return root cause, changed files, validation, manual scenario and residual risk.
