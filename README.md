# Engineering Flow 3.0

> **Incompatível com 2.1.1 e 1.7.0.** A 3.0 não tem compatibilidade com essas versões e não oferece migração automática. Para a linha 2.x, use a tag `v2.1.1`.

Índice de skills: [SKILLS-INDEX.md](SKILLS-INDEX.md)

Workflow de engenharia para descobrir sistemas, planejar e entregar bugs, features, refatorações e projetos novos com aprovação humana e evidência. O único harness é o **Grok Build**. Mantém expertise .NET moderno/Framework, Web Forms, ASP clássico, HTML/CSS/JavaScript e SQL Server; tecnologias adicionais são investigadas pelo contexto, sem lista fechada de linguagens.

**Entender → plano técnico → aprovação humana → implementar → executar testes aprovados → evidências → entregar.** Testes não pedidos/aprovados não executam automaticamente. Implementação aprovada sem testes é entregue como não validada; autorização existente não precisa ser repetida. Veja o [contrato comum](repo-template/docs/engineering-flow/workflow.md).

Versão `3.0.0`. Nome público Engineering Flow; repositório `engineering-flow`. O pack contém orientação, configurações e scripts locais, sem instalar runtimes ou afirmar suporte automatizado universal. Mobile inclui apps nativos, híbridos e multiplataforma, novos ou existentes; desktop e DevOps têm procedimentos proporcionais ao ambiente autorizado.

**Gate 2:** commit e push exigem o ok explícito do Matheus, dado depois de ele ver as evidências. O commit é feito só pelo Grok Build. O push é feito só pelo Jow ou, com o Jow indisponível, pelo Matheus manualmente. Nenhum outro agente comita ou dá push. Nunca na main ou na master, nunca force push.

| Perfil | Seleção | Conteúdo |
|---|---|---|
| core | sempre | Descoberta, projeto novo, bug, feature, refactor, review, completion, skills recorrentes e contrato. Entradas .NET antigas preservadas. |
| web | explícito ou evidência de UI | Procedimento geral de navegador/ASP clássico/SPA e especialização .NET web. |
| sqlserver | explícito ou provider/T-SQL específico | Entendimento read-only e mudanças SQL Server aprovadas. |
| mobile | explícito ou evidência de plataforma | Planejamento e validação nativa/híbrida/multiplataforma; não instala SDK/dispositivo. |
| quality | explícito, nunca automático | Revisões focadas de segurança, desempenho e entrega. |

Modos de operação: **Trivial** (1 critério observável, sem risco a dados/migração) e **Completo** (Gate 1 e Gate 2); na dúvida, Completo. Docs: [anti-padrões](repo-template/docs/engineering-flow/anti-patterns.md) (lidos antes de toda tarefa), [workspace de planejamento](repo-template/docs/engineering-flow/planning-workspace.md) e [pacote SQL de release](repo-template/docs/engineering-flow/sql-release-package.md), ambos opcionais por projeto. [GROK_BOT_WORKFLOW.md](GROK_BOT_WORKFLOW.md) descreve o bot secretário de engenharia opcional, fora do pack.

## Instalação

Execute na raiz do pack, apontando para Git root, monorepo ou pasta com repos independentes. Um repo Git vazio pode receber core e planejar scaffolding depois. Para pasta deliberadamente não Git use AllowNonGit.

```powershell
.\scripts\install-agent-pack.ps1 -RepoPath 'C:\src' -DiscoverOnly
.\scripts\install-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Profile web,sqlserver -DryRun
.\scripts\install-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Profile web,sqlserver
.\scripts\install-agent-pack.ps1 -RepoPath 'C:\src\NovoApp' -Profile mobile
```

```bash
bash ./scripts/install-agent-pack.sh /src --discover-only
bash ./scripts/install-agent-pack.sh /src/sistema --profile web,sqlserver --dry-run
bash ./scripts/install-agent-pack.sh /src/sistema --profile web,sqlserver
bash ./scripts/install-agent-pack.sh /src/novo-app --profile mobile
```

O harness instalado é sempre o Grok Build. Perfil explícito evita autodetecção; não prepara ferramentas por inferência. InstallGlobal é exemplo pessoal opt-in (`$GROK_HOME` ou `~/.grok/AGENTS.md`).

## Atualização segura

```powershell
.\scripts\update-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Check
.\scripts\update-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Apply
```

```bash
bash ./scripts/update-agent-pack.sh /src/sistema --check
bash ./scripts/update-agent-pack.sh /src/sistema --apply
```

Use updater, não Force. `pack-manifest.txt`, `pack-artifacts.txt` e `pack-version.txt` definem arquivos, IDs estáveis/propriedade e versão. `.agent-pack/state.txt` continua sendo o formato/local de estado. Perfis previamente selecionados são preservados; atualizar não adiciona mobile/quality não selecionados. `managed` atualizado somente pela reconciliação, `merge` exige revisão humana das diferenças, `seed` pertence ao projeto. Conflitos mantêm customização e precisam de AcceptPack, AcceptMerge (após merge) ou KeepLocal; confira o [guia detalhado](INSTRUCOES_DETALHADAS.md).

A 3.0 não migra instalações 2.1.1 nem 1.7.0. Catálogos históricos permanecem como registro; `compat/releases/2.1.1.txt` descreve a base 2.1.1 e `compat/releases/3.0.0.txt` a base 3.0.

## Uso diário

O Grok Build lê o [índice de skills](SKILLS-INDEX.md) e carrega só a skill escolhida. Comece com `$bootstrap-repo` ou prompts/00-bootstrap-repo.md quando faltar contexto. Escolha `$bugfix`, `$feature-slice`, `$refactor`, `$review-change` ou `$new-project`; conclua com `$complete-task`. Especialistas são opcionais. Use módulos somente quando pertinentes. Uma skill por repo só se justifica por procedimento recorrente confirmado.

Veja [manual e exemplos](MANUAL_DE_USO.md), [adoção e limites](INSTRUCOES_DETALHADAS.md), [capacidades de validação](repo-template/docs/engineering-flow/capabilities.md), [Grok Bot opcional](GROK_BOT_OPCIONAL.md) e [changelog](CHANGELOG.md).

A instalação/update preserva .gitignore e acrescenta proteção de resíduos operacionais, inclusive `.agent-pack/.runtime/task.lock`. Skills/configuração e .agent-pack/state.txt permanecem versionáveis; veja higiene Git no guia detalhado. Regras próprias e arquivos já rastreados exigem revisão quando incompatíveis.

Modo pack local (opcional): o pack fica no projeto sem ser versionado; AGENTS.md e docs/ai continuam versionados. Veja "Modo pack local" no guia detalhado.
