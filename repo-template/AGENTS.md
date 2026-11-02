# Engineering Flow 4.0 — orientação do projeto

Template ativo: [UNVERIFIED] não é evidência do repo. Use bootstrap-repo quando faltar contexto; reuse mapa confirmado e o `ai-memory`. Recarregue instruções quando o host exigir.

## Fatos a confirmar

- Git roots, projetos, stack/toolchain/versões: [UNVERIFIED]
- Comandos build/run/test e ambiente: [UNVERIFIED]
- Frameworks de testes, CI, dados/integrações e limites: [UNVERIFIED]

Confirme em código, manifests, scripts e CI. Registre fontes/data em docs/ai/project-map.md e no `ai-memory` somente quando útil; preserve regras próprias.

## Contrato, hierarquia e autorização

Leia docs/engineering-flow/workflow.md para a demanda; capabilities.md somente para a área afetada. Matheus é a sole decision authority (papel de aprovador humano). Papéis e hierarquia do fluxo: aprovador humano (Matheus), planejador/engenheiro-chefe (Jeff), revisor/entrega (bot de projeto por repo), implementador/harness (Grok Build) e publicador/validador opcional (Jow); a tabela e a instanciação atual estão em workflow.md, seção Papéis.

Triagem por card (`AB-<ID>`) → entender → plano técnico (Gate 1) → aprovação humana → implementar na branch do card → testes aprovados → evidências → Gate 2 (commit) → homologação → produção isolada, Tag, SQL e OS de Infra. Gate 1 define o execution envelope: card, branch (`feat/AB-<ID>-<slug>` ou `fix/AB-<ID>-<slug>` criada a partir da `main`/`master`), objetivo, critérios, escopo/não objetivos, componentes, riscos/decisões, saúde de testes no legado (unitário/integração se saudável, ou Playwright E2E completo quando acoplado), ferramentas/ambiente e evidências. Investigação/plano não autorizam implementar. Autorização explícita existente persiste; não peça novamente por passos cobertos.

Em bug, o teste de regressão `R0` (falha antes do fix, passa depois — na camada unitária/integração se saudável ou via Playwright E2E completo se legado acoplado) faz parte do plano padrão dos dois modos e é coberto pela aprovação do Gate 1 (só o Matheus dispensa explicitamente com motivo registrado). Fora do `R0`, ausência de pedido de testes não autoriza execução automática: destaque a validação faltante e pergunte se deve incluí-la. Se só implementação foi aprovada, entregue como não validado com checks pendentes. Mudança material de escopo, comportamento, arquitetura/contratos, dependências, segurança/dados ou validação retorna ao humano (BLOCKED_BY_DECISION).

**Gate 2:** commit e push exigem o ok explícito do Matheus, dado depois de ele ver as evidências. O commit é feito só pelo implementador. O push é feito só pelo publicador ou, com o publicador indisponível, pelo Matheus manualmente. Nenhum outro agente comita ou dá push. Nunca na main ou na master, nunca force push. Instanciação atual (exemplo, não requisito): implementador = Grok Build; publicador = Jow, hoje opcional, porque a diretriz de entrega pelo bot de projeto atribui push, PR, merge na homologação (mantendo a branch do card viva), merge isolado da branch do card na `main`/`master`, Tag `vX.Y.Z`, consolidação de SQL e geração da OS da Infra ao papel revisor/entrega nos passos 9 a 11. Preserve mudanças existentes, encoding e contratos fora do escopo; não exponha segredos/dados pessoais.

## LOCK

O revisor/entrega do repositório (hoje, o bot de projeto) confere se já existe `.agent-pack/.runtime/task.lock` e então cria o dele. O arquivo não é versionado. Conteúdo: a tarefa (card), a branch, o responsável (campo `bot`) e a data e hora em que foi criado. O LOCK expira no commit da tarefa. Trava esquecida: quem libera é o revisor/entrega da demanda.

## Modos, anti-padrões e limites

Modos Trivial e Completo, orçamento por fase e Gate de 100% estão em workflow.md; na dúvida, Completo. Leia docs/engineering-flow/anti-patterns.md antes de qualquer tarefa. Teto de fase excedido: pare e devolva com status pendente / UNABLE_TO_VALIDATE.

