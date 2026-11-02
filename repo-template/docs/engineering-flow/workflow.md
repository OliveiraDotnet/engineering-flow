# Engineering Flow 4.0 — contrato de execução

Triagem por card (`AB-<ID>`) → entender a demanda → plano técnico (Gate 1) → aprovação humana → implementar na branch do card → executar testes aprovados → reunir evidências → Gate 2 (commit) → homologação → produção isolada, Tag, SQL e OS de Infra.

O fluxo é definido por papéis, não por ferramentas (veja Papéis). O implementador conduz a execução; planejador (engenheiro-chefe) e revisor/entrega (bot de projeto) operam em hierarquia definida. Colaboração e segundo provedor são opcionais. Leia somente o índice de skills e carregue a skill escolhida; o nome `$skill` indica invocação nativa, não comando de shell. Instruções locais e autorização humana definem o envelope de execução.

## Papéis (Roles) e Hierarquia

| Papel | O que faz no fluxo | Instanciação atual (exemplo, não requisito) |
|---|---|---|
| Aprovador humano | Única autoridade decisória: aprova o Gate 1 (envelope), o Gate 2 (commit e push), decide `BLOCKED_BY_DECISION` / `UNABLE_TO_VALIDATE` e qualquer ida para produção. Não é delegável. | Matheus |
| Planejador (Engenheiro-Chefe) | Está acima dos bots de repositório. Recebe demandas (cards, Teams ou e-mail), garante a existência do card (`AB-<ID>`), consulta o `ai-memory`, fecha o plano técnico e o envelope do Gate 1 com o aprovador, acompanha o `Planejamento/DEMANDAS.md` (incluindo cobrança de demandas paradas em homologação) e delega a execução/instalação aos bots de projeto. | Matheus com o Jeff |
| Revisor/entrega (Bot de Projeto) | Responsável operacional pelo(s) repositório(s) do projeto: confere e cria o LOCK, mantém `.ai-memory.toml` e `Planejamento/DEMANDAS.md`, alinha a ordem de serviço (OS) com o implementador, revisa diff e evidência, faz push e merge na homologação (mantendo a branch do card viva) e, após ok do Matheus, promove a branch do card para a `main`, gera a Tag `vX.Y.Z`, consolida o SQL da release, gera a OS da Infra e exclui a branch do card. | bot de projeto (um por repo/projeto) |
| Implementador (Harness) | Executa só o envelope aprovado (via sessão gerenciada pelo `ai-memory`): implementa na branch do card, roda os testes aprovados, reúne a evidência e é o único que comita, depois do Gate 2. | Grok Build |
| Publicador / Validador (opcional) | Audita branches/releases ou executa push quando acionado explicitamente pelo aprovador humano. | Jow (opcional; mediante confirmação explícita do Matheus) |

Um mesmo agente pode acumular papéis: trabalhando sozinho, o implementador também planeja e revisa dentro do envelope. O método é nosso; as ferramentas da instanciação podem mudar sem mudar regras, gates ou branches.

## Triagem (Intake) e Ciclo de Branches por Card

- **Regra Sem Card = Sem Branch:** Toda demanda — mesmo recebida via chamada no Teams ou encaminhamento de e-mail — deve ter um card correspondente (ex: Azure DevOps `AB-<ID>`) registrado antes da abertura da branch e da OS. O estado de todas as demandas do projeto é rastreado em `Planejamento/DEMANDAS.md` (`TRIAGEM` → `EM_DEV` → `EM_HOMOLOGACAO` → `APROVADA_PROD` → `EM_PRODUCAO`).
- **Branch por Card:** Toda branch de trabalho inclui o ID do card no nome (`feat/AB-<ID>-<slug>` ou `fix/AB-<ID>-<slug>`) e **nasce obrigatoriamente a partir da `main` (`master`)**, salvo exceção explícita documentada por projeto na diretriz de entrega.
- **Homologação sem travar Produção:** Após o commit aprovado no Gate 2, o revisor/entrega faz push da branch do card e realiza o merge na branch de integração/homologação (`hom`, `develop` ou `hml`), **sem excluir a branch do card**.
- **Promoção Isolada para Produção:** Como a validação em homologação pelo consultor/cliente pode demorar dias ou semanas enquanto outras demandas avançam, quando uma demanda é aprovada para produção (com ok explícito do Matheus), o revisor/entrega faz o merge **da branch do card (`feat/AB-<ID>-<slug>`) diretamente na `main`/`master`**. Isso garante que apenas a demanda validada suba para produção, enquanto a branch de homologação preserva todas as demandas em teste.
- **Fechamento de Versão e Limpeza:** Após o merge na `main`/`master`, o revisor/entrega cria a Tag semântica (`vX.Y.Z`), consolida apenas os scripts SQL dos cards daquela Tag em `Planejamento/scripts/Releases/vX.Y.Z_consolidado.sql`, gera o resumo da OS para o Help Desk de Infra (`OS-INFRA-vX.Y.Z.md`) e **só então exclui a branch do card**.

