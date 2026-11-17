# Decisions and pendencies

> Last verified: `[UNVERIFIED]`

Fonte única para decisões técnicas e funcionais (`Dxx`) e pendências que bloqueiam fases ou cards (`Pxx`). Evite repetir decisões em outros documentos: aponte para o ID correspondente.

## 1. Decisões tomadas

| ID | Decisão | Data | Fonte / Card | Consequência no código |
|---|---|---|---|---|
| D01 | [decisão confirmada] | [YYYY-MM-DD] | [fonte / AB-ID] | [regra ou restrição resultante] |

## 2. Pendências abertas (`BLOCKED_BY_DECISION`)

| ID | Pendência | Dono | Bloqueia | Impacto | Status |
|---|---|---|---|---|---|
| P01 | [pendência em aberto] | [negócio / fiscal / infra / DBA / segurança] | [Gate 1 / Fase / AB-ID] | [risco ou efeito] | Aberta |

## 3. Liberações parciais do Gate 1 (quando aplicável)

| ID | Escopo liberado | Escopo ainda bloqueado | Pendências vinculadas | Data |
|---|---|---|---|---|
| — | [ex.: base técnica e persistência dev] | [ex.: regras de negócio, telas e integrações externas] | [P01, P02] | — |