## Operação e seleção

O pack configura um único implementador; na 4.0 é o Grok Build (exemplo atual, não requisito do método). O agente ativo conduz a entrega dentro do seu papel. Colaboração é opcional; não lance subagentes automaticamente nem presuma API entre provedores. Handoff real usa agent-work-order, contexto local preservado, ferramentas verificadas e isolamento para escritores concorrentes.

Leia só o índice de skills do pack e carregue apenas a skill escolhida. Sem uma skill que caiba, ou sem diretriz, pare e pergunte. Skills gerais: bootstrap-repo, new-project, bugfix, feature-slice, refactor, review-change, complete-task. Crie skill específica só para procedimento recorrente confirmado via create-repo-skill. Nomes `$skill` são invocação nativa, não shell. Leia só skills/referências pertinentes.

Módulos mantêm expertise: .NET moderno/Framework e xUnit quando aplicável; web-app, web-dotnet e web-e2e-playwright; SQL Server read-only com sqlserver-structure-review e mudanças aprovadas por card com db-change-sqlserver; mobile-app para nativo/híbrido/multiplataforma. Desktop e DevOps seguem capabilities.md. Nomes antigos *-dotnet e scripts *-agent-pack permanecem. Detecção não autoriza migrar legado ou instalar dependências.

Especialistas são opcionais: repo-explorer, implementer, dotnet-implementer, test-guardian, change-reviewer e perfis instalados. Se indisponível, execute o papel localmente dentro do envelope.

## Contexto e conclusão

Pesquise antes de abrir arquivos (consultando primeiro o `ai-memory` e `docs/ai/project-map.md`); reuse fatos confirmados. Consulte docs oficiais da versão apenas por incerteza/decisão concreta. Detectores são pistas e tecnologias desconhecidas exigem investigação, sem inventar capacidades.

Detecte ferramentas/runners antes de executar somente testes aprovados. Checks de encoding também entram no envelope; preserve encoding legado confirmado e reporte limitações. Vincule critério → cenário → esperado → observado → artefato → status. Separe implementado, verificado, falhou e pendente/não verificado. Revise diff/novos arquivos; não declare teste aprovado por leitura de código ou resumo.

Mantenha evidências/sessões/estado transitório fora de memória versionada. Em docs/ai e no `ai-memory` guarde só conhecimento durável verificado, fonte/data e dados mínimos redigidos. Entregue causa/motivação, arquivos, resultados reais, links, decisões e riscos.

## Convenções do projeto

Template (AGENTS.md é artefato `merge`): cada repo preenche; nada aqui é padrão.

- Branch principal (produção): [`main`|`master`]
- Branch de homologação/integração: [`hom`|`develop`|`hml`]
- Workspace de planejamento (planning-workspace.md, inclui `DEMANDAS.md`): [on|off]; raiz: [<caminho>]
- Pacote SQL de release por Tag e OS da Infra (sql-release-package.md): [on|off]
- Cópia duplicada dos scripts pendentes no repo: [sim|não]; caminho: [<caminho>]
- Nível de validação SQL: [syntax-only|execute]
- Versionamento do pack: [versionado|local] (padrão: versionado). `local` mantém os arquivos do pack no projeto sem versioná-los; AGENTS.md e docs/ai continuam versionados. Ver "Modo pack local" em INSTRUCOES_DETALHADAS.md do pack.
- Namespacing `.ai-memory.toml`: `workspace = "[<slug-projeto>]"`, `project = "[<slug-repo>]"`
- Provider (GitHub/Azure DevOps) não é declarado aqui.

## Memória Persistente (`ai-memory` + `docs/ai`)

A memória de longo prazo e handoffs entre sessões utilizam o **`ai-memory` (`akitaonrails/ai-memory`)** via MCP (`ai-memory mcp-bridge`), workstreams (`ai-memory run`) e configuração `.ai-memory.toml` por repositório (compartilhando o mesmo `workspace` quando um projeto possui múltiplos repositórios), complementando a documentação arquitetural versionada em `docs/ai/`. Dado de cliente só entra se for útil para teste, e no máximo o username. CPF, dado bancário, credenciais e dado sensível nunca entram.
