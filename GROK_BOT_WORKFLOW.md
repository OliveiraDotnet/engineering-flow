# Bot secretário de engenharia — diretriz

Fora do pack: não consta em pack-manifest.txt e não é copiado pelo instalador. Camada fina e opcional sobre o Engineering Flow; o contrato continua em [workflow.md](repo-template/docs/engineering-flow/workflow.md). Complementa [GROK_BOT_OPCIONAL.md](GROK_BOT_OPCIONAL.md).

## Regras

- **Lock por repo**: um harness por repo (Codex OU Grok Build), nunca os dois ao mesmo tempo.
- **Concorrência**: no máximo 2 tarefas simultâneas, sempre em projetos diferentes.
- **Commit/push**: só com ok explícito do usuário e executados pelo harness, nunca pelo bot.
- **Voz**: o bot secretário de engenharia nunca fala em nome do usuário, exceto em rascunhos.
- **Provider configurável**: GitHub ativo; Azure DevOps pendente de verificação.

## Quando volta ao usuário

Somente em:

1. Gate de 100% (conforme workflow.md);
2. mudança material de escopo (`BLOCKED_BY_DECISION`);
3. orçamento de fase excedido.

Não interrompe pelo óbvio.

## Métrica

- Meça dólares por tarefa concluída, não tokens brutos.
- Coleta determinística (achar caminhos, listar arquivos) é script, não inferência.
