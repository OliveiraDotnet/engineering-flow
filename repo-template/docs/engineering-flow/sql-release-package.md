# Pacote SQL de release e OS da Infra (opcional)

Aplica-se com o perfil `sqlserver`, somente quando o AGENTS.md do projeto declara o pacote (Convenções do projeto).

## Relação com db-change-sqlserver

A skill `db-change-sqlserver` produz o menor script idempotente e transacional por demanda, identificado pelo número do card (`AB-<ID>-<slug>.sql`). Como em sistemas legados as demandas em homologação podem ser aprovadas pelos consultores em ordens e tempos diferentes (às vezes levando semanas), **os scripts nunca são consolidados por mês calendário antes da aprovação de produção**. A consolidação ocorre exclusivamente no fechamento da Tag de Produção (`vX.Y.Z`), reunindo somente os scripts dos cards aprovados para aquela subida. Executar contra qualquer banco continua exigindo autorização explícita para aquele alvo.

## Conteúdo do script individual (`scripts\PendentesProducao\AB-<ID>-<slug>.sql`)

- **Cabeçalho de rastreabilidade**: Card (`AB-<ID>`), branch, autor, data e resumo dos objetos afetados.
- **Script idempotente e transacional**: `SET XACT_ABORT ON`, `BEGIN TRAN` / `COMMIT` com `TRY`/`CATCH` e verificações de existência (`IF NOT EXISTS`, `CREATE OR ALTER`) para permitir reexecução segura sem erro ou efeito duplicado.
- **Pré-checks**: abortam se o estado esperado (objetos, colunas, contagens) não for encontrado.
- **Rollback**: bloco documentado ou script reverso que reverte sem perda de dados; backups/cópias necessárias fazem parte do procedimento.

## Ciclo de Fechamento de Release (`vX.Y.Z`) e OS da Infra

1. **Durante Desenvolvimento e Homologação:**
   O script aprovado da demanda fica isolado em `scripts\PendentesProducao\AB-<ID>-<slug>.sql` (e opcionalmente espelhado no repositório quando configurado em `AGENTS.md`).
2. **Na Promoção para Produção (Passo 10 e 11 — Merge na `main` e Tag `vX.Y.Z`):**
   Quando o Matheus autoriza a subida de um ou mais cards aprovados para a `main`/`master` e o bot do projeto fecha a Tag `vX.Y.Z`:
   - Os scripts `AB-<ID>-*.sql` **apenas dos cards incluídos na Tag `vX.Y.Z`** são concatenados em ordem cronológica/dependência em `scripts\Releases\vX.Y.Z_consolidado.sql`, acompanhados de `scripts\Releases\vX.Y.Z_relatorio.md`.
   - O bot do projeto gera automaticamente o arquivo `scripts\Releases\OS-INFRA-vX.Y.Z.md` contendo:
     - Repositório, branch (`main`/`master`), Tag exata (`vX.Y.Z`) e hash do commit;
     - Lista de cards (`AB-<ID>`) contemplados no pacote;
     - Instrução explícita sobre banco de dados: se há script SQL (`vX.Y.Z_consolidado.sql`), ordem de execução (antes ou depois da publicação do código) e quem executará (Infra ou Desenvolvedor);
     - Tag anterior para rollback imediato caso necessário.
3. **Pós-Publicação em Produção:**
   Após a publicação pela Infra e execução confirmada do SQL em produção, os scripts individuais daqueles cards saem de `scripts\PendentesProducao\` e são movidos para `scripts\Aplicados\vX.Y.Z\`.

## Nível de validação

Definido no AGENTS.md do projeto:

- `syntax-only`: `SET PARSEONLY ON` / `SET NOEXEC ON` mais diff objeto a objeto contra o ambiente de homologação.
- `execute`: execução real em HOM/DEV autorizado.
