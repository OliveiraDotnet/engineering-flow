# Engineering Flow 5.0 — contrato de execução

Triagem por card (`AB-<ID>`) → entender a demanda → plano técnico (Gate 1) → aprovação humana → implementar na branch do card (`Implementor` + `Tester` em loop fechado) → reunir evidências → Gate 2 (commit) → homologação → produção isolada, Tag, SQL e OS de Infra.

O fluxo é definido por papéis e hierarquia de trabalho, não por ferramentas específicas (veja Papéis). Qualquer desenvolvedor pode operar **com um único harness acumulando papéis** (modo standalone) ou **distribuir a hierarquia entre agentes especializados**. Leia somente o índice de skills e carregue a skill escolhida; o nome `$skill` indica invocação nativa, não comando de shell. Instruções locais e autorização humana definem o envelope de execução (`execution envelope`).

## Papéis (Roles) e Hierarquia

| Papel | O que faz no fluxo | Modo Standalone (1 Harness) vs. Modo Multi-Bot |
|---|---|---|
| Aprovador humano | Única autoridade decisória (`sole decision authority`): aprova o Gate 1 (envelope), o Gate 2 (commit e push), decide `BLOCKED_BY_DECISION` / `UNABLE_TO_VALIDATE` e qualquer ida para produção. Não é delegável. | Sempre o usuário humano (ok explícito do aprovador humano). |
| Planejador (Engenheiro-Chefe) | Está no topo da coordenação. Recebe demandas (cards, chat ou e-mail), garante a existência do card (`AB-<ID>`), consulta o `ai-memory`, fecha o plano técnico e o envelope do Gate 1 com o aprovador, acompanha o `Planejamento/DEMANDAS.md` (incluindo cobrança de demandas paradas em homologação) e delega a execução/instalação ao papel Revisor/Entrega. | No modo standalone, o próprio harness planeja com o usuário; no modo multi-bot, um agente planejador/engenheiro-chefe dedicado conduz a triagem. |
| Revisor/entrega (Tech Lead de Repositório) | Responsável operacional pelo(s) repositório(s) do projeto: executa a instalação limpa do pack (onde **apenas `AGENTS.md` é versionado**), confere e cria o LOCK (`task.lock`), mantém `.ai-memory.toml` e `Planejamento/DEMANDAS.md`, escreve o `TASK_SPEC.md`, supervisiona o ciclo `Implementor` ↔ `Tester`, revisa diff e evidência, faz push e merge na homologação (mantendo a branch do card viva) e, após ok explícito do aprovador humano, promove a branch do card para a `main`, gera a Tag `vX.Y.Z`, consolida o SQL da release, gera a OS da Infra e exclui a branch do card. | No modo standalone, acumulado pelo harness ou usuário; no modo multi-bot, 1 bot especialista por repositório/projeto. |
| Implementor (Harness Coder) | Executa só o envelope aprovado na branch do card (`feat/AB-<ID>-<slug>` ou `fix/AB-<ID>-<slug>`): altera o código-fonte, consome falhas apontadas pelo `Tester`, nunca faz push e é o **único** que executa `git commit` depois do ok explícito no Gate 2 (`--commit-gate2`, expirando o `task.lock`). | Qualquer harness CLI ou IDE (invocado diretamente ou via `harness-cycle/scripts/run-implementor.{sh,ps1}`). |
| Tester (Harness QA / Validador) | Nunca altera código de negócio. Valida o `R0-RED` (falha antes do fix) e o `R0-GREEN` (passa depois do fix) em bugs, roda as suítes aprovadas (unitário/integração ou Playwright E2E completo quando legado acoplado) e grava `.agent-pack/evidencias/<CardId>/EVIDENCIA.md` e `.agent-pack/.runtime/test-status.json`. | Mesmo harness em passo de verificação ou runner dedicado via `harness-cycle/scripts/run-tester.{sh,ps1}`. |
| Publicador / Validador (opcional) | Audita branches/releases ou executa push quando acionado explicitamente pelo aprovador humano. | Opcional. |

Um mesmo agente pode acumular papéis: trabalhando sozinho com apenas um harness, o agente planeja, implementa, testa e revisa dentro do envelope aprovado, sem depender de bots externos.

## Instalação Limpa no Repositório Alvo (Apenas `AGENTS.md` Versionado)

Para não poluir repositórios compartilhados com outros desenvolvedores da equipe:
- O instalador (`install-agent-pack.{sh,ps1}`) faz uma instalação limpa e **não gera arquivos de versão/estado (`.agent-pack/state.txt`)** no repositório alvo.
- O script `protect-engineering-flow-files.{sh,ps1}` adiciona todas as pastas operacionais do Engineering Flow (`.agents/`, `.grok/`, `.agent-pack/`, `docs/engineering-flow/`, `docs/ai/`, `prompts/`, `Planejamento/`, `planejamento/`, `.engineering-flow-evidence/`, `*.agent-pack.new`, `*.agent-pack.backup-*`) ao `.gitignore` do repositório alvo.
- **Somente o arquivo `AGENTS.md` na raiz permanece versionável** no Git do projeto.

