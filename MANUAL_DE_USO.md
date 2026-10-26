# Manual do Engineering Flow 3.1

O fluxo é definido por papéis (aprovador humano, planejador, implementador, revisor/entrega e publicador opcional; veja a seção Papéis do [workflow.md](repo-template/docs/engineering-flow/workflow.md)). O implementador pode investigar, planejar, implementar e entregar sozinho, acumulando papéis. Não é necessário coordenador de outro provedor nem colaboração automática. Instanciação atual, como exemplo: planejador = Matheus com o Jeff; implementador = Grok Build; revisor/entrega = bot de projeto; Jow opcional. O fluxo completo está em [workflow.md](repo-template/docs/engineering-flow/workflow.md). Escolha a skill pelo [índice](SKILLS-INDEX.md).

**Gate 2:** commit e push exigem o ok explícito do Matheus, dado depois de ele ver as evidências. O commit é feito só pelo implementador. O push é feito só pelo publicador ou, com o publicador indisponível, pelo Matheus manualmente. Nenhum outro agente comita ou dá push. Nunca na main ou na master, nunca force push. Instanciação atual (exemplo, não requisito): implementador = Grok Build; publicador = Jow, hoje opcional, porque a diretriz de entrega pelo bot de projeto atribui push, PR e merge ao papel revisor/entrega nos passos 9 e 10.

## Seleção por demanda

| Demanda | Skill | Resultado esperado |
|---|---|---|
| Sistema desconhecido/existente/misto | bootstrap-repo | Mapa confirmado, regras concisas e plano sem produção alterada |
| Repo vazio/projeto novo | new-project | Requisitos, arquitetura e testes propostos antes do scaffolding aprovado |
| Defeito | bugfix | Causa observada/hipótese, plano mínimo, fix e R0 (falha antes, passa depois) |
| Funcionalidade | feature-slice | Fatia por critérios e contratos da stack existente |
| Refatoração/legado | refactor | Limites de comportamento preservado e caracterização aprovada |
| Revisão | review-change | Achados do diff/novos arquivos e evidência real |
| Entrega | complete-task | Critérios, resultados, artefatos e pendências |
| E2E de tela | web-e2e-playwright | Cenário Playwright, nomes de imagem e pasta de evidência; o pack não instala a ferramenta |
| Procedimento recorrente confirmado | create-repo-skill | Skill mínima útil conforme convenções do host |

Módulos: web-app (navegador e ASP clássico/SPA), web-dotnet (Razor/MVC/Blazor/Web Forms), dotnet-xunit-tests (somente xUnit), sqlserver-structure-review/db-change-sqlserver, mobile-app (nativo/híbrido/multiplataforma), quality (opt-in). Entradas *-dotnet continuam disponíveis para expertise .NET e obedecem ao contrato comum. Não carregar todas as skills em toda tarefa.

A pirâmide é unitário, integração em xUnit e e2e em Playwright. Dependências padrão no texto: Playwright, bUnit e Testcontainers. Nada disso é instalado pelo pack. Sem teste de integração, isso tem de ser reportado.

## Bug pequeno e R0

Pedido: “Ao salvar preço zero, a tela Web Forms rejeita o formulário”. Investigue binding, validação server-side e chamada SQL. Plano curto: aceitar zero e rejeitar negativo, tocar validator/service afetados, preservar contrato, R0 na framework real e cenário de tela. O planejador (hoje, o Jeff) opina antes. Só o Matheus dispensa o R0, com motivo registrado.

O R0 falha antes do fix e passa depois. As duas saídas vão para a evidência. Aprovação: “implemente e execute esses testes nesse ambiente”. Então execute e registre resultados. Se a resposta aprovar só o fix, implemente e indique não validado, perguntando se os checks devem ser incluídos.

