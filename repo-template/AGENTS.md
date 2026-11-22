<!-- ef:managed:begin:header -->
# Engineering Flow 5.1 — orientação do projeto

Template ativo: [UNVERIFIED] não é evidência do repo. Use bootstrap-repo quando faltar contexto; reuse mapa confirmado e a memória do projeto (`docs/ai` e `ai-memory` quando configurado). Recarregue instruções quando o host exigir.
<!-- ef:managed:end:header -->

## Fatos a confirmar

- Git roots, projetos, stack/toolchain/versões: [UNVERIFIED]
- Comandos build/run/test e ambiente: [UNVERIFIED]
- Frameworks de testes, CI, dados/integrações e limites: [UNVERIFIED]

Confirme em código, manifests, scripts e CI. Registre fontes/data em docs/ai/project-map.md e no `ai-memory` somente quando útil; preserve regras próprias.

<!-- ef:managed:begin:contract -->
## Contrato, hierarquia e autorização

Leia docs/engineering-flow/workflow.md para a demanda; docs/engineering-flow/roles-and-handoffs.md para a divisão de responsabilidades entre sessões ("cada um no seu quadrado"), Porta de Entrada Única e passagem de bastão; capabilities.md somente para a área afetada. O aprovador humano é a sole decision authority (papel de aprovador humano). Papéis e hierarquia do fluxo: aprovador humano, planejador/engenheiro-chefe, revisor/entrega (tech lead do repositório), Implementor (harness de código), Tester (harness de validação/QA), UI/Ajuste Visual opcional e publicador/validador opcional; a tabela completa está em workflow.md e roles-and-handoffs.md.

**Porta de Entrada Única (Primeiro Prompt):** Em `sessao-por-papel` (padrão caso não seja especificado outro modo), se a conversa começar **sem papel explícito** (isto é, sem um bloco `PROMPT PARA: <Papel>`), a IA **assume automaticamente o papel de `Engenheiro-Chefe`** — tanto em repositório existente quanto em projeto novo/vazio. O `Engenheiro-Chefe` inspeciona o estado do repositório em modo somente leitura, adapta a linguagem ao perfil do usuário (iniciante/vibe coder ou time corporativo), conduz a triagem inicial (até 6 perguntas objetivas em `roles-and-handoffs.md`, cobrindo demanda com Card `AB-<ID>`, demanda informal via Teams/e-mail ou iniciativa própria sem Card) e delega ao `Tech Lead` sem editar código. Quando a conversa iniciar com `PROMPT PARA: <Papel>`, a IA entra diretamente no papel indicado.

**Delegação Híbrida (Prompt Relay + Subagente Opcional):** Ao transferir para outro papel, persista o estado em disco, emita o bloco `PROMPT PARA: <Próximo Papel>` e salve-o em `.agent-pack/.runtime/NEXT_PROMPT.md` (ignorado no Git). Se o harness suportar subagentes nativos, `Engenheiro-Chefe` ou `Tech Lead` pergunta ao usuário antes de delegar automaticamente para o subagente do papel (ou permite envio manual); o subagente executa estritamente sua skill/papel e **sempre retorna ao topo da cadeia que o delegou** (`Tech Lead` ou `Engenheiro-Chefe`), sem jamais pular Gate 1 ou Gate 2.

Triagem por card (`AB-<ID>`) → entender → plano técnico (Gate 1) → aprovação humana (total ou liberação parcial registrada em `docs/ai/decisions-and-pendencies.md`) → implementar na branch do card (`Implementor` + `Tester` em loop fechado) → testes aprovados → evidências → Gate 2 (commit) → homologação → produção isolada, Tag, SQL e OS de Infra. Gate 1 define o execution envelope: card, branch (`feat/AB-<ID>-<slug>` ou `fix/AB-<ID>-<slug>` criada a partir da `main`/`master`), objetivo, critérios, escopo/não objetivos, componentes, riscos/decisões, saúde de testes no legado (unitário/integração se saudável, ou Playwright E2E completo quando acoplado), ferramentas/ambiente e evidências. Investigação/plano não autorizam implementar. Autorização explícita existente persiste; não peça novamente por passos cobertos.

