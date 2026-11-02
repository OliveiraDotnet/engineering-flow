# Diretriz: hierarquia Jeff, instalação limpa e entrega pelo bot de projeto (Engineering Flow 4.0, tag v4.0.0)

Aprovada pelo Matheus Oliveira em 26/10/2026. Revisão 2 (26/10/2026, 10h BRT): esclarece que a restrição de merge vale só para main/master.
Revisão 3 (26/10/2026, Gate 1 às 15h52): só troca a forma de nomear os papéis por papéis genéricos.
Revisão 4 (01/11/2026 — Engineering Flow 4.0): consolida a hierarquia do Jeff (engenheiro-chefe) acima dos bots de projeto, o rito de instalação limpa da v4.0 com `ai-memory` (Fábio Akita), a rastreabilidade de branches por Card (`AB-<ID>`), a promoção isolada da branch do card para a `main`/`master` (sem excluir a branch enquanto estiver apenas em homologação), o fechamento de Tag `vX.Y.Z`, a consolidação de SQL por Tag e a geração da OS para a Infra.

## Papéis e Hierarquia
As diretrizes seguem o engineering-flow 4.0. Os nomes entre parênteses são a instanciação atual, dada como exemplo e não como requisito:
1. **Aprovador humano** (Matheus): autoridade máxima e intransferível. Dá o ok explícito no Gate 1 (plano), no Gate 2 (commit e push) e na promoção para produção (`main`/`master`).
2. **Planejador / Engenheiro-Chefe** (Jeff, junto com o Matheus): está hierarquicamente **acima** dos bots de projeto. Recebe e tria demandas (cards, chamadas do Teams ou e-mails), garante que toda demanda tenha Card (`AB-<ID>`), consulta o `ai-memory`, fecha o envelope do Gate 1 com o Matheus, conduz o briefing diário das 7h (cobrando demandas em andamento e demandas paradas em homologação no `Planejamento/DEMANDAS.md`) e delega ordens de serviço ou instalações da v4.0 para os bots de projeto.
3. **Revisor/entrega** (bot de projeto, um por projeto/repositório): dono operacional do(s) repositório(s) do projeto. Executa a instalação limpa da v4.0 quando delegado pelo Jeff, mantém `.ai-memory.toml` e `Planejamento/DEMANDAS.md`, cria o LOCK (`task.lock`), alinha a OS com o implementador, confere o commit do Gate 2 e conduz push, PR, merge em homologação, promoção isolada para produção, Tag `vX.Y.Z`, pacote SQL e OS da Infra.
4. **Implementador / Harness** (Grok Build): executa o envelope aprovado dentro de uma sessão gerenciada pelo `ai-memory` (`ai-memory run`), avalia a saúde de testes no legado (unitário/integração se saudável, ou Playwright E2E completo se acoplado), roda os testes aprovados (`R0` obrigatório em bugs) e é o **único** que faz `git commit`, depois do Gate 2.
5. **Publicador / Validador opcional** (Jow): audita branches/releases (como na validação de releases do pack) ou apoia em casos extremos mediante confirmação explícita do Matheus.

## Rito de Instalação Limpa do Engineering Flow 4.0 (Delegação Jeff → Bot de Projeto)
Quando o Jeff delegar a instalação ou migração limpa para o Engineering Flow 4.0 em um projeto (com 1 ou múltiplos repositórios), o bot de projeto executa em cada repositório sob sua responsabilidade:
1. **Instalação limpa do Pack 4.0:**
   - Linux/WSL: `bash <caminho-engineering-flow>/scripts/install-agent-pack.sh <caminho-repo> --force --profile <perfis>`
   - Windows (PowerShell 7): `pwsh -File <caminho-engineering-flow>\scripts\install-agent-pack.ps1 -RepoPath <caminho-repo> -Force -Profile <perfis>`
   - O `--force` / `-Force` atualiza todas as skills, agentes `.grok/agents/`, prompts e contratos para a 4.0.0 criando backups automáticos (`*.agent-pack.backup-*`) de qualquer arquivo preexistente divergente e gravando `.agent-pack/state.txt` na versão `4.0.0`.
2. **Configuração do `ai-memory` (Fábio Akita):**
   - Criar ou validar `.ai-memory.toml` na raiz de cada repositório com:
     - `workspace = "<slug-do-projeto>"` (exatamente o mesmo `workspace` em todos os repositórios que pertencem ao mesmo sistema/projeto).
     - `project = "<slug-do-repositorio>"` (identificador único daquele repositório).
   - Garantir que o MCP bridge e os hooks do `ai-memory` estejam ativos para o ambiente do agente (`ai-memory install-mcp` / `ai-memory install-hooks`).
