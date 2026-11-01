---
name: feature-slice
description: Plan and implement a bounded feature through the existing layers and contracts after human approval.
---

# feature-slice

Leia o contrato comum em docs/engineering-flow/workflow.md do repositório quando aplicável. Card (`AB-<ID>`), branch (`feat/AB-<ID>-<slug>` criada a partir da `main`/`master`), plano, aprovação humana, testes aprovados e evidência são requisitos do fluxo; autorização existente persiste. Em modo independente o agente ativo entrega; não há delegação automática.

Consulte o `ai-memory` do projeto e mapeie critério observável, entrada/saída, chamadores, autenticação, dados e camadas existentes. Avalie a **saúde de testes no legado**: proponha testes unitários/integração quando a arquitetura permitir testes isolados saudáveis; quando o código legado for acoplado e não permitir testes unitários sem refatoração arriscada fora do escopo, proponha validação via **Teste E2E Completo (Playwright)**. Proponha fatia mínima com contratos, impactos, riscos, testes, ferramentas/ambiente e evidência. Aprovação precede implementação; decisão material retorna ao humano.

Implemente no padrão do repo e mantenha interfaces fora do escopo. Valide comportamento e falhas relevantes somente no envelope aprovado. Evidencie cada critério, inclusive UI real / Playwright E2E quando aprovada, e indique implementado/não verificado quando testes não foram autorizados.
