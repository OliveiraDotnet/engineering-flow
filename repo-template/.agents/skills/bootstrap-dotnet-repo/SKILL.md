---
name: bootstrap-dotnet-repo
description: Inspect and bootstrap a .NET workspace without changing production code. Use for first-run discovery of one Git repository, a parent folder of independent repositories, or a monorepo. Do not use to rewrite an already bootstrapped AGENTS.md; use agents-md-generator for that short file only.
---

## Engineering Flow 3.0 execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# Bootstrap a .NET repository

1. Classify the workspace from Git evidence: one repository, one Git root with multiple apps (monorepo), a parent folder of independent Git repositories, or a non-Git folder.
2. If independent repositories are found, list each Git root and inspect it separately. Do not write a parent-level `AGENTS.md` unless the user explicitly wants workspace-level notes.
3. Resolve the inspection script relative to this skill directory (whether loaded from `.agents/skills` or `.grok/skills`) and pass the selected repository explicitly. Run it without build, restore, test, database, network, or code changes:
   - Windows: `powershell -ExecutionPolicy Bypass -File <skill-directory>/scripts/inspect-dotnet-repo.ps1 -RepoPath <repository>`
   - Linux/macOS: `bash <skill-directory>/scripts/inspect-dotnet-repo.sh <repository>`
4. Verify reported facts against project files, CI, scripts, README and tests. Treat detection as evidence, not proof.
5. Recommend only real pack profiles with evidence: `web` and `sqlserver`. SQL Server requires a specific provider/client or T-SQL evidence; generic SQL, EF or Dapper alone cannot identify the database engine. Never invent `legacy-framework` or auto-select `quality`.
6. Update `docs/ai` and replace `[UNVERIFIED]` items in `AGENTS.md` only with confirmed, always-relevant rules. Keep `AGENTS.md` short; put details in `docs/ai`. Use `agents-md-generator` only for that short persistent shell.
7. End without changing production code. Ask the user to start a new task so updated instructions load.

Grok Build can perform bootstrap directly. Use the repository exploration role mapped by project instructions only when a bounded question benefits from delegation; no named agent is required. Do not fan out reviewers during bootstrap.
