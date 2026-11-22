---
name: bootstrap-repo
description: Discover an existing, mixed, unknown-stack or empty repository and propose concise project guidance from evidence.
---

# bootstrap-repo

Leia o contrato comum em docs/engineering-flow/workflow.md do repositório quando aplicável. Plano, aprovação humana, testes aprovados e evidência são requisitos do fluxo; autorização existente persiste. Em modo independente o agente ativo entrega; não há delegação automática.

Classifique Git roots, monorepo/projetos e pasta não Git. Inspecione status/diff e instruções aplicáveis sem alterar código. Execute `scripts/inspect-repo.ps1 -RepoPath <repo> -Format json -GenerateRepoMap` ou `bash scripts/inspect-repo.sh <repo> --generate-repo-map` relativos à skill carregada; esses scripts só inspecionam e geram o cache estrutural `.agent-pack/.runtime/repo-map.txt` (100% ignorado no Git, invalidado por commit), sem executar builds/testes/rede. Verifique as pistas em manifests, versões, código, scripts, CI, testes, infra e providers. Inspecione cada Git root separadamente; nenhum detector fecha a lista de tecnologias.

Em repo existente, leia `docs/engineering-flow/architecture-playbooks.md` (seção Brownfield) e **consolide** (nunca apague ou recrie do zero quando já existir) o `AGENTS.md` preservando regras próprias e envolvendo os blocos do SpecGuard 6 com marcadores `ef:managed`, preenchendo Convenções do Projeto (branch principal, branch de homologação, `Modo de operação dos papéis` assumindo `sessao-por-papel` se nada for especificado, `.ai-memory.toml` com `workspace` e `project`, workspace de planejamento com `Planejamento/DEMANDAS.md` e pacote SQL por Tag). Verifique e remova resquícios obsoletos de instalações anteriores (ex.: `.agent-pack/state.txt` ou sidecars `*.agent-pack.new` após mesclagem revisada). Produza `docs/ai/project-map.md`, `docs/ai/architecture.md` (separando **Padrões Ativos** de **Padrões Legados em Quarentena**) e `docs/ai/decisions-and-pendencies.md` (`Dxx` com `applies_to`), além da avaliação inicial de saúde de testes no legado. Marque hipóteses e comandos derivados como não confirmados. Só grave orientação/memória no escopo autorizado. Reuse `.agent-pack/.runtime/repo-map.txt`, contexto confirmado e o `ai-memory` em tarefas seguintes.

Em repo vazio, use new-project para requisitos e plano de arquitetura/scaffolding antes de implementar. Tecnologia desconhecida exige mais investigação e procedimento verificável; consulte documentação oficial da versão quando necessário. Não crie boilerplate de memória, skills ou integrações por obrigação. Retorne mapa, sugestões de módulos, riscos, plano e lacunas de ferramentas/ambiente.
