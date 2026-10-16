# Engineering Flow 2.0

Workflow de engenharia para descobrir sistemas, planejar e entregar bugs, features, refatorações e projetos novos com aprovação humana e evidência. Funciona independentemente em Codex ou Grok Build, com compatibilidade Claude e extensão por instruções/skills de outros agentes. Mantém expertise .NET moderno/Framework, Web Forms, ASP clássico, HTML/CSS/JavaScript e SQL Server; tecnologias adicionais são investigadas pelo contexto, sem lista fechada de linguagens.

**Entender → plano técnico → aprovação humana → implementar → executar testes aprovados → evidências → entregar.** Testes não pedidos/aprovados não executam automaticamente. Implementação aprovada sem testes é entregue como não validada; autorização existente não precisa ser repetida. Veja o [contrato comum](repo-template/docs/engineering-flow/workflow.md).

Versão `2.1.0`. Nome público Engineering Flow; repositório `engineering-flow`. Suporta instalação inicial e atualização de instalações 2.0.0, 1.7.0 e versões anteriores reconhecidas pelos catálogos. O pack contém orientação, configurações e scripts locais, sem instalar runtimes ou afirmar suporte automatizado universal. Mobile inclui apps nativos, híbridos e multiplataforma, novos ou existentes; desktop e DevOps têm procedimentos proporcionais ao ambiente autorizado.

| Perfil | Seleção | Conteúdo |
|---|---|---|
| core | sempre | Descoberta, projeto novo, bug, feature, refactor, review, completion, skills recorrentes e contrato. Entradas .NET antigas preservadas por compatibilidade. |
| web | explícito ou evidência de UI | Procedimento geral de navegador/ASP clássico/SPA e especialização .NET web. |
| sqlserver | explícito ou provider/T-SQL específico | Entendimento read-only e mudanças SQL Server aprovadas. |
| mobile | explícito ou evidência de plataforma | Planejamento e validação nativa/híbrida/multiplataforma; não instala SDK/dispositivo. |
| quality | explícito, nunca automático | Revisões focadas de segurança, desempenho e entrega. |

Modos de operação: **Trivial** (1 critério observável, sem risco a dados/migração) e **Completo** (Gate 1 e Gate 2); na dúvida, Completo. Docs: [anti-padrões](repo-template/docs/engineering-flow/anti-patterns.md) (lidos antes de toda tarefa), [workspace de planejamento](repo-template/docs/engineering-flow/planning-workspace.md) e [pacote SQL de release](repo-template/docs/engineering-flow/sql-release-package.md), ambos opcionais por projeto. [GROK_BOT_WORKFLOW.md](GROK_BOT_WORKFLOW.md) descreve o bot secretário de engenharia opcional, fora do pack.

## Instalação

Execute na raiz do pack, apontando para Git root, monorepo ou pasta com repos independentes. Um repo Git vazio pode receber core e planejar scaffolding depois. Para pasta deliberadamente não Git use AllowNonGit.

```powershell
.\scripts\install-engineering-flow.ps1 -RepoPath 'C:\src' -DiscoverOnly
.\scripts\install-engineering-flow.ps1 -RepoPath 'C:\src\Sistema' -Integration grok -Profile web,sqlserver -DryRun
.\scripts\install-engineering-flow.ps1 -RepoPath 'C:\src\Sistema' -Integration grok -Profile web,sqlserver
.\scripts\install-engineering-flow.ps1 -RepoPath 'C:\src\NovoApp' -Integration codex -Profile mobile
```

```bash
bash ./scripts/install-engineering-flow.sh /src --discover-only
bash ./scripts/install-engineering-flow.sh /src/sistema --integration grok --profile web,sqlserver --dry-run
bash ./scripts/install-engineering-flow.sh /src/sistema --integration grok --profile web,sqlserver
bash ./scripts/install-engineering-flow.sh /src/novo-app --integration codex --profile mobile
```

Sem seleção inicial, Codex é o padrão. `Integration grok` instala Grok independente; `codex,grok` permite coexistência; `claude` é compatibilidade opcional. IncludeClaude/IncludeGrokBuild continuam disponíveis. Em instalação existente, seleção registrada é preservada. Perfil explícito evita autodetecção; não prepara ferramentas por inferência. InstallGlobal é exemplo pessoal opt-in.

## Atualização segura

```powershell
.\scripts\update-engineering-flow.ps1 -RepoPath 'C:\src\Sistema' -Check
.\scripts\update-engineering-flow.ps1 -RepoPath 'C:\src\Sistema' -Apply
```

```bash
bash ./scripts/update-engineering-flow.sh /src/sistema --check
bash ./scripts/update-engineering-flow.sh /src/sistema --apply
```

Use updater, não Force. `pack-manifest.txt`, `pack-artifacts.txt` e `pack-version.txt` definem arquivos, IDs estáveis/propriedade e versão. `.agent-pack/state.txt` e nomes antigos de scripts/skills permanecem compatíveis. Perfis/integrações previamente selecionados são preservados; atualizar não adiciona mobile/quality não selecionados. `managed` atualizado somente pela reconciliação, `merge` exige revisão humana das diferenças, `seed` pertence ao projeto. Conflitos mantêm customização e precisam de AcceptPack, AcceptMerge (após merge) ou KeepLocal; confira o [guia detalhado](INSTRUCOES_DETALHADAS.md).

Catálogos históricos são preservados. `compat/releases/1.7.0.txt` identifica arquivos da pré-release 1.7, sem alegar release publicado. Artifacts Flutter antigos de 1.5 podem ser aposentados se intactos; customizados exigem decisão. O novo perfil mobile é um procedimento geral, sem substituir silenciosamente aqueles arquivos.

## Uso diário

Comece com `$bootstrap-repo` ou prompts/00-bootstrap-repo.md quando faltar contexto. Escolha `$bugfix`, `$feature-slice`, `$refactor`, `$review-change` ou `$new-project`; conclua com `$complete-task`. Skills são selecionáveis por nome/tarefa e invocadas pelo host ativo. Especialistas são opcionais; segundo provedor não é requisito. Use módulos somente quando pertinentes. Uma skill por repo só se justifica por procedimento recorrente confirmado.

Veja [manual e exemplos](MANUAL_DE_USO.md), [adoção/migração e limites](INSTRUCOES_DETALHADAS.md), [capacidades de validação](repo-template/docs/engineering-flow/capabilities.md), [Grok Bot opcional](GROK_BOT_OPCIONAL.md) e [changelog](CHANGELOG.md).

A instalação/update preserva .gitignore e acrescenta proteção de resíduos operacionais. Skills/configuração e .agent-pack/state.txt permanecem versionáveis; veja higiene Git no guia detalhado. Regras próprias e arquivos já rastreados exigem revisão quando incompatíveis.
