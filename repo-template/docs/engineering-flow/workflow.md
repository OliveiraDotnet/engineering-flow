# Engineering Flow 3.1 — contrato de execução

Entender a demanda → plano técnico → aprovação humana → implementar → executar testes aprovados → reunir evidências → entregar.

O fluxo é definido por papéis, não por ferramentas (veja Papéis). O implementador conduz a execução; planejador e revisor/entrega podem ser agentes separados ou o próprio implementador. Colaboração e segundo provedor são opcionais. Leia somente o índice de skills e carregue a skill escolhida; o nome `$skill` indica invocação nativa, não comando de shell. Instruções locais e autorização humana definem o envelope de execução.

## Papéis (Roles)

| Papel | O que faz no fluxo | Instanciação atual (exemplo, não requisito) |
|---|---|---|
| Aprovador humano | Única autoridade decisória: aprova o Gate 1 (envelope), o Gate 2 (commit e push), decide `BLOCKED_BY_DECISION` / `UNABLE_TO_VALIDATE` e qualquer ida para produção. Não é delegável. | Matheus |
| Planejador | Entende a demanda, prepara contexto, propõe o plano técnico e o envelope do Gate 1 junto com o aprovador; orquestra outros papéis só quando o aprovador pede. | Matheus com o Jeff |
| Implementador | Executa só o envelope aprovado: implementa, roda os testes aprovados, reúne a evidência e é o único que comita, depois do Gate 2. | Grok Build |
| Revisor/entrega | No repositório da tarefa: confere e cria o LOCK, alinha a ordem de serviço com o implementador, revisa diff e evidência e conduz a entrega conforme a diretriz de entrega vigente. | bot de projeto (um por repo) |
| Publicador (opcional) | Faz o push quando a diretriz vigente o aciona. | Jow (opcional; só em caso extremo, com confirmação explícita do Matheus) |

Um mesmo agente pode acumular papéis: trabalhando sozinho, o implementador também planeja e revisa dentro do envelope. O método é nosso; as ferramentas da instanciação podem mudar sem mudar regras, gates ou branches.

## Modos de operação

- **Trivial**: exatamente 1 critério observável, sem risco a dados e sem migração. O agente escreve o critério em uma frase, o implementador executa e entrega o diff para ok humano. Sem plano formal e sem tabela de evidência. A evidência do Trivial é um resumo curto do implementador (hoje, o Grok Build) com o arquivo alterado. Uma linha de conferência não substitui esse resumo.
- **Completo**: fluxo atual com Gate 1 (plano aprovado) e Gate 2 (commit e push). A evidência é a tabela e a bateria completa.
- Regra de corte: qualquer coisa além do Trivial, ou qualquer dúvida, é Completo.
- Commit e push seguem o Gate 2 nos dois modos.

## Anti-padrões

Leia [anti-patterns.md](anti-patterns.md) antes de iniciar qualquer tarefa, nos dois modos.

## Orçamento por fase

O plano declara um teto por fase, em leituras de arquivo e/ou minutos. Teto excedido sem entrega: o agente para e devolve o que tem com status `pendente` / `UNABLE_TO_VALIDATE`. Continuar exige nova aprovação humana.

## Plano e aprovação

Antes de implementar, apresente objetivo, critérios de aceitação observáveis, escopo/não objetivos, componentes afetados, riscos/decisões, testes propostos, ferramentas/ambiente necessários e evidências esperadas. Um bug pequeno cabe em poucas linhas; projeto novo ou alteração de contratos precisa das decisões correspondentes. Investigação e plano não autorizam implementação.

Registre o que foi aprovado: implementação, testes/cenários/comandos, ambiente e ações externas. Ausência de pedido de testes não é autorização automática: destaque a validação faltante e pergunte se deve incluí-la. Autorização explícita existente persiste; não peça novamente por passos cobertos. Se só implementação foi aprovada, entregue como implementado e não validado, com verificações pendentes. Inspeção de código não prova teste executado.

Em bug, o R0 entra no plano padrão dos dois modos, então o teste deixa de ser "ausente": a aprovação do Gate 1 cobre o R0. Fora desse plano, a ausência de pedido continua sem autorizar teste.

Mudança material de escopo, comportamento, arquitetura/contratos, dependências, segurança/dados ou validação retorna à decisão humana com evidência, opções e recomendação (BLOCKED_BY_DECISION). Não troque ambiente nem instale ferramentas para contornar uma limitação. Um handoff não amplia permissões.

