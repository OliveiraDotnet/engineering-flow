# Fontes oficiais do Grok Build

Este arquivo registra as decisões específicas do Grok Build usadas pelo Engineering Flow 3.0. Consulte novamente as fontes antes de alterar caminhos, formatos ou políticas. O único harness do pack é o Grok Build.

## Regras e contexto do projeto

- [Project rules](https://docs.x.ai/build/features/project-rules): o Grok Build lê `AGENTS.md` como instrução de projeto.
- O pack não cria `GROK.md`: `AGENTS.md` é a fonte de orientação do projeto.

## Skills, agentes e configuração

- [Skills, plugins and marketplaces](https://docs.x.ai/build/features/skills-plugins-marketplaces): skills locais do projeto usam `.grok/skills`.
- [Subagents](https://docs.x.ai/build/features/subagents): agentes personalizados usam arquivos Markdown em `.grok/agents`; subagentes podem executar em paralelo e usar isolamento por worktree.
- [Settings](https://docs.x.ai/build/settings): configuração de projeto usa `.grok/config.toml`.
- [Permissions](https://docs.x.ai/build/features/permissions): regras de permissão podem permitir, perguntar ou negar comandos específicos.

O pack instala em `.grok/config.toml` somente uma política mínima do projeto que nega operações destrutivas. Commit e push seguem o Gate 2: ok explícito do Matheus, commit só pelo Grok Build, push só pelo Jow ou pelo Matheus manualmente. Autenticação, modelo, sandbox e preferências pessoais continuam sob responsabilidade da configuração do usuário.

## Worktrees e execução não interativa

- [Worktrees](https://docs.x.ai/build/features/worktrees): worktrees nativos ficam em `~/.grok/worktrees`, fora do repositório principal; sessões ficam em `~/.grok/sessions`.
- [CLI reference](https://docs.x.ai/build/cli/reference): `--worktree`, `--ref`, `--output-format` e `--no-auto-update` são opções oficiais.
- [Headless and scripting](https://docs.x.ai/build/cli/headless-scripting): `grok -p` permite execução headless e saída estruturada.
- [Grok Build overview](https://docs.x.ai/build/overview): visão geral do produto e instalação.
- [Official source: getting started](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-pager/docs/user-guide/01-getting-started.md): guia mantido no repositório oficial.
- [Official source: subagents](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-pager/docs/user-guide/16-subagents.md): detalhes de paralelismo e isolamento.
- [Announcement](https://x.ai/news/grok-build-cli): anúncio oficial do Grok Build.

O Grok Build lê o índice de skills, escolhe a skill pertinente, implementa, testa e traz evidências. Sem skill que caiba, pergunta.

Veja também [assistente opcional](ASSISTENTE_OPCIONAL.md), sem dependência ou integração direta assumida.

## Decisões deliberadas do pack

- O Grok Build é o único harness; Codex e Claude saíram na 3.0.
- Os 10 agentes têm origem em `.grok/agents`.
- Skills compartilhadas continuam canônicas em `.agents/skills` e são espelhadas em `.grok/skills` para descoberta nativa.
- Não se versionam worktrees, sessões, transcrições, estado da máquina nem `.agent-pack/.runtime/task.lock`.
- Não se cria `.ai-collab`, `.grok-worktrees` ou outro diretório de coordenação no repositório.
- Não se ignora `.grok/` inteira: agentes, skills e configuração de projeto instalados ali são parte intencional e versionável da integração.
- A automação padrão não usa `--yolo`; permissões amplas exigem decisão explícita do usuário.
- A tarefa não concede automaticamente commit ou push. O Gate 2 define os papéis.
- Matheus é a única autoridade decisória; plano/aprovação precedem implementação e somente testes aprovados executam.
