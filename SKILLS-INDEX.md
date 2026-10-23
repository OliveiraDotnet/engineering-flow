# Índice de skills — Engineering Flow 3.0

Gerado por `tools/generate-skills-index.sh` a partir do frontmatter `name`/`description` de `repo-template/.agents/skills/*/SKILL.md`. O Grok Build lê este índice e carrega apenas a skill escolhida.

| Nome | Quando usar | Entrada exigida |
|---|---|---|
| agent-work-order | Coordinate or execute a bounded handoff between coding agents using shared scope, isolated work, and evidence-based review. Use only for actual delegation or receipt of a work order; standalone work needs no handoff. | ver SKILL.md |
| agents-md-generator | Create or improve concise AGENTS.md guidance from repository evidence. Use when project instructions need to be created or rewritten, in any repository or explicitly selected folder. | ver SKILL.md |
| bootstrap-dotnet-repo | Inspect and bootstrap a .NET workspace without changing production code. Use for first-run discovery of one Git repository, a parent folder of independent repositories, or a monorepo. Do not use to rewrite an already bootstrapped AGENTS.md; use agents-md-generator for that short file only. | ver SKILL.md |
| bootstrap-repo | Discover an existing, mixed, unknown-stack or empty repository and propose concise project guidance from evidence. | ver SKILL.md |
| bugfix | Diagnose and fix a reported bug with a bounded approved plan and criterion-linked evidence in the existing stack. | ver SKILL.md |
| bugfix-dotnet | Correct a .NET bug with evidence, a minimal safe change, regression or characterization coverage, and focused validation. Use for modern or legacy .NET bugfixes. | ver SKILL.md |
| check-text-encoding | Detect invalid UTF-8 and likely mojibake in changed or repository text files. Use after editing source, documentation, prompts, rules, or skills, or when text appears corrupted. | ver SKILL.md |
| complete-task | Review task completion and report implemented, verified, failed and pending acceptance criteria with actual artifacts. | ver SKILL.md |
| create-repo-skill | Create or refine a repository-specific skill for a confirmed recurring procedure; avoid skills for one-off tasks. | ver SKILL.md |
| db-change-sqlserver | Plan a SQL Server schema or data change with compatibility, rollback, and .NET consumer impact, then write scripts only after the user approves that plan. Use for requested database changes. Do not use for read-only understanding; use sqlserver-structure-review instead. | ver SKILL.md |
| delegate-to-grok-build | Hand a bounded task to an available Grok Build session or native subagent with explicit scope and independent diff review. Use when Grok delegation is requested or useful, not as a prerequisite for standalone work. | ver SKILL.md |
| dotnet-xunit-tests | Create, improve, or repair xUnit tests for .NET projects, including focused regressions, fixtures, and integration or API test architecture. | ver SKILL.md |
| feature-slice | Plan and implement a bounded feature through the existing layers and contracts after human approval. | ver SKILL.md |
| feature-slice-dotnet | Implement a bounded .NET feature by following the repository's existing flow, validation pattern, data boundaries, and acceptance criteria. Use for modern or legacy .NET feature work. | ver SKILL.md |
| legacy-refactor-dotnet | Refactor legacy .NET code in small behavior-preserving steps using characterization evidence and focused validation. Use when the requested outcome is maintainability without a feature or bugfix. | ver SKILL.md |
| maintain-agent-memory | Update durable repository guidance after a verified lesson, recurring bug, command discovery, or architecture decision. Use when a coding agent needs to keep AGENTS.md or docs/ai accurate without changing production code. | ver SKILL.md |
| mobile-app | Plan, implement and validate native, hybrid or cross-platform mobile apps using detected platform tooling and authorized devices. | ver SKILL.md |
| new-project | Plan and scaffold a new application after human approval, including empty repositories and web, backend, desktop or mobile targets. | ver SKILL.md |
| performance-review-dotnet | Investigate a measurable .NET or SQL Server performance concern using a slow path, diff, trace, query plan, or workload evidence. Use only when the quality profile is installed and a performance question is in scope. | ver SKILL.md |
| pr-review-dotnet | Review a .NET branch or change set for evidence-backed correctness, regression, tests, data, configuration, security, and performance risks. Use before merge or release decisions. | ver SKILL.md |
| refactor | Plan a behavior-preserving refactor of existing or legacy code with explicit boundaries and approved characterization checks. | ver SKILL.md |
| review-change | Review an actual diff and new files for acceptance, authorization, contracts and evidence; execution checks require an approved envelope. | ver SKILL.md |
| security-review-dotnet | Perform an evidence-based security review of a .NET change or endpoint, including authorization boundaries, validation, sensitive data, and common web attack paths. Use only when the quality profile is installed and security scope is relevant. | ver SKILL.md |
| sqlserver-structure-review | Review SQL Server schema, programmable objects, and application data access read-only. Reconstruct system behavior and dependencies from repository evidence or authorized metadata. | ver SKILL.md |
| update-agent-pack | Inspect and safely reconcile an existing repository installation with a newer Agent Pack, including added, changed, renamed, or retired skills, agents, prompts, and rules. Use when the user asks Grok Build to check, update, migrate, synchronize, or repair an installed Agent Pack without losing repository-specific guidance or local customizations. | ver SKILL.md |
| web-app | Plan and validate web UI behavior in the detected stack, including HTML/CSS/JavaScript, SPAs and classic ASP. | ver SKILL.md |
| web-dotnet | Implement or fix UI in a .NET web app (Razor Pages, MVC, Blazor, Web Forms, .aspx, and app JavaScript). Use when the change lives in the .NET web project itself. Do not use for Angular/React SPAs, API-only work, or SQL schema changes. | ver SKILL.md |

