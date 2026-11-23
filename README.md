# SpecGuard 6 (Engineering Flow 6.0)

> **Governança determinística de engenharia assistida por IA: agnóstico de ferramenta, 99,9% desacoplado do projeto, com cache estruturado de contexto, arquitetura verificável e entrega por card.**

Versão atual: **`6.1.2`** · [Releases no GitHub](https://github.com/OliveiraDotnet/engineering-flow/releases) · [Índice de Skills](SKILLS-INDEX.md) · [Manual de Uso](MANUAL_DE_USO.md) · [Guia Detalhado](INSTRUCOES_DETALHADAS.md) · [Changelog](CHANGELOG.md)

---

## O que é o SpecGuard 6 (Engineering Flow 6.0)

O **SpecGuard 6** (evolução do **Engineering Flow**) é um framework operacional para conduzir desenvolvimento de software de ponta a ponta com agentes de IA — tanto em **repositórios existentes (brownfield)** quanto em **projetos do zero (greenfield)** — unindo **Gates humanos**, **travas determinísticas executáveis**, **continuidade de contexto sem amnésia** e **arquitetura verificável**.

### Principais pilares da geração 6.0

- **Desacoplamento 99,9% & Instalação Limpa (100% Agnóstico):** **somente `AGENTS.md` permanece versionado** no Git do projeto alvo; todas as skills e agentes ficam exclusivamente em `.agents/` (sem espelhos de fornecedores como `.grok/` ou `openai.yaml`), e todos os arquivos operacionais/runtime (`.agent-pack/.runtime/session-state.json`, `repo-map.txt`, `NEXT_PROMPT.md`, `metrics.jsonl`, `docs/engineering-flow/`, `docs/ai/`, `.agents/`) ficam 100% no `.gitignore`. Quando `AGENTS.md` já existe no repositório, ele **é sempre consolidado via blocos gerenciados (`ef:managed`), nunca apagado ou recriado do zero**.
- **Porta de Entrada Única & Delegação Híbrida:** no primeiro prompt sem papel explícito, a IA assume automaticamente como **`Engenheiro-Chefe`**, lê o repositório em modo somente leitura, conduz até 6 perguntas objetivas (cobrindo Card `AB-<ID>`, pedido informal via Teams/e-mail ou iniciativa própria sem Card) e delega ao `Tech Lead` via `.agent-pack/.runtime/NEXT_PROMPT.md` (perguntando se deseja usar subagente nativo com retorno ao topo ou envio manual).
- **Cache de Contexto & Continuidade entre Conversas:**
  - **`.agent-pack/.runtime/session-state.json`** (`.agents/tools/session-state.{ps1,sh}`): checkpoint JSON estrito com critérios, fase, **`deadEnds`** (abordagens já falhadas para nunca repetir erros entre sessões) e limpeza automática dos arquivos transitórios no `close`.
  - **`.agent-pack/.runtime/repo-map.txt`** (`inspect-repo.{ps1,sh} -GenerateRepoMap`): cache estrutural compacto de símbolos indexado por commit (`cache-hit` instantâneo em `HEAD` limpo, sem vazar segredos/corpos).
  - **Contexto Estático-Primeiro & Compaction de Logs:** prefixo imutável para maximizar *Prompt Caching* e resumos de erro de 20–40 linhas nos handoffs.
- **Arquitetura Greenfield vs. Brownfield & Decisões Escopadas:** [architecture-playbooks.md](repo-template/docs/engineering-flow/architecture-playbooks.md) (**Monólito Modular + Vertical Slices / Schema-First** em projetos novos; **Quarentena de Legado + Characterization Tests + Strangler Fig** em projetos existentes) + decisões `Dxx` com `applies_to` (`docs/ai/decisions-and-pendencies.md`).
- **Governança Determinística, Risk Tiering e Telemetria Enxuta:**
  - **Risk Tiering (`Tier 0 Trivial`, `Tier 1 Padrão`, `Tier 2 Crítico`):** elimina *Spec Sprawl* em tarefas rotineiras e concentra rigor onde há risco real.
  - **`.agents/tools/verify-envelope.{ps1,sh}`:** trava determinística pré-Gate 2 instalada no repositório destino que valida branches protegidas (`main`/`master`, `EF_PROTECTED_BRANCHES` e `AGENTS.md`), blast radius 100% dentro de `ef:paths`, zero arquivo operacional no staging, `test-status.json` aprovado para o card ativo e `secretScan == clean`.
  - **Fitness Functions Arquiteturais:** receita integrada ao `harness-cycle` (`NetArchTest`, `dependency-cruiser`, `ArchUnit`) para barrar erosão arquitetural automaticamente antes do Gate 2.
  - **`.agent-pack/.runtime/metrics.jsonl`:** telemetria local append-only (1 linha JSON/card) para medir gargalos reais sem servidor externo.
- **100% Agnóstico de Ferramenta:** funciona em modo **Standalone** (1 harness) ou **Multi-Agente** (`sessao-por-papel` / subagentes), com especialização para **.NET moderno e .NET Framework**, **Web Forms**, **ASP clássico**, **HTML/CSS/JavaScript/TypeScript**, **SQL Server** e **Mobile**.

---

## Hierarquia de Papéis, Porta de Entrada Única e Delegação Híbrida

> **Primeiro Prompt (Porta de Entrada Única):** após instalar o Engineering Flow 5.1 (em repositório existente ou projeto do zero), qualquer conversa iniciada **sem papel explícito** assume automaticamente o papel de **`Engenheiro-Chefe`**. Ele inspeciona o repositório em modo somente leitura, conduz até 6 perguntas objetivas (cobrindo demanda com Card `AB-<ID>`, pedido informal via Teams/e-mail ou iniciativa própria sem Card) e delega ao **`Tech Lead`** via `.agent-pack/.runtime/NEXT_PROMPT.md` — perguntando ao usuário se prefere delegar para um **subagente nativo** (com retorno obrigatório ao topo da cadeia) ou enviar o bloco `PROMPT PARA:` manualmente. Veja [roles-and-handoffs.md](repo-template/docs/engineering-flow/roles-and-handoffs.md).

```mermaid
flowchart TD
    H["Aprovador Humano (Autoridade Única — Gate 1, Gate 2 e Produção)"]
    P["Planejador / Engenheiro-Chefe (Porta de Entrada Única — Triagem com/sem Card)"]
    R["Revisor / Entrega (Tech Lead de Repositório)"]
    I["Implementor (Harness de Código — Edição e Commit Pós-Gate 2)"]
    T["Tester (Harness de QA — R0-RED, R0-GREEN e Evidências)"]

    H -->|"1º Prompt (sem papel explícito)"| P
    P -->|"NEXT_PROMPT.md (Prompt Relay ou Subagente com retorno)"| R
    R -->|"Plano Técnico (Gate 1)"| H
    H -->|"Aprova escopo/envelope (Gate 1)"| R
    R -->|"Branch do card + task.lock + TASK_SPEC.md"| I
    I <-->|"Loop fechado harness-cycle (máx. 3 tentativas)"| T
    T -->|"EVIDENCIA.md + test-status.json (retorna ao topo)"| R
    R -->|"Apresenta diff + evidências"| H
    H -->|"OK explícito (Gate 2)"| R
    R -->|"Delega --commit-gate2"| I
```

| Papel | Responsabilidade Principal | Pode Commitar? | Pode Dar Push? |
| :--- | :--- | :---: | :---: |
| **Aprovador Humano** | Única autoridade decisória (`sole decision authority`); aprova Gate 1, Gate 2 e subida para produção. | Manual se necessário | Manual se necessário |
| **Planejador / Engenheiro-Chefe** | Garante triagem por card (`AB-<ID>`), fecha plano técnico no Gate 1 e delega aos repositórios. | Não | Não |
| **Revisor / Entrega (Tech Lead)** | Mantém `Planejamento/DEMANDAS.md`, cria branch do card e `task.lock`, revisa diff/evidências, gerencia PR, homologação, promoção isolada para `main`/`master`, Tag `vX.Y.Z`, SQL consolidado e OS de Infra. | Não | Sim |
| **Implementor (Harness)** | Edita o código-fonte na branch do card, corrige falhas apontadas pelo `Tester` e executa `git commit` exclusivamente após Gate 2 (`--commit-gate2`, expirando o `task.lock`). | **Sim (pós-Gate 2)** | Não |
| **Tester (Harness)** | Nunca altera código de negócio; prova `R0-RED` antes do fix em bugs, executa `R0-GREEN` e suíte `FULL`, gravando `.agent-pack/evidencias/<CardId>/EVIDENCIA.md` e `.agent-pack/.runtime/test-status.json`. | Não | Não |
| **Publicador / Validador (Opcional)** | Audita branches/releases ou executa publicação quando acionado pelo aprovador humano. | Não | Opcional |

> No **Modo Harness Único (Standalone)**, o mesmo harness segue exatamente essa ordem de responsabilidades (planejar e pedir Gate 1 → provar `R0-RED` → implementar → provar `R0-GREEN` e evidências → pedir Gate 2 antes de commitar). Veja [workflow.md](repo-template/docs/engineering-flow/workflow.md) e [ASSISTENTE_WORKFLOW.md](ASSISTENTE_WORKFLOW.md).

---

## Ciclo de Trabalho e Gates

1. **Triagem por Card (`AB-<ID>`):** nenhuma tarefa começa sem card identificado. Em modo multi-repositório, é registrada em `Planejamento/DEMANDAS.md`.
2. **Descoberta & Saúde de Testes no Legado:** entende o contexto antes de propor solução. Em código legado altamente acoplado, **não** força refatoração arriscada para criar testes unitários artificiais; sobe a validação para **Playwright E2E completo**.
3. **Gate 1 (Plano Técnico):** apresenta plano, envelope de alteração, riscos e, em bugs, o teste de regressão obrigatório **`R0`** (somente o aprovador humano pode dispensar o `R0`, com motivo registrado).
4. **Branch do Card e LOCK:** branch criada a partir de `main`/`master` (`feat/AB-<ID>-<slug>` ou `fix/AB-<ID>-<slug>`), protegida por `.agent-pack/.runtime/task.lock`.
5. **Ciclo `harness-cycle` (`Implementor` ↔ `Tester`):**
   - Em bugs, `Tester` comprova `R0-RED` (falha antes da correção).
   - `Implementor` aplica a correção na working tree (sem commitar).
   - `Tester` comprova `R0-GREEN` e executa apenas os testes aprovados (`FULL`), gerando `EVIDENCIA.md` e `test-status.json` (disjuntor automático de no máximo 3 tentativas).
6. **Gate 2 (Evidência e Commit):** testes não solicitados não rodam automaticamente; falhas impedem entrega como validada. Após ver as evidências reais e dar o **ok explícito**, apenas o `Implementor` executa `git commit` (`--commit-gate2`), expirando o `task.lock`. Nunca comita na `main`/`master` e nunca executa force push.
7. **Homologação e Produção Isolada:** merge na homologação mantendo a branch do card viva; após validação em homologação e aprovação humana, promoção isolada apenas da branch aprovada na `main`/`master`, criação da Tag `vX.Y.Z`, pacote SQL consolidado da Tag e geração de `OS-INFRA-vX.Y.Z.md` ([DIRETRIZ-entrega-pelo-bot-de-projeto.md](diretrizes/DIRETRIZ-entrega-pelo-bot-de-projeto.md)).

Modos de execução: **Trivial** (1 critério observável, sem risco a dados/migração) e **Completo** (Gate 1 e Gate 2 obrigatórios); na dúvida, **Completo**.

---

## Instalação Limpa 6.0 (99,9% Desacoplado — Apenas `AGENTS.md` Versionado)

No **SpecGuard 6 (`6.0.0`)**, instalar o fluxo em um repositório de equipe é limpo por padrão:

- **Não gera arquivos de versão/estado (`.agent-pack/state.txt`)** no repositório destino e consolida arquivos equivalentes sem resquícios de instalações anteriores.
- **Atualiza o `.gitignore` automaticamente** para ignorar todas as pastas e arquivos operacionais (`.agents/`, `.grok/`, `.agent-pack/`, `.ai-memory.toml`, `docs/engineering-flow/`, `docs/ai/`, `prompts/`, `Planejamento/`, `planejamento/`, `.engineering-flow-evidence/`, `*.agent-pack.new`, `*.agent-pack.backup-*`).
- **Somente `AGENTS.md` permanece versionável no Git** — e quando já existir, **é sempre consolidado via blocos gerenciados (`ef:managed`), nunca apagado ou recriado do zero**.

### Baixar ou Clonar

Baixe o pacote da [Release `v6.1.2`](https://github.com/OliveiraDotnet/engineering-flow/releases/tag/v6.1.2) ou clone o repositório:

```bash
git clone --branch v6.1.2 https://github.com/OliveiraDotnet/engineering-flow.git
```

### Instalar em um Repositório Alvo

Execute a partir da raiz do `engineering-flow`, apontando para o repositório Git destino (ou para uma pasta contendo vários repositórios):

```bash
# Linux / macOS (Bash)
bash ./scripts/install-agent-pack.sh /caminho/do/repositorio --discover-only
bash ./scripts/install-agent-pack.sh /caminho/do/repositorio --profile web,sqlserver --dry-run
bash ./scripts/install-agent-pack.sh /caminho/do/repositorio --profile web,sqlserver
```

```powershell
# Windows (PowerShell 7+)
.\scripts\install-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -DiscoverOnly
.\scripts\install-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Profile web,sqlserver -DryRun
.\scripts\install-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Profile web,sqlserver
```

> Para pastas deliberadamente sem Git, use `--allow-non-git` / `-AllowNonGit`. Sem `--force`, divergências geram sidecars `*.agent-pack.new` para revisão sem sobrescrever customizações. Use `--force` / `-Force` para **merge por blocos gerenciados** (`ef:managed`) no `AGENTS.md` e atualização dos arquivos `managed` (com backup `*.agent-pack.backup-*`); arquivos `seed` (`docs/ai/*`) **nunca são sobrescritos** mesmo com `--force` (mantêm o conteúdo local e geram sidecar `*.agent-pack.new` se o template mudou). Se o `AGENTS.md` atual não tiver marcadores `ef:managed`, o instalador preserva o arquivo e o sidecar e sai com código `7` para migração única.

### Atualização Reconciliada (Repositórios com `state.txt` da linha 3.x / 4.x)

Se um repositório legado ainda mantiver `.agent-pack/state.txt`, você pode reconciliar sem perder customizações locais:

```bash
bash ./scripts/update-agent-pack.sh /caminho/do/repositorio --check
bash ./scripts/update-agent-pack.sh /caminho/do/repositorio --apply
```

```powershell
.\scripts\update-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Check
.\scripts\update-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Apply -Confirm:$false
```

`pack-manifest.txt`, `pack-artifacts.txt` e `pack-version.txt` definem artefatos e propriedade (`managed`, `merge`, `seed`). Catálogos de compatibilidade permanecem em `compat/releases/` (`1.1.0` a `6.1.2`).

---

## Perfis e Uso Diário

| Perfil | Quando Ativar | Conteúdo |
| :--- | :--- | :--- |
| `core` | Sempre | Descoberta (`$bootstrap-repo`), projeto novo, `$bugfix`, `$feature-slice`, `$refactor`, `$review-change`, `$complete-task`, `$harness-cycle` e contrato comum. |
| `web` | Explícito ou evidência de UI | Navegação, ASP clássico/SPA, Playwright E2E e especialização .NET Web. |
| `sqlserver` | Explícito ou SQL Server | Análise read-only, mudanças idempotentes por card (`PendentesProducao/`) e pacote de release por Tag. |
| `mobile` | Explícito ou app mobile | Planejamento e validação nativa/híbrida/multiplataforma (não instala SDK/emulador). |
| `quality` | Explícito (nunca automático) | Revisões focadas de segurança, desempenho e entrega. |

### Uso Rápido das Skills

1. Consulte o [índice de skills](SKILLS-INDEX.md) e carregue apenas a skill necessária para a demanda.
2. Em repositórios sem contexto mapeado, comece com `$bootstrap-repo` (`prompts/00-bootstrap-repo.md`).
3. Use `$bugfix`, `$feature-slice`, `$refactor`, `$review-change` ou `$new-project` conforme o card.
4. Para o loop fechado automatizado entre implementação e testes no harness, use **`$harness-cycle`** (`run-implementor`, `run-tester`, `supervise-harness`).
5. Encerre a entrega com `$complete-task`.

---

## Memória Persistente, Isolamento e Pré-Requisitos

- **Memória e Handoffs:** combina documentação local em `docs/ai/` com suporte opcional ao **`ai-memory` (`akitaonrails/ai-memory`)** via `.ai-memory.toml` / MCP quando configurado no harness. Como bots externos não compartilham necessariamente a memória MCP do harness, os handoffs inter-agentes ficam sempre explícitos em arquivos (`TASK_SPEC.md`, `EVIDENCIA.md`, `test-status.json`, `Planejamento/DEMANDAS.md`).
- **Requisitos locais para os scripts do pack:**
  - **Linux / macOS:** `bash` e `git` (os scripts `.sh` rodam localmente sem runtime extra).
  - **Windows:** **PowerShell 7+** (`pwsh`, `#Requires -Version 7`) e `git`.
  - O pack **não instala** SDKs, browsers ou dependências da sua aplicação (`xUnit`, `Playwright`, `bUnit`, `Testcontainers`).

### Documentação Relacionada

- [Contrato Canônico de Workflow](repo-template/docs/engineering-flow/workflow.md)
- [Playbooks de Arquitetura (Greenfield vs. Brownfield)](repo-template/docs/engineering-flow/architecture-playbooks.md)
- [Papéis, Porta de Entrada Única e Delegação Híbrida](repo-template/docs/engineering-flow/roles-and-handoffs.md)
- [Anti-Padrões (leitura prévia obrigatória)](repo-template/docs/engineering-flow/anti-patterns.md)
- [Capacidades e Limites de Validação](repo-template/docs/engineering-flow/capabilities.md)
- [Workspace de Planejamento (`Planejamento/DEMANDAS.md`)](repo-template/docs/engineering-flow/planning-workspace.md)
- [Pacote SQL de Release por Tag](repo-template/docs/engineering-flow/sql-release-package.md)
- [Hierarquia Multi-Bot (Operação Opcional)](ASSISTENTE_WORKFLOW.md) · [Assistente Opcional](ASSISTENTE_OPCIONAL.md)
- [Diretriz de Entrega pelo Revisor/Bot de Projeto](diretrizes/DIRETRIZ-entrega-pelo-bot-de-projeto.md)
- [Manual de Uso](MANUAL_DE_USO.md) · [Instruções Detalhadas](INSTRUCOES_DETALHADAS.md)
