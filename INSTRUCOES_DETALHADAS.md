# Adoção — SpecGuard 6 (Engineering Flow 6.0)

Instalação e exemplos: [README](README.md) e [manual](MANUAL_DE_USO.md). Versão atual `6.1.2`. O **SpecGuard 6** evolui a linha `5.x` mantendo o fluxo 100% agnóstico de ferramenta (apenas `.agents/`, zero espelhos de fornecedores) e 99,9% desacoplado do projeto (**apenas `AGENTS.md` versionado, sempre consolidado via `ef:managed` e nunca recriado do zero**), instalando as ferramentas operacionais em `.agents/tools/` (checkpoint estruturado de sessão com limpeza de runtime no `close` via `.agents/tools/session-state.{ps1,sh}`, trava `.agents/tools/task-lock.{ps1,sh}` e guarda determinística pré-Gate 2 `.agents/tools/verify-envelope.{ps1,sh}` com leitura de branches protegidas do `AGENTS.md`), cache de símbolos por commit (`inspect-repo -GenerateRepoMap`), Playbooks de Arquitetura Greenfield/Brownfield, decisões `Dxx` escopadas (`applies_to`), Risk Tiering (`Tier 0/1/2`), telemetria local (`metrics.jsonl`) e Fitness Functions no `harness-cycle`. Na raiz do repositório `engineering-flow`, `tools/{verify-envelope,session-state,task-lock}.{ps1,sh}` permanecem como wrappers finos de compatibilidade. Este pack não instala runtimes nem configura contas externas.

## Instalação Limpa 6.x (Apenas `AGENTS.md` Versionado no Repositório Alvo)

Inspecione com DiscoverOnly/--discover-only, confira Git roots e perfis, faça DryRun/--dry-run e instale dentro do escopo autorizado. Core sempre, web/sqlserver/mobile sugeridos por evidência, quality apenas explícito. Perfil explícito evita autodetecção. Vários repos recebem instalação por Git root; pasta não Git requer AllowNonGit/--allow-non-git. Repo Git vazio recebe instruções e segue new-project para planejar antes de criar aplicação.

Na **Instalação Limpa do SpecGuard 6** em um repositório (executada diretamente pelo desenvolvedor ou pelo agente Revisor/Entrega do repositório):
1. Executa-se o instalador apontando para o repositório (ex: `bash ./scripts/install-agent-pack.sh /caminho/repo --profile web,sqlserver`). Sem `--force`, arquivos divergentes preexistentes geram sidecars `*.agent-pack.new` para revisão sem sobrescrever customizações locais; o instalador instala as skills e agentes em `.agents/` (sem espelhos de fornecedor), prompts e contratos do SpecGuard 6 e **não cria arquivo de versão/estado (`.agent-pack/state.txt`)**.
2. O script `protect-engineering-flow-files.{sh,ps1}` é executado automaticamente pelo instalador e adiciona ao `.gitignore` todas as pastas e arquivos operacionais (`.agents/`, `.grok/`, `.agent-pack/`, `.ai-memory.toml`, `docs/engineering-flow/`, `docs/ai/`, `prompts/`, `Planejamento/`, `planejamento/`, `.engineering-flow-evidence/`, `*.agent-pack.new`, `*.agent-pack.backup-*`), além de corrigir automaticamente no preflight o caso legado em que `AGENTS.md` esteja ignorado (`!AGENTS.md`).
3. Dessa forma, **apenas o arquivo `AGENTS.md` na raiz do repositório permanece versionável** — e quando já existir, **é sempre consolidado via blocos `ef:managed`, nunca recriado do zero**.
4. Opcionalmente, configura-se o arquivo `.ai-memory.toml` local (`workspace = "<slug-do-projeto>"` e `project = "<slug-do-repo>"`), preenchem-se as Convenções do Projeto em `AGENTS.md` e inicializam-se `Planejamento/DEMANDAS.md` e `Planejamento/scripts/{PendentesProducao,Releases,Aplicados}`.
5. **Commit da instalação/upgrade do SpecGuard:** para versionar apenas `AGENTS.md` e/ou `.gitignore` resultantes da adoção ou atualização do pack (sem tocar código de aplicação), abra uma branch de manutenção (`chore/specguard-vX.Y.Z` a partir da branch principal do repositório) e solicite aprovação humana no Gate 2 antes de commitar/subir — não exige Card `AB-<ID>` (salvo regra interna do projeto) e nunca commita direto na branch de produção. Se você trocou de branch após rodar o instalador, confira na branch ativa com `git check-ignore` que `.ai-memory.toml` e as pastas operacionais continuam ignorados.

