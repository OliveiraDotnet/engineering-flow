# Hierarquia de Agentes e Operação — diretriz Engineering Flow 5.0

Fora do pack: não consta em `pack-manifest.txt` e não é copiado pelo instalador. Camada operacional sobre o Engineering Flow 5.0; o contrato canônico está em [workflow.md](repo-template/docs/engineering-flow/workflow.md) e a diretriz de entrega detalhada está em [DIRETRIZ-entrega-pelo-bot-de-projeto.md](diretrizes/DIRETRIZ-entrega-pelo-bot-de-projeto.md). Complementa [ASSISTENTE_OPCIONAL.md](ASSISTENTE_OPCIONAL.md).

## Papéis e Hierarquia Agnóstica

Os papéis são os do [workflow.md](repo-template/docs/engineering-flow/workflow.md) (seção Papéis). O Engineering Flow 5.0 é 100% genérico: pode ser operado por **um único harness acumulando papéis** ou por **uma hierarquia de bots construída de baixo para cima**:

1. **Aprovador humano:** autoridade decisória única (`sole decision authority`). Decide Gate 1 (plano/envelope), Gate 2 (commit e push) e subida para produção (`main`/`master`).
2. **Planejador / Engenheiro-Chefe:** está acima dos revisores de repositório. Recebe demandas brutas (chamadas, e-mails ou cards), garante que toda demanda receba um Card (`AB-<ID>`), fecha o plano técnico (Gate 1) com o aprovador humano e delega a execução ou a instalação limpa da v5.0 para o revisor/entrega responsável pelo repositório.
3. **Revisor/entrega (Tech Lead de Repositório, um por projeto/repositório):** responde ao aprovador humano e ao planejador. Executa a instalação limpa do Engineering Flow 5.0 (onde **apenas `AGENTS.md` é versionado**), mantém o quadro vivo `Planejamento/DEMANDAS.md`, cria o LOCK (`task.lock`), cria a branch por card (`feat/AB-<ID>-<slug>` ou `fix/AB-<ID>-<slug>` a partir da `main`/`master`), gera o `TASK_SPEC.md`, aciona o supervisor do harness (`supervise-harness`), revisa o diff e a evidência, comanda o commit pós-Gate 2 (`--commit-gate2`), faz merge na homologação (mantendo a branch do card viva) e, após o ok explícito do aprovador humano, promove a branch do card para a `main`/`master`, gera a Tag `vX.Y.Z`, consolida o pacote SQL daquela Tag, gera a `OS-INFRA-vX.Y.Z.md` e exclui a branch do card.
4. **Implementor (Harness de Código):** atua na base da pirâmide sobre o código-fonte. Executa o `TASK_SPEC.md` na branch do card, corrige falhas apontadas pelo `Tester`, nunca faz push e é o **único** que executa `git commit` após o Gate 2 (`--commit-gate2`, expirando o `task.lock`).
5. **Tester (Harness de QA / Validação):** atua ao lado do `Implementor`. Nunca altera código de negócio; executa `R0-RED` (falha antes do fix em bugs), `R0-GREEN` (passa depois do fix) e `FULL`, gravando `.agent-pack/evidencias/<CardId>/EVIDENCIA.md` e `.agent-pack/.runtime/test-status.json`.
6. **Publicador / Validador opcional:** audita branches/releases ou atua quando acionado explicitamente pelo aprovador humano.

## Construção Bottom-Up e Isolamento de Memória / CLI

Quando o usuário opta por automatizar a hierarquia com bots dedicados:
- **Ordem de construção (de baixo para cima):** constrói-se e valida-se primeiro a camada de harness (`Tester` e `Implementor` via `harness-cycle`), depois o `Revisor/Entrega (Bot de Repositório)` e por último o `Planejador / Engenheiro-Chefe`.
- **Isolamento de Memória:** bots externos não compartilham necessariamente a memória MCP (`ai-memory`) interna do harness. Por isso, cada agente tem escopo estrito e se comunica por contratos em arquivo (`AGENTS.md`, `Planejamento/DEMANDAS.md`, `TASK_SPEC.md`, `test-status.json` e `EVIDENCIA.md`), evitando confusão de estado.
- **Comunicação CLI Fluida com o Harness:** os agentes que invocam o harness via linha de comando (`run-implementor`, `run-tester`, `supervise-harness`) utilizam execução não-interativa/headless com permissões de escopo explícitas, evitando bloqueios de terminal ("aguardando confirmação") durante o loop fechado.

