---
name: feature-slice-dotnet
description: Implement a bounded .NET feature by following the repository's existing flow, validation pattern, data boundaries, and acceptance criteria. Use for modern or legacy .NET feature work.
---

## Engineering Flow 3.0 execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# Feature slice .NET

1. Confirm objective, acceptance criteria, exclusions and expected user-visible behavior.
2. Read the project map and find the closest existing flow before designing a new pattern.
3. Map only the impacted layers, projects, contracts, configuration and data consumers.
4. Plan first when the change crosses multiple independent areas, alters data, authorization or an external contract.
5. Use an installed specialist only when evidence requires it: `frontend_web`, `database_sqlserver` or a quality reviewer.
6. Implement the smallest complete slice that meets the criteria and follows repository conventions.
7. Add focused validation and a concise manual scenario when automated validation is insufficient.

Return scope, implementation, changed files, validation, rollout impact and remaining risks.
