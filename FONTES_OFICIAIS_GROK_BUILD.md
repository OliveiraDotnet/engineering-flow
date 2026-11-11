# Integração de Harness e Configuração de Segurança — Engineering Flow 5.0

Este arquivo registra as convenções de integração de harness e salvaguardas locais usadas pelo Engineering Flow 5.0. O método é **agnóstico de ferramenta**: qualquer harness (CLI ou IDE) pode operar como `Implementor` e `Tester`, usando `.agents/skills/` (ou o espelho `.grok/skills/` e `.grok/agents/` quando aplicável).

## Regras e contexto do projeto

- `AGENTS.md` na raiz do repositório é a fonte canônica de orientação do projeto e o **único arquivo do Engineering Flow versionado no Git do repositório alvo**.
- A instalação do Engineering Flow 5.0 não cria arquivos de versão (`.agent-pack/state.txt`) e adiciona `.agents/`, `.grok/`, `.agent-pack/`, `docs/engineering-flow/`, `docs/ai/`, `prompts/` e `Planejamento/` ao `.gitignore` do repositório alvo.

## Skills, agentes e salvaguardas locais

- Skills canônicas do projeto ficam em `.agents/skills/` e são espelhadas em `.grok/skills/`.
- Perfis de subagentes ficam em `.grok/agents/` (`repo-explorer`, `implementer`, `dotnet-implementer`, `test-guardian`, `change-reviewer`, `frontend-web`, `database-sqlserver`, `security-reviewer`, `performance-reviewer`, `release-reviewer`).
- A configuração `.grok/config.toml` instala uma política mínima de proteção que nega operações destrutivas (`git reset --hard`, `git clean`, `rm -rf`).
- Commit e push seguem o Gate 2: ok explícito do aprovador humano, commit feito exclusivamente pelo `Implementor` (`--commit-gate2`), push feito exclusivamente pelo revisor/entrega (ou publicador) ou pelo aprovador humano manualmente.

## Execução não interativa (Headless CLI) e Ciclo de Harness (`harness-cycle`)

Para evitar bloqueios quando um bot ou supervisor invoca o harness por linha de comando:
- Utilize os runners `run-implementor.{sh,ps1}`, `run-tester.{sh,ps1}` e `supervise-harness.{sh,ps1}` em `.agents/skills/harness-cycle/scripts/`.
- Ao passar `--harness-cmd`, utilize o modo headless/não-interativo documentado da ferramenta escolhida para que o processo não trave aguardando input interativo no terminal.
- O estado do último teste é gravado em `.agent-pack/.runtime/test-status.json` e o relatório detalhado em `.agent-pack/evidencias/<CardId>/EVIDENCIA.md`.

## Decisões deliberadas do pack 5.0

- O Engineering Flow 5.0 não exige nenhuma ferramenta específica: pode ser usado com um único harness standalone ou com múltiplos bots em hierarquia.
- Os 10 perfis de especialistas têm origem em `.grok/agents`.
- Skills compartilhadas continuam canônicas em `.agents/skills` e espelhadas em `.grok/skills`.
- No repositório alvo, **apenas `AGENTS.md` é versionado**; nenhuma pasta operacional ou arquivo de versão do EF é versionado no projeto do usuário.
- A tarefa não concede automaticamente commit ou push. O Gate 2 define os papéis.
- O aprovador humano é a única autoridade decisória; plano/aprovação precedem implementação e somente testes aprovados executam.
