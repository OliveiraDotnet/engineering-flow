# Decisions and pendencies

> Last verified: `[UNVERIFIED]`

Fonte única para decisões técnicas e funcionais (`Dxx`) e pendências que bloqueiam fases ou cards (`Pxx`). Evite repetir decisões em outros documentos: aponte para o ID correspondente.

## 1. Decisões tomadas (`Dxx` / ADRs Escopadas)

> Ao montar `.agent-pack/.runtime/TASK_SPEC.md`, o `Tech Lead` inclui em `decisionsInScope` apenas os IDs `Dxx` cujo `Escopo (applies_to)` intercepta os arquivos de `ef:paths` (ou `global`).

| ID | Decisão | Escopo (`applies_to`) | Regra verificável (`DO / DO NOT`) | Data | Fonte / Card |
|---|---|---|---|---|---|
| D01 | [decisão confirmada] | [`global` ou `src/Modulo/**`] | [DO: ... / DO NOT: ...] | [YYYY-MM-DD] | [fonte / AB-ID] |

## 2. Pendências abertas (`BLOCKED_BY_DECISION`)

| ID | Pendência | Dono | Bloqueia | Impacto | Status |
|---|---|---|---|---|---|
| P01 | [pendência em aberto] | [negócio / fiscal / infra / DBA / segurança] | [Gate 1 / Fase / AB-ID] | [risco ou efeito] | Aberta |

## 3. Liberações parciais do Gate 1 (quando aplicável)

| ID | Escopo liberado | Escopo ainda bloqueado | Pendências vinculadas | Data |
|---|---|---|---|---|
| — | [ex.: base técnica e persistência dev] | [ex.: regras de negócio, telas e integrações externas] | [P01, P02] | — |
