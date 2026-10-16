# Anti-padrões

O agente lê este arquivo antes de toda tarefa, nos modos Trivial e Completo. Entradas vêm somente de incidentes reais; não acrescente hipóteses. Uma linha por incidente.

| Sintoma | Causa | Correção |
|---|---|---|
| Servidor gravou o decimal `"100.00"` como `10000`. | Parse dependente da cultura regional pt-BR (ponto lido como separador de milhar). | Parser/tipo que aceite vírgula e ponto, ou cultura invariante explícita; teste cobrindo os dois formatos. |
| UI enviou o campo `anexos`, mas o servidor só persistia `anexosExecucao`; anexos perdidos sem erro. | Contrato UI/API divergente e não verificado. | Aceitar o nome de campo correto e adicionar teste de contrato entre UI e API. |
| Texto de erro de uma CDN salvo como se fosse URL. | Resposta não-sucesso tratada como sucesso; URL não validada. | Rejeitar respostas não-sucesso e validar a URL antes de persistir. |
