# Diretriz: hierarquia de papéis, instalação limpa, ciclo de harness e entrega (Engineering Flow 5.0, tag v5.0.0)

Revisão 5 (Engineering Flow 5.0): generaliza todos os papéis removendo nomes pessoais e acoplamento a ferramentas específicas, introduz o ciclo fechado `Implementor` ↔ `Tester` (`harness-cycle`) na base da pirâmide e estabelece que a instalação nos repositórios destino é limpa, sem gerar arquivos de versão (`.agent-pack/state.txt`) e versionando **apenas o arquivo `AGENTS.md`**.

## Papéis e Hierarquia
As diretrizes seguem o Engineering Flow 5.0. O fluxo pode ser operado por um único harness acumulando papéis ou por agentes separados em hierarquia:
1. **Aprovador humano**: autoridade máxima e intransferível (`sole decision authority`). Dá o ok explícito no Gate 1 (plano), no Gate 2 (commit e push) e na promoção para produção (`main`/`master`).
2. **Planejador / Engenheiro-Chefe**: está hierarquicamente **acima** dos revisores de repositório. Recebe e tria demandas (cards, chat ou e-mails), garante que toda demanda tenha Card (`AB-<ID>`), fecha o envelope do Gate 1 com o aprovador humano, acompanha o `Planejamento/DEMANDAS.md` (cobrando demandas em andamento e demandas paradas em homologação) e delega ordens de serviço ou instalações da v5.0 para os revisores de repositório.
3. **Revisor/entrega (Tech Lead de Repositório, um por projeto/repositório)**: dono operacional do(s) repositório(s) do projeto. Executa a instalação limpa da v5.0, mantém `.ai-memory.toml` (quando aplicável) e `Planejamento/DEMANDAS.md`, cria o LOCK (`task.lock`), escreve o `TASK_SPEC.md`, supervisiona o loop `Implementor` ↔ `Tester`, confere o commit do Gate 2 e conduz push, PR, merge em homologação, promoção isolada para produção, Tag `vX.Y.Z`, pacote SQL e OS da Infra.
4. **Implementor (Harness de Código)**: executa o envelope aprovado na branch do card (`feat/AB-<ID>-<slug>` ou `fix/AB-<ID>-<slug>`), corrige apontamentos do `Tester`, nunca faz push e é o **único** que faz `git commit`, depois do Gate 2 (`--commit-gate2`).
5. **Tester (Harness de Validação / QA)**: nunca altera código de negócio; avalia e executa os testes aprovados (`R0-RED` antes do fix e `R0-GREEN` depois do fix em bugs: unitário/integração se saudável no legado, ou Playwright E2E completo se acoplado) e grava `.agent-pack/evidencias/<CardId>/EVIDENCIA.md` e `.agent-pack/.runtime/test-status.json`.
6. **Publicador / Validador opcional**: audita branches/releases ou apoia mediante confirmação explícita do aprovador humano.

## Rito de Instalação Limpa do Engineering Flow 5.0 (Apenas `AGENTS.md` Versionado)
Na instalação ou atualização para o Engineering Flow 5.0 em um projeto (com 1 ou múltiplos repositórios), executa-se em cada repositório:
1. **Instalação limpa do Pack 5.0:**
   - Linux/WSL: `bash <caminho-engineering-flow>/scripts/install-agent-pack.sh <caminho-repo> --force --profile <perfis>`
   - Windows (PowerShell 7): `pwsh -File <caminho-engineering-flow>\scripts\install-agent-pack.ps1 -RepoPath <caminho-repo> -Force -Profile <perfis>`
   - O instalador atualiza skills, agentes, prompts e contratos criando backups automáticos (`*.agent-pack.backup-*`) de qualquer arquivo preexistente divergente, **não gera `.agent-pack/state.txt`** e adiciona todas as pastas operacionais do Engineering Flow ao `.gitignore` para que **somente `AGENTS.md` seja versionado** no repositório.
