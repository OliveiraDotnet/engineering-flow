# Engineering Flow 3.0 — contrato de execução

Entender a demanda → plano técnico → aprovação humana → implementar → executar testes aprovados → reunir evidências → entregar.

O Grok Build conduz o fluxo. Colaboração e segundo provedor são opcionais. Leia somente o índice de skills e carregue a skill escolhida; o nome `$skill` indica invocação nativa, não comando de shell. Instruções locais e autorização humana definem o envelope de execução.

## Modos de operação

- **Trivial**: exatamente 1 critério observável, sem risco a dados e sem migração. O agente escreve o critério em uma frase, o harness executa e entrega o diff para ok humano. Sem plano formal e sem tabela de evidência.
- **Completo**: fluxo atual com Gate 1 (plano aprovado) e Gate 2 (commit e push).
- Regra de corte: qualquer coisa além do Trivial, ou qualquer dúvida, é Completo.
- Commit e push seguem o Gate 2 nos dois modos.

## Anti-padrões

Leia [anti-patterns.md](anti-patterns.md) antes de iniciar qualquer tarefa, nos dois modos.

## Orçamento por fase

O plano declara um teto por fase, em leituras de arquivo e/ou minutos. Teto excedido sem entrega: o agente para e devolve o que tem com status `pendente` / `UNABLE_TO_VALIDATE`. Continuar exige nova aprovação humana.

## Plano e aprovação

Antes de implementar, apresente objetivo, critérios de aceitação observáveis, escopo/não objetivos, componentes afetados, riscos/decisões, testes propostos, ferramentas/ambiente necessários e evidências esperadas. Um bug pequeno cabe em poucas linhas; projeto novo ou alteração de contratos precisa das decisões correspondentes. Investigação e plano não autorizam implementação.

Registre o que foi aprovado: implementação, testes/cenários/comandos, ambiente e ações externas. Ausência de pedido de testes não é autorização automática: destaque a validação faltante e pergunte se deve incluí-la. Autorização explícita existente persiste; não peça novamente por passos cobertos. Se só implementação foi aprovada, entregue como implementado e não validado, com verificações pendentes. Inspeção de código não prova teste executado.

Mudança material de escopo, comportamento, arquitetura/contratos, dependências, segurança/dados ou validação retorna à decisão humana com evidência, opções e recomendação (BLOCKED_BY_DECISION). Não troque ambiente nem instale ferramentas para contornar uma limitação. Um handoff não amplia permissões.

**Gate 2:** commit e push exigem o ok explícito do Matheus, dado depois de ele ver as evidências. O commit é feito só pelo Grok Build. O push é feito só pelo Jow ou, com o Jow indisponível, pelo Matheus manualmente. Nenhum outro agente comita ou dá push. Nunca na main ou na master, nunca force push.

## LOCK

O LOCK fica em `.agent-pack/.runtime/task.lock` no repositório em trabalho. O arquivo não é versionado.

- Quem cria: o bot do repo, depois de conferir que não existe outro LOCK.
- Conteúdo: a tarefa, a branch, o bot responsável e a data e hora em que foi criado.
- Quando expira: no commit da tarefa.
- Trava esquecida: quem libera é o bot da demanda.

## Descoberta proporcional

No modo Completo o coordenador nunca lê um arquivo inteiro sem justificativa no plano: cada leitura é uma linha no plano com caminho e motivo.

Pesquise primeiro. Reuse mapa confirmado e referências; leia apenas caminhos afetados. Verifique status/diff e preserve alterações existentes. Detectores sugerem pistas, não limitam a linguagem nem comprovam suporte automatizado. Examine código, manifests/dependências/versões, scripts, testes, CI/infraestrutura, provedores/acesso a dados e documentação. Separe repos independentes de projetos no mesmo Git root.

No repo existente, confirme o caminho de execução e produza AGENTS.md conciso, mapa técnico com fontes/data e somente memória útil. Preserve regras próprias, marque hipóteses e evite preencher todos os documentos por obrigação. Num repo vazio, reúna requisitos, plataformas, contratos, armazenamento, arquitetura e estratégia de validação antes do plano de scaffolding aprovado.

Tecnologia desconhecida pede investigação adicional e procedimentos verificados. Consulte documentação oficial da versão detectada quando houver incerteza técnica ou decisão concreta; pesquisa externa é opcional, sob demanda. Recomendações atuais não autorizam modernizar legado. Não invente comando, integração, runner ou capacidade universal.

## Implementação e validação

Execute somente o envelope aprovado. Detecte runners, ferramentas e ambiente existentes antes de usá-los; proponha preparação faltante para aprovação. Use [capabilities.md](capabilities.md) para escolher a validação aplicável. Corrija falhas e repita os cenários afetados dentro do envelope, mantendo os critérios; ampliação material precisa de decisão. Zero testes, screenshots isoladas e leitura de código não equivalem a comportamento verificado.

## Evidência e entrega

Relacione cada critério aos seus cenários. Use uma tabela curta ou relatório existente com estas colunas:

| Critério | Cenário/ambiente | Esperado | Observado | Artefato | Status |
|---|---|---|---|---|---|
| Identificador e comportamento | Entrada, ação, comando e versão | Resultado mensurável | Resultado real ou motivo de não execução | Caminho/link acessível, dados mínimos redigidos | verificado / falhou / pendente / não verificado |

Mostre separadamente o que foi implementado, verificado, falhou e ficou pendente. Capture comando, código de saída, quantidade de testes/cenários quando disponível e evidência relevante. Artefatos podem ser relatórios de testes, consultas, logs, screenshots ou gravações vinculados ao comportamento. Não declare sucesso sem resultado observado nem enfraqueça critérios para concluir.

Mantenha evidência transitória e estado operacional fora da memória versionada (diretório temporário externo por padrão). Não grave credenciais, dados pessoais, payloads sensíveis, sessões ou dumps. Em docs/ai registre só fatos duráveis verificados, fonte e data, sem transcrições. Entregue motivação/causa, arquivos, decisões, resultados, links e limitações precisas. Documente o cenário manual pendente sem apresentá-lo como executado.

## Gate de 100%

Antes da entrega, todo critério de aceitação da tabela de evidência tem resultado observado: `verificado`, `falhou` ou `pendente`, cada um com motivo. Isto **não** é cobertura de código: cobertura mostra apenas que um teste tocou uma linha, não que o comportamento está correto.

## Workspace de planejamento (opcional)

Convenção por projeto, fora do git, declarada em AGENTS.md (Convenções do projeto). Veja [planning-workspace.md](planning-workspace.md).

## Pacote SQL de release (opcional)

Consolidação de scripts SQL Server aprovados, declarada em AGENTS.md (Convenções do projeto). Veja [sql-release-package.md](sql-release-package.md).
