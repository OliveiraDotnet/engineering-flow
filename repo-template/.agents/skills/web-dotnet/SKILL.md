---
name: web-dotnet
description: Implement or fix UI in a .NET web app (Razor Pages, MVC, Blazor, Web Forms, .aspx, and app JavaScript). Use when the change lives in the .NET web project itself. Do not use for Angular/React SPAs, API-only work, or SQL schema changes.
---

## Engineering Flow 3.0 execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# .NET web UI

Use only when the `web` profile is installed. Follow the repository's existing UI stack; do not introduce Blazor, a SPA, or a new JS framework.

1. Confirm the UI stack from project files: ASP.NET Core 3.1+ (Razor Pages, MVC, Blazor) or .NET Framework (Web Forms, MVC 5, `web.config`).
2. Read the closest existing screen or endpoint and copy its layout, binding names, validation, and error/empty/loading states.
3. Keep server-side validation. Client validation may assist; it must not replace server checks.
4. Preserve model-binding field names, routes, partials, components, antiforgery tokens, and shared scripts.
5. Do not duplicate domain rules in the UI. Do not change public API contracts unless the request includes them.
6. Read `references/web-dotnet-checklist.md` before touching Web Forms ViewState, `web.config`, or a mixed Framework/Core solution.
7. Validate with confirmed repository commands only. Provide a short manual scenario when UI automation is unavailable.

Return stack detected, files changed, preserved contracts, validation, and residual risk.
