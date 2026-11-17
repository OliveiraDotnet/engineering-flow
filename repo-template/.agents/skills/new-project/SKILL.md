---
name: new-project
description: Plan and scaffold a new application after human approval, including empty repositories and web, backend, desktop or mobile targets.
---

# new-project

Leia o contrato comum em docs/engineering-flow/workflow.md do repositório quando aplicável. Plano, aprovação humana, testes aprovados e evidência são requisitos do fluxo; autorização existente persiste. Em modo independente o agente ativo entrega; não há delegação automática.

Confirme problema, usuários, requisitos funcionais e não funcionais, plataformas, integrações, dados, critérios e restrições. Separe explicitamente **fato**, **suposição** e **pergunta aberta**, e classifique cada demanda entre escopo **core/contratual**, **necessário à solução** ou **ampliação de escopo** antes de assumi-la. Descubra arquivos existentes, ferramentas e convenções; repo vazio não implica escolha automática de stack.

Proponha arquitetura, tecnologias/versões com justificativa, estrutura mínima, contratos, armazenamento, matriz inicial de rastreabilidade (`Requisito → Tela/Endpoint → Cenário → Tabela/Migration`), testes/ambiente e evidências. Registre decisões e pendências bloqueantes em `docs/ai/decisions-and-pendencies.md` (incluindo eventual **liberação parcial** do Gate 1 apenas para base técnica/persistência dev) e fronteiras/saídas externas em `docs/ai/external-boundaries.md` (proibindo CDNs/telemetria não inventariadas). Confira `.gitignore` antes de criar arquivos locais de configuração (`*.example.*` sem segredos) e verifique o **grafo transitivo real** de dependências via lock file (`RestoreLockedMode` em CI). Consulte fontes oficiais só para decisões/incertezas reais. Obtenha aprovação humana antes de scaffolding, dependências ou preparação faltante. Implemente fatias verificáveis dentro do envelope; mobile inclui alvos e ambiente nativo/híbrido/multiplataforma disponível. Entregue resultados e pendências pelo contrato comum.
