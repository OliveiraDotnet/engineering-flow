---
name: update-engineering-flow
description: Plan and safely update an Engineering Flow or older Agent Pack installation, preserving local rules, ownership and selected profiles/integrations.
---

# Atualizar Engineering Flow

Leia docs/engineering-flow/workflow.md e [update-agent-pack](../update-agent-pack/SKILL.md), a implementação compatível da reconciliação. Inspecione o destino e a fonte confiável indicada; use scripts/update-engineering-flow em Check/--check antes de Apply/--apply. O updater usa `.agent-pack/state.txt`, IDs estáveis e catálogos confiáveis, sem inventar seleção ou instalar perfis novos.

Apresente diferenças, conflitos, riscos e validação proposta; obtenha aprovação humana ou reuse a existente antes de aplicar. Resolva cada ID explicitamente, preservando managed customizado, merge próprio e seed de memória. Execute somente checks aprovados, revise diff/novos arquivos e entregue resultados/pendências. Não use Force, não reescreva catálogos históricos nem amplie providers automaticamente.
