---
name: check-text-encoding
description: Detect invalid UTF-8 and likely mojibake in changed or repository text files. Use after editing source, documentation, prompts, rules, or skills, or when text appears corrupted.
---

# Check text encoding

1. Resolve scripts relative to this SKILL.md, whether loaded from .agents, .grok, or .claude. Run scripts/check-mojibake.ps1 with RepoPath on Windows, or scripts/check-mojibake.sh with --repo on Linux/macOS, using the actual repository path.
2. Scan changed text by default; use All/--all only for a full audit.
3. Inspect findings against bytes, surrounding text, and Git history before editing. Do not transcode or rewrite an entire file based only on a heuristic.
4. Preserve the repository's confirmed encoding and line endings. A legitimate legacy encoding needs an explicit reported limitation, not forced UTF-8 conversion. Never strip accents to hide corruption.
5. Intentional suspicious test text may use agent-pack:allow-mojibake on the same line with a reason.
6. Rerun after an authorized fix and report unresolved findings. A check/review alone does not authorize rewriting source.

These helpers do not modify scanned files. NUL-containing files are skipped as binary (including some UTF-16 text); report that coverage limitation when relevant. Invalid UTF-8 in scanned text is a finding; heuristic matches require context.
