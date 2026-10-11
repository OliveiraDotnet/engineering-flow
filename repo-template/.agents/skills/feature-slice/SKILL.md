---
name: feature-slice
description: Plan and implement a bounded feature through the existing layers and contracts after human approval.
---

# feature-slice

Leia o contrato comum em docs/engineering-flow/workflow.md do repositório quando aplicável. Plano, aprovação humana, testes aprovados e evidência são requisitos do fluxo; autorização existente persiste. Em modo independente o agente ativo entrega; não há delegação automática.

Mapeie critério observável, entrada/saída, chamadores, autenticação, dados e camadas existentes. Proponha fatia mínima com contratos, impactos, riscos, testes, ferramentas/ambiente e evidência. Aprovação precede implementação; decisão material retorna ao humano.

Implemente no padrão do repo e mantenha interfaces fora do escopo. Valide comportamento e falhas relevantes somente no envelope aprovado. Evidencie cada critério, inclusive UI real quando aprovada, e indique implementado/não verificado quando testes não foram autorizados.
