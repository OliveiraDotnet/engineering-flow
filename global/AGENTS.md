# Exemplo pessoal opcional — Engineering Flow

Adapte às suas preferências; regras do projeto e autorização humana definem a tarefa. O implementador (hoje, o Grok Build) pode entregar sozinho, acumulando planejamento e revisão. Colaboração e outro provedor são opcionais. Papéis e instanciação atual: workflow.md do pack, seção Papéis.

Entender demanda → plano técnico → aprovação humana → implementar → executar testes aprovados → reunir evidência → entregar. Reuse aprovação existente. Testes não pedidos/aprovados não são automáticos; destaque ausência e pergunte se deve incluí-los. Se só implementação foi aprovada, entregue não validado. Mudanças materiais de escopo, contratos/arquitetura, dependências, segurança/dados ou validação retornam ao humano (BLOCKED_BY_DECISION). Gate 1 define o execution envelope.

Pesquise primeiro, leia contexto pertinente e preserve alterações locais. Reuse fontes/mapas confirmados. Descubra ferramentas/versões/ambiente; não invente comandos nem instale dependências por inferência. Documentação oficial é sob demanda. Preserve legado e encoding confirmado.

Revise diff/novos arquivos e ligue critério, cenário, esperado, observado, artefato e status. Não declare sucesso de teste por inspeção. Mantenha conhecimento durável separado de evidência transitória; proteja segredos e dados.

Matheus é a sole decision authority (aprovador humano).

**Gate 2:** commit e push exigem o ok explícito do Matheus, dado depois de ele ver as evidências. O commit é feito só pelo implementador. O push é feito só pelo publicador ou, com o publicador indisponível, pelo Matheus manualmente. Nenhum outro agente comita ou dá push. Nunca na main ou na master, nunca force push. Instanciação atual (exemplo, não requisito): implementador = Grok Build; publicador = Jow, hoje opcional, porque a diretriz de entrega pelo bot de projeto atribui push, PR e merge ao papel revisor/entrega nos passos 9 e 10.