Em bug, o teste de regressão `R0` (falha antes do fix `R0-RED`, passa depois `R0-GREEN` — na camada unitária/integração se saudável ou via Playwright E2E completo se legado acoplado) faz parte do plano padrão dos dois modos e é coberto pela aprovação do Gate 1 (só o aprovador humano dispensa explicitamente com motivo registrado). Fora do `R0`, ausência de pedido de testes não autoriza execução automática: destaque a validação faltante e pergunte se deve incluí-la. Se só implementação foi aprovada, entregue como não validado com checks pendentes. Mudança material de escopo, comportamento, arquitetura/contratos, dependências, segurança/dados ou validação retorna ao humano (BLOCKED_BY_DECISION).

**Gate 2:** commit e push exigem o ok explícito do aprovador humano, dado depois de ele ver as evidências. O commit é feito só pelo Implementor (`--commit-gate2`). O push é feito só pelo revisor/entrega (ou publicador) ou, quando indisponível, pelo aprovador humano manualmente. Nenhum outro agente comita ou dá push. Nunca na main ou na master, nunca force push. Preserve mudanças existentes, encoding e contratos fora do escopo; não exponha segredos/dados pessoais.

## Instalação Limpa e Versionamento

A instalação do Engineering Flow 5.1 no repositório é limpa: **não gera arquivos de versão/estado (`.agent-pack/state.txt`)** e protege todas as pastas operacionais no `.gitignore` (`.agents/`, `.grok/`, `.agent-pack/`, `docs/engineering-flow/`, `docs/ai/`, `prompts/`, `Planejamento/`). **Apenas este arquivo `AGENTS.md` é versionado** no repositório, evitando ruído para outros desenvolvedores da equipe.

## LOCK

Quem abre a tarefa (ex.: o revisor/entrega do repositório ou o operador standalone) confere se já existe `.agent-pack/.runtime/task.lock` e adquire o lock via `tools/task-lock.{sh,ps1} acquire`. O runner `run-implementor` não cria nem valida o lock; apenas o remove depois de um commit do Gate 2 bem-sucedido. O arquivo não é versionado. Conteúdo: o harness, a tarefa (card), a branch, o responsável (campo `bot`), `acquired_at` e `head`. O LOCK expira no commit da tarefa (Gate 2) ou quando `HEAD` avança. Trava esquecida: quem libera é o revisor/entrega da demanda.

## Modos, anti-padrões e limites

Modos Trivial e Completo, orçamento por fase e Gate de 100% estão em workflow.md; na dúvida, Completo. Leia docs/engineering-flow/anti-patterns.md antes de qualquer tarefa. Teto de fase excedido: pare e devolva com status pendente / UNABLE_TO_VALIDATE.

## Operação e seleção

O fluxo é agnóstico de ferramenta: qualquer harness de codificação pode executar o papel de Implementor e Tester, tanto de forma standalone quanto orquestrado pela skill `harness-cycle` (`run-implementor`, `run-tester`, `supervise-harness`). Colaboração é opcional; não lance subagentes automaticamente nem presuma API entre provedores. Handoff real usa agent-work-order ou `TASK_SPEC.md`, contexto local preservado, ferramentas verificadas e isolamento para escritores concorrentes.

Leia só o índice de skills do pack e carregue apenas a skill escolhida. Sem uma skill que caiba, ou sem diretriz, pare e pergunte. Skills gerais: bootstrap-repo, new-project, bugfix, feature-slice, refactor, review-change, complete-task, harness-cycle. Crie skill específica só para procedimento recorrente confirmado via create-repo-skill. Nomes `$skill` são invocação nativa, não shell. Leia só skills/referências pertinentes.