## Atualização por Reconciliação (`update-agent-pack`) ou Reinstalação Limpa

- **Reinstalação Limpa (Recomendado no SpecGuard 6, sem `--force`):** Como as pastas `.agents/`, `docs/engineering-flow/` e `prompts/` são locais (ignoradas no Git) e `AGENTS.md` guarda as regras do projeto, para atualizar basta rodar `install-agent-pack` **sem** `--force`: o instalador preserva `AGENTS.md` e `docs/ai/` locais, gerando sidecars `*.agent-pack.new` para revisão quando houver diferença.
- **Merge por blocos no `AGENTS.md` com `--force` / `-Force`:** Use `--force` para atualizar automaticamente os blocos gerenciados (`<!-- ef:managed:begin:<id> -->` … `<!-- ef:managed:end:<id> -->`) do `AGENTS.md` via merge por blocos (preservando todo conteúdo do projeto fora dos blocos e gerando backup `AGENTS.md.agent-pack.backup-*`) e atualizar arquivos `managed` (com backup). Arquivos `seed` (`docs/ai/*`) **nunca são sobrescritos** mesmo com `--force` — o conteúdo local é preservado e divergências de template geram apenas sidecar `*.agent-pack.new`. Se o `AGENTS.md` atual não tiver marcadores `ef:managed` (ou tiver marcadores malformados), o instalador mantém o `AGENTS.md` intacto, preserva `AGENTS.md.agent-pack.new` para revisão e sai com **código 7** (`AGENTS_MD_MERGE_SKIPPED`).
  - **Migração única para repositórios antigos (sem marcadores):** o Tech Lead do repositório envolve as seções do pack no `AGENTS.md` com os marcadores `ef:managed` usando `AGENTS.md.agent-pack.new` como referência e reinstala com `--force`.
  - **Caminho para repositório sem `.agent-pack/state.txt`:** (1) reinstalar sem `--force`; (2) revisar e mesclar cada `*.agent-pack.new`, começando por `AGENTS.md` (ou usar o merge por blocos via `--force`); (3) apagar o sidecar; (4) `update-agent-pack` só se aplica quando houver `state.txt` ou um arquivo rastreado pelo catálogo.
- **Reconciliação (`update-agent-pack`):** Mantida para compatibilidade com instalações anteriores que possuam `.agent-pack/state.txt` ou arquivos rastreados pelos catálogos históricos (`compat/releases/1.1.0.txt` a `5.0.0.txt`).

| Propriedade | Comportamento |
|---|---|
| managed | Skills, prompts e docs do método; atualizados pelo pack |
| merge | `AGENTS.md` e configuração local preservados com proposta de diferenças para revisão/merge |
| seed | `docs/ai/*` pertencem ao repositório local; não são sobrescritos silenciosamente por template |

## Camada de Harness (`Implementor` + `Tester` + `harness-cycle`)

