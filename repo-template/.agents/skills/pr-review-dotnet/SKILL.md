---
name: pr-review-dotnet
description: Review a .NET branch or change set for evidence-backed correctness, regression, tests, data, configuration, security, and performance risks. Use before merge or release decisions.
---

## Engineering Flow 3.0 execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# Review a .NET change

1. Confirm the request, base revision and intended delivery stage.
2. Inspect the diff and affected execution paths before reviewing specialists are requested.
3. Use `change_reviewer` for the primary review. Add at most the specialist supported by evidence: SQL Server for data changes, quality for an exposed security or performance boundary, or web for UI behavior.
4. Classify only evidence-backed findings:
   - P0: blocks merge or requested release.
   - P1: high confidence risk to fix before production.
   - P2: relevant follow-up with clear impact.
5. For every finding, include file/symbol evidence, confidence, impact and a focused validation or fix.
6. Do not report preference, formatting or hypothetical risk without a failure path.

Return release readiness, blockers, findings, known validation gaps and a focused manual checklist.
