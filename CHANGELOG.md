# Engineering Flow changelog

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
