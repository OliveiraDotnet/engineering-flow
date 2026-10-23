---
name: db-change-sqlserver
description: Plan a SQL Server schema or data change with compatibility, rollback, and .NET consumer impact, then write scripts only after the user approves that plan. Use for requested database changes. Do not use for read-only understanding; use sqlserver-structure-review instead.
---

## Engineering Flow 3.0 execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# SQL Server change

Use only when the `sqlserver` profile is installed.

1. Confirm the schema source of truth and the authorized target environment.
2. Map affected objects and .NET consumers before proposing SQL.
3. Classify each operation as additive, compatible, or destructive. Read `references/sqlserver-change-gates.md`.
4. Produce a plan only: objects, expand/contract sequence, data backfill, locks, rollback, and validation. Do not write `.sql`/migration files yet.
5. Verify that the plan is covered by actual user authorization; reuse approval already given for the same scope. Destructive operations (`DROP`, narrowing `ALTER`, unique indexes on dirty data, `NOT NULL` without backfill) require explicit authorization covering those operations.
6. After approval, write the smallest idempotent script or migration the repository already uses. Do not execute it against any database unless the user names the environment and has explicitly authorized that execution and target. Prior authorization remains valid if scope and conditions are unchanged.
7. Update consumers only as required by the approved plan. Keep app and database overlapping versions compatible when releases can drift.
8. If the project declares a SQL release package in AGENTS.md, consolidate the approved scripts following `docs/engineering-flow/sql-release-package.md`. Execution still requires explicit authorization for the target.

Return diagnosis, approved scope, script/migration (only after approval), data and application impact, rollback, and remaining validation.
