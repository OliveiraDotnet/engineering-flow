# SpecGuard 6 (Engineering Flow) changelog

## 6.0.0 — 2026-11-22 (SpecGuard 6)

- **Identidade SpecGuard 6 & Desacoplamento 99,9%:** Evolução major para **SpecGuard 6 (`6.0.0`)** mantendo compatibilidade retroativa com `compat/releases/1.1.0..5.1.0`, marcadores `ef:managed`/`ef:paths` e estrutura `docs/engineering-flow/`. Apenas `AGENTS.md` permanece versionável no repositório destino — sempre consolidado via blocos gerenciados (`ef:managed`) e nunca apagado/recriado do zero quando já existir; todos os novos arquivos de runtime ficam 100% ignorados em `.agent-pack/.runtime/`.
- **Porta de Entrada Única & Delegação Híbrida:** No primeiro prompt sem papel explícito, a IA assume automaticamente `Engenheiro-Chefe`, faz leitura read-only prévia, conduz até 6 perguntas objetivas (cobrindo Card `AB-<ID>`, demandas informais via Teams/e-mail e projetos independentes/vibe coder) e delega ao `Tech Lead` gravando `.agent-pack/.runtime/NEXT_PROMPT.md` (com escolha explícita entre subagente nativo — sempre retornando ao topo da cadeia — ou envio manual).
- **Checkpoint Estruturado de Sessão & Telemetria Local (`tools/session-state.{ps1,sh}`):** Gerencia `.agent-pack/.runtime/session-state.json` (com `deadEnds` deduplicado para impedir repetição de abordagens falhas entre conversas) e grava 1 linha JSON append-only em `.agent-pack/.runtime/metrics.jsonl` no fechamento do card (`complete-task`). Coberto por `scripts/test-session-state.ps1`.
- **Contexto Estático-Primeiro (Prompt Caching) & Compaction de Logs:** Prompts de harness (`12-implementor-harness.md`, `13-tester-harness.md`) e handoffs (`roles-and-handoffs.md`) padronizados com prefixo imutável no topo e dados dinâmicos no final, passando no máximo 20–40 linhas do erro raiz + caminho do log mascarado.
- **Risk Tiering (`Tier 0 Trivial`, `Tier 1 Padrão`, `Tier 2 Crítico`):** Evolução dos modos de operação em `workflow.md` e `AGENTS.md` combatendo *Spec Sprawl* em tarefas rotineiras e concentrando rigor em mudanças críticas (SQL/migrations, auth/LGPD, contratos, dependências e arquitetura).
- **Playbooks de Arquitetura Greenfield vs. Brownfield (`docs/engineering-flow/architecture-playbooks.md`) & `Dxx` Escopadas (`applies_to`):** Padrão default **Monólito Modular + Vertical Slices / Schema-First** em projetos novos e **Quarentena de Legado + Characterization Tests + Strangler Fig** em legados; `docs/ai/decisions-and-pendencies.md` passa a declarar `Escopo (applies_to)` e `Regra verificável (DO / DO NOT)` para injeção seletiva no `TASK_SPEC.md`.
- **Cache Estrutural de Símbolos por Commit (`inspect-repo.{ps1,sh} -GenerateRepoMap`):** Gera `.agent-pack/.runtime/repo-map.txt` (`.cs`, `.ts`, `.js`, `.py`, `.go`, `.java`, `.kt`, `.sql`) sem vazar corpos/segredos, com `cache-hit` automático quando `HEAD` limpo não mudou. Coberto por `scripts/test-repo-map.ps1`.
- **Guarda Determinística Pré-Gate 2 (`tools/verify-envelope.{ps1,sh}`) & Fitness Functions Arquiteturais:** Bloqueia deterministicamente branch protegida (`exit 10`), alterações fora de `ef:paths` (`exit 11`), vazamento de arquivo operacional no staging (`exit 12`), `SECRET_IN_LOG` (`exit 13`) e `test-status.json` não aprovado (`exit 14`). Integrado à receita de Fitness Functions (`NetArchTest` / `dependency-cruiser` / `ArchUnit`) no `harness-cycle`. Coberto por `scripts/test-verify-envelope.ps1`.

## 5.1.0 — 2026-11-17

- **Decisões, Pendências e Liberação Parcial no Gate 1:** Adicionado o template `seed` `docs/ai/decisions-and-pendencies.md` (registro único `Dxx` / `Pxx` com dono, impacto e fase/card bloqueado) e suporte explícito em `workflow.md` e `AGENTS.md` para **liberação parcial** no Gate 1 (ex.: liberar base técnica/persistência dev enquanto regras de negócio seguem bloqueadas).
- **Inventário de Fronteiras e Saídas Externas:** Adicionado o template `seed` `docs/ai/external-boundaries.md` para mapear origens/destinos, protocolos, políticas de CDN/telemetria e uploads; novas saídas fora do inventário disparam `BLOCKED_BY_DECISION`.
- **Descoberta Funcional e Rastreabilidade em `new-project`:** Atualizados `.agents/skills/new-project/SKILL.md` e `prompts/10-new-project.md` para separar **fato**, **suposição** e **pergunta aberta**, classificar escopo (**core** vs. **ampliação**), gerar matriz inicial de rastreabilidade (`Requisito → Tela/Endpoint → Cenário → Tabela/Migration`) e exigir verificação do grafo transitivo real via lock files (`RestoreLockedMode`).
- **Estados Canônicos e Transições Fechadas:** Atualizado `docs/ai/domain-glossary.md` com o padrão de separação entre estado de negócio/externo e estado de processamento, rótulos derivados na UI e tabela fechada de transições permitidas.
- **Fronteira Funcional × Visual (UI), Fechamento Independente de Segurança e Higiene Preventiva:** Atualizados `workflow.md`, `web-app`, `web-dotnet`, `frontend-web`, `security-review-dotnet`, `security-reviewer`, `review-change`, `db-change-sqlserver` e `maintain-agent-memory`: (1) `Implementor` define estrutura, rotas, campos, menus e regras enquanto refinamentos visuais preservam comportamento; (2) achados corrigidos ficam `Em verificação` e só fecham após reteste independente; (3) conferência de `.gitignore` (`git check-ignore`) antes de criar configs locais ou relatórios (`TestResults/`, `*.trx`), `*.example.*` sem segredos e guarda `IsDevelopment()` obrigatória em exceções de dev.
- **Instalação Limpa Preservada:** Os novos artefatos `docs/ai/*` herdam a proteção automática no `.gitignore`; apenas `AGENTS.md` segue versionável no repositório destino.

