---
name: security-review-dotnet
description: Perform an evidence-based security review of a .NET change or endpoint, including authorization boundaries, validation, sensitive data, and common web attack paths. Use only when the quality profile is installed and security scope is relevant.
---

## Engineering Flow execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# Security review .NET

1. Define the changed trust boundary, actor, resource and authorization rule, checking `docs/ai/external-boundaries.md` when present.
2. Inspect the relevant diff, endpoint, configuration and existing control; never inspect or reveal secret values.
3. Verify only applicable risks: resource or tenant authorization, input validation, injection, XSS/CSRF, uploads, external requests (including uninventoried CDNs/telemetry/SSRF), logging and data exposure.
4. Check preventive hygiene: `.gitignore` coverage (`git check-ignore`) for `appsettings*.json`, `.env`, `TestResults/` and `*.trx`; `*.example.*` without real values; explicit environment guards (`IsDevelopment()`) and safe defaults (`false`) for any dev-only TLS/security exception; and real transitive dependencies/lock files (`RestoreLockedMode`).
5. Return evidence, precondition, severity, confidence, impacted boundary and safe validation/retest criteria for each finding; fixes stay pending independent retest before closing.
6. Separate unverified hypotheses from findings.
