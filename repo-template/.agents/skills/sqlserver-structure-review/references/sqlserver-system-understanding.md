# Understand the system from SQL Server

Read-only. Build an application picture from schema, programmable objects, and application consumers where available. Do not emit `ALTER`, `DROP`, or data-changing SQL.

## What to reconstruct

- Bounded contexts implied by schemas, table prefixes, and ownership.
- Aggregate-like clusters: tables that always change together (orders/items, person/address).
- Status, tenant/company, audit, and soft-delete columns that shape runtime behavior.
- Stored-procedure contracts: parameters, result sets, side effects, and C# callers.
- Jobs, reports, views, and integrations that read the same tables.
- Overlap between current app version and older readers still on the database.

## Evidence order

1. Repository SQL, SSDT, EF model, Dapper queries, and `FromSql*` strings.
2. User-supplied sanitized metadata from `scripts/sqlserver-metadata-map.sql`.
3. Execution plans or Query Store only when provided.

For live metadata, follow [collection guidance](metadata-collection.md). Preflight is optional for an authorized direct-access path, not a requirement for user-run exports. Do not retry known VPN/DNS failures without a relevant environment change.

## Output

- Domain map (tables → behavior).
- Dependency map (SQL object ↔ C# consumer).
- Risks labeled static, metadata-backed, or runtime-backed.
- Gaps that need a human (unknown jobs, undocumented result sets).
- Propose a context-document update only when useful; write only when requested, in the existing documentation location. Use maintain-agent-memory if available, never as a prerequisite; do not edit production code.
