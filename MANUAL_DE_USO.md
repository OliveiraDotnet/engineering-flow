# Manual do Engineering Flow 5.0

O fluxo é definido por papéis em hierarquia clara: **aprovador humano → planejador/engenheiro-chefe → revisor/entrega por repositório → Implementor + Tester (no harness) → publicador/validador opcional** (veja a seção Papéis do [workflow.md](repo-template/docs/engineering-flow/workflow.md)). O fluxo não depende de nenhuma ferramenta específica: o desenvolvedor pode operar **com um único harness acumulando todos os papéis** (modo standalone) ou **distribuir os papéis entre agentes/bots independentes**. O fluxo completo está em [workflow.md](repo-template/docs/engineering-flow/workflow.md). Escolha a skill pelo [índice](SKILLS-INDEX.md).

**Gate 2:** commit e push exigem o ok explícito do aprovador humano, dado depois de ele ver as evidências. O commit é feito só pelo `Implementor` (`--commit-gate2`). O push é feito só pelo revisor/entrega (ou publicador) ou, quando indisponível, pelo aprovador humano manualmente. Nenhum outro agente comita ou dá push. Nunca na main ou na master, nunca force push. A diretriz de entrega pelo revisor de repositório atribui push, PR, merge em homologação (mantendo a branch do card viva), promoção isolada da branch do card na `main`/`master`, Tag `vX.Y.Z`, consolidação SQL e OS da Infra ao papel revisor/entrega nos passos 9 a 11.

## Seleção por demanda

| Demanda | Skill | Resultado esperado |
|---|---|---|
| Sistema desconhecido/existente/misto | bootstrap-repo | Mapa confirmado, convenções de branch/SQL e regras concisas em `AGENTS.md` (único arquivo versionado) sem produção alterada |
| Repo vazio/projeto novo | new-project | Requisitos, arquitetura e testes propostos antes do scaffolding aprovado |
| Defeito | bugfix | Card `AB-<ID>`, branch `fix/AB-<ID>-<slug>`, avaliação de saúde de testes no legado, plano mínimo, fix e `R0` (`R0-RED` antes, `R0-GREEN` depois) |
| Funcionalidade | feature-slice | Card `AB-<ID>`, branch `feat/AB-<ID>-<slug>`, fatia por critérios e contratos da stack existente |
| Ciclo fechado Código ↔ Teste | harness-cycle | Execução coordenada `run-implementor` ↔ `run-tester` (`supervise-harness`, máx. 3 tentativas) e commit autorizado no Gate 2 |
| Refatoração/legado | refactor | Limites de comportamento preservado e caracterização aprovada |
| Revisão | review-change | Achados do diff/novos arquivos e evidência real |
| Entrega | complete-task | Critérios, resultados, artefatos e pendências |
| E2E de tela ou legado acoplado | web-e2e-playwright | Cenário Playwright, nomes de imagem e pasta de evidência; o pack não instala a ferramenta |
| Procedimento recorrente confirmado | create-repo-skill | Skill mínima útil conforme convenções do host |

Módulos: web-app (navegador e ASP clássico/SPA), web-dotnet (Razor/MVC/Blazor/Web Forms), dotnet-xunit-tests (somente xUnit), sqlserver-structure-review/db-change-sqlserver, mobile-app (nativo/híbrido/multiplataforma), quality (opt-in). Entradas *-dotnet continuam disponíveis para expertise .NET e obedecem ao contrato comum. Não carregar todas as skills em toda tarefa.

A pirâmide é unitário, integração em xUnit e e2e em Playwright. No legado, avalia-se primeiro se é saudável criar unitário/integração; quando acoplado, sobe-se para Playwright E2E completo sem forçar refatoração invasiva. Dependências padrão no texto: Playwright, bUnit e Testcontainers. Nada disso é instalado pelo pack. Sem teste de integração, isso tem de ser reportado.

## Bug pequeno, Saúde no Legado e Loop `R0-RED` → `Implementor` → `R0-GREEN`

Pedido (Card `AB-1042`): “Ao salvar preço zero, a tela Web Forms rejeita o formulário”. Consulte a documentação do projeto (`docs/ai/` e `ai-memory` quando disponível), investigue binding, validação server-side, chamada SQL e avalie se a validação pode ser testada em unitário de forma saudável ou se exige Playwright E2E completo. Plano curto: branch `fix/AB-1042-preco-zero` criada a partir da `main`, aceitar zero e rejeitar negativo, tocar validator/service afetados, preservar contrato, `R0` (unitário se isolado ou Playwright E2E completo se acoplado ao Web Forms) e cenário de tela. O planejador opina antes. Só o aprovador humano dispensa o `R0`, com motivo registrado.