### Correções (reemissão de 18/11/2026)

- **B0 (`scripts/test-harness-cycle.{sh,ps1}`):** Reescritas as suítes de teste do ciclo de harness contra a CLI real dos runners (`--card-id`/`-CardId`, `--demand-type`/`-DemandType`, `--implementor-cmd`/`-ImplementorCommand`, `--r0-red-cmd`/`-R0RedCommand`, `--max-retries`/`-MaxRetries`, saída `passed` em `test-status.json`), preservando os cenários de R0-RED→GREEN, retry via `EF_ATTEMPT`, circuit breaker (`UNABLE_TO_VALIDATE` com exit 1) e liberação de lock, além dos novos cenários S1–S4.
- **S1 (`ef-secrets.{sh,ps1}`, `run-tester.{sh,ps1}`, `pack-manifest.txt`, `pack-artifacts.txt`):** Criada a biblioteca `ef-secrets` (`ef_load_secrets`, `ef_mask`, `ef_scan`) incluída no manifesto (`core` e `grok-core`); `run-tester` mascara a saída de `r0-red` e `validate` em memória antes de gravar `.agent-pack/evidencias/<CardId>/{r0-red.log,test-output.log}` e atualiza apenas o bloco delimitado `<!-- runner:begin -->` … `<!-- runner:end -->` na `EVIDENCIA.md` com `commandSha256` (12 hex, nunca o comando literal), contagem de mascaramentos e resultado do scan (exit 2 se os marcadores estiverem malformados).
- **S2 (`run-implementor.{sh,ps1}`):** O conteúdo de `TASK_SPEC.md`, do prompt `12-implementor-harness.md` e do feedback (bloco `runner` da `EVIDENCIA.md` mais cauda do `test-output.log` já mascarado) passa por `ef_mask` antes de ser gravado em `.agent-pack/.runtime/implementor-prompt-<card>.md`, registrando apenas a contagem de mascaramentos.
- **S3 (`run-implementor.{sh,ps1}`, `harness-cycle/SKILL.md`):** `--commit-gate2`/`-CommitGate2` passa a exigir staging explícito via `--paths`/`-Paths` ou bloco `ef:paths` do `TASK_SPEC.md` (`git add --`, exigindo caminhos de arquivo individual — diretórios e caminhos vazios, absolutos, com `..`, fora do repo ou sob diretórios do pack são recusados com exit 5 —, e listando `UNSTAGED_OUT_OF_SCOPE`); recusa commit em branches protegidas (`main`, `master`, `HEAD` destacado, `AGENTS.md` `- Branches protegidas (harness): ...` e `EF_PROTECTED_BRANCHES`) com exit 3; e `--allow-unvalidated` exige `--reason` com pelo menos 10 caracteres (exit 2 se ausente), registrando em `EVIDENCIA.md` e `test-status.json`.
- **S4 (scripts de `harness-cycle/scripts/`, `harness-cycle/SKILL.md`, `workflow.md`, prompts 12/13):** Adicionado suporte a `--harness <agy|claude|grok>` e `--harness-args` (`EF_HARNESS`/`EF_HARNESS_ARGS`), capturando stdout/stderr linha a linha via `ef_mask` para `$EF_HARNESS_LOG_DIR/<CardId>_<role>_attempt<N>.jsonl`/`.err` (além do `--harness-cmd` legado), com perfis (`agy` exigindo `--effort high`, `claude`, `grok` apenas com `--harness-args` explícito), suporte a `EF_SECRET_VALUES_FILE` (validado fora do repo/logs/evidencias/.runtime), `EF_SECRET_NAMES` e `AGENTS.md` (`- Nomes sensíveis (mascaramento): ...`), e scan obrigatório `ef_scan` ao final de `run-implementor`, `run-tester` e `--commit-gate2` detectando padrões fixos, `EF_SECRET_NAMES` e lista de valores com exit 6 `SECRET_IN_LOG` nas duas plataformas (`sh` e `ps1`, mascarando no lugar e abortando o `supervise-harness` sem retry; nova rodada limpa em `run-tester --phase validate` desbloqueia); escapes JSON (`\u003d`, `\u003c`, `\u0026`, `\"`, entre outros) são decodificados para o match preservando a linha original fora do trecho mascarado, e permanecem como limitações conhecidas segredos em base64, URL-encoded e valores partidos entre eventos do stream.
- **P4 (`DIRETRIZ`, `ASSISTENTE_WORKFLOW.md`, `harness-cycle/SKILL.md`, `workflow.md`, `validate-pack.{sh,ps1}`):** Documentado que apenas o harness (`Implementor`/`Tester`) executa `supervise-harness`, `run-implementor`, `run-tester` e `--commit-gate2`, ficando o Revisor/entrega responsável por `TASK_SPEC.md`, revisão, push, PR e merge; adicionada checagem estática em `validate-pack.{sh,ps1}`.
- **I5 (`repo-template/AGENTS.md`, `scripts/install-agent-pack.{sh,ps1}`, `scripts/merge-managed-blocks.{sh,ps1}`, `scripts/test-install-agent-pack.{sh,ps1}`, docs):** Adicionados blocos gerenciados `<!-- ef:managed:begin:<id> -->` (`header`, `contract`, `memory`) em `repo-template/AGENTS.md`; `install-agent-pack --force` passa a fazer merge por blocos em `AGENTS.md` preservando o conteúdo fora dos blocos (backup + remoção do sidecar) e sai com **exit 7** (`AGENTS_MD_MERGE_SKIPPED`) mantendo o arquivo intacto e o sidecar `.agent-pack.new` quando não houver marcadores ou houver marcadores malformados; atualizada a documentação removendo a recomendação ampla de `--force`.
- **I6 (`scripts/protect-engineering-flow-files.{sh,ps1}`, `scripts/install-agent-pack.{sh,ps1}`, `scripts/test-install-agent-pack.{sh,ps1}`, docs):** Adicionado o modo `unignore-agents-md`/`-UnignoreAgentsMd` chamado no preflight do instalador: quando `git check-ignore` aponta `AGENTS.md` ignorado, faz append idempotente de `!AGENTS.md` ao `.gitignore` preservando regras, BOM e EOL existentes (exit 5 se continuar ignorado; `--dry-run` emite `WOULD-UNIGNORE`).
- **I7 (`scripts/protect-engineering-flow-files.{sh,ps1}`, `INSTRUCOES_DETALHADAS.md`, `scripts/test-install-agent-pack.{sh,ps1}`, `scripts/test-git-hygiene.ps1`):** Incluído `.ai-memory.toml` na lista de proteção no `.gitignore` e removido o número de versão do comentário marcador.
- **C8 (docs, 25 arquivos de skills/agents, `SKILLS-INDEX.md`, `tools/generate-skills-index.{sh,ps1}`, `scripts/validate-pack.{sh,ps1}`, `scripts/test-validate-pack.{sh,ps1}`):** Atualizados títulos para `Engineering Flow 5.1`, os 25 headers para `Engineering Flow execution gate` e as menções residuais à versão 5.0 (`v5.0`, `padrão`/`pack 5.0`, `instalação limpa 5.0`) para `5.1` (mantidas as menções históricas `README.md` `"A linha 5.0"` e `INSTRUCOES_DETALHADAS.md` `"A linha 5.0 evolui a 4.x"`); `generate-skills-index` passa a ler `pack-version.txt` (`SKILLS-INDEX.md` regenerado); `validate-pack` barra `Engineering Flow [345].0` e essas formas residuais `v5.0`/`padrão 5.0`/`pack 5.0`/`instalação limpa 5.0` (com allowlist para `CHANGELOG.md`, `compat/*`, `tests/*` e `scripts/update-agent-pack.{sh,ps1}`), coberto pelas novas suítes `scripts/test-validate-pack.{sh,ps1}`.
- **C9 (`INSTRUCOES_DETALHADAS.md`, `workflow.md`, `ASSISTENTE_WORKFLOW.md`, `harness-cycle/SKILL.md`, `DIRETRIZ`):** Alinhada a documentação ao comportamento real de `tools/task-lock.{sh,ps1}` e `run-implementor`: quem abre a tarefa adquire o lock via `task-lock acquire`, e `run-implementor` não cria nem valida o lock, apenas o remove após o commit bem-sucedido do Gate 2.
- **C10 (`prompts/12-implementor-harness.md`, `prompts/13-tester-harness.md`, `harness-cycle/SKILL.md`, `validate-pack.{sh,ps1}`, `test-validate-pack.{sh,ps1}`):** Incluída na cadeia do harness a leitura obrigatória de `docs/ai/decisions-and-pendencies.md` e `docs/ai/external-boundaries.md`, parada com `BLOCKED_BY_DECISION` quando faltar decisão ou saída inventariada, e regras de proteção de logs/segredos (S4), com checagem estática em `validate-pack.{sh,ps1}`.
- **C11 (`repo-template/AGENTS.md`, `DIRETRIZ`, `workflow.md`):** Adicionadas em `Convenções do projeto` de `AGENTS.md` as linhas `Exceção sem homologação`, `Branches protegidas (harness)` e `Nomes sensíveis (mascaramento)`, documentando o merge direto para `main`/`master` apenas mediante exceção explicitamente aprovada no `AGENTS.md`.
- **C12 (`workflow.md`, `MANUAL_DE_USO.md`, `bugfix-dotnet/SKILL.md`, `dotnet-xunit-tests/references/xunit-test-checklist.md`):** Atualizada a regra de `.NET Framework 4.8`: o harness pode compilar e executar localmente detectando MSBuild (`where msbuild` ou `vswhere`), Developer Prompt, IIS Express e cópia de execução fora do Git (sem instalar nada); apenas release/publish permanece com o aprovador humano no VS 2022 (sem MSBuild detectado, status `pendente` com o bloqueio exato).
- **Revisão (18/11/2026):** Corrigidos os achados da revisão: **B1** (`ef-secrets.ps1` substitui o `$count++` dentro de `MatchEvaluator` — que incrementava apenas uma variável local de escopo filho — por contagem explícita das correspondências via `.Matches()` e `Invoke-EfReplaceSpans`, eliminando o falso `clean` no `ef_scan` com padrões fixos ou `EF_SECRET_NAMES` e igualando `masked: N` e exit 6 com o `sh`), **B2** (`ef_mask`/`ef_scan` decodificam escapes JSON `\u003d`, `\u003c`, `\u0026`, `\"`, entre outros, apenas para o match sem alterar os bytes originais fora do trecho mascarado) e **N1** (menções residuais à 5.0 atualizadas para 5.1 e guard do `validate-pack` ampliado), além da documentação de `--paths` somente para arquivos (exit 5 para diretórios) e limitações conhecidas em `harness-cycle/SKILL.md`, cobertos pelos novos testes negativos em `scripts/test-harness-cycle.{sh,ps1}` e `scripts/test-validate-pack.{sh,ps1}`.
- **Separação de papéis por sessão e Prompt Relay (`docs/engineering-flow/roles-and-handoffs.md`):** Adicionado o documento `managed` agnóstico de ferramenta com a matriz "Faz | Não faz", posse de pastas/artefatos e protocolo de passagem de bastão (`PROMPT PARA: <Próximo Papel>`); adicionado `Modo de operação dos papéis` em `AGENTS.md` e nos bootstraps (`bootstrap-repo`, `bootstrap-dotnet-repo`) assumindo **`sessao-por-papel`** por padrão quando nada for especificado.