**Gate 2:** commit e push exigem o ok explícito do Matheus, dado depois de ele ver as evidências. O commit é feito só pelo implementador. O push é feito só pelo publicador ou, com o publicador indisponível, pelo Matheus manualmente. Nenhum outro agente comita ou dá push. Nunca na main ou na master, nunca force push. Instanciação atual (exemplo, não requisito): implementador = Grok Build; publicador = Jow, hoje opcional, porque a diretriz de entrega pelo bot de projeto atribui push, PR e merge ao papel revisor/entrega nos passos 9 e 10.

## Diretriz de entrega (revisão 3)

A revisão 3 é a revisão 2 com papéis genéricos, sem mudança de regra, gate ou branch. As exceções de GA, B2TI, SISMAN e FASTCRED entram com o texto literal. O documento fica na raiz do repositório engineering-flow, em `diretrizes/DIRETRIZ-entrega-pelo-bot-de-projeto.md`, e não é copiado pelo instalador.

## LOCK

O LOCK fica em `.agent-pack/.runtime/task.lock` no repositório em trabalho. O arquivo não é versionado.

- Quem cria: o revisor/entrega do repositório (hoje, o bot de projeto), depois de conferir que não existe outro LOCK.
- Conteúdo: a tarefa, a branch, o responsável (campo `bot`) e a data e hora em que foi criado.
- Quando expira: no commit da tarefa.
- Trava esquecida: quem libera é o revisor/entrega da demanda (hoje, o bot de projeto da demanda).

## Descoberta proporcional

No modo Completo quem conduz a tarefa (coordenador) nunca lê um arquivo inteiro sem justificativa no plano: cada leitura é uma linha no plano com caminho e motivo.

Pesquise primeiro. Reuse mapa confirmado e referências; leia apenas caminhos afetados. Verifique status/diff e preserve alterações existentes. Detectores sugerem pistas, não limitam a linguagem nem comprovam suporte automatizado. Examine código, manifests/dependências/versões, scripts, testes, CI/infraestrutura, provedores/acesso a dados e documentação. Separe repos independentes de projetos no mesmo Git root.

No repo existente, confirme o caminho de execução e produza AGENTS.md conciso, mapa técnico com fontes/data e somente memória útil. Preserve regras próprias, marque hipóteses e evite preencher todos os documentos por obrigação. Num repo vazio, reúna requisitos, plataformas, contratos, armazenamento, arquitetura e estratégia de validação antes do plano de scaffolding aprovado.

Tecnologia desconhecida pede investigação adicional e procedimentos verificados. Consulte documentação oficial da versão detectada quando houver incerteza técnica ou decisão concreta; pesquisa externa é opcional, sob demanda. Recomendações atuais não autorizam modernizar legado. Não invente comando, integração, runner ou capacidade universal.

## Camada de teste

A pirâmide mínima é unitário, integração em xUnit e e2e em Playwright. Repo que já usa NUnit ou MSTest continua com eles; xUnit é o padrão só para projeto de teste novo. Não se migra framework.

Dependências padrão no texto: Playwright, bUnit e Testcontainers. O pack não instala nenhuma delas.

- **R0, regressão obrigatória em bug.** O teste falha antes do fix e passa depois. As duas execuções entram na evidência com comando, código de saída e contagem. O planejador (hoje, o Jeff) opina antes. Só o Matheus dispensa, de forma explícita e registrada no plano com o motivo.
- **Sem teste de integração:** isso tem de ser reportado. Não se omite a camada.
- **.NET Framework 4.8:** build e testes rodam com o Matheus no VS 2022. O implementador entrega os passos e não presume `msbuild` nem `dotnet build` nesse alvo.
- **SQL:** teste que toca banco só roda pelo harness do implementador, contra o servidor de teste confirmado no envelope (pelo nome, nunca pela credencial). Sem confirmação: `pendente`.

### Validação no Gate 1

| ID | Critério | Camada | Teste/cenário | Quem executa | Evidência esperada | Obrigatório |
|---|---|---|---|---|---|---|
| R0 | Regressão do bug | unit / integração / e2e / manual | teste ou roteiro | implementador, ou o Matheus (4.8 no VS 2022) | antes falhou, depois passou | sim, em bug |
| C | Critério observável | camada do critério | teste aprovado | implementador | print / `.trx` | conforme o modo |
| B | Bateria completa | unit + integração | suítes dos projetos afetados | implementador ou o Matheus | `.trx` e contagem | sim, no Completo |
| T | Resumo do Trivial | manual + teste focado se houver | arquivo alterado | implementador | resumo curto com o arquivo | sim, no Trivial |

