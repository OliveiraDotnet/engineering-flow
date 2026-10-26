# Assistente opcional (exemplo atual: Grok Bot)

O Engineering Flow funciona integralmente sem assistente. Quando útil e autorizado, o usuário pode usar um assistente (hoje, o Grok Bot) no papel de apoio ao planejador ou ao revisor/entrega para preparar demanda/contexto, reproduzir cenários UI acessíveis com resultado observado e screenshots/clips, ou acompanhar uma tarefa por integração comprovada. Reuse o plano, envelope e retorno do contrato em `repo-template/docs/engineering-flow/workflow.md` e a skill `agent-work-order` em um handoff real.

Antes de transferir, confirme ferramenta, integração, ambiente acessível, dados permitidos e critérios; retire segredos e dados empresariais não autorizados. Devolva cenário, esperado/observado, artefato, falhas e pendências. O agente que recebe revisa o diff e a evidência dentro do envelope; a passagem de contexto não autoriza commit, push, publicação ou produção.

Hierarquia e briefing diário, quando usados, ficam descritos em [ASSISTENTE_WORKFLOW.md](ASSISTENTE_WORKFLOW.md). Não obrigam ninguém a usar nem a criar rotina. O pack não configura contas, envia dados, inicia bots, rotinas ou monitores.

A documentação oficial descreve computador compartilhado na nuvem, contexto via serviços conectados e exemplo de handoff para Cursor cloud agents. Isso não estabelece comunicação direta com o implementador (hoje, o Grok Build). Compatibilidade com MCP/plugins/skills do Cursor não comprova uma integração específica. Não presuma acesso a checkout local, LAN ou dispositivo mobile.

Fontes oficiais da instanciação atual: [Introducing Grok Bot](https://x.ai/news/introducing-grok-bot), [Grok Bot 101](https://x.ai/bot/guides/grok-bot-101), [Engineering](https://x.ai/bot/guides/engineering). São referências opcionais; verifique a integração concreta quando usá-la.