#### BREAKING

1. `--commit-gate2`/`-CommitGate2` passa a exigir `--paths` ou o bloco `ef:paths` do TASK_SPEC. Antes fazia `git add -A` (`run-implementor.sh:58`; `.ps1:46`). Quem chama sem lista agora recebe exit 5.
2. `--allow-unvalidated` passa a exigir `--reason`. Antes era um switch sem argumento (`run-implementor.sh:30`; `.ps1:12`). Sem motivo, exit 2.
3. Branches protegidas além de main/master, vindas do `AGENTS.md` ou de `EF_PROTECTED_BRANCHES`, passam a recusar o commit com exit 3. Antes só `main|master|""` era recusado (`run-implementor.sh:45-49`).
4. Novo exit 6 (`SECRET_IN_LOG`) em `run-implementor`, `run-tester` e `--commit-gate2`, que `--allow-unvalidated` não contorna. O `supervise-harness` para sem retry.
5. `install-agent-pack --force` **não substitui mais** o `AGENTS.md`. Antes era `REPLACE` (`install-agent-pack.sh:328-329`; `test-install-agent-pack.sh:123-125`). Agora há merge por blocos, ou, sem marcadores, o arquivo fica, com sidecar e **exit 7**. Como nenhum AGENTS.md instalado até 4846121 tem marcadores, **todo `--force` em repo existente sai com exit 7 até a migração única** (I5), e automações que tratam código diferente de zero como falha precisam saber disso.
6. O instalador passa a **acrescentar `!AGENTS.md` ao `.gitignore`** quando o AGENTS.md está ignorado (I6). É uma mudança de comportamento, mas não quebra API: só faz append, sem remover regra nenhuma.

