---
name: sqlserver-structure-review
description: Review SQL Server schema, programmable objects, and application data access read-only. Reconstruct system behavior and dependencies from repository evidence or authorized metadata.
---

## Engineering Flow 3.0 execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# SQL Server structure review

This skill is distributed with the sqlserver profile. Grok Build can run it directly; map any delegated database role through project instructions. Keep analysis read-only.

1. Read applicable project instructions and existing database notes; identify the requested scope, source of truth, SQL Server version/compatibility when available, and relevant application consumers. Do not require .NET source for a database-only review.
2. Start with static evidence. Map relevant tables, constraints, indexes, procs, views, functions, triggers, and callers. For a large tree use [reference finder](scripts/find-sqlserver-references.ps1) with an explicit target path and preferably SummaryOnly first; results are candidate locations, not proven dependencies.
3. For a system-level map read [system understanding](references/sqlserver-system-understanding.md). Use only relevant sections of [review checklist](references/sqlserver-review-checklist.md) and [risk patterns](references/sqlserver-risk-patterns.md); do not treat a pattern alone as a proven defect.
4. If metadata is needed, prefer sanitized user-supplied results. Read [collection guidance](references/metadata-collection.md) before using the bundled scripts. Run [network preflight](scripts/sqlserver-access-preflight.ps1) at most once only if direct access is relevant, authorized, and reachability is uncertain; it is unnecessary for user-run collection. Never ask for secrets or connect to production without explicit instruction.
5. Classify findings as static, metadata-backed, or runtime-backed with evidence, impact, confidence, and unresolved dependencies. Missing visibility, dynamic SQL, encrypted modules, or absent callers limit completeness. SQL version, compatibility, and workload qualify performance claims.
6. Recommend the smallest safe next step; do not execute schema/data changes or emit destructive SQL. Use db-change-sqlserver only if available and change work is separately authorized; otherwise return an actionable plan without requiring a companion skill.

Return scope, relevant system/dependency map, findings, assumptions, and validation gaps concisely. For an explicitly requested context document, reuse the existing docs location and [context template](references/sqlserver-context-template.md), preserve manual content, and omit irrelevant sections; a review alone does not authorize creating documentation.
