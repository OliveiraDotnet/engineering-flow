# Engineering Flow 4.0

> **Incompatível com 2.1.1 e 1.7.0.** A linha 4.0 evolui a arquitetura 3.x consolidando a hierarquia do engenheiro-chefe (Jeff) e bots de projeto, adoção exclusiva do **`ai-memory` (Fábio Akita)** no lugar do script local `mem`, rastreabilidade de branches por Card (`AB-<ID>`), promoção isolada para `main`/`master`, pacote SQL por Tag de Release (`vX.Y.Z`) com geração de OS para Infra e regra de saúde de testes no legado vs. Playwright E2E completo.

Índice de skills: [SKILLS-INDEX.md](SKILLS-INDEX.md)

Workflow de engenharia para descobrir sistemas, triar demandas por card, planejar e entregar bugs, features, refatorações e projetos novos com aprovação humana e evidência. O método define papéis em hierarquia clara (aprovador humano, engenheiro-chefe/planejador, revisor/entrega por repo, implementador/harness e publicador/validador opcional) e não depende de uma ferramenta; a instanciação atual é exemplo, não requisito: aprovador = Matheus, engenheiro-chefe/planejador = Jeff (com o Matheus), revisor/entrega = bot de projeto, implementador = **Grok Build**, validador/publicador opcional = Jow. Mantém expertise .NET moderno/Framework, Web Forms, ASP clássico, HTML/CSS/JavaScript e SQL Server; tecnologias adicionais são investigadas pelo contexto, sem lista fechada de linguagens.

**Triagem por Card (`AB-<ID>`) → entender → plano técnico (Gate 1) → aprovação humana → implementar na branch do card → executar testes aprovados → evidências → Gate 2 (commit) → homologação (mantendo branch viva) → produção isolada, Tag `vX.Y.Z`, SQL consolidado e OS de Infra.** Em bug, o teste de regressão `R0` (falha antes, passa depois — unitário/integração se saudável no legado, ou Playwright E2E completo se acoplado) entra por padrão no plano do Gate 1. Fora do `R0`, testes não pedidos/aprovados não executam automaticamente. Implementação aprovada sem testes é entregue como não validada; autorização existente não precisa ser repetida. Veja o [contrato comum](repo-template/docs/engineering-flow/workflow.md).

Versão `4.0.0`. Nome público Engineering Flow; repositório `engineering-flow`. O pack contém orientação, configurações e scripts locais, sem instalar runtimes ou afirmar suporte automatizado universal. Mobile inclui apps nativos, híbridos e multiplataforma, novos ou existentes; desktop e DevOps têm procedimentos proporcionais ao ambiente autorizado. Memória persistente de longo prazo e handoffs entre sessões utilizam o **`ai-memory` (`akitaonrails/ai-memory`)** via `.ai-memory.toml` e MCP, junto com `docs/ai/`.

**Gate 2:** commit e push exigem o ok explícito do Matheus, dado depois de ele ver as evidências. O commit é feito só pelo implementador. O push é feito só pelo publicador ou, com o publicador indisponível, pelo Matheus manualmente. Nenhum outro agente comita ou dá push. Nunca na main ou na master, nunca force push. Instanciação atual (exemplo, não requisito): implementador = Grok Build; publicador = Jow, hoje opcional, porque a [diretriz de entrega pelo bot de projeto](diretrizes/DIRETRIZ-entrega-pelo-bot-de-projeto.md) atribui push, PR, merge na homologação (sem excluir a branch do card), promoção isolada da branch do card na `main`/`master`, Tag `vX.Y.Z`, consolidação SQL e geração da OS da Infra ao papel revisor/entrega nos passos 9 a 11.

| Perfil | Seleção | Conteúdo |
|---|---|---|
| core | sempre | Descoberta, projeto novo, bug, feature, refactor, review, completion, skills recorrentes e contrato. Entradas .NET antigas preservadas. |
| web | explícito ou evidência de UI | Procedimento geral de navegador/ASP clássico/SPA, Playwright E2E e especialização .NET web. |
| sqlserver | explícito ou provider/T-SQL específico | Entendimento read-only, mudanças SQL Server idempotentes por card e pacote de release por Tag. |
| mobile | explícito ou evidência de plataforma | Planejamento e validação nativa/híbrida/multiplataforma; não instala SDK/dispositivo. |
| quality | explícito, nunca automático | Revisões focadas de segurança, desempenho e entrega. |

