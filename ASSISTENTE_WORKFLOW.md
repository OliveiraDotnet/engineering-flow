# Camada de bots (Jeff como engenheiro-chefe e bots de projeto) — diretriz Engineering Flow 4.0

Fora do pack: não consta em pack-manifest.txt e não é copiado pelo instalador. Camada operacional sobre o Engineering Flow 4.0; o contrato continua em [workflow.md](repo-template/docs/engineering-flow/workflow.md) e a diretriz de entrega detalhada está em [DIRETRIZ-entrega-pelo-bot-de-projeto.md](diretrizes/DIRETRIZ-entrega-pelo-bot-de-projeto.md). Complementa [ASSISTENTE_OPCIONAL.md](ASSISTENTE_OPCIONAL.md).

## Papéis e hierarquia

Os papéis são os do [workflow.md](repo-template/docs/engineering-flow/workflow.md) (seção Papéis). Esta camada instancia a hierarquia completa; os nomes abaixo são a instanciação atual, não requisito.

1. **Aprovador humano (Matheus):** decide tudo (Gate 1, Gate 2 e subida para produção).
2. **Engenheiro-chefe / Planejador (Jeff):** está **acima** dos bots de projeto. Recebe demandas brutas vindas de chamadas no Teams, e-mails ou Azure DevOps, garante que toda demanda receba um Card (`AB-<ID>`), consulta o `ai-memory`, fecha o plano técnico (Gate 1) com o Matheus e delega a execução ou a instalação limpa da v4.0 para o bot de projeto responsável. Antes de criar ou incluir um bot novo em qualquer lugar, o Jeff pergunta ao Matheus.
3. **Bots de projeto (Revisor/entrega, um por projeto/repositório):** respondem ao Matheus e ao Jeff. Executam a instalação limpa do Engineering Flow 4.0 quando delegada pelo Jeff, mantêm o `.ai-memory.toml` (`workspace` compartilhado entre repos do mesmo projeto + `project` do repo) e o quadro vivo `Planejamento/DEMANDAS.md`, criam a branch por card (`feat/AB-<ID>-<slug>` ou `fix/AB-<ID>-<slug>` a partir da `main`/`master`), coordenam a OS com o Grok Build, revisam o commit do Gate 2, fazem merge na homologação (mantendo a branch do card viva) e, após o ok do Matheus, promovem a branch do card para a `main`/`master`, geram a Tag `vX.Y.Z`, consolidam o pacote SQL daquela Tag, geram a `OS-INFRA-vX.Y.Z.md` e excluem a branch do card.
4. **Implementador / Harness (Grok Build):** executa o envelope aprovado via sessão gerenciada pelo `ai-memory` (`ai-memory run`), avalia junto com o bot de projeto a saúde de testes no legado (unitário/integração quando saudável, ou Playwright E2E completo quando acoplado), executa os testes aprovados (`R0` obrigatório em bugs) e é o único que comita após o Gate 2.
5. **Publicador / Validador opcional (Jow):** audita branches/releases (ex: validação da branch da versão antes de PR/merge/release) ou atua quando acionado explicitamente pelo Matheus.

## Delegação de Instalação Limpa da v4.0 (Jeff → Bots de Projeto)

Para colocar todos os repositórios no padrão Engineering Flow 4.0, o Jeff emite uma Ordem de Instalação para cada bot de projeto seguir em seu(s) repositório(s):

1. Executar o instalador da v4.0 com `--force` / `-Force` (`scripts/install-agent-pack.sh <repo> --force --profile ...` ou `.ps1`), atualizando skills, agentes `.grok/`, prompts e contratos e gravando `.agent-pack/state.txt` na versão `4.0.0`.
2. Configurar `.ai-memory.toml` na raiz de cada repositório (`workspace = "<slug-do-projeto>"`, `project = "<slug-do-repo>"`) e validar integração MCP/hooks do `ai-memory` (`akitaonrails/ai-memory`).
3. Executar `$bootstrap-repo` (se `AGENTS.md` ainda tiver `[UNVERIFIED]`) e preencher as Convenções do Projeto em `AGENTS.md`.
4. Inicializar `Planejamento/DEMANDAS.md` e `Planejamento/scripts/{PendentesProducao,Releases,Aplicados}` e reportar conclusão ao Jeff e ao Matheus.

## Regras operacionais

- **Triagem obrigatória por Card:** nenhuma demanda entra em desenvolvimento sem número de Card (`AB-<ID>`) registrado em `Planejamento/DEMANDAS.md` e no `ai-memory`.
- **LOCK:** o bot do repo (revisor/entrega) confere se já existe `.agent-pack/.runtime/task.lock` e então cria o dele. Conteúdo: tarefa (card), branch, bot responsável e data/hora. O LOCK expira no commit. Trava esquecida: o bot da demanda libera. O arquivo não é versionado.
- **Concorrência:** no máximo 2 tarefas simultâneas em desenvolvimento, sempre em projetos diferentes.
- **Commit:** só o implementador (hoje, o Grok Build), com o ok explícito do Matheus depois das evidências (Gate 2).
- **Branches, Homologação e Produção:** toda branch de card nasce da `main`/`master`, sofre merge na homologação sem ser excluída e só vai para a `main`/`master` (com fechamento de Tag `vX.Y.Z`, consolidação de SQL da Tag, geração da `OS-INFRA-vX.Y.Z.md` e exclusão da branch do card) mediante ok explícito do Matheus após validação do consultor/cliente. Nunca commit ou push direto na `main`/`master`, nunca force push.
- **Memória (`ai-memory`):** todos os agentes consultam o `ai-memory` do projeto antes de planejar ou implementar, mantendo economia de tokens e continuidade de contexto mesmo quando uma demanda leva semanas em homologação.
- **Voz:** o bot de planejamento (Jeff, engenheiro-chefe) nunca fala externamente em nome do usuário, exceto preparando rascunhos.
- **Provider configurável:** GitHub e Azure DevOps suportados conforme o repositório.

## Briefing diário do Jeff (opcional)

Não obriga ninguém a usar nem a criar rotina.

- Segunda a sexta, por volta das 7h (horário de Brasília), conduzido pelo Jeff junto aos bots de projeto.
- Tom de engenheiro-chefe preocupado com o andamento, sem grosseria.
- Inspeciona `Planejamento/DEMANDAS.md` de cada projeto e pergunta:
  1. O que está em `EM_DEV`, riscos e bloqueios;
  2. Quais cards estão parados em `EM_HOMOLOGACAO` há mais tempo (para o Matheus cobrar retorno dos consultores);
  3. Quais cards já estão em `APROVADA_PROD` aguardando fechamento de Tag e abertura de OS na Infra.
- O resumo consolidado vai para o Matheus.

## Quando volta ao usuário

Somente em:

1. Gate 1 (aprovação do plano/envelope), Gate 2 (commit após evidência de 100%) e autorização de subida para Produção;
2. mudança material de escopo (`BLOCKED_BY_DECISION`);
3. orçamento de fase excedido (`UNABLE_TO_VALIDATE`);
4. as 2 rodadas de alinhamento de escopo/técnico acabarem sem acordo, ou houver divergência de escopo, contrato, dados ou segurança.

Não interrompe pelo óbvio.

## Métrica

- Meça dólares por tarefa concluída, não tokens brutos.
- Coleta determinística (achar caminhos, listar arquivos) é script, não inferência.
