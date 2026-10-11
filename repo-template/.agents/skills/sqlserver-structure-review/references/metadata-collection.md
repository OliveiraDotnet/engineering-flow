# Metadata collection

Use repository SQL first. User-run metadata collection does not need a network preflight.

## Search helper

Run scripts/find-sqlserver-references.ps1 relative to this skill directory with an explicit repository/subdirectory Path. SummaryOnly groups counts; default output contains only category, path, and line number (no source text) and is limited by MaxResults, default 200. Read only necessary matching source privately and redact any excerpts. Matches can include comments and similarly named methods; they are leads, not semantic dependency proof. File access errors stop the scan instead of silently claiming completeness.

## Network helper

scripts/sqlserver-access-preflight.ps1 accepts a host/IP and Port (default 1433 only for a plain host). HOST\INSTANCE requires an explicit actual TCP port and is split before DNS lookup. Connection strings, URI and host,port forms are not accepted; supply only the host and separate Port. TimeoutMs bounds each DNS/TCP wait, not the total process lifetime. A timeout can leave the OS DNS resolution finishing in the background; no repeated application-level probes are started.

TCP success proves only reachability, not SQL Server identity, login, permissions, or query safety. Named-instance port discovery and authentication are outside the helper. Validate an authorized target before use and switch to sanitized user-run results after a clear environmental failure.

## Metadata script

scripts/sqlserver-metadata-map.sql targets SQL Server 2016+ because it uses temporal/Query Store metadata. For an older or different engine, adapt only the needed queries after checking its catalog support; do not run the whole script as if portable.

The script reads catalog metadata, not application rows. Module bodies and default/computed/check/filter expressions are suppressed by default with IncludeDefinitions = 0. Enable definitions only when needed in an authorized local inspection; they may contain secrets and must be sanitized before sharing. Names and metadata can also be confidential. Do not export every definition simply because it is available.

Catalog visibility is permission-dependent. Report missing access, encrypted/unavailable definitions, failed sections, and omitted definition text as gaps, never as proof of absence. Do not elevate privileges automatically. Row counts from sys.partitions are approximate; unusual storage and workload cases need separate evidence.

Dependencies do not fully capture dynamic SQL, external application calls, jobs, cross-database behavior, synonyms, or result-set contracts. Extend the read-only collection selectively if the task needs them. A successful metadata export is not runtime verification or permission for schema changes.

Sources for catalog semantics: [sys.partitions](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-partitions-transact-sql) and [sys.sql_modules](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-modules-transact-sql).