2. **Configuração opcional do `ai-memory`:**
   - Quando o ambiente utilizar `ai-memory`, criar ou validar `.ai-memory.toml` com `workspace = "<slug-do-projeto>"` e `project = "<slug-do-repositorio>"`.
   - Como bots externos não compartilham necessariamente o MCP do harness, toda comunicação entre papéis utiliza artefatos explícitos em disco (`TASK_SPEC.md`, `EVIDENCIA.md`, `test-status.json`, `Planejamento/DEMANDAS.md` e `AGENTS.md`).
3. **Mapeamento e Convenções do Repositório (`AGENTS.md` + `docs/ai/`):**
   - Se o repositório ainda tiver `[UNVERIFIED]` em `AGENTS.md`, executar `$bootstrap-repo` (ou `$bootstrap-dotnet-repo`).
   - Preencher a seção `Convenções do projeto` em `AGENTS.md` com: branch de produção (`main`/`master`), branch de homologação (`hom`/`develop`/`hml`), workspace de planejamento (`on`), pacote SQL de release (`on` quando usar SQL Server) e `Versionamento do pack: apenas AGENTS.md`.
4. **Inicialização do Controle de Demandas e Scripts SQL (`Planejamento/`):**
   - Criar na raiz do workspace de planejamento do projeto:
     - `Planejamento/DEMANDAS.md` (Quadro Vivo de Demandas);
     - `Planejamento/scripts/PendentesProducao/` (scripts SQL individuais por card `AB-<ID>-<slug>.sql`);
     - `Planejamento/scripts/Releases/` (pacotes SQL consolidados por Tag `vX.Y.Z_consolidado.sql` e `OS-INFRA-vX.Y.Z.md`);
     - `Planejamento/scripts/Aplicados/` (scripts já executados em produção, organizados por Tag `vX.Y.Z/`).

## Ciclo Completo de Entrega por Card (Com Loop `Implementor` ↔ `Tester`)
Cada revisor/entrega conduz o ciclo completo no seu repositório:
1. **Triagem e Branch por Card:**
   - Confere se a demanda possui número de card (`AB-<ID>`). Sem card, registra ou solicita ao planejador/aprovador antes de iniciar.
   - Registra a demanda como `EM_DEV` em `Planejamento/DEMANDAS.md` e cria o LOCK (`.agent-pack/.runtime/task.lock`).
   - Cria a branch da tarefa com o número do card (`feat/AB-<ID>-<slug>` ou `fix/AB-<ID>-<slug>`) **sempre a partir da `main`/`master`** (salvo exceção explícita documentada em `AGENTS.md` do projeto).
2. **Loop Fechado de Harness (`Implementor` ↔ `Tester`) e Conferência do Gate 2:**
   - Gera `.agent-pack/.runtime/TASK_SPEC.md` com o escopo aprovado no Gate 1.
   - Supervisiona o ciclo (`supervise-harness.{sh,ps1}`): em bugs, o `Tester` confirma `R0-RED` (falha antes do fix); o `Implementor` aplica o código na working tree sem comitar; o `Tester` valida `R0-GREEN` / `FULL` (até 3 tentativas).
   - Quando `STATUS=PASSED`, apresenta a evidência (`EVIDENCIA.md`) ao aprovador humano para o Gate 2.
   - Após o ok explícito do aprovador humano no Gate 2, aciona `run-implementor --commit-gate2` para o `Implementor` realizar o `git commit` (expirando o `task.lock`) e confere: diff contra o escopo do Gate 1, tabela de evidências do Gate 2, script SQL idempotente (se houver) em `Planejamento/scripts/PendentesProducao/AB-<ID>-<slug>.sql`, ausência de segredos/dados sensíveis e branch correta.
3. **Ida para Homologação (Mantendo a Branch Viva):**
   - Faz o push da branch do card (`feat/AB-<ID>-<slug>`).
   - Abre o PR e faz o merge da branch do card na branch de homologação/integração (`hom` / `develop` / `hml`).
   - **Não exclui a branch do card (`feat/AB-<ID>-<slug>`):** ela permanece intacta até que a demanda seja aprovada em homologação e promovida para a `main`/`master`.
   - Atualiza `Planejamento/DEMANDAS.md` para `EM_HOMOLOGACAO` (registrando a data e o responsável pelo teste).
