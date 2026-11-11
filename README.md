# Engineering Flow 5.0

> **Fluxo de trabalho agnóstico de ferramenta e baseado em hierarquia de papéis.** A linha 5.0 evolui a arquitetura 4.x introduzindo a camada de harness de baixo para cima (`Implementor` + `Tester` + `harness-cycle`), a instalação limpa nos repositórios destino (onde **apenas o `AGENTS.md` é versionado** e nenhum arquivo de versão/estado `.agent-pack/state.txt` é gerado no destino), o isolamento explícito de memória entre agentes e a remoção de qualquer acoplamento a ferramentas ou personas específicas.

Índice de skills: [SKILLS-INDEX.md](SKILLS-INDEX.md)

Workflow de engenharia para descobrir sistemas, triar demandas por card, planejar e entregar bugs, features, refatorações e projetos novos com aprovação humana e evidência. O método define uma **hierarquia clara de papéis** (aprovador humano → planejador/engenheiro-chefe → revisor/entrega por repositório → Implementor + Tester no harness → publicador/validador opcional) e **não exige nenhuma ferramenta proprietária específica**: qualquer pessoa pode trabalhar usando **um único harness acumulando papéis** (modo standalone) ou distribuir os papéis entre bots especializados. Mantém expertise .NET moderno/Framework, Web Forms, ASP clássico, HTML/CSS/JavaScript e SQL Server; tecnologias adicionais são investigadas pelo contexto, sem lista fechada de linguagens.

**Triagem por Card (`AB-<ID>`) → entender → plano técnico (Gate 1) → aprovação humana → implementar e testar em loop fechado na branch do card (`Implementor` ↔ `Tester`) → evidências → Gate 2 (commit) → homologação (mantendo branch viva) → produção isolada, Tag `vX.Y.Z`, SQL consolidado e OS de Infra.** Em bug, o teste de regressão `R0` (`R0-RED` falha antes, `R0-GREEN` passa depois — unitário/integração se saudável no legado, ou Playwright E2E completo se acoplado) entra por padrão no plano do Gate 1. Fora do `R0`, testes não pedidos/aprovados não executam automaticamente. Implementação aprovada sem testes é entregue como não validada; autorização existente não precisa ser repetida. Veja o [contrato comum](repo-template/docs/engineering-flow/workflow.md).

Versão `5.0.0`. Nome público Engineering Flow; repositório `engineering-flow`. O pack contém orientação, configurações e scripts locais, sem instalar runtimes ou afirmar suporte automatizado universal. Mobile inclui apps nativos, híbridos e multiplataforma, novos ou existentes; desktop e DevOps têm procedimentos proporcionais ao ambiente autorizado. Memória persistente de longo prazo pode utilizar o **`ai-memory` (`akitaonrails/ai-memory`)** junto com `docs/ai/`, mantendo handoffs em arquivos explícitos (`TASK_SPEC.md`, `EVIDENCIA.md`, `test-status.json`, `Planejamento/DEMANDAS.md`) para preservar a separação entre agentes que não compartilham a mesma memória MCP do harness.

**Gate 2:** commit e push exigem o ok explícito do aprovador humano, dado depois de ele ver as evidências. O commit é feito só pelo `Implementor` (`--commit-gate2`). O push é feito só pelo revisor/entrega (ou publicador) ou, quando indisponível, pelo aprovador humano manualmente. Nenhum outro agente comita ou dá push. Nunca na main ou na master, nunca force push. A [diretriz de entrega pelo revisor de repositório](diretrizes/DIRETRIZ-entrega-pelo-bot-de-projeto.md) detalha push, PR, merge na homologação (sem excluir a branch do card), promoção isolada da branch do card na `main`/`master`, Tag `vX.Y.Z`, consolidação SQL e geração da OS da Infra nos passos 9 a 11.

| Perfil | Seleção | Conteúdo |
|---|---|---|
| core | sempre | Descoberta, projeto novo, bug, feature, refactor, review, completion, `harness-cycle` (`Implementor` + `Tester`), skills recorrentes e contrato. |
| web | explícito ou evidência de UI | Procedimento geral de navegador/ASP clássico/SPA, Playwright E2E e especialização .NET web. |
| sqlserver | explícito ou provider/T-SQL específico | Entendimento read-only, mudanças SQL Server idempotentes por card e pacote de release por Tag. |
| mobile | explícito ou evidência de plataforma | Planejamento e validação nativa/híbrida/multiplataforma; não instala SDK/dispositivo. |
| quality | explícito, nunca automático | Revisões focadas de segurança, desempenho e entrega. |