## Triagem (Intake) e Ciclo de Branches por Card

- **Regra Sem Card = Sem Branch:** Toda demanda deve ter um card correspondente (`AB-<ID>`) registrado antes da abertura da branch e da OS. O estado de todas as demandas do projeto é rastreado em `Planejamento/DEMANDAS.md` (`TRIAGEM` → `EM_DEV` → `EM_HOMOLOGACAO` → `APROVADA_PROD` → `EM_PRODUCAO`).
- **Branch por Card:** Toda branch de trabalho inclui o ID do card no nome (`feat/AB-<ID>-<slug>` ou `fix/AB-<ID>-<slug>`) e **nasce obrigatoriamente a partir da `main` (`master`)**, salvo exceção explícita documentada por projeto na diretriz de entrega.
- **Loop Fechado de Harness (`Implementor` ↔ `Tester` antes do Gate 2):** Com o `task.lock` ativo, o supervisor (`supervise-harness.{sh,ps1}`) ou o agente ativo executa: (1) em bugs, `Tester` em `R0-RED` confirmando a falha antes do fix; (2) `Implementor` aplicando o fix/feature na working tree sem comitar; (3) `Tester` em `R0-GREEN` / `FULL`; se falhar, retorna o log ao `Implementor` (até 3 tentativas; se exceder, para com `UNABLE_TO_VALIDATE`). Só quando `STATUS=PASSED` as evidências sobem para o Gate 2.
- **Homologação sem travar Produção:** Após o commit aprovado no Gate 2, o revisor/entrega faz push da branch do card e realiza o merge na branch de integração/homologação (`hom`, `develop` ou `hml`), **sem excluir a branch do card**.
- **Promoção Isolada para Produção:** Quando uma demanda é aprovada para produção (com ok explícito do aprovador humano), o revisor/entrega faz o merge **da branch do card (`feat/AB-<ID>-<slug>`) diretamente na `main`/`master`**. Isso garante que apenas a demanda validada suba para produção, enquanto a branch de homologação preserva todas as demandas em teste.
- **Fechamento de Versão e Limpeza:** Após o merge na `main`/`master`, o revisor/entrega cria a Tag semântica (`vX.Y.Z`), consolida apenas os scripts SQL dos cards daquela Tag em `Planejamento/scripts/Releases/vX.Y.Z_consolidado.sql`, gera o resumo da OS para a Infra (`OS-INFRA-vX.Y.Z.md`) e **só então exclui a branch do card**.

## Modos de operação

- **Trivial**: exatamente 1 critério observável, sem risco a dados e sem migração. O agente escreve o critério em uma frase, o implementador executa e entrega o diff para ok humano. Sem plano formal e sem tabela de evidência. A evidência do Trivial é um resumo curto do implementador com o arquivo alterado. Uma linha de conferência não substitui esse resumo.
- **Completo**: fluxo completo com Gate 1 (plano aprovado) e Gate 2 (commit e push). A evidência é a tabela e a bateria completa.
- Regra de corte: qualquer coisa além do Trivial, ou qualquer dúvida, é Completo.
- Commit e push seguem o Gate 2 nos dois modos.

## Anti-padrões

Leia [anti-patterns.md](anti-patterns.md) antes de iniciar qualquer tarefa, nos dois modos.

## Orçamento por fase

O plano declara um teto por fase, em leituras de arquivo e/ou minutos (e até 3 ciclos no loop `Implementor` ↔ `Tester`). Teto excedido sem entrega: o agente para e devolve o que tem com status `pendente` / `UNABLE_TO_VALIDATE`. Continuar exige nova aprovação humana.

## Plano e aprovação

Antes de implementar, apresente objetivo, card (`AB-<ID>`), branch (`feat/AB-<ID>-<slug>`), critérios de aceitação observáveis, escopo/não objetivos, componentes afetados, riscos/decisões, avaliação de saúde de testes no legado, testes propostos, ferramentas/ambiente necessários e evidências esperadas. Investigação e plano não autorizam implementação.

Registre o que foi aprovado: implementação, testes/cenários/comandos, ambiente e ações externas. Ausência de pedido de testes não é autorização automática: destaque a validação faltante e pergunte se deve incluí-la. Autorização explícita existente persiste; não peça novamente por passos cobertos. Se só implementação foi aprovada, entregue como implementado e não validado, com verificações pendentes. Inspeção de código não prova teste executado.