No ciclo de harness (`harness-cycle`):
1. O `Tester` roda em modo `R0-RED` e comprova que o teste falha antes da correção (`R0-antes.log`).
2. O `Implementor` aplica a correção na working tree (sem comitar).
3. O `Tester` roda em modo `R0-GREEN` / `FULL` (`R0-depois.log`) e grava `.agent-pack/evidencias/AB-1042/EVIDENCIA.md` e `.agent-pack/.runtime/test-status.json`. Se falhar, o supervisor devolve o erro ao `Implementor` (até 3 tentativas).

No Trivial, o implementador manda um resumo curto com o arquivo alterado. Não basta uma linha de conferência. Exemplo de resumo: “arquivo alterado `PrecoValidator.cs`; R0 falhou antes (1 teste) e passou depois; critério: zero aceito.”

No Completo, a tabela e a bateria completa fecham o Gate 2. A imagem é obrigatória em critério de tela, em validação E2E de legado acoplado ou em evidência de cliente, gerada pelo Playwright E2E. A imagem acompanha o resultado observado.

| Critério | Cenário | Esperado | Observado | Artefato | Status |
|---|---|---|---|---|---|
| R0 | Regressão do zero rejeitado, antes e depois | falha antes, passa depois | [duas execuções] | `R0-antes.log`, `R0-depois.log` | [verificado] |
| Zero aceito | Salvar/recarregar preço 0 | Valor permanece 0 | [resultado real] | print Playwright do passo e do final | [verificado/falhou/pendente] |
| Integração | Suíte de integração do projeto | contagem estável | [ou ausência reportada por legado acoplado] | `.trx` ou a frase “sem teste de integração (coberto por E2E)” | [verificado/pendente] |

## Feature complexa

Pedido (Card `AB-1045`): “Novo filtro por status com API e listagem”. Plano explicita card, branch `feat/AB-1045-filtro-status` (a partir da `main`), critérios, rotas/payloads, autenticação, consultas/índices, script SQL idempotente `AB-1045-filtro-status.sql`, componentes, riscos e a camada saudável da pirâmide (unitário, integração xUnit, e2e Playwright). Mudança de contrato ou novo acesso a banco não cabe como detalhe mecânico; retorna ao humano. Não instale runner/browser automaticamente. Cada critério tem cenário e observado. Falha fica como falha até corrigir e reexecutar dentro do envelope. .NET Framework 4.8 sem CLI: o aprovador humano roda build e testes no VS 2022.

## Projeto novo e mobile

Repo vazio: confirme usuários, plataformas, dados/offline, integrações, restrições e critérios. Proponha arquitetura/stack/versões e estratégia de validação; escolha pelo problema e ferramentas, não por detector. Só faça scaffolding após aprovação. Para app nativo/híbrido/multiplataforma novo ou existente, confirme SDK e dispositivo/emulador/simulador. Teste UI/lógica nativa no ambiente autorizado. Browser pode cobrir a parte web híbrida, mas não prova bridge/permissões/lifecycle. Sem ambiente nativo, reporte implementação e validação pendente com preparo/roteiro, sem fingir execução.

## Evidência de aprovação, Homologação e Produção

Registre envelope: “implementação do filtro + unitários no runner existente + integração xUnit + UI Playwright no localhost; banco externo não incluído”. Autorização persiste nas próximas etapas; ampliação material é nova decisão.

| Critério | Cenário | Esperado | Observado | Artefato | Status |
|---|---|---|---|---|---|
| Zero aceito | Salvar/recarregar preço 0 no ambiente aprovado | Valor permanece 0 | [resultado real] | [relatório/log/clip acessível e redigido] | [verificado/falhou/pendente] |
| Negativo rejeitado | Teste com -1 | Erro de validação | Não executado, teste não aprovado | Roteiro proposto | não verificado |

A tabela é exemplo, não execução. Reporte comandos/códigos de saída e testes realmente descobertos. Screenshots complementam cenários; não comprovam comportamento sozinhas. No Completo, a imagem de critério de tela, de validação E2E em legado acoplado ou de evidência de cliente é obrigatória e é gerada pelo Playwright E2E.

Memória persistente e isolamento: utiliza `docs/ai/` e, quando configurado no ambiente do harness, o **`ai-memory` (`akitaonrails/ai-memory`)** via `.ai-memory.toml` e MCP. Como bots externos não compartilham necessariamente o MCP do harness, os handoffs acontecem por arquivos explícitos (`TASK_SPEC.md`, `EVIDENCIA.md`, `test-status.json`, `Planejamento/DEMANDAS.md`). Dado de cliente só entra se for útil para teste, e no máximo o username. CPF, dado bancário, credenciais e dado sensível nunca entram.

Um [assistente opcional](ASSISTENTE_OPCIONAL.md) pode apoiar os papéis de planejamento e revisão conforme [ASSISTENTE_WORKFLOW.md](ASSISTENTE_WORKFLOW.md).
