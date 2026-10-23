---
name: legacy-refactor-dotnet
description: Refactor legacy .NET code in small behavior-preserving steps using characterization evidence and focused validation. Use when the requested outcome is maintainability without a feature or bugfix.
---

## Engineering Flow 3.0 execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# Legacy refactor .NET

1. Separate the refactor from feature and bugfix scope.
2. Map the current observable behavior, boundaries and callers.
3. Add characterization coverage when viable; otherwise document a controlled before/after scenario.
4. Change one cohesive seam at a time. Preserve contracts, configuration and persistence behavior.
5. Do not combine framework upgrades, data changes or broad renaming with a local refactor unless explicitly approved.
6. Run confirmed focused validation and compare behavior before and after.

Return motivation, preserved behavior, changed files, validation and residual risk.
