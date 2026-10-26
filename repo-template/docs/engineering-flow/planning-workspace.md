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
      <aaaammdd-hhmm>-<suite>.trx | .log
      R0-antes.log
      R0-depois.log
    evidencias\
      C01-<descricao>-passo.png
      C01-<descricao>-final.png
      C01-<descricao>-trace.zip   (somente em falha)
    conferencia-trivial.md
  scripts\
    PendentesProducao\   (script transacional consolidado, rollback, relatorio.md)
    Aplicados\           (mesmo nível de PendentesProducao; recebe scripts aplicados em produção)
    substituidos\        (opcional, por projeto)
```

Exemplo de mês: `marco`, `outubro`.

## Regras

- Se a raiz do projeto é um repo git, `Planejamento/`, `planejamento/` e `conhecimento/` entram no `.gitignore`. Esse é o `.gitignore` aplicado pelo repo-template: os instaladores acrescentam as três linhas em todo repo e não duplicam quando rodam de novo. O pack não leva um `.gitignore` dentro de `repo-template/`, porque todo arquivo de lá é instalado e um artefato desses substituiria o `.gitignore` do projeto.
- No Trivial, `conferencia-trivial.md` pode existir, mas a evidência exigida é o resumo curto do implementador com o arquivo alterado.
- No Completo, a imagem de critério de tela ou de evidência de cliente é obrigatória e é gerada pelo Playwright E2E. A imagem fica em `evidencias\` e não fecha critério sozinha.
- Scripts são organizados por mês. Quando o consolidado do mês passa de ~100 KB, abra uma release e inicie um novo consolidado. Veja [sql-release-package.md](sql-release-package.md).
- Evidência fica fora da memória versionada, conforme [workflow.md](workflow.md); não grave credenciais, dados pessoais ou dumps. A memória local (`conhecimento/`) também fica fora do Git; versionamento em Git previsto para a 3.2. Evidência não vai para `conhecimento/`.

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
