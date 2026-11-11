# Adoção — Engineering Flow 5.0

Instalação e exemplos: [README](README.md) e [manual](MANUAL_DE_USO.md). Versão atual `5.0.0`. A linha 5.0 evolui a 4.x tornando o fluxo 100% agnóstico de ferramenta e de persona, introduzindo a camada de harness (`Implementor` + `Tester` + `harness-cycle`) e garantindo instalação limpa nos repositórios destino (**apenas `AGENTS.md` versionado**, sem geração de `.agent-pack/state.txt` na instalação). Este pack não instala runtimes nem configura contas externas.

## Instalação Limpa 5.0 (Apenas `AGENTS.md` Versionado no Repositório Alvo)

Inspecione com DiscoverOnly/--discover-only, confira Git roots e perfis, faça DryRun/--dry-run e instale dentro do escopo autorizado. Core sempre, web/sqlserver/mobile sugeridos por evidência, quality apenas explícito. Perfil explícito evita autodetecção. Vários repos recebem instalação por Git root; pasta não Git requer AllowNonGit/--allow-non-git. Repo Git vazio recebe instruções e segue new-project para planejar antes de criar aplicação.

Na **Instalação Limpa da v5.0** em um repositório (executada diretamente pelo desenvolvedor ou pelo agente Revisor/Entrega do repositório):
1. Executa-se o instalador apontando para o repositório (ex: `bash ./scripts/install-agent-pack.sh /caminho/repo --force --profile web,sqlserver`). O instalador cria backups seguros (`*.agent-pack.backup-*`) de arquivos preexistentes divergentes, instala todas as skills (`.agents/skills/` e espelho `.grok/skills/`), prompts e contratos da v5.0 e **não cria arquivo de versão/estado (`.agent-pack/state.txt`)**.
2. O script `protect-engineering-flow-files.{sh,ps1}` é executado automaticamente pelo instalador e adiciona ao `.gitignore` todas as pastas e arquivos operacionais do Engineering Flow (`.agents/`, `.grok/`, `.agent-pack/`, `docs/engineering-flow/`, `docs/ai/`, `prompts/`, `Planejamento/`, `planejamento/`, `.engineering-flow-evidence/`, `*.agent-pack.new`, `*.agent-pack.backup-*`).
3. Dessa forma, **apenas o arquivo `AGENTS.md` na raiz do repositório permanece versionável**. Quando outros desenvolvedores da equipe derem `git pull`, não receberão pastas de agentes, prompts ou arquivos de versão do método.
4. Opcionalmente, configura-se o arquivo `.ai-memory.toml` local (`workspace = "<slug-do-projeto>"` e `project = "<slug-do-repo>"`), preenchem-se as Convenções do Projeto em `AGENTS.md` e inicializam-se `Planejamento/DEMANDAS.md` e `Planejamento/scripts/{PendentesProducao,Releases,Aplicados}`.

## Atualização por Reconciliação (`update-agent-pack`) ou Reinstalação Limpa

- **Reinstalação Limpa (Recomendado no padrão 5.0):** Como no padrão 5.0 as pastas `.agents/`, `.grok/`, `docs/engineering-flow/` e `prompts/` são locais (ignoradas no Git) e `AGENTS.md` guarda as regras do projeto, atualizar o pack basta rodar `install-agent-pack` novamente (sem `--force`, o instalador preserva `AGENTS.md` e `docs/ai/` locais gerando `.agent-pack.new` se houver diferença; ou com `--force` gerando backup `*.agent-pack.backup-*`).
- **Reconciliação (`update-agent-pack`):** Mantida para compatibilidade com instalações anteriores que possuam `.agent-pack/state.txt` ou arquivos rastreados pelos catálogos históricos (`compat/releases/1.1.0.txt` a `5.0.0.txt`).