## Rito de Instalação Limpa da v5.0 nos Repositórios

Para colocar qualquer repositório no padrão Engineering Flow 5.0 sem gerar ruído no Git da equipe:

1. Executar o instalador da v5.0 (`scripts/install-agent-pack.sh <repo> --force --profile ...` ou `.ps1`). O instalador **não gera arquivos de versão (`.agent-pack/state.txt`)** e protege todas as pastas do método no `.gitignore`, deixando **somente `AGENTS.md` versionável**.
2. Configurar `.ai-memory.toml` local quando o `ai-memory` for usado no ambiente (`workspace = "<slug-do-projeto>"`, `project = "<slug-do-repo>"`).
3. Executar `$bootstrap-repo` (se `AGENTS.md` ainda tiver `[UNVERIFIED]`) e preencher as Convenções do Projeto em `AGENTS.md`.
4. Inicializar `Planejamento/DEMANDAS.md` e `Planejamento/scripts/{PendentesProducao,Releases,Aplicados}`.

## Regras operacionais

- **Triagem obrigatória por Card:** nenhuma demanda entra em desenvolvimento sem número de Card (`AB-<ID>`) registrado em `Planejamento/DEMANDAS.md`.
- **LOCK:** o revisor/entrega (ou `run-implementor`) confere se já existe `.agent-pack/.runtime/task.lock` e então cria o dele. Conteúdo: harness, tarefa (card), branch, responsável e data/hora. O LOCK expira no commit do Gate 2. Trava esquecida: o revisor da demanda libera. O arquivo não é versionado.
- **Concorrência:** no máximo 2 tarefas simultâneas em desenvolvimento, sempre em projetos diferentes.
- **Commit:** só o `Implementor`, com o ok explícito do aprovador humano depois das evidências (Gate 2).
- **Branches, Homologação e Produção:** toda branch de card nasce da `main`/`master`, sofre merge na homologação sem ser excluída e só vai para a `main`/`master` (com fechamento de Tag `vX.Y.Z`, consolidação de SQL da Tag, geração da `OS-INFRA-vX.Y.Z.md` e exclusão da branch do card) mediante ok explícito do aprovador humano após validação de homologação. Nunca commit ou push direto na `main`/`master`, nunca force push.
- **Voz:** o agente planejador nunca fala externamente em nome do usuário, exceto preparando rascunhos.
- **Provider configurável:** GitHub e Azure DevOps suportados conforme o repositório.

## Briefing diário do Planejador (opcional)

Não obriga ninguém a usar nem a criar rotina.

- Conduzido pelo planejador junto aos revisores de projeto.
- Inspeciona `Planejamento/DEMANDAS.md` de cada projeto e verifica:
  1. O que está em `EM_DEV`, riscos e bloqueios;
  2. Quais cards estão parados em `EM_HOMOLOGACAO` há mais tempo;
  3. Quais cards já estão em `APROVADA_PROD` aguardando fechamento de Tag e abertura de OS na Infra.
- O resumo consolidado vai para o aprovador humano.

## Quando volta ao aprovador humano

Somente em:

1. Gate 1 (aprovação do plano/envelope), Gate 2 (commit após evidência de 100%) e autorização de subida para Produção;
2. mudança material de escopo (`BLOCKED_BY_DECISION`);
3. orçamento de fase ou limite de 3 tentativas do loop `Implementor` ↔ `Tester` excedido (`UNABLE_TO_VALIDATE`);
4. divergência de escopo, contrato, dados ou segurança.

Não interrompe pelo óbvio.
