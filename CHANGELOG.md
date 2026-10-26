# Engineering Flow changelog

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