Reemissão: a tag v5.1.0 é recriada no commit de merge desta correção; instalações feitas a partir de 4846121 têm hashes que não constam mais do catálogo (ver update-agent-pack).

- `pack-version.txt` = `5.1.0`. `compat/releases/5.1.0.txt`.

## 5.0.0 — 2026-11-11

- **Arquitetura 100% Genérica e Agnóstica de Ferramenta / Persona:** Removidas referências obrigatórias a ferramentas proprietárias (`Claude Code`, `Grok Build`, `Grok Bot`, `Antigravity`) e nomes pessoais (`Jeff`, `Jow`, `Matheus`) em toda a documentação, prompts, skills e scripts. O Engineering Flow 5.0 define uma hierarquia universal de papéis (`Aprovador humano` → `Planejador / Engenheiro-Chefe` → `Revisor / Entrega (Tech Lead de Repositório)` → `Implementor` + `Tester` no harness → `Publicador / Validador opcional`) que pode ser operada por **um único harness acumulando papéis (standalone)** ou por **múltiplos agentes independentes construídos de baixo para cima**.
- **Camada de Harness Bottom-Up (`Implementor` + `Tester` + `harness-cycle`):** Adicionados os contratos `prompts/12-implementor-harness.md` e `prompts/13-tester-harness.md`, a skill `harness-cycle` (`.agents/skills/harness-cycle/SKILL.md` e espelho `.grok/skills/harness-cycle/SKILL.md`) e os runners multiplataforma `run-implementor.{sh,ps1}`, `run-tester.{sh,ps1}` e `supervise-harness.{sh,ps1}`. O supervisor executa o loop fechado pré-Gate 2 (`R0-RED` antes do fix em bugs → `Implementor` → `R0-GREEN` / `FULL`, até 3 tentativas), gerando `.agent-pack/evidencias/<CardId>/EVIDENCIA.md` e `.agent-pack/.runtime/test-status.json`. Somente o `Implementor` executa `git commit` após o Gate 2 (`--commit-gate2`), expirando o `task.lock`.
- **Instalação Limpa no Repositório Alvo (Apenas `AGENTS.md` Versionado, Sem `state.txt`):** Atualizados `scripts/install-agent-pack.{sh,ps1}` e `scripts/protect-engineering-flow-files.{sh,ps1}`. A instalação em repositórios destino não gera arquivos de versão/estado (`.agent-pack/state.txt`) e adiciona todas as pastas operacionais do Engineering Flow (`.agents/`, `.grok/`, `.agent-pack/`, `docs/engineering-flow/`, `docs/ai/`, `prompts/`, `Planejamento/`, `planejamento/`, `.engineering-flow-evidence/`, `*.agent-pack.new`, `*.agent-pack.backup-*`) ao `.gitignore` do repositório alvo, garantindo que **somente `AGENTS.md` seja versionado** e evitando ruído para outros desenvolvedores da equipe.
- **Isolamento Explícito de Memória e CLI Sólido:** Documentado o isolamento entre agentes externos (que não compartilham a memória MCP `ai-memory` interna do harness) por meio de artefatos em disco (`TASK_SPEC.md`, `EVIDENCIA.md`, `test-status.json`, `Planejamento/DEMANDAS.md`, `AGENTS.md`), bem como a execução CLI headless não-bloqueante. Default do `tools/task-lock.{sh,ps1}` alterado para `harness=default`.
- `pack-version.txt` = `5.0.0`. `compat/releases/5.0.0.txt`.