No Trivial, o implementador (hoje, o Grok Build) manda um resumo curto com o arquivo alterado. Não basta uma linha de conferência. Exemplo de resumo: “arquivo alterado `PrecoValidator.cs`; R0 falhou antes (1 teste) e passou depois; critério: zero aceito.”

No Completo, a tabela e a bateria completa fecham o Gate 2. A imagem é obrigatória em critério de tela ou em evidência de cliente, gerada pelo Playwright E2E. A imagem acompanha o resultado observado.

| Critério | Cenário | Esperado | Observado | Artefato | Status |
|---|---|---|---|---|---|
| R0 | Regressão do zero rejeitado, antes e depois | falha antes, passa depois | [duas execuções] | `R0-antes.log`, `R0-depois.log` | [verificado] |
| Zero aceito | Salvar/recarregar preço 0 | Valor permanece 0 | [resultado real] | print Playwright do passo e do final | [verificado/falhou/pendente] |
| Integração | Suíte de integração do projeto | contagem estável | [ou ausência reportada] | `.trx` ou a frase “sem teste de integração” | [verificado/pendente] |

## Feature complexa

Pedido: “Novo filtro por status com API e listagem”. Plano explicita critérios, rotas/payloads, autenticação, consultas/índices, componentes, riscos e a pirâmide (unitário, integração xUnit, e2e Playwright no critério de tela). Mudança de contrato ou novo acesso a banco não cabe como detalhe mecânico; retorna ao humano. Não instale runner/browser automaticamente. Cada critério tem cenário e observado. Falha fica como falha até corrigir e reexecutar dentro do envelope. .NET Framework 4.8: o Matheus roda build e testes no VS 2022.

## Projeto novo e mobile

Repo vazio: confirme usuários, plataformas, dados/offline, integrações, restrições e critérios. Proponha arquitetura/stack/versões e estratégia de validação; escolha pelo problema e ferramentas, não por detector. Só faça scaffolding após aprovação. Para app nativo/híbrido/multiplataforma novo ou existente, confirme SDK e dispositivo/emulador/simulador. Teste UI/lógica nativa no ambiente autorizado. Browser pode cobrir a parte web híbrida, mas não prova bridge/permissões/lifecycle. Sem ambiente nativo, reporte implementação e validação pendente com preparo/roteiro, sem fingir execução.

## Evidência de aprovação e entrega

Registre envelope: “implementação do filtro + unitários no runner existente + integração xUnit + UI Playwright no localhost; banco externo não incluído”. Autorização persiste nas próximas etapas; ampliação material é nova decisão.

| Critério | Cenário | Esperado | Observado | Artefato | Status |
|---|---|---|---|---|---|
| Zero aceito | Salvar/recarregar preço 0 no ambiente aprovado | Valor permanece 0 | [resultado real] | [relatório/log/clip acessível e redigido] | [verificado/falhou/pendente] |
| Negativo rejeitado | Teste com -1 | Erro de validação | Não executado, teste não aprovado | Roteiro proposto | não verificado |

A tabela é exemplo, não execução. Reporte comandos/códigos de saída e testes realmente descobertos. Screenshots complementam cenários; não comprovam comportamento sozinhas. No Completo, a imagem de critério de tela ou de evidência de cliente é obrigatória e é gerada pelo Playwright E2E. Memória durável em docs/ai contém fonte/data; evidência e estado de execução ficam fora do repositório por padrão. Não inclua segredos/dados sensíveis.

Memória local; versionamento em Git previsto para a 3.2. Dado de cliente só entra se for útil para teste, e no máximo o username. CPF, dado bancário e dado sensível nunca entram.

Pesquisa oficial é sob demanda por incerteza técnica e versões; mapa existente evita redescoberta. Stack desconhecida exige investigar e reportar limites. Desktop/DevOps usam checks adequados ao host e ambiente aprovados. Um [assistente opcional](ASSISTENTE_OPCIONAL.md) (exemplo atual: Grok Bot) ajuda com handoff limitado, sem integração direta presumida.
