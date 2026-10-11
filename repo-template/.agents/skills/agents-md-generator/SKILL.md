---
name: agents-md-generator
description: Create or improve concise AGENTS.md guidance from repository evidence. Use when project instructions need to be created or rewritten, in any repository or explicitly selected folder.
---

## Engineering Flow 2.0 execution gate

Follow docs/engineering-flow/workflow.md in the target repository. Understand demand, present a technical plan, receive human approval, implement, execute only approved tests, gather criterion-linked evidence, deliver. Existing explicit authorization persists. Investigation/plan do not authorize implementation. Absence of a test request does not automatically authorize tests: highlight missing validation and ask whether to include it. If only implementation is approved, deliver it as unvalidated with pending checks. Material changes in scope, behavior, architecture/contracts, dependencies, security/data or validation return to the human. This gate governs execution steps below; no automatic delegation or second provider is required.

# AGENTS.md Generator

## Overview

Create or improve `AGENTS.md` files from the actual repository shape. Inspect first, preserve useful project-specific guidance, and avoid inventing commands or architecture.

## Workflow

1. Read any existing `AGENTS.md` and `AGENTS.override.md` files that apply to the target path.
2. Inspect Git status and relevant staged/unstaged diffs before editing; preserve existing user changes. Inspect the workspace selectively: Git roots, `README*`, `docs/`, solution/project files, package manifests, CI files, Docker files, and major folders.
3. Classify the workspace as one repository, a monorepo, multiple independent repositories, or a normal folder without Git metadata.
4. Infer stack, architecture, commands, conventions, and dominant documentation language only from real files.
5. Decide the target: root `AGENTS.md` for one repository, root plus selective nested files for monorepos, per-repository files for multiple independent repositories, or no write until the user confirms a target.
6. Ask only when the target remains ambiguous after using the request and available context; existing authorization for a selected repository or all repositories is sufficient.
7. Write a concise, practical `AGENTS.md` with TODO markers where facts cannot be confirmed.
8. Report workspace detection, existing status, proposed action, files changed, assumptions or TODOs, and final summary.

For the detailed inspection checklist, read `references/agents-md-checklist.md` before creating or materially rewriting an `AGENTS.md`.

## Workspace Detection

Use repository evidence, not folder names alone.

- Use `.git` directories or `git rev-parse --show-toplevel` to identify repository boundaries.
- Treat a root with one `.git` plus several apps/packages as a possible monorepo.
- Treat a folder containing multiple child `.git` directories as multiple independent repositories.
- Treat a folder without Git metadata as a normal folder unless another clear workspace signal exists.

Do not create a parent-level `AGENTS.md` for multiple independent repositories unless the user explicitly requests parent-folder guidance.

## Existing AGENTS.md Handling

When `AGENTS.md` exists:

- Read it completely before editing.
- Preserve useful instructions, project-specific rules, and known commands.
- Remove or rewrite duplicated, vague, obsolete, unsafe, or contradictory guidance.
- Avoid deleting project rules unless clearly wrong, duplicated, or unsafe.
- Explain what changed and why.

When `AGENTS.md` does not exist:

- Create a focused file based on inspected repository facts.
- Include TODO markers for unknown commands, unclear conventions, or unverified architecture.
- Keep generic best-practice filler out.

## Content Standard

Follow existing repository guidance. If Agent Pack is installed, reuse its template; otherwise create concise standalone guidance without requiring the pack or its skills. Keep the file short and always-relevant:

- Facts to confirm, or confirmed facts after bootstrap
- Working rules
- Context and delegation
- Codex and Grok Build collaboration when that integration is present
- Definition of done

Link existing detailed documentation in the repository's chosen location (`docs/ai` only when that convention exists). Retain short, confirmed build/test commands that agents need regularly. Do not create a documentation tree or relocate manual notes merely to match a template. Include database rules only when they are durable, confirmed operating constraints.

## Safety Rules

- Do not modify application source code while creating or improving `AGENTS.md`.
- Do not add dependencies.
- Do not modify CI/CD unless explicitly requested.
- Do not include secrets, tokens, real connection strings, private keys, or personal data.
- Do not invent commands. Use TODO markers when commands are not confirmed by docs, scripts, project files, or CI.
- Keep public contracts stable unless the user explicitly asks to change them.

## Language

Write `AGENTS.md` in the dominant language used by existing technical documentation. Prefer English for English documentation, Portuguese for Portuguese documentation, and the language used by existing technical docs when the repository is mixed.

## Output

After work, report:

1. Workspace detection
2. Existing `AGENTS.md` status
3. Proposed or completed action
4. Files created or changed
5. Important assumptions or TODOs
6. Final `AGENTS.md` summary