4. **Promoção Isolada para Produção (Merge da Branch do Card na `main`):**
   - Quando a demanda é validada em homologação (mesmo que outras demandas continuem em teste na branch de homologação) e o **aprovador humano dá o ok explícito para produção**, o revisor/entrega faz o merge **da branch do card (`feat/AB-<ID>-<slug>`) diretamente na `main`/`master`**.
5. **Fechamento de Versão (Tag `vX.Y.Z`, SQL Consolidado, OS da Infra e Limpeza):**
   - Cria a Tag semântica anotada (`vX.Y.Z`) na `main`/`master` e faz push da tag.
   - Consolida apenas os scripts SQL dos cards incluídos naquela Tag em `Planejamento/scripts/Releases/vX.Y.Z_consolidado.sql`.
   - Gera o documento `Planejamento/scripts/Releases/OS-INFRA-vX.Y.Z.md` pronto para abertura do chamado de publicação na Infra.
   - **Exclui a branch do card (`feat/AB-<ID>-<slug>`)** que já subiu para a `main`/`master` e atualiza o status no `Planejamento/DEMANDAS.md` para `EM_PRODUCAO (vX.Y.Z)`.

## Regras travadas (não negociáveis)
- Merge em `main`/`master` só com ok explícito do aprovador humano, depois da evidência e da validação de homologação. Sem esse ok, nunca.
- Nenhum trabalho, commit ou push direto em `main`/`master`. `main`/`master` só recebe merge de branches de card aprovadas.
- Nunca excluir a branch do card (`feat/AB-<ID>-*` / `fix/AB-<ID>-*`) antes de ela ter sido mergeada na `main`/`master` e tagueada.
- Nunca force push.
- Todo repositório tem uma branch de homologação/integração que não é `main` nem `master` (por exemplo `hom`, `hml` ou `develop`).
- Quem comita continua sendo só o `Implementor`, depois do Gate 2. O LOCK expira no commit.
- Apenas `AGENTS.md` é versionado no repositório alvo; nenhum arquivo de versão ou pasta interna do Engineering Flow sobe no Git do projeto.
- Se um push, PR, merge ou tag for bloqueado ou falhar, o revisor/entrega para e avisa o aprovador humano/planejador. Nada de contornar.

## Fluxo atualizado (passos 8 a 11)
8. **Gate 2:** com o ok explícito do aprovador humano após ver a evidência do `Tester`, o `Implementor` comita na branch do card (`feat/AB-<ID>-<slug>`).
9. **Homologação:** o revisor/entrega confere o commit, faz o push da branch do card, abre o PR para a branch de homologação/integração, faz o merge na homologação **sem excluir a branch do card** e marca `EM_HOMOLOGACAO` em `Planejamento/DEMANDAS.md`.
10. **Ida para produção:** com o ok explícito do aprovador humano após a aprovação em homologação, o revisor/entrega faz o merge **da branch do card (`feat/AB-<ID>-<slug>`) na `main`/`master`**.
11. **Release e OS da Infra:** o revisor/entrega cria e empurra a Tag `vX.Y.Z` na `main`/`master`, consolida o SQL daquela Tag em `Releases/vX.Y.Z_consolidado.sql`, gera a `OS-INFRA-vX.Y.Z.md`, exclui a branch do card já promovida e atualiza o `DEMANDAS.md` para `EM_PRODUCAO (vX.Y.Z)`.

## Exceções e convenções específicas por projeto
Qualquer exceção de branch ou de aprovação específica de um repositório deve ser registrada na seção `Convenções do projeto` do `AGENTS.md` daquele repositório (e na pasta local ignorada `Planejamento/`), prevalecendo sobre a regra geral quando explicitamente autorizada pelo aprovador humano.
