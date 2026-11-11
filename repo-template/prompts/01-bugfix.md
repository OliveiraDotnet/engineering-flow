# bugfix

Use $bugfix pelo host ativo. Leia o contrato docs/engineering-flow/workflow.md. Consulte o `ai-memory` do projeto, investigue, avalie a saúde de testes no código legado, apresente plano com `R0` e aguarde aprovação humana (Gate 1) antes de implementar; autorização existente persiste.

Card / Demanda: [ex: AB-1042 — descreva]
Branch: [fix/AB-1042-slug]
Atual/esperado e critérios: [preencha]
Contexto/evidência: [caminhos, ambiente, sem segredos]
Restrições/não objetivos: [preencha]
Testes/cenários e ambiente: [Em bug, o R0 (falha antes, passa depois) é obrigatório por padrão no plano do Gate 1: unitário/integração se saudável no legado, ou Playwright E2E completo se legado acoplado. Só o aprovador humano dispensa explicitamente]

Retorne plano com componentes, avaliação de saúde de testes, `R0`, riscos/decisões, ferramentas e evidências. Após aprovação, entregue implementado/verificado/falhou/pendente com links reais; confirme preparo faltante antes de usar outro ambiente.