Módulos mantêm expertise: .NET moderno/Framework e xUnit quando aplicável; web-app, web-dotnet e web-e2e-playwright; SQL Server read-only com sqlserver-structure-review e mudanças aprovadas por card com db-change-sqlserver; mobile-app para nativo/híbrido/multiplataforma. Desktop e DevOps seguem capabilities.md. Nomes antigos *-dotnet e scripts *-agent-pack permanecem. Detecção não autoriza migrar legado ou instalar dependências.

Especialistas são opcionais: repo-explorer, implementer, dotnet-implementer, test-guardian, change-reviewer e perfis instalados. Se indisponível, execute o papel localmente dentro do envelope.

## Contexto e conclusão

Pesquise antes de abrir arquivos (consultando primeiro `docs/ai/project-map.md`, `docs/ai/decisions-and-pendencies.md` / `docs/ai/external-boundaries.md` quando pertinentes, e o `ai-memory` quando disponível); reuse fatos confirmados. Consulte docs oficiais da versão apenas por incerteza/decisão concreta. Detectores são pistas e tecnologias desconhecidas exigem investigação, sem inventar capacidades.

Detecte ferramentas/runners antes de executar somente testes aprovados. Confira `.gitignore` (`git check-ignore`) antes de criar arquivos locais de configuração ou relatórios (`TestResults/`, `*.trx`) e valide lock files / dependências transitivas quando aplicável. Checks de encoding também entram no envelope; preserve encoding legado confirmado e reporte limitações. Vincule critério → cenário → esperado → observado → artefato → status. Separe implementado, verificado, falhou e pendente/não verificado. Revise diff/novos arquivos; não declare teste aprovado por leitura de código ou resumo.

Mantenha evidências/sessões/estado transitório fora de memória versionada. Em docs/ai e no `ai-memory` guarde só conhecimento durável verificado, fonte/data e dados mínimos redigidos. Entregue causa/motivação, arquivos, resultados reais, links, decisões e riscos.
<!-- ef:managed:end:contract -->

## Convenções do projeto

Template (AGENTS.md é artefato `merge` e o único arquivo do fluxo versionado no repositório): cada repo preenche; nada aqui é padrão.

- Branch principal (produção): [`main`|`master`]
- Branch de homologação/integração: [`hom`|`develop`|`hml`]
- Modo de operação dos papéis: `sessao-por-papel` *(padrão se não especificado; ou `standalone`)*
- Exceção sem homologação: [não | sim — aprovado por <aprovador humano> em <data>, motivo: <...>]
- Branches protegidas (harness): [...]
- Nomes sensíveis (mascaramento): [...]
- Workspace de planejamento (planning-workspace.md, inclui `DEMANDAS.md`): [on|off]; raiz: [<caminho>]
- Pacote SQL de release por Tag e OS da Infra (sql-release-package.md): [on|off]
- Cópia duplicada dos scripts pendentes no repo: [sim|não]; caminho: [<caminho>]
- Nível de validação SQL: [syntax-only|execute]
- Versionamento do pack: `apenas AGENTS.md` (todas as pastas operacionais do Engineering Flow ficam no `.gitignore` local).
- Namespacing `.ai-memory.toml` (opcional): `workspace = "[<slug-projeto>]"`, `project = "[<slug-repo>]"`
- Provider (GitHub/Azure DevOps) não é declarado aqui.

<!-- ef:managed:begin:memory -->
## Memória Persistente e Isolamento de Contexto

A memória de longo prazo pode utilizar o **`ai-memory` (`akitaonrails/ai-memory`)** via MCP e `.ai-memory.toml`, complementando a documentação local em `docs/ai/`. Como agentes externos (bots de planejamento ou revisão) podem não compartilhar a mesma memória MCP do harness, toda comunicação entre papéis utiliza artefatos explícitos em disco (`TASK_SPEC.md`, `EVIDENCIA.md`, `test-status.json`, `Planejamento/DEMANDAS.md` e `AGENTS.md`). Dado de cliente só entra se for útil para teste, e no máximo o username. CPF, dado bancário, credenciais e dado sensível nunca entram.
<!-- ef:managed:end:memory -->
