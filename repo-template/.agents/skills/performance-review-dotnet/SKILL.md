---
name: performance-review-dotnet
description: Investigate a measurable .NET or SQL Server performance concern using a slow path, diff, trace, query plan, or workload evidence. Use only when the quality profile is installed and a performance question is in scope.
---

## Engineering Flow 2.0 execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# Performance review .NET

1. Start from a concrete path, metric, trace, plan, diff or reproducible workload.
2. Inspect only relevant query shape, pagination, materialization, blocking I/O, repeated remote work, allocation and cache behavior.
3. Label observations and hypotheses separately. State the minimum measurement needed to confirm each hypothesis.
4. Recommend the smallest measurable intervention and comparison before/after.
