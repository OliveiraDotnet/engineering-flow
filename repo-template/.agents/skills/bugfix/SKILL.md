---
name: bugfix
description: Diagnose and fix a reported bug with a bounded approved plan and criterion-linked evidence in the existing stack.
---

# bugfix

Leia o contrato comum em docs/engineering-flow/workflow.md do repositório quando aplicável. Plano, aprovação humana, testes aprovados e evidência são requisitos do fluxo; autorização existente persiste. Em modo independente o agente ativo entrega; não há delegação automática.

Trace comportamento atual/esperado e caminho afetado. Distinga causa observada de hipótese. Reprodução por teste ou execução de app requer aprovação de cenário/ambiente; investigação read-only pode caracterizar o defeito antes disso.

Apresente plano pequeno com critério de aceitação, fix mínimo, riscos e o R0. Regressão em bug é obrigatória: o teste falha antes e passa depois. O planejador (hoje, o Jeff) opina antes. Só o Matheus dispensa, de forma explícita e registrada no plano com o motivo. A pirâmide é unitário, integração em xUnit e e2e em Playwright. Sem teste de integração, isso tem de ser reportado. Playwright, bUnit e Testcontainers são dependências padrão no texto; o pack não as instala. No Trivial, a evidência é um resumo curto com o arquivo alterado. No Completo, a imagem é obrigatória em critério de tela ou em evidência de cliente, gerada pelo Playwright E2E.

Depois da aprovação implemente preservando contratos fora do defeito, sem refatoração incidental. Execute apenas validação aprovada, corrija falhas e repita dentro do envelope. Use expertise .NET, web/ASP clássico, SQL ou mobile conforme evidência. Entregue causa, diff e estado real da validação.
