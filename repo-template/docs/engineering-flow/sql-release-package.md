# Pacote SQL de release (opcional)

Aplica-se com o perfil `sqlserver`, somente quando o AGENTS.md do projeto declara o pacote (Convenções do projeto).

## Relação com db-change-sqlserver

A skill `db-change-sqlserver` continua produzindo o menor script idempotente por mudança. O pacote de release é um passo posterior e opcional que consolida scripts por mudança já aprovados. Executar contra qualquer banco continua exigindo autorização explícita para aquele alvo.

## Conteúdo do pacote

- **Script consolidado**: transacional (`BEGIN TRAN`/`COMMIT`, `SET XACT_ABORT ON`) e idempotente (reexecutável sem efeito duplicado).
- **Pré-checks**: abortam se o estado esperado (objetos, colunas, contagens) não for encontrado.
- **Rollback**: reverte sem perda de dados; backups/cópias necessárias fazem parte do script.
- **relatorio.md**: o que muda nos dados (tabelas, volume estimado, impacto em consumidores).

## Ciclo

`scripts\PendentesProducao\` → aplicado em produção com autorização → `scripts\Aplicados\`. Consolidado acima de ~100 KB fecha a release e inicia outro. Veja [planning-workspace.md](planning-workspace.md).

## Nível de validação

Definido no AGENTS.md do projeto:

- `syntax-only`: `SET PARSEONLY ON` / `SET NOEXEC ON` mais diff objeto a objeto contra o ambiente de homologação.
- `execute`: execução real em HOM/DEV autorizado.