## 4.0.0 — 2026-11-01

- **Memória Persistente (`ai-memory` do Fábio Akita):** Removidos `tools/memoria.sh`, `tools/memoria.ps1`, `scripts/test-memoria.sh`, `scripts/test-memoria.ps1`, `memory-template/`, `config/maquinas.conf.example` e a pasta local `conhecimento/`. O Engineering Flow 4.0 adota exclusivamente o **`ai-memory` (`akitaonrails/ai-memory`)** via MCP (`ai-memory mcp-bridge`), workstreams (`ai-memory run`) e `.ai-memory.toml` (`workspace` compartilhado em projetos multi-repo + `project` por repositório), mantendo as travas de privacidade/LGPD (proibido armazenar CPF, dados bancários, credenciais ou connection strings).
- **Hierarquia Jeff (Engenheiro-Chefe) e Bots de Projeto + Rito de Instalação Limpa:** Atualizados `ASSISTENTE_WORKFLOW.md`, `INSTRUCOES_DETALHADAS.md` e `diretrizes/DIRETRIZ-entrega-pelo-bot-de-projeto.md` (Revisão 4) estabelecendo o fluxo de delegação do Jeff para cada bot de projeto realizar a instalação limpa da `4.0.0` (`install-agent-pack --force`), configurar `.ai-memory.toml`, mapear `AGENTS.md` e inicializar `Planejamento/DEMANDAS.md` e `Planejamento/scripts/{PendentesProducao,Releases,Aplicados}`.
- **Triagem por Card (`AB-<ID>`) e Quadro Vivo (`Planejamento/DEMANDAS.md`):** Nenhuma demanda inicia sem número de card. Todas as demandas (incluindo as vindas de Teams/e-mail) são rastreadas em `Planejamento/DEMANDAS.md` (`TRIAGEM` → `EM_DEV` → `EM_HOMOLOGACAO` → `APROVADA_PROD` → `EM_PRODUCAO`), auditado no briefing diário das 7h pelo Jeff para evitar demandas esquecidas em homologação.
- **Ciclo de Branches por Card e Promoção Isolada para Produção:** Toda branch inclui o ID do card (`feat/AB-<ID>-<slug>` ou `fix/AB-<ID>-<slug>`) e nasce obrigatoriamente da `main`/`master`. No Passo 9, o bot de projeto faz merge na branch de homologação (`hom`/`develop`/`hml`) **sem excluir a branch do card**. No Passo 10, quando o consultor aprova a demanda e o Matheus dá o ok explícito, o bot de projeto faz o merge **da branch do card diretamente na `main`/`master`** (permitindo subir demandas aprovadas sem levar outras demandas ainda em homologação), fecha a Tag `vX.Y.Z` (Passo 11) e só então exclui a branch do card.
- **Governança de SQL Legado por Card e Release (`sql-release-package.md` + `db-change-sqlserver`):** Substituído o consolidado mensal pelo controle individual por card em `scripts/PendentesProducao/AB-<ID>-<slug>.sql` (sempre idempotente e transacional). No fechamento da Tag `vX.Y.Z`, consolidam-se apenas os scripts dos cards aprovados naquela Tag em `scripts/Releases/vX.Y.Z_consolidado.sql`, gerando automaticamente a Ordem de Serviço da Infra (`OS-INFRA-vX.Y.Z.md`) e movendo os scripts aplicados para `scripts/Aplicados/vX.Y.Z/`.
- **Saúde de Testes no Legado vs. Playwright E2E Completo e Alinhamento do `R0`:** Alinhados `AGENTS.md` (projeto e global), `workflow.md`, `prompts/01-bugfix.md`, `bugfix`, `bugfix-dotnet`, `feature-slice`, `feature-slice-dotnet` e `.grok/agents/test-guardian.md`. No Gate 1, avalia-se se é saudável criar teste unitário/integração no legado sem refatoração invasiva fora do escopo; se o legado for acoplado, é proibido forçar refatoração arriscada e a validação (incluindo o `R0` obrigatório em bugs) sobe para o **Teste E2E Completo (Playwright)**.
- `pack-version.txt` = `4.0.0`. `compat/releases/4.0.0.txt`.

