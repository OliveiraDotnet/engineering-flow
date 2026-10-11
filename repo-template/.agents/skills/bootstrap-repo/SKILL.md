---
name: bootstrap-repo
description: Discover an existing, mixed, unknown-stack or empty repository and propose concise project guidance from evidence.
---

# bootstrap-repo

Leia o contrato comum em docs/engineering-flow/workflow.md do repositório quando aplicável. Plano, aprovação humana, testes aprovados e evidência são requisitos do fluxo; autorização existente persiste. Em modo independente o agente ativo entrega; não há delegação automática.

Classifique Git roots, monorepo/projetos e pasta não Git. Inspecione status/diff e instruções aplicáveis sem alterar código. Execute scripts/inspect-repo.ps1 -RepoPath <repo> -Format json ou bash scripts/inspect-repo.sh <repo> relativos à skill carregada; esses scripts só inspecionam, não executam builds/testes/rede. Verifique as pistas em manifests, versões, código, scripts, CI, testes, infra e providers. Inspecione cada Git root separadamente; nenhum detector fecha a lista de tecnologias.

Em repo existente, proponha AGENTS.md curto com regras aplicáveis, mapa técnico com fontes/data e documentos úteis. Preserve regras próprias e alterações locais; marque hipóteses e comandos derivados como não confirmados. Só grave orientação/memória no escopo autorizado. Reuse contexto confirmado em tarefas seguintes.

Em repo vazio, use new-project para requisitos e plano de arquitetura/scaffolding antes de implementar. Tecnologia desconhecida exige mais investigação e procedimento verificável; consulte documentação oficial da versão quando necessário. Não crie boilerplate de memória, skills ou integrações por obrigação. Retorne mapa, sugestões de módulos, riscos, plano e lacunas de ferramentas/ambiente.