## Implementação e validação

Execute somente o envelope aprovado. Detecte runners, ferramentas e ambiente existentes antes de usá-los; proponha preparação faltante para aprovação. Use [capabilities.md](capabilities.md) para escolher a validação aplicável. Corrija falhas e repita os cenários afetados dentro do envelope, mantendo os critérios; ampliação material precisa de decisão. Zero testes, screenshots isoladas e leitura de código não equivalem a comportamento verificado.

## Evidência e entrega

Relacione cada critério aos seus cenários. Use uma tabela curta ou relatório existente com estas colunas:

| Critério | Cenário/ambiente | Esperado | Observado | Artefato | Status |
|---|---|---|---|---|---|
| Identificador e comportamento | Entrada, ação, comando e versão | Resultado mensurável | Resultado real ou motivo de não execução | Caminho/link acessível, dados mínimos redigidos | verificado / falhou / pendente / não verificado |

Mostre separadamente o que foi implementado, verificado, falhou e ficou pendente. Capture comando, código de saída, quantidade de testes/cenários quando disponível e evidência relevante. Artefatos podem ser relatórios de testes, consultas, logs, screenshots ou gravações vinculados ao comportamento. Não declare sucesso sem resultado observado nem enfraqueça critérios para concluir.

- **Trivial:** o implementador manda um resumo curto com o arquivo alterado. Não basta uma linha de conferência. Se for bug e houver suíte na camada, o R0 focado entra no resumo com as duas execuções.
- **Completo:** tabela e bateria completa (suítes existentes dos projetos afetados, e2e dos critérios de tela e o R0 se for bug). A imagem é obrigatória em critério de tela ou em evidência de cliente, gerada pelo Playwright E2E (estado final e passo-chave; em falha, trace ou vídeo). A imagem acompanha o resultado observado e não fecha critério sozinha.
- **Sem teste de integração:** a linha correspondente fica explícita na evidência, com o motivo.

Mantenha evidência transitória e estado operacional fora da memória versionada (diretório temporário externo por padrão, ou o workspace de planejamento quando estiver ativo). Não grave credenciais, dados pessoais, payloads sensíveis, sessões ou dumps. Em docs/ai registre só fatos duráveis verificados, fonte e data, sem transcrições. Entregue motivação/causa, arquivos, decisões, resultados, links e limitações precisas. Documente o cenário manual pendente sem apresentá-lo como executado.

### Lições e regras

O relatório de evidência tem a seção "Lições e regras". O implementador propõe candidatos; não escreve na memória. O revisor/entrega confere.

| # | Tipo | Escopo/contexto | Afirmação (1 frase) | Fonte | Ação proposta |
|---|---|---|---|---|---|
| 1 | regra | projeto/contexto | frase verificável | codigo ou teste, sem conteúdo sensível | novo ou atualizar ID |

## Memória local

Memória local; versionamento em Git previsto para a 3.2. Não há busca semântica nesta versão. A raiz vem de `config/maquinas.conf`, escolhida por `EF_MAQUINA`. O comando é `mem` (`tools/memoria.sh` e `tools/memoria.ps1`).

Cartão ditado nasce `pendente` e só fica ativo com o ok do Matheus. Captura feita pelo bot nasce `rascunho`. Não há `revalidar_em` nem teto. O piloto é o SISMAN, só no texto.

Dado de cliente só entra se for útil para teste, e no máximo o username. CPF, dado bancário e dado sensível nunca entram.

## Gate de 100%

Antes da entrega, todo critério de aceitação da tabela de evidência tem resultado observado: `verificado`, `falhou` ou `pendente`, cada um com motivo. Isto **não** é cobertura de código: cobertura mostra apenas que um teste tocou uma linha, não que o comportamento está correto.

## Workspace de planejamento (opcional)

Convenção por projeto, fora do git, declarada em AGENTS.md (Convenções do projeto). Veja [planning-workspace.md](planning-workspace.md).

## Pacote SQL de release (opcional)

Consolidação de scripts SQL Server aprovados, declarada em AGENTS.md (Convenções do projeto). Veja [sql-release-package.md](sql-release-package.md).
