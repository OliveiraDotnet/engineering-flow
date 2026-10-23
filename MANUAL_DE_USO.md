# Manual do Engineering Flow 3.0

O Grok Build pode investigar, planejar, implementar e entregar sozinho. Não é necessário coordenador de outro provedor nem colaboração automática. O fluxo completo está em [workflow.md](repo-template/docs/engineering-flow/workflow.md). Escolha a skill pelo [índice](SKILLS-INDEX.md).

**Gate 2:** commit e push exigem o ok explícito do Matheus, dado depois de ele ver as evidências. O commit é feito só pelo Grok Build. O push é feito só pelo Jow ou, com o Jow indisponível, pelo Matheus manualmente. Nenhum outro agente comita ou dá push. Nunca na main ou na master, nunca force push.

## Seleção por demanda

| Demanda | Skill | Resultado esperado |
|---|---|---|
| Sistema desconhecido/existente/misto | bootstrap-repo | Mapa confirmado, regras concisas e plano sem produção alterada |
| Repo vazio/projeto novo | new-project | Requisitos, arquitetura e testes propostos antes do scaffolding aprovado |
| Defeito | bugfix | Causa observada/hipótese, plano mínimo, fix e regressão aprovada |
| Funcionalidade | feature-slice | Fatia por critérios e contratos da stack existente |
| Refatoração/legado | refactor | Limites de comportamento preservado e caracterização aprovada |
| Revisão | review-change | Achados do diff/novos arquivos e evidência real |
| Entrega | complete-task | Critérios, resultados, artefatos e pendências |
| Procedimento recorrente confirmado | create-repo-skill | Skill mínima útil conforme convenções do host |

Módulos: web-app (navegador e ASP clássico/SPA), web-dotnet (Razor/MVC/Blazor/Web Forms), dotnet-xunit-tests (somente xUnit), sqlserver-structure-review/db-change-sqlserver, mobile-app (nativo/híbrido/multiplataforma), quality (opt-in). Entradas *-dotnet continuam disponíveis para expertise .NET e obedecem ao contrato comum. Não carregar todas as skills em toda tarefa.

## Bug pequeno

Pedido: “Ao salvar preço zero, a tela Web Forms rejeita o formulário”. Investigue binding, validação server-side e chamada SQL. Plano curto: aceitar zero e rejeitar negativo, tocar validator/service afetados, preservar contrato, propor regressão na framework real e cenário navegador salvar/recarregar com ambiente de teste. Aprovação: “implemente e execute esses testes nesse ambiente”. Então execute e registre resultados, inclusive console/rede quando pertinente. Se a resposta aprovar só o fix, implemente e indique não validado, perguntando se os checks devem ser incluídos.

## Feature complexa

Pedido: “Novo filtro por status com API e listagem”. Plano explicita critérios, rotas/payloads, autenticação, consultas/índices, componentes, riscos e testes unitários/integração/UI. Mudança de contrato ou novo acesso a banco não cabe como detalhe mecânico; retorna ao humano. Não instale runner/browser automaticamente. Cada critério tem cenário e observado. Falha fica como falha até corrigir e reexecutar dentro do envelope.

## Projeto novo e mobile

Repo vazio: confirme usuários, plataformas, dados/offline, integrações, restrições e critérios. Proponha arquitetura/stack/versões e estratégia de validação; escolha pelo problema e ferramentas, não por detector. Só faça scaffolding após aprovação. Para app nativo/híbrido/multiplataforma novo ou existente, confirme SDK e dispositivo/emulador/simulador. Teste UI/lógica nativa no ambiente autorizado. Browser pode cobrir a parte web híbrida, mas não prova bridge/permissões/lifecycle. Sem ambiente nativo, reporte implementação e validação pendente com preparo/roteiro, sem fingir execução.

## Evidência de aprovação e entrega

Registre envelope: “implementação do filtro + unitários no runner existente + UI no localhost; banco externo não incluído”. Autorização persiste nas próximas etapas; ampliação material é nova decisão.

| Critério | Cenário | Esperado | Observado | Artefato | Status |
|---|---|---|---|---|---|
| Zero aceito | Salvar/recarregar preço 0 no ambiente aprovado | Valor permanece 0 | [resultado real] | [relatório/log/clip acessível e redigido] | [verificado/falhou/pendente] |
| Negativo rejeitado | Teste com -1 | Erro de validação | Não executado, teste não aprovado | Roteiro proposto | não verificado |

A tabela é exemplo, não execução. Reporte comandos/códigos de saída e testes realmente descobertos. Screenshots complementam cenários; não comprovam comportamento sozinhas. Memória durável em docs/ai contém fonte/data; evidência e estado de execução ficam fora do repositório por padrão. Não inclua segredos/dados sensíveis.

Pesquisa oficial é sob demanda por incerteza técnica e versões; mapa existente evita redescoberta. Stack desconhecida exige investigar e reportar limites. Desktop/DevOps usam checks adequados ao host e ambiente aprovados. [Grok Bot](GROK_BOT_OPCIONAL.md) é ajuda opcional com handoff limitado, sem integração direta presumida.
