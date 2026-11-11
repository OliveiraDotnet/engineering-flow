# Exemplo pessoal opcional — Engineering Flow 5.0

Adapte às suas preferências; regras do projeto e autorização humana definem a tarefa. O harness de implementação pode entregar sozinho, acumulando planejamento, testes e revisão, ou operar sob a coordenação de um planejador (engenheiro-chefe) e de um revisor/entrega (tech lead de repositório). Colaboração e múltiplos agentes são opcionais. Papéis e hierarquia: workflow.md do pack, seção Papéis.

Triagem por card (`AB-<ID>`) → entender demanda → plano técnico (Gate 1) → aprovação humana → implementar na branch do card (`feat/AB-<ID>-<slug>` ou `fix/AB-<ID>-<slug>`) em loop fechado (`Implementor` + `Tester`) → executar testes aprovados → reunir evidência → Gate 2 (commit) → homologação → produção isolada, Tag, SQL e OS de Infra. Reuse aprovação existente. Em bug, o teste de regressão `R0` (falha antes do fix `R0-RED`, passa depois `R0-GREEN` — em unitário/integração se saudável, ou via Playwright E2E completo quando legado acoplado) faz parte do plano padrão do Gate 1. Fora do `R0`, testes não pedidos/aprovados não são automáticos; destaque ausência e pergunte se deve incluí-los. Se só implementação foi aprovada, entregue não validado. Mudanças materiais de escopo, contratos/arquitetura, dependências, segurança/dados ou validação retornam ao humano (BLOCKED_BY_DECISION). Gate 1 define o execution envelope.

Pesquise primeiro (consultando `docs/ai` e o `ai-memory` quando disponível), leia contexto pertinente e preserve alterações locais. Reuse fontes/mapas confirmados. Descubra ferramentas/versões/ambiente; não invente comandos nem instale dependências por inferência. Documentação oficial é sob demanda. Preserve legado e encoding confirmado.

Revise diff/novos arquivos e ligue critério, cenário, esperado, observado, artefato e status. Não declare sucesso de teste por inspeção. Mantenha conhecimento durável em `docs/ai` e no `ai-memory` separado de evidência transitória; proteja segredos e dados (nunca grave CPF, dados bancários ou credenciais).

O aprovador humano é a sole decision authority.

**Gate 2:** commit e push exigem o ok explícito do aprovador humano, dado depois de ele ver as evidências. O commit é feito só pelo Implementor. O push é feito só pelo revisor/entrega (ou publicador) ou, quando indisponível, pelo aprovador humano manualmente. Nenhum outro agente comita ou dá push. Nunca na main ou na master, nunca force push. Nos repositórios instalados com o Engineering Flow 5.0, apenas o `AGENTS.md` é versionado no Git.
