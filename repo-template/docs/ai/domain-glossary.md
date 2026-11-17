# Domain glossary

> Last verified: `[UNVERIFIED]`

## Objetivo

Registrar termos de negócio confirmados para reduzir ambiguidade em bugs e features. Marque inferências e dúvidas explicitamente.

## Termos

| Termo | Significado | Onde aparece | Observações |
|---|---|---|---|
| [termo] | [definição] | [tela/API/tabela] | [observação] |

## Entidades principais

### [Entidade]

- Responsabilidade:
- Campos importantes:
- Regras:
- Tabelas relacionadas:
- Telas/APIs relacionadas:

## Regras de negócio conhecidas

- ...

## Dúvidas para validação humana

- ...

## Estados canônicos e transições (quando aplicável)

- Separe **estado de negócio/externo** (ex.: confirmado por autorizador/parceiro) de **estado de processamento** (fila/execução). Derive rótulos de UI a partir dessas dimensões em vez de persistir um terceiro estado redundante.
- Qualquer transição fora da tabela permitida deve falhar fechado no servidor.

| De | Para | Condição / Quem executa | Restrição |
|---|---|---|---|
| [estado] | [estado] | [condição] | [ex.: nunca reenviar após resultado incerto] |