A versão 5.1 formaliza os dois papéis da base da pirâmide que operam diretamente sobre o código-fonte:
- **`Implementor` (`prompts/12-implementor-harness.md` e `run-implementor.{sh,ps1}`):** recebe o `TASK_SPEC.md` (e o relatório de falha do Tester quando em retentativa), não cria nem valida o `.agent-pack/.runtime/task.lock` (que deve ser adquirido previamente via `.agents/tools/task-lock.{sh,ps1} acquire` por quem abre a tarefa), altera o código na branch do card (`feat/AB-<ID>-<slug>` ou `fix/AB-<ID>-<slug>`) sem fazer commit durante o loop, e executa o `git commit` exclusivamente quando invocado com `--commit-gate2` após o ok humano no Gate 2 (removendo o `task.lock` após o commit bem-sucedido).
- **`Tester` (`prompts/13-tester-harness.md` e `run-tester.{sh,ps1}`):** nunca altera código de negócio; valida `R0-RED` (falha antes do fix), `R0-GREEN` (passa após o fix) e `FULL`, gravando `.agent-pack/evidencias/<CardId>/EVIDENCIA.md` e `.agent-pack/.runtime/test-status.json`.
- **Supervisor (`supervise-harness.{sh,ps1}`):** executa o loop fechado pré-Gate 2 entre `run-implementor` e `run-tester` com limite máximo de 3 tentativas.
- **Comunicação CLI Sólida e Não-Bloqueante:** Quando um bot ou supervisor invoca um harness via CLI em modo headless, o comando deve incluir as flags não-interativas do respectivo CLI para evitar bloqueios aguardando confirmação humana no terminal.

## Limites verificáveis

Detectores levantam manifests, projetos, CI/scripts e pistas de runtime/provider sem imprimir conexão, script body ou segredo. PowerShell retorna JSON/markdown com metadados; Bash retorna markdown e caminhos para inspeção posterior. Não são parsers universais nem executam app/teste. Verifique versão e comando no repo real. SQL genérico não identifica SQL Server; use provider/T-SQL específico. AndroidManifest, alvos iOS em projeto Xcode, pubspec/MAUI e dependências mobile/híbridas são pistas que precisam confirmação; Kotlin/Swift isolados não selecionam mobile. Tecnologias não reconhecidas continuam investigáveis.

Testes do pack exercitam scripts, instalação limpa, ciclo de harness (`test-harness-cycle`), atualização/ownership/seleções, rollback e fixtures. Checks de contrato são estáticos, não prova de obediência de modelos. Browser real, banco, app desktop ou device mobile só são verificados quando executados e autorizados na tarefa. Zero testes, ambiente ausente, falha e evidência incompleta são estados distintos. [Capabilities](repo-template/docs/engineering-flow/capabilities.md) define evidência por área. Os testes PowerShell exigem PowerShell 7 ou mais novo; cada `.ps1` tem equivalente `.sh`.

## Higiene Git no destino

Instalação e atualização acrescentam somente padrões faltantes ao `.gitignore` existente, preservando conteúdo, encoding UTF-8, BOM e CRLF originais. DryRun/WhatIf e Check não escrevem.

Se o repositório tiver um `.gitignore` herdado (por exemplo da linha 3.0) que ignore `AGENTS.md`, o instalador verifica `git check-ignore` no preflight (antes de copiar qualquer arquivo, exceto com `--allow-non-git`) e executa `protect-engineering-flow-files` no modo `unignore-agents-md` (`-UnignoreAgentsMd` no PowerShell) para acrescentar `!AGENTS.md` ao fim do `.gitignore` sem apagar nem alterar regras existentes; se `AGENTS.md` permanecer ignorado após o append, aborta com exit `5`.

No padrão 5.1, `protect-engineering-flow-files.{sh,ps1}` garante que todas as pastas e artefatos operacionais do Engineering Flow fiquem ignorados no `.gitignore`:
```gitignore
*.agent-pack.new
*.agent-pack.backup-*
.agent-pack/
.agents/
.grok/
.ai-memory.toml
docs/engineering-flow/
docs/ai/
prompts/
.engineering-flow-evidence/
Planejamento/
planejamento/
```
Assim, **apenas `AGENTS.md` permanece visível e versionável no Git do projeto**. Se algum arquivo de versão antigo já estiver rastreado no índice Git de um repositório legado, remova-o do índice com `git rm --cached` revisado (mantendo o arquivo local se desejar).