## 3.1.2 — 2026-10-27

- Causa: no Windows, o teste capturava a saída do `pwsh -File tools/memoria.ps1` com `[Console]::OutputEncoding` OEM. O filho já escrevia UTF-8. O C07 via `não é um bloco` como mojibake (`n├úo` na CP850) e a asserção não casava. No Linux com `LANG=C` o pwsh 7 não reproduz isso. Os `.ps1` com acento estavam em UTF-8 sem BOM; o Windows PowerShell 5.1 lê esse arquivo como ANSI.
- Correção: `scripts/test-memoria.ps1` lê stdout e stderr do filho com `StandardOutputEncoding` e `StandardErrorEncoding` UTF-8. Todo `.ps1` com caractere não ASCII fica UTF-8 com BOM. `tools/memoria.ps1` e `scripts/test-memoria.ps1` ficam também com CRLF.
- Causa: `Get-Rel` e `Resolve-MemDir` comparavam o prefixo sem normalizar `\` e `/`. `Get-MemPath` monta a pasta com `/` e o `FullName` / `Get-Location` no Windows traz `\`. `README.md`, `_templates/cartao.md` e `INDEX.md` contavam como cartão (`lint` falha, `index` aborta, `pendentes` lista o modelo). Sem `--sistema`, a pasta atual parecia fora da raiz.
- Correção: os separadores viram `/` antes da comparação. No Windows o prefixo usa `OrdinalIgnoreCase`. As funções ficam testáveis por dot-source, sem comando novo na CLI. O filtro de `.cache` já aceitava os dois separadores e não mudou.
- Causa cosmética: a lista de blocos saía com espaço antes do ponto (`Blocos: fixture semraiz .`).
- Correção: trim da lista em `tools/memoria.ps1` e `tools/memoria.sh`. O `memoria.sh` não mistura `FullName` com `\`; o caminho dele não mudou.
- Testes: logo após o `init`, `lint` é 0, `index` não aborta e `pendentes` não lista o modelo. A busca sem `--sistema` funciona na pasta da memória e numa subpasta. As mensagens com acento casam. Há um caso com caminhos no estilo Windows (`C:\x/sisman/conhecimento`).
- Texto: `maintain-agent-memory` e o prompt 06 não falam mais em revalidação, validade ou expiração. O `AGENTS.md` do repo-template também saiu da revalidação. O cartão não vence e não há teto. A confirmação continua sendo a edição manual do front-matter depois do ok do Matheus.
- Documentação: `update-agent-pack.ps1 -Apply` no PowerShell sem console inclui `-Confirm:$false`. `ConfirmImpact` e a lógica de confiança do updater não mudaram.
- `pack-version.txt` = 3.1.2. `compat/releases/3.1.2.txt`.

## 3.1.1 — 2026-10-27

- Causa: `compat/releases/3.0.0.txt`, publicado na 3.0.0 e repetido na 3.1.0, tinha 35 hashes que não correspondem ao conteúdo da tag `v3.0.0`. O updater da 3.1.0 recusa um state 3.0.0 intacto.
- Correção: esses 35 hashes foram substituídos pelo SHA-256 normalizado (UTF-8 sem BOM, CRLF/CR para LF) da tag `v3.0.0`. Ids, destinos e ordem permanecem. A verificação de confiança do updater não mudou.
- Teste novo: `scripts/test-compat-catalogs.ps1` e `scripts/test-compat-catalogs.sh` conferem catálogo × tag, ids × `pack-artifacts.txt`, o catálogo da versão atual × working tree e a fixture 3.0.0 → atual.
- Aviso: a 3.1.0 não atualiza repositórios com state 3.0.0 intacto. Use a 3.1.1.
- Skills `update-agent-pack` e `bootstrap-dotnet-repo`: o comando Windows passa a `pwsh -File` (os scripts exigem PowerShell 7).
- `workflow.md` registra que `tools/memoria.*` roda a partir do clone do pack (`$AGENT_PACK_HOME/tools/...`).

## 3.1.0 — 2026-10-26

- Papéis genéricos no método: aprovador humano, planejador, implementador, revisor/entrega e publicador opcional. A instanciação atual (Matheus, Jeff, Grok Build, bot de projeto, Jow) é exemplo. Nenhuma regra de gate ou de branch mudou.
- Renomeação, fora do pack: `GROK_BOT_WORKFLOW.md` passou a `ASSISTENTE_WORKFLOW.md` e `GROK_BOT_OPCIONAL.md` passou a `ASSISTENTE_OPCIONAL.md`.
- Diretriz de entrega revisão 3 em `diretrizes/DIRETRIZ-entrega-pelo-bot-de-projeto.md`: a revisão 2 com papéis genéricos. Exceções de GA, B2TI, SISMAN e FASTCRED com o texto literal.
- Camada de teste: R0 obrigatório em bug (falha antes, passa depois; o planejador opina antes; só o Matheus dispensa), pirâmide unitário / integração xUnit / e2e Playwright, e o aviso explícito quando não há teste de integração.
- Dependências padrão no texto, sem instalação pelo pack: Playwright, bUnit e Testcontainers. Imagem obrigatória no Completo para critério de tela ou evidência de cliente, gerada pelo Playwright E2E. No Trivial, resumo curto com o arquivo alterado.
- Skill nova `web-e2e-playwright` (texto e template). Checklist xUnit: .NET Framework 4.8 no VS 2022, com o Matheus.
- `config/maquinas.conf.example` e `EF_MAQUINA`. O `maquinas.conf` real não é versionado.
- Instaladores acrescentam `Planejamento/`, `planejamento/` e `conhecimento/` ao `.gitignore`, sem duplicar.
- Memória local (`tools/memoria.sh`, `tools/memoria.ps1`, `memory-template/`). Versionamento em Git previsto para a 3.2. Sem busca semântica. Piloto SISMAN só no texto.
- Lint do `mem` bloqueia CPF, e-mail, telefone, dado bancário e segredo, sem exceção. Username e CPF de 11 dígitos com dígito inválido passam. Dado de cliente, no máximo o username.
- `pack-version.txt` = 3.1.0. `compat/releases/3.1.0.txt`.

## 3.0.0 — 2026-10-23

- Só Grok Build: saem Codex, Claude, `CLAUDE.md`, `.codex/`, `.claude/`, `execute-codex-work-order`, o prompt 09, os scripts `install`/`update-engineering-flow` e a skill `update-engineering-flow`.
- Os 10 agentes passam a ter origem em `repo-template/.grok/agents/`.
- Sem compatibilidade com 2.1.1 e 1.7.0, e sem migração automática; a linha 2.x permanece na tag `v2.1.1`.
- Gate 2: commit e push exigem o ok explícito do Matheus; o Grok Build comita; o Jow dá push (ou o Matheus, se o Jow estiver indisponível); nunca na main/master, nunca force push.
- LOCK em `.agent-pack/.runtime/task.lock` (não versionado): criado pelo bot do repo, expira no commit, trava esquecida liberada pelo bot da demanda.
- Índice de skills gerado por `tools/generate-skills-index.sh` (e `.ps1`) em `SKILLS-INDEX.md`.
- `tools/task-lock.sh` (e `.ps1`): `acquire`/`release`/`status` do LOCK, com testes `scripts/test-task-lock.{sh,ps1}`.
- Removido `scripts/test-update-agent-pack.ps1`; `scripts/test-update-agent-pack.sh` permanece.
- PowerShell 7 (`#Requires -Version 7`) em todos os `.ps1`; `.gitattributes` cobre `*.sh`, `*.ps1`, `*.md` e `*.txt`.
- `compat/releases/2.1.1.txt` e `3.0.0.txt`; `pack-version.txt` = 3.0.0.
- Hierarquia e briefing opcionais só em `GROK_BOT_*.md`, fora do pack de projeto.

