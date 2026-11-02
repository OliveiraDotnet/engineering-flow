# Update technical memory

Use `$maintain-agent-memory` for the lesson below.

## Lesson

[durable rule, recurring bug, convention, or trap]

## Expected output

- File or `ai-memory` entry updated, evidence, and why it belongs there.
- Persistent memory uses **`ai-memory` (`akitaonrails/ai-memory`)** configured via `.ai-memory.toml` (`workspace` shared across project repos + repo `project`) and MCP/workstreams, alongside versioned architecture docs in `docs/ai/`. Never store valid CPF, bank details, credentials, connection strings, or sensitive customer data (at most a test username when strictly needed for testing).