Modos de operação: **Trivial** (1 critério observável, sem risco a dados/migração) e **Completo** (Gate 1 e Gate 2); na dúvida, Completo. Docs: [anti-padrões](repo-template/docs/engineering-flow/anti-patterns.md) (lidos antes de toda tarefa), [workspace de planejamento](repo-template/docs/engineering-flow/planning-workspace.md) (inclui `Planejamento/DEMANDAS.md`) e [pacote SQL de release](repo-template/docs/engineering-flow/sql-release-package.md), opcionais por projeto. [ASSISTENTE_WORKFLOW.md](ASSISTENTE_WORKFLOW.md) descreve a operação da hierarquia completa (standalone ou multi-bot) e o rito de instalação limpa da v5.0.

## Instalação Limpa 5.0 (Apenas `AGENTS.md` Versionado no Repositório Alvo)

Execute na raiz do pack, apontando para Git root, monorepo ou pasta com repos independentes. Um repo Git vazio pode receber core e planejar scaffolding depois. Para pasta deliberadamente não Git use AllowNonGit. Para substituir arquivos preexistentes divergentes com backup automático (`*.agent-pack.backup-*`), use `--force` / `-Force`.

```powershell
.\scripts\install-agent-pack.ps1 -RepoPath 'C:\src' -DiscoverOnly
.\scripts\install-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Profile web,sqlserver -DryRun
.\scripts\install-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Profile web,sqlserver
.\scripts\install-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Profile web,sqlserver -Force
```

```bash
bash ./scripts/install-agent-pack.sh /src --discover-only
bash ./scripts/install-agent-pack.sh /src/sistema --profile web,sqlserver --dry-run
bash ./scripts/install-agent-pack.sh /src/sistema --profile web,sqlserver
bash ./scripts/install-agent-pack.sh /src/sistema --profile web,sqlserver --force
```

Na versão `5.0.0`, a instalação em um repositório é **totalmente limpa**:
- **Não gera arquivos de versão (`.agent-pack/state.txt`)** na instalação do repositório alvo;
- Adiciona todas as árvores operacionais do Engineering Flow (`.agents/`, `.grok/`, `.agent-pack/`, `docs/engineering-flow/`, `docs/ai/`, `prompts/`, `Planejamento/`, `planejamento/`, `.engineering-flow-evidence/`, `*.agent-pack.new`, `*.agent-pack.backup-*`) ao `.gitignore` do repositório;
- **Somente o arquivo `AGENTS.md` é versionado**, permitindo trabalhar em repositórios compartilhados com outros desenvolvedores sem subir arquivos de método para o time.

## Atualização reconciliada (quando aplicável)

```powershell
.\scripts\update-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Check
.\scripts\update-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Apply -Confirm:$false
```

```bash
bash ./scripts/update-agent-pack.sh /src/sistema --check
bash ./scripts/update-agent-pack.sh /src/sistema --apply
```

`pack-manifest.txt`, `pack-artifacts.txt` e `pack-version.txt` definem arquivos, IDs estáveis/propriedade e versão. Catálogos históricos permanecem em `compat/releases/` (`1.1.0` a `5.0.0`). Em repositórios onde o pack está ignorado no `.gitignore` (padrão 5.0), você também pode atualizar simplesmente reexecutando `install-agent-pack` com `--force` / `-Force`.

## Uso diário e Ciclo de Harness (`harness-cycle`)

O agente ativo lê o [índice de skills](SKILLS-INDEX.md) e carrega só a skill escolhida. Comece com `$bootstrap-repo` ou `prompts/00-bootstrap-repo.md` quando faltar contexto. Escolha `$bugfix`, `$feature-slice`, `$refactor`, `$review-change` ou `$new-project`; utilize `$harness-cycle` (`run-implementor`, `run-tester`, `supervise-harness`) para o loop fechado de implementação e testes; conclua com `$complete-task`.

Veja [manual e exemplos](MANUAL_DE_USO.md), [adoção e limites](INSTRUCOES_DETALHADAS.md), [capacidades de validação](repo-template/docs/engineering-flow/capabilities.md), [assistente opcional](ASSISTENTE_OPCIONAL.md) e [changelog](CHANGELOG.md).