## Modos de operação

- **Trivial**: exatamente 1 critério observável, sem risco a dados e sem migração. O agente escreve o critério em uma frase, o implementador executa e entrega o diff para ok humano. Sem plano formal e sem tabela de evidência. A evidência do Trivial é um resumo curto do implementador (hoje, o Grok Build) com o arquivo alterado. Uma linha de conferência não substitui esse resumo.
- **Completo**: fluxo atual com Gate 1 (plano aprovado) e Gate 2 (commit e push). A evidência é a tabela e a bateria completa.
- Regra de corte: qualquer coisa além do Trivial, ou qualquer dúvida, é Completo.
- Commit e push seguem o Gate 2 nos dois modos.

## Anti-padrões

Leia [anti-patterns.md](anti-patterns.md) antes de iniciar qualquer tarefa, nos dois modos.

## Orçamento por fase

O plano declara um teto por fase, em leituras de arquivo e/ou minutos. Teto excedido sem entrega: o agente para e devolva o que tem com status `pendente` / `UNABLE_TO_VALIDATE`. Continuar exige nova aprovação humana.

## Plano e aprovação

Antes de implementar, apresente objetivo, card (`AB-<ID>`), branch (`feat/AB-<ID>-<slug>`), critérios de aceitação observáveis, escopo/não objetivos, componentes afetados, riscos/decisões, avaliação de saúde de testes no legado, testes propostos, ferramentas/ambiente necessários e evidências esperadas. Um bug pequeno cabe em poucas linhas; projeto novo ou alteração de contratos precisa das decisões correspondentes. Investigação e plano não autorizam implementação.

Registre o que foi aprovado: implementação, testes/cenários/comandos, ambiente e ações externas. Ausência de pedido de testes não é autorização automática: destaque a validação faltante e pergunte se deve incluí-la. Autorização explícita existente persiste; não peça novamente por passos cobertos. Se só implementação foi aprovada, entregue como implementado e não validado, com verificações pendentes. Inspeção de código não prova teste executado.

Em bug, o R0 entra no plano padrão dos dois modos, então o teste deixa de ser "ausente": a aprovação do Gate 1 cobre o R0. Fora desse plano, a ausência de pedido continua sem autorizar teste.

Mudança material de escopo, comportamento, arquitetura/contratos, dependências, segurança/dados ou validação retorna à decisão humana com evidência, opções e recomendação (BLOCKED_BY_DECISION). Não troque ambiente nem instale ferramentas para contornar uma limitação. Um handoff não amplia permissões.

**Gate 2:** commit e push exigem o ok explícito do Matheus, dado depois de ele ver as evidências. O commit é feito só pelo implementador. O push é feito só pelo publicador ou, com o publicador indisponível, pelo Matheus manualmente. Nenhum outro agente comita ou dá push. Nunca na main ou na master, nunca force push. Instanciação atual (exemplo, não requisito): implementador = Grok Build; publicador = Jow, hoje opcional, porque a diretriz de entrega pelo bot de projeto atribui push, PR, merge, tag e geração da OS da Infra ao papel revisor/entrega nos passos 9 a 11.

## Diretriz de entrega (versão 4.0)

As regras detalhadas de entrega por card, promoção isolada para `main`, tag e exceções por projeto (GA, B2TI, SISMAN e FASTCRED) ficam na raiz do repositório engineering-flow, em `diretrizes/DIRETRIZ-entrega-pelo-bot-de-projeto.md`.

## LOCK

O LOCK fica em `.agent-pack/.runtime/task.lock` no repositório em trabalho. O arquivo não é versionado.

