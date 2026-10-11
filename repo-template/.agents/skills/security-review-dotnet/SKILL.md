---
name: security-review-dotnet
description: Perform an evidence-based security review of a .NET change or endpoint, including authorization boundaries, validation, sensitive data, and common web attack paths. Use only when the quality profile is installed and security scope is relevant.
---

## Engineering Flow 2.0 execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# Security review .NET

1. Define the changed trust boundary, actor, resource and authorization rule.
2. Inspect the relevant diff, endpoint, configuration and existing control; never inspect or reveal secret values.
3. Verify only applicable risks: resource or tenant authorization, input validation, injection, XSS/CSRF, uploads, external requests, logging and data exposure.
4. Return evidence, precondition, severity, confidence, impacted boundary and safe validation for each finding.
5. Separate unverified hypotheses from findings.
