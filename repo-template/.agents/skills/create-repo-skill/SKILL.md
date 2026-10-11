---
name: create-repo-skill
description: Create or refine a repository-specific skill for a confirmed recurring procedure; avoid skills for one-off tasks.
---

# create-repo-skill

Leia o contrato comum em docs/engineering-flow/workflow.md do repositório quando aplicável. Plano, aprovação humana, testes aprovados e evidência são requisitos do fluxo; autorização existente persiste. Em modo independente o agente ativo entrega; não há delegação automática.

Confirme repetição, gatilho, procedimento verificado, limites e benefício de reutilização no repo. Para tarefa única use o fluxo comum. Preserve convenções de skill do host; se skill-creator estiver disponível, aplique-a. Proponha localização e conteúdo no plano autorizado.

Crie somente SKILL.md com frontmatter name/description discriminante e passos que alterem decisões. Nome/pasta em lowercase-hyphen sob 64 caracteres. Acrescente scripts/referências apenas quando úteis; paths relativos à skill. Sem valores de segredos ou acoplamento ao estado operacional. Não sobrescreva skill própria homônima: apresente conflito/diff. Valide estrutura com ferramenta disponível/aprovada e, quando justificável/autorizado, cenário real; check estático não comprova comportamento do agente.
