# SpecGuard 6 — Playbooks de Arquitetura (Greenfield vs. Brownfield)

> Guia curto carregado sob demanda durante `$bootstrap-repo`, `$new-project` ou mudanças arquiteturais **Tier 2**. O objetivo é evitar *over-engineering* em projetos novos e *architecture drift* em projetos legados, maximizando a legibilidade para humanos e agentes de IA.

---

## 1. Projetos Novos (Greenfield) — *Simple by Default, Modular by Boundary*

1. **Padrão Default (80% dos sistemas de negócio): Monólito Modular + Vertical Slices.**
   - Organize o código por **funcionalidade/domínio** (ex.: `Features/Billing/`, `Modules/Orders/`), mantendo fronteiras explícitas entre módulos.
   - **Por que funciona melhor com IA:** cada fatia de entrega cabe em poucos arquivos contíguos (`ef:paths` enxuto), reduz drasticamente o *blast radius* e evita espalhar uma feature simples por 8 camadas horizontais.
2. **Contratos Primeiro (Schema-First):**
   - Defina DTOs, contratos HTTP/OpenAPI, regras de validação e migrations **antes** de gerar telas/UI ou lógica interna — previne divergências silenciosas entre frontend, API e banco.
3. **Escalonamento somente por evidência concreta:**
   - Adote Clean/Hexagonal completa apenas quando houver múltiplos adaptadores reais de entrada/saída ou domínio de alta complexidade comprovada.
   - **Proibido por padrão em MVP/Greenfield** (salvo justificativa explícita aprovada no Gate 1): microserviços distribuídos, mensageria/event bus distribuído sem requisito de escala, `IRepository<T>` genérico sobre ORM moderno sem ganho real, e camadas vazias de pass-through.
4. **Arquitetura Verificável desde o Dia 1 (Tier 2):**
   - Inclua 1 arquivo enxuto de **Fitness Functions arquiteturais** na suíte de testes (`NetArchTest` em .NET, `dependency-cruiser` em JS/TS, `ArchUnit` em Java) travando fronteiras de módulo e dependências proibidas dentro do `harness-cycle`.

---

## 2. Projetos Existentes (Brownfield) — *Respeite o Existente, Isole o Novo*

1. **Consistência Local acima de Preferência Pessoal:**
   - Código novo segue o padrão **ativo** predominante do módulo. Nunca introduza uma "terceira arquitetura" no mesmo repositório durante uma feature ou bugfix.
2. **Mapa de Quarentena em `docs/ai/architecture.md`:**
   - Separe explicitamente:
     - **Padrões Ativos (replicar):** convenções atuais que toda alteração nova deve seguir.
     - **Padrões Legados em Quarentena (não replicar):** padrões antigos que permanecem funcionando no legado, mas **não podem ser copiados em código novo** e **não devem ser migrados sem card próprio**.
3. **Characterization Tests (Golden Master) + Strangler Fig:**
   - Antes de alterar rotina legada crítica sem cobertura unitária saudável, capture primeiro o comportamento real observado (via **Playwright E2E completo** ou teste de caracterização entrada → saída) como trava `R0`.
   - Isole a nova regra atrás de uma fachada/serviço fino chamado pelo legado (*Strangler Fig*), evitando refatoração invasiva fora do envelope aprovado.

---

## 3. Decisões Arquiteturais Escopadas (`Dxx` com `applies_to`)

- Toda decisão arquitetural (`Dxx`) em `docs/ai/decisions-and-pendencies.md` declara **`Escopo (applies_to)`** (globs/pastas como `src/Billing/**`, `*.sql` ou `global`) e **`Regra verificável (DO / DO NOT)`**.
- Ao montar `.agent-pack/.runtime/TASK_SPEC.md`, o `Tech Lead` lista em `decisionsInScope` apenas os `Dxx` cujo `applies_to` cruza com `ef:paths`, evitando tanto ruído de contexto quanto regressão de decisões passadas (*architecture drift*).
