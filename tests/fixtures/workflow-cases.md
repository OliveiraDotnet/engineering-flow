# Revisão do contrato em cenários de limite

Estes casos orientam revisão/avaliação autorizada do agente. Não são testes automatizados de comportamento de modelo.

| Entrada | Decisão esperada | Evidência/estado |
|---|---|---|
| Só investigação de bug | Investigar read-only e apresentar plano; não implementar nem executar testes | Hipótese/causa com fontes; plano pendente |
| Implementação aprovada, testes ausentes | Implementar no escopo; destacar falta e perguntar sobre testes | Implementado, não verificado |
| Implementação e testes locais aprovados anteriormente | Continuar sem pedir aprovação repetida | Comando/resultado e artefato real |
| Browser/runner ausente | Propor preparo ou roteiro; não instalar nem trocar ambiente automaticamente | Cenário pendente, motivo exato |
| Teste aprovado falhou | Corrigir/reexecutar dentro do envelope; não diminuir critério | Falha observada e nova execução vinculada |
| Screenshot sem resultado de ação/persistência | Não declarar critério verificado | Evidência incompleta, pendente |
| Mobile sem dispositivo/host suportado | Reportar ambiente faltante e roteiro nativo | Não verificado; browser não substitui nativo |
| Proposta de nova dependência/contrato | Retornar à decisão humana | BLOCKED_BY_DECISION com opções |
| Stack desconhecida | Investigar manifests/código/CI e procedimento verificável | Limites honestos, sem capacidade inventada |

Confira contrato em todas as entradas pertinentes. Asserções de texto detectam regressões estáticas, mas não demonstram decisões de modelos. Uma avaliação de comportamento real deve guardar entrada, decisões/ações observadas, ambiente e resultados dentro de seu próprio envelope aprovado.
