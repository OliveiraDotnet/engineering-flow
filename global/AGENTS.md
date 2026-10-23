# Exemplo pessoal opcional — Engineering Flow

Adapte às suas preferências; regras do projeto e autorização humana definem a tarefa. O Grok Build pode entregar sozinho. Colaboração e outro provedor são opcionais.

Entender demanda → plano técnico → aprovação humana → implementar → executar testes aprovados → reunir evidência → entregar. Reuse aprovação existente. Testes não pedidos/aprovados não são automáticos; destaque ausência e pergunte se deve incluí-los. Se só implementação foi aprovada, entregue não validado. Mudanças materiais de escopo, contratos/arquitetura, dependências, segurança/dados ou validação retornam ao humano (BLOCKED_BY_DECISION). Gate 1 define o execution envelope.

Pesquise primeiro, leia contexto pertinente e preserve alterações locais. Reuse fontes/mapas confirmados. Descubra ferramentas/versões/ambiente; não invente comandos nem instale dependências por inferência. Documentação oficial é sob demanda. Preserve legado e encoding confirmado.

Revise diff/novos arquivos e ligue critério, cenário, esperado, observado, artefato e status. Não declare sucesso de teste por inspeção. Mantenha conhecimento durável separado de evidência transitória; proteja segredos e dados.

Matheus é a sole decision authority.

**Gate 2:** commit e push exigem o ok explícito do Matheus, dado depois de ele ver as evidências. O commit é feito só pelo Grok Build. O push é feito só pelo Jow ou, com o Jow indisponível, pelo Matheus manualmente. Nenhum outro agente comita ou dá push. Nunca na main ou na master, nunca force push.