3. **Mapeamento e Convenções do Repositório (`AGENTS.md` + `docs/ai/`):**
   - Se o repositório ainda tiver `[UNVERIFIED]` em `AGENTS.md`, executar `$bootstrap-repo` (ou `$bootstrap-dotnet-repo`).
   - Preencher a seção `Convenções do projeto` em `AGENTS.md` com: branch de produção (`main`/`master`), branch de homologação (`hom`/`develop`/`hml`), workspace de planejamento (`on`), pacote SQL de release (`on` quando usar SQL Server) e namespacing do `.ai-memory.toml`.
4. **Inicialização do Controle de Demandas e Scripts SQL (`Planejamento/`):**
   - Criar na raiz do workspace de planejamento do projeto:
     - `Planejamento/DEMANDAS.md` (Quadro Vivo de Demandas);
     - `Planejamento/scripts/PendentesProducao/` (scripts SQL individuais por card `AB-<ID>-<slug>.sql`);
     - `Planejamento/scripts/Releases/` (pacotes SQL consolidados por Tag `vX.Y.Z_consolidado.sql` e `OS-INFRA-vX.Y.Z.md`);
     - `Planejamento/scripts/Aplicados/` (scripts já executados em produção, organizados por Tag `vX.Y.Z/`).

## Ciclo Completo de Entrega pelo Bot de Projeto (Por Card)
Cada revisor/entrega (bot de projeto) conduz o ciclo completo no seu repositório:
1. **Triagem e Branch por Card:**
   - Confere se a demanda possui número de card (`AB-<ID>`). Sem card, registra ou solicita ao Jeff/Matheus antes de iniciar.
   - Registra a demanda como `EM_DEV` em `Planejamento/DEMANDAS.md` e cria o LOCK (`.agent-pack/.runtime/task.lock`).
   - Cria a branch da tarefa com o número do card (`feat/AB-<ID>-<slug>` ou `fix/AB-<ID>-<slug>`) **sempre a partir da `main`/`master`** (salvo exceção explícita da seção Exceções abaixo).
2. **Execução e Conferência do Gate 2:**
   - Após o implementador (Grok Build) executar o plano aprovado, rodar os testes aprovados (`R0` em bugs: unitário/integração se saudável no legado, ou Playwright E2E completo se acoplado) e comitar após o ok do Matheus no Gate 2, o bot de projeto confere: diff contra o escopo do Gate 1, tabela de evidências do Gate 2, script SQL idempotente (se houver) em `Planejamento/scripts/PendentesProducao/AB-<ID>-<slug>.sql`, ausência de segredos/dados sensíveis e branch correta.
3. **Ida para Homologação (Mantendo a Branch Viva):**
   - Faz o push da branch do card (`feat/AB-<ID>-<slug>`).
   - Abre o PR e faz o merge da branch do card na branch de homologação/integração (`hom` / `develop` / `hml`).
   - **Não exclui a branch do card (`feat/AB-<ID>-<slug>`):** ela permanece intacta até que a demanda seja aprovada pelo consultor e promovida para a `main`/`master`.
   - Atualiza `Planejamento/DEMANDAS.md` para `EM_HOMOLOGACAO` (registrando a data e o consultor/responsável pelo teste).
4. **Promoção Isolada para Produção (Merge da Branch do Card na `main`):**
   - Quando o consultor valida a demanda (mesmo que outras demandas continuem em teste na branch de homologação) e o **Matheus dá o ok explícito para produção**, o bot de projeto faz o merge **da branch do card (`feat/AB-<ID>-<slug>`) diretamente na `main`/`master`**.
   - Dessa forma, a `main`/`master` recebe exclusivamente as demandas aprovadas para produção, enquanto a branch de homologação mantém todas as demandas em teste.
5. **Fechamento de Versão (Tag `vX.Y.Z`, SQL Consolidado, OS da Infra e Limpeza):**
   - Cria a Tag semântica anotada (`vX.Y.Z`) na `main`/`master` e faz push da tag.
   - Consolida apenas os scripts SQL dos cards incluídos naquela Tag em `Planejamento/scripts/Releases/vX.Y.Z_consolidado.sql`.
   - Gera o documento `Planejamento/scripts/Releases/OS-INFRA-vX.Y.Z.md` pronto para abertura do chamado de publicação na Infra.
   - **Exclui a branch do card (`feat/AB-<ID>-<slug>`)** que já subiu para a `main`/`master` e atualiza o status no `Planejamento/DEMANDAS.md` para `EM_PRODUCAO (vX.Y.Z)`.