Modos de operação: **Trivial** (1 critério observável, sem risco a dados/migração) e **Completo** (Gate 1 e Gate 2); na dúvida, Completo. Docs: [anti-padrões](repo-template/docs/engineering-flow/anti-patterns.md) (lidos antes de toda tarefa), [workspace de planejamento](repo-template/docs/engineering-flow/planning-workspace.md) (inclui `Planejamento/DEMANDAS.md`) e [pacote SQL de release](repo-template/docs/engineering-flow/sql-release-package.md), opcionais por projeto. [ASSISTENTE_WORKFLOW.md](ASSISTENTE_WORKFLOW.md) descreve a hierarquia do Jeff (engenheiro-chefe) e dos bots de projeto e o rito de instalação limpa da v4.0.

## Instalação (Padrão e Instalação Limpa 4.0 pelos Bots de Projeto)

Execute na raiz do pack, apontando para Git root, monorepo ou pasta com repos independentes. Um repo Git vazio pode receber core e planejar scaffolding depois. Para pasta deliberadamente não Git use AllowNonGit. Para instalação limpa da 4.0 delegada pelo Jeff aos bots de projeto sobre instalações anteriores, use `--force` / `-Force` (cria backup `*.agent-pack.backup-*` de arquivos divergentes e atualiza para `4.0.0`).

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

O instalador configura o implementador Grok Build (`integration|grok`, único valor aceito). Perfil explícito evita autodetecção; não prepara ferramentas por inferência. InstallGlobal é exemplo pessoal opt-in (`$GROK_HOME` ou `~/.grok/AGENTS.md`).

## Atualização reconciliada (3.x → 4.0)

```powershell
.\scripts\update-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Check
.\scripts\update-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Apply -Confirm:$false
```

No PowerShell sem console, o `-Apply` inclui `-Confirm:$false`. Sem esse argumento, `ConfirmImpact` High tenta perguntar e o host sem console recusa.

```bash
bash ./scripts/update-agent-pack.sh /src/sistema --check
bash ./scripts/update-agent-pack.sh /src/sistema --apply
```

`pack-manifest.txt`, `pack-artifacts.txt` e `pack-version.txt` definem arquivos, IDs estáveis/propriedade e versão. `.agent-pack/state.txt` continua sendo o formato/local de estado. Perfis previamente selecionados são preservados; atualizar não adiciona mobile/quality não selecionados. `managed` atualizado somente pela reconciliação, `merge` exige revisão humana das diferenças, `seed` pertence ao projeto. Conflitos mantêm customização e precisam de AcceptPack, AcceptMerge (após merge) ou KeepLocal; confira o [guia detalhado](INSTRUCOES_DETALHADAS.md).

Catálogos históricos permanecem em `compat/releases/` (`1.1.0` a `4.0.0`).

## Uso diário

O implementador lê o [índice de skills](SKILLS-INDEX.md) e carrega só a skill escolhida. Comece com `$bootstrap-repo` ou prompts/00-bootstrap-repo.md quando faltar contexto. Escolha `$bugfix`, `$feature-slice`, `$refactor`, `$review-change` ou `$new-project`; conclua com `$complete-task`. Especialistas são opcionais. Use módulos somente quando pertinentes. Uma skill por repo só se justifica por procedimento recorrente confirmado.

Veja [manual e exemplos](MANUAL_DE_USO.md), [adoção e limites](INSTRUCOES_DETALHADAS.md), [capacidades de validação](repo-template/docs/engineering-flow/capabilities.md), [assistente opcional](ASSISTENTE_OPCIONAL.md) e [changelog](CHANGELOG.md).

A instalação/update preserva .gitignore e acrescenta proteção de resíduos operacionais, inclusive `.agent-pack/.runtime/task.lock`, `Planejamento/` e `planejamento/`. Skills/configuração e .agent-pack/state.txt permanecem versionáveis; veja higiene Git no guia detalhado. Regras próprias e arquivos já rastreados exigem revisão quando incompatíveis.

Modo pack local (opcional): o pack fica no projeto sem ser versionado; AGENTS.md e docs/ai continuam versionados. Veja "Modo pack local" no guia detalhado.