Em bug, o R0 entra no plano padrão dos dois modos, então o teste deixa de ser "ausente": a aprovação do Gate 1 cobre o R0. Fora desse plano, a ausência de pedido continua sem autorizar teste.

Mudança material de escopo, comportamento, arquitetura/contratos, dependências, segurança/dados ou validação retorna à decisão humana com evidência, opções e recomendação (BLOCKED_BY_DECISION). Não troque ambiente nem instale ferramentas para contornar uma limitação. Um handoff não amplia permissões.

**Gate 2:** commit e push exigem o ok explícito do aprovador humano, dado depois de ele ver as evidências. O commit é feito só pelo implementador (`Implementor`). O push é feito só pelo revisor/entrega (ou publicador) ou, quando indisponível, pelo aprovador humano manualmente. Nenhum outro agente comita ou dá push. Nunca na main ou na master, nunca force push.

## Diretriz de entrega (versão 5.0)

As regras detalhadas de entrega por card, promoção isolada para `main`, tag e convenções por projeto ficam na raiz do repositório engineering-flow, em `diretrizes/DIRETRIZ-entrega-pelo-bot-de-projeto.md`.

## LOCK

O LOCK fica em `.agent-pack/.runtime/task.lock` no repositório em trabalho. O arquivo não é versionado.

- Quem cria: o revisor/entrega do repositório (ou o runner `run-implementor`), depois de conferir que não existe outro LOCK ativo.
- Conteúdo: o harness (`default` ou nome informado), a tarefa (card), a branch, o responsável (campo `bot`), `acquired_at` e `head`.
- Quando expira: no commit da tarefa (quando `HEAD` avança no Gate 2).
- Trava esquecida: quem libera é o revisor/entrega da demanda (`task-lock.{sh,ps1} release --force`).

## Descoberta proporcional

No modo Completo quem conduz a tarefa (coordenador) nunca lê um arquivo inteiro sem justificativa no plano: cada leitura é uma linha no plano com caminho e motivo.

Pesquise primeiro (incluindo consulta ao `ai-memory` quando disponível e ao `docs/ai/project-map.md`). Reuse mapa confirmado e referências; leia apenas caminhos afetados. Verifique status/diff e preserve alterações existentes. Detectores sugerem pistas, não limitam a linguagem nem comprovam suporte automatizado. Examine código, manifests/dependências/versões, scripts, testes, CI/infraestrutura, provedores/acesso a dados e documentação. Separe repos independentes de projetos no mesmo Git root.

No repo existente, confirme o caminho de execução e produza AGENTS.md conciso, `.ai-memory.toml` configurado (quando usar `ai-memory`), mapa técnico com fontes/data e somente memória útil. Preserve regras próprias, marque hipóteses e evite preencher todos os documentos por obrigação. Num repo vazio, reúna requisitos, plataformas, contratos, armazenamento, arquitetura e estratégia de validação antes do plano de scaffolding aprovado.

Tecnologia desconhecida pede investigação adicional e procedimentos verificados. Consulte documentação oficial da versão detectada quando houver incerteza técnica ou decisão concreta; pesquisa externa é opcional, sob demanda. Recomendações atuais não autorizam modernizar legado. Não invente comando, integração, runner ou capacidade universal.

## Camada de teste e Saúde no Legado

A pirâmide mínima é unitário, integração em xUnit e e2e em Playwright. Repo que já usa NUnit ou MSTest continua com eles; xUnit é o padrão só para projeto de teste novo. Não se migra framework.

Dependências padrão no texto: Playwright, bUnit e Testcontainers. O pack não instala nenhuma delas.

- **Avaliação de Saúde de Testes no Legado (Gate 1):** Antes de propor testes em sistemas legados, o planejador/revisor e o implementador avaliam se é **saudável** testar a alteração na camada unitária ou de integração (isto é, sem exigir refatoração invasiva de código legado acoplado, Web Forms, ASP clássico ou procedures fora do escopo da demanda).
  - **Se for saudável:** Cria/executa o teste unitário e/ou de integração focado na camada correspondente.
  - **Se não for saudável no legado:** É proibido forçar refatoração estrutural arriscada apenas para viabilizar teste unitário artificial. A validação (incluindo o `R0` em bugs) sobe obrigatoriamente para o **Teste E2E Completo (Playwright)**, validando o fluxo real de ponta a ponta antes e depois da alteração.
- **R0, regressão obrigatória em bug.** O teste falha antes do fix (`R0-RED`) e passa depois (`R0-GREEN`). As duas execuções entram na evidência com comando, código de saída e contagem. O planejador opina antes. Só o aprovador humano dispensa, de forma explícita e registrada no plano com o motivo.
- **Sem teste de integração:** isso tem de ser reportado explicitamente na evidência (junto com a justificativa de saúde do legado, quando substituído por E2E completo). Não se omite a camada.
- **.NET Framework 4.8:** quando não houver runner CLI configurado no ambiente, build e testes rodam com o aprovador humano no VS 2022. O implementador entrega os passos e não presume `msbuild` nem `dotnet build` sem verificar.
- **SQL:** teste que toca banco só roda pelo harness de teste contra o servidor de teste confirmado no envelope (pelo nome, nunca pela credencial). Sem confirmação: `pendente`.