## Regras travadas (não negociáveis)
- Merge em `main`/`master` só com ok explícito do Matheus, depois da evidência e da validação de homologação. Sem esse ok, nunca.
- Nenhum trabalho, commit ou push direto em `main`/`master`. `main`/`master` só recebe merge de branches de card aprovadas (ou da branch de integração quando o pacote inteiro da integração estiver 100% aprovado).
- Nunca excluir a branch do card (`feat/AB-<ID>-*` / `fix/AB-<ID>-*`) antes de ela ter sido mergeada na `main`/`master` e tagueada.
- Nunca force push.
- Todo repositório tem uma branch de homologação/integração que não é `main` nem `master` (por exemplo `hom`, `hml` ou `develop`).
- Quem comita continua sendo só o implementador (hoje, o Grok Build), depois do Gate 2. O LOCK expira no commit.
- Se um push, PR, merge ou tag for bloqueado ou falhar, o revisor/entrega para e avisa o Matheus/Jeff. Nada de contornar.

## Fluxo atualizado (passos 8 a 11)
8. **Gate 2:** com o ok explícito do Matheus após ver a evidência, o implementador (hoje, o Grok Build) comita na branch do card (`feat/AB-<ID>-<slug>`).
9. **Homologação:** o revisor/entrega (bot de projeto) confere o commit, faz o push da branch do card, abre o PR para a branch de homologação/integração, faz o merge na homologação **sem excluir a branch do card** e marca `EM_HOMOLOGACAO` em `Planejamento/DEMANDAS.md`.
10. **Ida para produção:** com o ok explícito do Matheus após a aprovação em homologação, o revisor/entrega faz o merge **da branch do card (`feat/AB-<ID>-<slug>`) na `main`/`master`**.
11. **Release e OS da Infra:** o revisor/entrega cria e empurra a Tag `vX.Y.Z` na `main`/`master`, consolida o SQL daquela Tag em `Releases/vX.Y.Z_consolidado.sql`, gera a `OS-INFRA-vX.Y.Z.md`, exclui a branch do card já promovida e atualiza o `DEMANDAS.md` para `EM_PRODUCAO (vX.Y.Z)`.

## Exceções e convenções por projeto
Quando houver conflito, a regra do projeto prevalece sobre o texto geral acima.

### GA (SEAL, cliente Durr): ajuste do Matheus por voz em 26/10/2026, às 10h06, registrado pelo bot-ga
- O bot-ga confere o commit, faz o push da branch da tarefa e abre o PR para a `ajustes-durr-convergint`.
- O merge desse PR só acontece com o ok explícito do Matheus, depois da evidência.
- Enquanto durar a migração da Durr, nenhum PR nem merge vai da `ajustes-durr-convergint` para main/master, porque a main é o repositório da Cial.
- Todo o trabalho do GA fica na `ajustes-durr-convergint`.

### B2TI (b2ti-gestaodepv): convenção de branches definida pelo Matheus por ligação em 26/10/2026, às 10h14, registrada pelo bot-b2ti
1. `main` é a branch de produção, e `develop` é a de integração. A `hml` é a de homologação.
2. A `dev` não é usada para nada e fica parada. Se alguém quiser excluí-la, a equipe exclui; nenhum bot mexe nela.
3. O desenvolvimento segue com branch por card (`feat/AB-<ID>-<slug>`) mantendo a branch viva até a promoção final para produção.
4. Nunca commit nem push direto em `develop`; ela só recebe código por PR da branch de tarefa.
5. EXCEÇÃO (Matheus, 26/10/2026, 10h26): no B2TI, o merge da branch de tarefa na `develop` SEMPRE precisa do ok explícito do Matheus, mesmo em mudança trivial. O item de merge automático na homologação não vale aqui. <!-- agent-pack:allow-mojibake -->
6. Diretriz do projeto: `C:\Repositorios\b2ti-gestaodepv\planejamento\diretrizes\diretriz-branches-b2ti.md` (a pasta `planejamento` é ignorada no .gitignore).

### SISMAN (Web e App)
- Branch de integração/homologação: `develop`, nos dois repos (`workspace = "sisman"` compartilhado no `.ai-memory.toml`), registrada pelo bot-sisman em 26/10/2026.

### FASTCRED (SOS Dinheiro)
- Branch de integração/homologação: `hom`.