## 2.1.1 — 2026-10-16

- Documentação: suporte oficial ao modo pack local (pack no projeto sem versionamento), com campo `Versionamento do pack` em "Convenções do projeto" do AGENTS.md e seção "Modo pack local" em INSTRUCOES_DETALHADAS.md.
- `compat/releases/2.1.0.txt` com a base 2.1.0 para atualização segura.
- Sem mudança de scripts.

## 2.1.0 — 2026-10-15

- workflow.md: modos Trivial/Completo com regra de corte, orçamento por fase, descoberta proporcional com leitura justificada, leitura obrigatória de anti-padrões e Gate de 100% (não é cobertura de código).
- Novos docs gerenciados: anti-patterns.md, planning-workspace.md e sql-release-package.md (opcionais por projeto via "Convenções do projeto" em AGENTS.md).
- db-change-sqlserver: passo 8 opcional de consolidação no pacote SQL de release.
- `compat/releases/2.0.0.txt` com a base 2.0.0 para atualização segura.
- GROK_BOT_WORKFLOW.md (fora do pack): diretriz do bot secretário de engenharia.
- A adoção do workspace de planejamento pode ser gradual: demanda já em andamento termina na estrutura anterior.

## 2.0.0 — 2026-10-11

- Nome público Engineering Flow e repositório engineering-flow; instalação inicial e migração de versões anteriores.
- Núcleo geral de descoberta, projeto novo, bug, feature, refatoração, review e completion; aprovação humana e testes somente no envelope aprovado.
- Evidência por critério/cenário/esperado/observado/artefato/status, limites explícitos e memória durável separada.
- Expertise .NET/Framework/Web Forms/SQL Server preservada, web/ASP clássico ampliado, mobile nativo/híbrido/multiplataforma opcional e procedimentos desktop/DevOps.
- Codex/Grok Build independentes, Claude compatível, handoff e Grok Bot opcionais; sem integração direta presumida ou nova dependência.
- Aliases install/update-engineering-flow, IDs/ownership e estado antigos preservados, catálogo da base 1.7.0 e regressões de migração/seleção.
- Testes de scripts/fixtures e checks estáticos não comprovam execução de apps nem cumprimento universal por modelos.

## 1.7.0 — compatibilidade de pré-release

Independência Codex/Grok, seleções de integração preservadas, agent-work-order compartilhado e salvaguardas de instalação/update. Seleções, customizações e IDs estáveis são preservados nas atualizações.


## 1.6.0

