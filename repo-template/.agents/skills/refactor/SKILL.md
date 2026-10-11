---
name: refactor
description: Plan a behavior-preserving refactor of existing or legacy code with explicit boundaries and approved characterization checks.
---

# refactor

Leia o contrato comum em docs/engineering-flow/workflow.md do repositório quando aplicável. Plano, aprovação humana, testes aprovados e evidência são requisitos do fluxo; autorização existente persiste. Em modo independente o agente ativo entrega; não há delegação automática.

Mapeie comportamento, contratos, dependências e pontos sensíveis do legado. Defina limites e invariantes; não modernize stack ou dependências por recomendação genérica. Proponha mudanças pequenas e caracterização/regressão com ambiente e evidência antes da aprovação.

Após aprovação refatore preservando comportamento; alterações funcionais são decisão separada. Execute somente checks aprovados. Sem testes autorizados, entregue refatoração não validada e riscos; leitura de diff não prova equivalência de runtime.