### Validação no Gate 1

| ID | Critério | Camada | Teste/cenário | Quem executa | Evidência esperada | Obrigatório |
|---|---|---|---|---|---|---|
| R0 | Regressão do bug | unit / integração (se saudável) ou Playwright E2E completo (legado acoplado) | teste automatizado ou E2E | Tester (harness) ou aprovador humano (4.8 no VS 2022) | antes falhou (`R0-RED`), depois passou (`R0-GREEN`) | sim, em bug |
| C | Critério observável | camada saudável do critério (ou E2E completo no legado) | teste aprovado | Tester (harness) | print / `.trx` | conforme o modo |
| B | Bateria completa | unit + integração (ou E2E completo quando legado sem suíte saudável) | suítes dos projetos afetados | Tester (harness) ou aprovador humano | `.trx`, prints E2E e contagem | sim, no Completo |
| T | Resumo do Trivial | manual + teste focado se houver | arquivo alterado | Implementor / Tester | resumo curto com o arquivo | sim, no Trivial |

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

Mantenha evidência transitória e estado operacional fora da memória versionada (diretório `.agent-pack/evidencias/<CardId>/` ou o workspace de planejamento quando estiver ativo, ambos ignorados no Git). Não grave credenciais, dados pessoais, payloads sensíveis, sessões ou dumps. Em `docs/ai` e no `ai-memory` registre só fatos duráveis verificados, fonte e data, sem transcrições brutas com dados sensíveis. Entregue motivação/causa, arquivos, decisões, resultados, links e limitações precisas. Documente o cenário manual pendente sem apresentá-lo como executado.

### Lições e regras

O relatório de evidência tem a seção "Lições e regras". O implementador propõe candidatos; o revisor/entrega confere e consolida no `ai-memory` (e em `docs/ai` local) após o ok do aprovador humano.

| # | Tipo | Escopo/contexto | Afirmação (1 frase) | Fonte | Ação proposta |
|---|---|---|---|---|---|
| 1 | regra | projeto/contexto | frase verificável | codigo ou teste, sem conteúdo sensível | registrar no `ai-memory` / `docs/ai` |

## Memória Persistente (`ai-memory` + `docs/ai` local) e Isolamento entre Papéis

O Engineering Flow 5.0 utiliza o **`ai-memory` (`akitaonrails/ai-memory`)** quando disponível no ambiente, em conjunto com a documentação local em `docs/ai/` e os artefatos de handoff (`TASK_SPEC.md`, `Planejamento/DEMANDAS.md`, `EVIDENCIA.md`).

- **Isolamento de Memória entre Bots e Harness:** Agentes externos (como bots de planejamento ou de revisão que rodam fora do harness) podem não compartilhar a mesma instância MCP do `ai-memory` do harness de execução. Por isso, toda passagem de bastão entre papéis deve ser explícita e autossuficiente via arquivos locais (`TASK_SPEC.md`, `EVIDENCIA.md`, `test-status.json`, `Planejamento/DEMANDAS.md` e `AGENTS.md`), garantindo que cada agente tenha sua função estritamente separada sem depender de estado implícito.
- **Namespacing Multi-Repo (`.ai-memory.toml`):** Quando o `ai-memory` é utilizado, define-se `workspace = "<slug-do-projeto>"` e `project = "<slug-do-repositorio>"`.
- **Segurança e Privacidade (LGPD):** Dado de cliente só entra se for estritamente útil para teste, e no máximo o username. CPF, e-mail pessoal, telefone, dado bancário, senhas, connection strings e segredos nunca entram no `ai-memory` nem em `docs/ai`.

## Gate de 100%

Antes da entrega, todo critério de aceitação da tabela de evidência tem resultado observado: `verificado`, `falhou` ou `pendente`, cada um com motivo. Isto **não** é cobertura de código: cobertura mostra apenas que um teste tocou uma linha, não que o comportamento está correto.

## Workspace de planejamento (opcional)

Convenção por projeto, fora do git, declarada em AGENTS.md (Convenções do projeto). Inclui o controle de fila `Planejamento/DEMANDAS.md`. Veja [planning-workspace.md](planning-workspace.md).

## Pacote SQL de release (opcional)

Governança de scripts SQL Server por card (`AB-<ID>`) e consolidação por Tag de Release (`vX.Y.Z`) + geração de OS para Infra, declarada em AGENTS.md (Convenções do projeto). Veja [sql-release-package.md](sql-release-package.md).