- Quem cria: o revisor/entrega do repositório (hoje, o bot de projeto), depois de conferir que não existe outro LOCK.
- Conteúdo: a tarefa (card), a branch, o responsável (campo `bot`) e a data e hora em que foi criado.
- Quando expira: no commit da tarefa.
- Trava esquecida: quem libera é o revisor/entrega da demanda (hoje, o bot de projeto da demanda).

## Descoberta proporcional

No modo Completo quem conduz a tarefa (coordenador) nunca lê um arquivo inteiro sem justificativa no plano: cada leitura é uma linha no plano com caminho e motivo.

Pesquise primeiro (incluindo consulta ao `ai-memory` e ao `docs/ai/project-map.md`). Reuse mapa confirmado e referências; leia apenas caminhos afetados. Verifique status/diff e preserve alterações existentes. Detectores sugerem pistas, não limitam a linguagem nem comprovam suporte automatizado. Examine código, manifests/dependências/versões, scripts, testes, CI/infraestrutura, provedores/acesso a dados e documentação. Separe repos independentes de projetos no mesmo Git root.

No repo existente, confirme o caminho de execução e produza AGENTS.md conciso, `.ai-memory.toml` configurado, mapa técnico com fontes/data e somente memória útil. Preserve regras próprias, marque hipóteses e evite preencher todos os documentos por obrigação. Num repo vazio, reúna requisitos, plataformas, contratos, armazenamento, arquitetura e estratégia de validação antes do plano de scaffolding aprovado.

Tecnologia desconhecida pede investigação adicional e procedimentos verificados. Consulte documentação oficial da versão detectada quando houver incerteza técnica ou decisão concreta; pesquisa externa é opcional, sob demanda. Recomendações atuais não autorizam modernizar legado. Não invente comando, integração, runner ou capacidade universal.

## Camada de teste e Saúde no Legado

A pirâmide mínima é unitário, integração em xUnit e e2e em Playwright. Repo que já usa NUnit ou MSTest continua com eles; xUnit é o padrão só para projeto de teste novo. Não se migra framework.

Dependências padrão no texto: Playwright, bUnit e Testcontainers. O pack não instala nenhuma delas.

- **Avaliação de Saúde de Testes no Legado (Gate 1):** Antes de propor testes em sistemas legados, o planejador/bot do repo e o implementador avaliam se é **saudável** testar a alteração na camada unitária ou de integração (isto é, sem exigir refatoração invasiva de código legado acoplado, Web Forms, ASP clássico ou procedures fora do escopo da demanda).
  - **Se for saudável:** Cria/executa o teste unitário e/ou de integração focado na camada correspondente.
  - **Se não for saudável no legado:** É proibido forçar refatoração estrutural arriscada apenas para viabilizar teste unitário artificial. A validação (incluindo o `R0` em bugs) sobe obrigatoriamente para o **Teste E2E Completo (Playwright)**, validando o fluxo real de ponta a ponta antes e depois da alteração.
- **R0, regressão obrigatória em bug.** O teste falha antes do fix e passa depois (seja na camada unitária/integração quando saudável, seja via Playwright E2E completo quando legado acoplado). As duas execuções entram na evidência com comando, código de saída e contagem. O planejador (hoje, o Jeff) opina antes. Só o Matheus dispensa, de forma explícita e registrada no plano com o motivo.
- **Sem teste de integração:** isso tem de ser reportado explicitamente na evidência (junto com a justificativa de saúde do legado, quando substituído por E2E completo). Não se omite a camada.
- **.NET Framework 4.8:** build e testes rodam com o Matheus no VS 2022. O implementador entrega os passos e não presume `msbuild` nem `dotnet build` nesse alvo.
- **SQL:** teste que toca banco só roda pelo harness do implementador, contra o servidor de teste confirmado no envelope (pelo nome, nunca pela credencial). Sem confirmação: `pendente`.

### Validação no Gate 1