- Freezes 1.5.0 fingerprints in `compat/releases/1.5.0.txt` so existing installs can update without a guessed baseline.
- Inspects the workspace before install: one Git root, a parent folder of independent repositories, or an explicit non-Git folder.
- Auto-selects `web` and `sqlserver` from repository evidence when `-Profile` / `--profile` is omitted; `quality` stays opt-in.
- Writes `.agent-pack/state.txt` on new installs.
- Removes the Flutter profile. Unchanged 1.5.0 Flutter artifacts that match the catalog are retired on update; customized files require an explicit resolution.
- Adds `web-dotnet` for Razor, MVC, Blazor, Web Forms, and .NET 3.1+ / Framework UI.
- Tightens `sqlserver-structure-review` as read-only system understanding and `db-change-sqlserver` so destructive SQL waits for an approved plan.
- Aligns `agents-md-generator` with the short pack `AGENTS.md` template and stops the inspector from suggesting a non-existent `legacy-framework` profile.
- Ships installed prompts, agents, and pack documentation in English.

## 1.5.0

- Incorpora `agents-md-generator` e `dotnet-xunit-tests` ao núcleo compartilhado.
- Adiciona `sqlserver-structure-review` ao perfil `sqlserver`, com checklists, scripts de inventário e preflight de acesso, além de consulta de metadados somente leitura.
- Adiciona o perfil opt-in `flutter` com a skill `flutter-tests`, sem instalá-la em repositórios .NET por padrão.
- Espelha as novas skills e seus recursos para Claude Code e Grok Build quando as integrações correspondentes são selecionadas.
- Atualiza instaladores, manifestos, metadados e smoke tests para reconhecer o perfil `flutter`.

## 1.4.0

- Define o usuário como única autoridade decisória na colaboração Codex + Grok Build.
- Introduz Gate 1 para aprovação explícita do plano antes de trabalho não trivial e Gate 2 para validação manual antes de ações de integração ou produção.
- Define o plano aprovado como envelope de execução e obriga escalação de desvios materiais com evidências, alternativas, trade-offs e recomendação.
- Padroniza o Work Order com escopo humano real, áreas de leitura/modificação, contratos preservados, limites decisórios e condições de escalação.
- Padroniza o retorno do Grok em `COMPLETED`, `COMPLETED_WITH_CONCERNS`, `BLOCKED_BY_DECISION` ou `UNABLE_TO_VALIDATE`.
- Adiciona `MANUAL_DE_USO.md` com instalação nova, verificação/atualização de pack antigo e operação correta do fluxo completo.
- Preserva a versão 1.3.0 no catálogo de compatibilidade para atualização reconciliada de instalações existentes.
- Amplia os validadores para proteger semanticamente os gates, a autoridade humana e os contratos Codex→Grok.

## 1.3.0

- Adiciona suporte opt-in ao Grok Build por `-IncludeGrokBuild` e `--include-grok-build`, mantendo Codex obrigatório e Claude Code independente.
- Define Codex como plano de controle para raciocínio, design, review e julgamento, e Grok Build como plano de execução para paralelismo, velocidade e isolamento por worktree.
- Instala configuração mínima em `.grok/config.toml`, agentes em `.grok/agents` e skills espelhadas em `.grok/skills`, sem criar `GROK.md`.
- Adiciona as skills complementares `delegate-to-grok-build` e `execute-codex-work-order`, com proibição de commit, push, deploy, migration e operações destrutivas.
- Adiciona o prompt `09-migrate-claude-to-codex-grok.md` para preservar orientação útil, remover artefatos Claude comprovadamente gerenciados e preparar o repositório.
- Adiciona `Integration codex,grok` e `--integration codex,grok` ao reconciliador para tornar a seleção durável e impedir a reinstalação futura do Claude.
- Mantém worktrees, sessões e estado operacional do Grok fora do repositório; somente regras, configuração, agentes e skills do projeto são versionados.
- Estende validadores, smoke tests e fontes oficiais para cobrir paridade de agentes/skills, perfis opcionais e política de segurança do Grok.

## 1.2.0

- Adiciona atualização reconciliada para repositórios que já possuem o Agent Pack, com plano somente leitura, estado local e aplicação bloqueada por conflitos.
- Introduz IDs estáveis e políticas `managed`, `merge` e `seed` em `pack-artifacts.txt`, além do catálogo de compatibilidade da versão 1.1.0.
- Preserva customizações do repositório e exige decisões explícitas por artefato para aceitar o pack, aceitar uma mesclagem manual ou manter a versão local.
- Adiciona a skill compartilhada `update-agent-pack` e o prompt operacional correspondente para Codex e Claude Code.
- Adiciona a skill `check-text-encoding`, com verificadores PowerShell e Bash para UTF-8 inválido, caractere de substituição e assinaturas prováveis de mojibake.
- Integra a verificação de texto às regras persistentes e à validação do próprio pack.
- Define disciplina de contexto e tokens: buscar antes de ler, carregar somente evidência relevante, evitar releituras e delegação redundante, sem reduzir segurança ou validação.

## 1.1.0

- Adiciona suporte opt-in ao Claude Code por `-IncludeClaude` e `--include-claude`, mantendo o Codex como integração padrão.
- Instala o bridge `CLAUDE.md`, agentes em `.claude/agents` e skills espelhadas em `.claude/skills` somente quando solicitado.
- Estende o manifesto com destino opcional para reutilizar uma origem canônica em caminhos específicos de cada ferramenta.
- Documenta a equivalência entre `$skill` no Codex e `/skill` no Claude Code, além do mapeamento de agentes de `snake_case` para `kebab-case`.
- Mantém `InstallGlobal` e `--install-global` exclusivos da orientação global do Codex.

## 1.0.0

- Generaliza o pack para repositórios .NET modernos e legados.
- Adiciona instalação por componentes, descoberta determinística e validações locais.
- Separa perfis opcionais de web, SQL Server e qualidade.
