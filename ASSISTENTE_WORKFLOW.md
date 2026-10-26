# Camada de bots (planejamento e repositórios) — diretriz

Fora do pack: não consta em pack-manifest.txt e não é copiado pelo instalador. Camada fina e opcional sobre o Engineering Flow; o contrato continua em [workflow.md](repo-template/docs/engineering-flow/workflow.md). Complementa [ASSISTENTE_OPCIONAL.md](ASSISTENTE_OPCIONAL.md).

## Papéis e hierarquia (opcional, só nesta documentação)

Os papéis são os do [workflow.md](repo-template/docs/engineering-flow/workflow.md) (seção Papéis). Esta camada instancia dois deles com bots; os nomes abaixo são a instanciação atual, não requisito.

O aprovador humano (Matheus) decide tudo. Depois vem o bot de planejamento (hoje, o Jeff), que planeja com o Matheus e orquestra só quando o Matheus pede. Depois vêm os bots de projeto, um por repositório, no papel revisor/entrega. Antes de incluir um bot novo em qualquer lugar, o bot de planejamento pergunta ao Matheus.

## Regras

- **LOCK:** o bot do repo (revisor/entrega) confere se já existe `.agent-pack/.runtime/task.lock` e então cria o dele. Conteúdo: tarefa, branch, bot responsável e data/hora. O LOCK expira no commit. Trava esquecida: o bot da demanda libera. O arquivo não é versionado.
- **Concorrência:** no máximo 2 tarefas simultâneas, sempre em projetos diferentes.
- **Commit:** só o implementador (hoje, o Grok Build), com o ok explícito do Matheus depois das evidências.
- **Push:** só o publicador (no texto da v3.0.0, o Jow), com o ok do Matheus. Com o Jow indisponível, o Matheus faz o push manualmente. Nenhum outro bot dá push. Nunca na main ou na master, nunca force push. Onde a diretriz de entrega pelo bot de projeto se aplica, push, PR e merge passam ao revisor/entrega e o Jow fica opcional.
- **Voz:** o bot de planejamento (secretário de engenharia) nunca fala em nome do usuário, exceto em rascunhos.
- **Provider configurável:** GitHub ativo; Azure DevOps continua configurável.

## Briefing diário (opcional)

Não obriga ninguém a usar nem a criar rotina.

- Segunda a sexta, por volta das 7h (horário de Brasília), só com os bots de projeto.
- Tom de chefe preocupado com o andamento, sem grosseria.
- Pergunta o que ficou em aberto, os riscos e os bloqueios.
- O resumo vai no dia útil seguinte.

## Quando volta ao usuário

Somente em:

1. Gate de 100% (conforme workflow.md);
2. mudança material de escopo (`BLOCKED_BY_DECISION`);
3. orçamento de fase excedido;
4. as 2 rodadas de alinhamento de escopo/técnico acabarem sem acordo, ou houver divergência de escopo, contrato, dados ou segurança.

Não interrompe pelo óbvio.

## Métrica

- Meça dólares por tarefa concluída, não tokens brutos.
- Coleta determinística (achar caminhos, listar arquivos) é script, não inferência.
