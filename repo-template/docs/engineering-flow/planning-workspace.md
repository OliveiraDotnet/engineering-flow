# Workspace de planejamento (opcional)

Convenção opcional por projeto, fora do git. Ative em AGENTS.md (Convenções do projeto), que também define a raiz.

## Estrutura

```text
Planejamento\<aaaa>\<mes-por-extenso-minusculo-sem-acento>\
  <dd-mm-aaaa-nome-demanda>\
    demanda.md
    diagnostico.md
    plano.md
    relatorio-implementacao.md
    logs\
    evidencias\
  scripts\
    PendentesProducao\   (script transacional consolidado, rollback, relatorio.md)
    Aplicados\           (mesmo nível de PendentesProducao; recebe scripts aplicados em produção)
    substituidos\        (opcional, por projeto)
```

Exemplo de mês: `marco`, `outubro`.

## Regras

- Se a raiz do projeto é um repo git, `Planejamento/` entra no `.gitignore`.
- Scripts são organizados por mês. Quando o consolidado do mês passa de ~100 KB, abra uma release e inicie um novo consolidado. Veja [sql-release-package.md](sql-release-package.md).
- Evidência fica fora da memória versionada, conforme [workflow.md](workflow.md); não grave credenciais, dados pessoais ou dumps.

## Fase → arquivo

| Fase | Arquivo |
|---|---|
| Entender a demanda | `demanda.md` |
| Descoberta/diagnóstico | `diagnostico.md` |
| Plano técnico e aprovação (Gate 1) | `plano.md` (inclui orçamento por fase e leituras justificadas) |
| Implementação | `relatorio-implementacao.md` |
| Testes aprovados | `logs/` |
| Evidência e entrega (Gate de 100%) | `evidencias/` + tabela em `relatorio-implementacao.md` |
| Scripts SQL aprovados | `scripts\PendentesProducao\` → `scripts\Aplicados\` |

## Transição gradual

Projeto com demanda já em andamento numa estrutura anterior pode concluí-la na estrutura antiga e adotar esta convenção quando essa demanda chegar à produção.
