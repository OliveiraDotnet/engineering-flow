# Engineering Flow 3.1

> **Incompatível com 2.1.1 e 1.7.0.** A 3.0 não tem compatibilidade com essas versões e não oferece migração automática. Para a linha 2.x, use a tag `v2.1.1`. A 3.1 continua a partir da 3.0.

Índice de skills: [SKILLS-INDEX.md](SKILLS-INDEX.md)

Workflow de engenharia para descobrir sistemas, planejar e entregar bugs, features, refatorações e projetos novos com aprovação humana e evidência. O método define papéis (aprovador humano, planejador, implementador, revisor/entrega e publicador opcional) e não depende de uma ferramenta; a instanciação atual é exemplo, não requisito: planejador = Matheus com o Jeff, implementador = **Grok Build**, revisor/entrega = bot de projeto, Jow opcional. Na 3.0 o pack configura um único implementador, o Grok Build. Mantém expertise .NET moderno/Framework, Web Forms, ASP clássico, HTML/CSS/JavaScript e SQL Server; tecnologias adicionais são investigadas pelo contexto, sem lista fechada de linguagens.

**Entender → plano técnico → aprovação humana → implementar → executar testes aprovados → evidências → entregar.** Testes não pedidos/aprovados não executam automaticamente. Implementação aprovada sem testes é entregue como não validada; autorização existente não precisa ser repetida. Veja o [contrato comum](repo-template/docs/engineering-flow/workflow.md).

Versão `3.1.2`. Nome público Engineering Flow; repositório `engineering-flow`. O pack contém orientação, configurações e scripts locais, sem instalar runtimes ou afirmar suporte automatizado universal. Mobile inclui apps nativos, híbridos e multiplataforma, novos ou existentes; desktop e DevOps têm procedimentos proporcionais ao ambiente autorizado. Memória local; versionamento em Git previsto para a 3.2.

**Gate 2:** commit e push exigem o ok explícito do Matheus, dado depois de ele ver as evidências. O commit é feito só pelo implementador. O push é feito só pelo publicador ou, com o publicador indisponível, pelo Matheus manualmente. Nenhum outro agente comita ou dá push. Nunca na main ou na master, nunca force push. Instanciação atual (exemplo, não requisito): implementador = Grok Build; publicador = Jow, hoje opcional, porque a diretriz de entrega pelo bot de projeto atribui push, PR e merge ao papel revisor/entrega nos passos 9 e 10.

| Perfil | Seleção | Conteúdo |
|---|---|---|
| core | sempre | Descoberta, projeto novo, bug, feature, refactor, review, completion, skills recorrentes e contrato. Entradas .NET antigas preservadas. |
| web | explícito ou evidência de UI | Procedimento geral de navegador/ASP clássico/SPA e especialização .NET web. |
| sqlserver | explícito ou provider/T-SQL específico | Entendimento read-only e mudanças SQL Server aprovadas. |
| mobile | explícito ou evidência de plataforma | Planejamento e validação nativa/híbrida/multiplataforma; não instala SDK/dispositivo. |
| quality | explícito, nunca automático | Revisões focadas de segurança, desempenho e entrega. |

Modos de operação: **Trivial** (1 critério observável, sem risco a dados/migração) e **Completo** (Gate 1 e Gate 2); na dúvida, Completo. Docs: [anti-padrões](repo-template/docs/engineering-flow/anti-patterns.md) (lidos antes de toda tarefa), [workspace de planejamento](repo-template/docs/engineering-flow/planning-workspace.md) e [pacote SQL de release](repo-template/docs/engineering-flow/sql-release-package.md), ambos opcionais por projeto. [ASSISTENTE_WORKFLOW.md](ASSISTENTE_WORKFLOW.md) descreve a camada opcional de bots (planejamento e repositórios), fora do pack.

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

O instalador da 3.0 configura sempre o mesmo implementador, o Grok Build (`integration|grok`, único valor aceito). Perfil explícito evita autodetecção; não prepara ferramentas por inferência. InstallGlobal é exemplo pessoal opt-in (`$GROK_HOME` ou `~/.grok/AGENTS.md`).

## Atualização segura

```powershell
.\scripts\update-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Check
.\scripts\update-agent-pack.ps1 -RepoPath 'C:\src\Sistema' -Apply -Confirm:$false
```

No PowerShell sem console, o `-Apply` inclui `-Confirm:$false`. Sem esse argumento, `ConfirmImpact` High tenta perguntar e o host sem console recusa.

```bash
bash ./scripts/update-agent-pack.sh /src/sistema --check
bash ./scripts/update-agent-pack.sh /src/sistema --apply
```

Use updater, não Force. `pack-manifest.txt`, `pack-artifacts.txt` e `pack-version.txt` definem arquivos, IDs estáveis/propriedade e versão. `.agent-pack/state.txt` continua sendo o formato/local de estado. Perfis previamente selecionados são preservados; atualizar não adiciona mobile/quality não selecionados. `managed` atualizado somente pela reconciliação, `merge` exige revisão humana das diferenças, `seed` pertence ao projeto. Conflitos mantêm customização e precisam de AcceptPack, AcceptMerge (após merge) ou KeepLocal; confira o [guia detalhado](INSTRUCOES_DETALHADAS.md).

A 3.0 não migra instalações 2.1.1 nem 1.7.0. Catálogos históricos permanecem como registro; `compat/releases/2.1.1.txt` descreve a base 2.1.1, `compat/releases/3.0.0.txt` é a base 3.0.0 corrigida na 3.1.1, `compat/releases/3.1.0.txt` a base 3.1, `compat/releases/3.1.1.txt` a base 3.1.1 e `compat/releases/3.1.2.txt` a base 3.1.2.

## Uso diário

O implementador lê o [índice de skills](SKILLS-INDEX.md) e carrega só a skill escolhida. Comece com `$bootstrap-repo` ou prompts/00-bootstrap-repo.md quando faltar contexto. Escolha `$bugfix`, `$feature-slice`, `$refactor`, `$review-change` ou `$new-project`; conclua com `$complete-task`. Especialistas são opcionais. Use módulos somente quando pertinentes. Uma skill por repo só se justifica por procedimento recorrente confirmado.

Veja [manual e exemplos](MANUAL_DE_USO.md), [adoção e limites](INSTRUCOES_DETALHADAS.md), [capacidades de validação](repo-template/docs/engineering-flow/capabilities.md), [assistente opcional](ASSISTENTE_OPCIONAL.md) e [changelog](CHANGELOG.md).

A instalação/update preserva .gitignore e acrescenta proteção de resíduos operacionais, inclusive `.agent-pack/.runtime/task.lock`, `Planejamento/`, `planejamento/` e `conhecimento/`. Skills/configuração e .agent-pack/state.txt permanecem versionáveis; veja higiene Git no guia detalhado. Regras próprias e arquivos já rastreados exigem revisão quando incompatíveis.

Modo pack local (opcional): o pack fica no projeto sem ser versionado; AGENTS.md e docs/ai continuam versionados. Veja "Modo pack local" no guia detalhado.
