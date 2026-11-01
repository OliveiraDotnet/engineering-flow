---
name: bugfix
description: Diagnose and fix a reported bug with a bounded approved plan and criterion-linked evidence in the existing stack.
---

# bugfix

Leia o contrato comum em docs/engineering-flow/workflow.md do repositório quando aplicável. Plano, card (`AB-<ID>`), branch (`fix/AB-<ID>-<slug>` criada a partir da `main`/`master`), aprovação humana, testes aprovados e evidência são requisitos do fluxo; autorização existente persiste. Em modo independente o agente ativo entrega; não há delegação automática.

Consulte o `ai-memory` do projeto e trace comportamento atual/esperado e caminho afetado. Distinga causa observada de hipótese. Reprodução por teste ou execução de app requer aprovação de cenário/ambiente; investigação read-only pode caracterizar o defeito antes disso.

No Gate 1, avalie a **saúde de testes no código legado**: se for saudável criar teste unitário/integração sem refatoração estrutural arriscada fora do escopo, proponha unitário/integração; se o código legado for acoplado (ex: Web Forms, ASP clássico, UI acoplada ou SQL sem isolamento saudável), é proibido forçar refatoração invasiva só para criar unitário e a validação (`R0` e critérios) sobe obrigatoriamente para **Teste E2E Completo (Playwright)**.

Apresente plano pequeno com card, branch, critério de aceitação, fix mínimo, avaliação de saúde de testes, riscos e o `R0`. Regressão em bug (`R0`) é obrigatória: o teste falha antes e passa depois. O planejador (hoje, o Jeff) opina antes. Só o Matheus dispensa, de forma explícita e registrada no plano com o motivo. A pirâmide é unitário, integração em xUnit e e2e em Playwright. Sem teste de integração, isso tem de ser reportado (incluindo quando substituído por E2E completo no legado). Playwright, bUnit e Testcontainers são dependências padrão no texto; o pack não as instala. No Trivial, a evidência é um resumo curto com o arquivo alterado. No Completo, a imagem é obrigatória em critério de tela, em E2E de legado acoplado ou em evidência de cliente, gerada pelo Playwright E2E.

Depois da aprovação implemente preservando contratos fora do defeito, sem refatoração incidental. Execute apenas validação aprovada, corrija falhas e repita dentro do envelope. Use expertise .NET, web/ASP clássico, SQL ou mobile conforme evidência. Entregue causa, diff e estado real da validação.