| ID | Critério | Camada | Teste/cenário | Quem executa | Evidência esperada | Obrigatório |
|---|---|---|---|---|---|---|
| R0 | Regressão do bug | unit / integração (se saudável) ou Playwright E2E completo (legado acoplado) | teste automatizado ou E2E | implementador, ou o Matheus (4.8 no VS 2022) | antes falhou, depois passou | sim, em bug |
| C | Critério observável | camada saudável do critério (ou E2E completo no legado) | teste aprovado | implementador | print / `.trx` | conforme o modo |
| B | Bateria completa | unit + integração (ou E2E completo quando legado sem suíte saudável) | suítes dos projetos afetados | implementador ou o Matheus | `.trx`, prints E2E e contagem | sim, no Completo |
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
- **Completo:** tabela e bateria completa (suítes existentes dos projetos afetados, e2e dos critérios de tela/legado acoplado e o R0 se for bug). A imagem é obrigatória em critério de tela, em validação E2E de legado acoplado ou em evidência de cliente, gerada pelo Playwright E2E (estado final e passo-chave; em falha, trace ou vídeo). A imagem acompanha o resultado observado e não fecha critério sozinha.
- **Sem teste de integração:** a linha correspondente fica explícita na evidência, com o motivo (ex: legado acoplado coberto por E2E completo).

Mantenha evidência transitória e estado operacional fora da memória versionada (diretório temporário externo por padrão, ou o workspace de planejamento quando estiver ativo). Não grave credenciais, dados pessoais, payloads sensíveis, sessões ou dumps. Em `docs/ai` e no `ai-memory` registre só fatos duráveis verificados, fonte e data, sem transcrições brutas com dados sensíveis. Entregue motivação/causa, arquivos, decisões, resultados, links e limitações precisas. Documente o cenário manual pendente sem apresentá-lo como executado.

### Lições e regras

O relatório de evidência tem a seção "Lições e regras". O implementador propõe candidatos; o revisor/entrega confere e consolida no `ai-memory` (e em `docs/ai` quando for regra estrutural versionada no código) após o ok do Matheus.

| # | Tipo | Escopo/contexto | Afirmação (1 frase) | Fonte | Ação proposta |
|---|---|---|---|---|---|
| 1 | regra | projeto/contexto | frase verificável | codigo ou teste, sem conteúdo sensível | registrar no `ai-memory` / `docs/ai` |

## Memória Persistente (`ai-memory` do Fábio Akita + `docs/ai`)

Na versão 4.0, o script local legado `mem` (`conhecimento/`) foi removido e substituído integralmente pelo **`ai-memory` (`akitaonrails/ai-memory`)** integrado via MCP (`ai-memory mcp-bridge`), hooks de ciclo de vida e workstreams (`ai-memory run`).

- **Namespacing Multi-Repo (`.ai-memory.toml`):** Todo repositório deve possuir um arquivo `.ai-memory.toml` na raiz definindo `workspace = "<slug-do-projeto>"` e `project = "<slug-do-repositorio>"`. Quando um projeto possui múltiplos repositórios, todos compartilham o mesmo `workspace` para que o planejador (Jeff), os bots de projeto e o implementador (Grok Build) compartilhem o contexto do sistema inteiro.
- **Workstreams e Handoffs por Demanda:** Cada card (`AB-<ID>`) utiliza um workstream identificado no `ai-memory`, preservando o histórico e os handoffs entre sessões mesmo quando a demanda permanece semanas aguardando validação em homologação.
- **Segurança e Privacidade (LGPD):** Dado de cliente só entra se for estritamente útil para teste, e no máximo o username. CPF, e-mail pessoal, telefone, dado bancário, senhas, connection strings e segredos nunca entram no `ai-memory` nem em `docs/ai`.

## Gate de 100%

Antes da entrega, todo critério de aceitação da tabela de evidência tem resultado observado: `verificado`, `falhou` ou `pendente`, cada um com motivo. Isto **não** é cobertura de código: cobertura mostra apenas que um teste tocou uma linha, não que o comportamento está correto.

## Workspace de planejamento (opcional)

Convenção por projeto, fora do git, declarada em AGENTS.md (Convenções do projeto). Inclui o controle de fila `Planejamento/DEMANDAS.md`. Veja [planning-workspace.md](planning-workspace.md).

## Pacote SQL de release (opcional)

Governança de scripts SQL Server por card (`AB-<ID>`) e consolidação por Tag de Release (`vX.Y.Z`) + geração de OS para Infra, declarada em AGENTS.md (Convenções do projeto). Veja [sql-release-package.md](sql-release-package.md).