| Propriedade | Comportamento |
|---|---|
| managed | Skills, prompts e docs do método; atualizados pelo pack |
| merge | `AGENTS.md` e configuração local preservados com proposta de diferenças para revisão/merge |
| seed | `docs/ai/*` pertencem ao repositório local; não são sobrescritos silenciosamente por template |

## Camada de Harness (`Implementor` + `Tester` + `harness-cycle`)

A versão 5.0 formaliza os dois papéis da base da pirâmide que operam diretamente sobre o código-fonte:
- **`Implementor` (`prompts/12-implementor-harness.md` e `run-implementor.{sh,ps1}`):** recebe o `TASK_SPEC.md` (e o relatório de falha do Tester quando em retentativa), adquire/valida o `.agent-pack/.runtime/task.lock`, altera o código na branch do card (`feat/AB-<ID>-<slug>` ou `fix/AB-<ID>-<slug>`) sem fazer commit durante o loop, e executa o `git commit` exclusivamente quando invocado com `--commit-gate2` após o ok humano no Gate 2 (expirando o `task.lock`).
- **`Tester` (`prompts/13-tester-harness.md` e `run-tester.{sh,ps1}`):** nunca altera código de negócio; valida `R0-RED` (falha antes do fix), `R0-GREEN` (passa após o fix) e `FULL`, gravando `.agent-pack/evidencias/<CardId>/EVIDENCIA.md` e `.agent-pack/.runtime/test-status.json`.
- **Supervisor (`supervise-harness.{sh,ps1}`):** executa o loop fechado pré-Gate 2 entre `run-implementor` e `run-tester` com limite máximo de 3 tentativas.
- **Comunicação CLI Sólida e Não-Bloqueante:** Quando um bot ou supervisor invoca um harness via CLI em modo headless, o comando deve incluir as flags não-interativas do respectivo CLI para evitar bloqueios aguardando confirmação humana no terminal.

## Limites verificáveis

Detectores levantam manifests, projetos, CI/scripts e pistas de runtime/provider sem imprimir conexão, script body ou segredo. PowerShell retorna JSON/markdown com metadados; Bash retorna markdown e caminhos para inspeção posterior. Não são parsers universais nem executam app/teste. Verifique versão e comando no repo real. SQL genérico não identifica SQL Server; use provider/T-SQL específico. AndroidManifest, alvos iOS em projeto Xcode, pubspec/MAUI e dependências mobile/híbridas são pistas que precisam confirmação; Kotlin/Swift isolados não selecionam mobile. Tecnologias não reconhecidas continuam investigáveis.

Testes do pack exercitam scripts, instalação limpa, ciclo de harness (`test-harness-cycle`), atualização/ownership/seleções, rollback e fixtures. Checks de contrato são estáticos, não prova de obediência de modelos. Browser real, banco, app desktop ou device mobile só são verificados quando executados e autorizados na tarefa. Zero testes, ambiente ausente, falha e evidência incompleta são estados distintos. [Capabilities](repo-template/docs/engineering-flow/capabilities.md) define evidência por área. Os testes PowerShell exigem PowerShell 7 ou mais novo; cada `.ps1` tem equivalente `.sh`.

## Higiene Git no destino

Instalação e atualização acrescentam somente padrões faltantes ao `.gitignore` existente, preservando conteúdo, encoding UTF-8, BOM e CRLF originais. DryRun/WhatIf e Check não escrevem.

No padrão 5.0, `protect-engineering-flow-files.{sh,ps1}` garante que todas as pastas e artefatos operacionais do Engineering Flow fiquem ignorados no `.gitignore`:
```gitignore
*.agent-pack.new
*.agent-pack.backup-*
.agent-pack/
.agents/
.grok/
docs/engineering-flow/
docs/ai/
prompts/
.engineering-flow-evidence/
Planejamento/
planejamento/
```
Assim, **apenas `AGENTS.md` permanece visível e versionável no Git do projeto**. Se algum arquivo de versão antigo já estiver rastreado no índice Git de um repositório legado, remova-o do índice com `git rm --cached` revisado (mantendo o arquivo local se desejar).
