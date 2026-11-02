# Workspace de planejamento (opcional)

Convenção opcional por projeto, fora do git. Ative em AGENTS.md (Convenções do projeto), que também define a raiz.

## Estrutura

```text
Planejamento\
  DEMANDAS.md                  (Quadro vivo de controle de todos os cards ativos e em homologação)
  <aaaa>\<mes-por-extenso-minusculo-sem-acento>\
    <dd-mm-aaaa-AB-ID-nome-demanda>\
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
    PendentesProducao\
      AB-<ID>-<slug>.sql       (script idempotente/transacional individual por card em homologação)
    Releases\
      vX.Y.Z_consolidado.sql   (consolidado gerado apenas com os cards aprovados que subiram na Tag vX.Y.Z)
      OS-INFRA-vX.Y.Z.md       (texto pronto da Ordem de Serviço para publicação pela equipe de Infra)
    Aplicados\
      vX.Y.Z\                  (recebe os scripts individuais AB-<ID>-*.sql após aplicação em produção)
    substituidos\              (opcional, por projeto)
```

Exemplo de mês: `marco`, `outubro`, `novembro`.

## Quadro Vivo (`Planejamento/DEMANDAS.md`)

Para evitar que demandas recebidas via Teams/e-mail ou paradas em homologação por semanas se percam em pastas de meses anteriores, o bot do projeto mantém o arquivo `Planejamento/DEMANDAS.md` na raiz do workspace com as colunas:

| Card | Título | Branch | Status | Ambiente / Consultor | Atualizado em | Script SQL |
|---|---|---|---|---|---|---|
| `AB-1042` | Ajuste cálculo ICMS | `feat/AB-1042-calculo-icms` | `EM_HOMOLOGACAO` | `hom` (Consultor João) | `2026-11-01` | `PendentesProducao/AB-1042-icms.sql` |

Estados válidos: `TRIAGEM`, `EM_DEV`, `EM_HOMOLOGACAO`, `APROVADA_PROD`, `EM_PRODUCAO (vX.Y.Z)`.

## Regras

- Se a raiz do projeto é um repo git, `Planejamento/` e `planejamento/` entram no `.gitignore`. Esse é o `.gitignore` aplicado pelo repo-template: os instaladores acrescentam as duas linhas em todo repo e não duplicam quando rodam de novo. O pack não leva um `.gitignore` dentro de `repo-template/`, porque todo arquivo de lá é instalado e um artefato desses substituiria o `.gitignore` do projeto.
- Toda demanda possui um número de card (`AB-<ID>`) antes de iniciar. A branch da tarefa (`feat/AB-<ID>-<slug>` ou `fix/AB-<ID>-<slug>`) nasce da `main`/`master`, sofre merge na branch de homologação (`hom`/`develop`) sem ser excluída e só é excluída após ser promovida para a `main`/`master` e tagueada (`vX.Y.Z`).
- No Trivial, `conferencia-trivial.md` pode existir, mas a evidência exigida é o resumo curto do implementador com o arquivo alterado.
- No Completo, a imagem de critério de tela, de validação E2E em legado acoplado ou de evidência de cliente é obrigatória e é gerada pelo Playwright E2E. A imagem fica em `evidencias\` e não fecha critério sozinha.
- Scripts SQL são organizados **por card de demanda** em `scripts\PendentesProducao\AB-<ID>-<slug>.sql` e consolidados **por Tag de Release (`vX.Y.Z`)** em `scripts\Releases\` no momento de subir para produção. Veja [sql-release-package.md](sql-release-package.md).
- Evidência fica fora da memória versionada, conforme [workflow.md](workflow.md); não grave credenciais, dados pessoais ou dumps. A memória persistente de longo prazo utiliza o `ai-memory` (Fábio Akita) e `docs/ai/`. Evidência transitória não vai para o `ai-memory`.

## Fase → arquivo

| Fase | Arquivo |
|---|---|
| Triagem (Intake Teams/E-mail/Card) | `Planejamento/DEMANDAS.md` + `demanda.md` |
| Descoberta/diagnóstico e saúde de testes | `diagnostico.md` |
| Plano técnico e aprovação (Gate 1) | `plano.md` (inclui orçamento por fase e leituras justificadas) |
| Implementação | `relatorio-implementacao.md` |
| Testes aprovados (`R0`, unit/integração ou E2E) | `logs/` |
| Evidência e entrega (Gate de 100%) | `evidencias/` + tabela em `relatorio-implementacao.md` |
| Script SQL aprovado da demanda | `scripts\PendentesProducao\AB-<ID>-<slug>.sql` |
| Fechamento de Release para Produção (Tag `vX.Y.Z`) | `scripts\Releases\vX.Y.Z_consolidado.sql` + `OS-INFRA-vX.Y.Z.md` → `scripts\Aplicados\vX.Y.Z\` |

## Transição gradual

Projeto com demanda já em andamento numa estrutura anterior pode concluí-la na estrutura antiga e adotar esta convenção quando essa demanda chegar à produção.
