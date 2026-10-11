---
name: execute-codex-work-order
description: Compatibility entrypoint for executing a delegated coding-agent work order in Grok Build. Use when explicitly handed an order; normal standalone Grok work does not require Codex.
---

# Execute a delegated work order

The historical name is retained for installed workflows; the coordinator can be Codex or Grok Build. Read [agent work order](../agent-work-order/SKILL.md) and follow its worker contract. The user remains the decision authority.

If no work order was supplied and the user directly requested ordinary implementation, use the relevant project skill and complete the task yourself. Do not demand a Codex session or fabricate approval.

Return the shared status and evidence contract. Escalate material unresolved decisions before executing them; report that the material change was not performed.
