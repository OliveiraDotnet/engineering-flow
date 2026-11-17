# External boundaries and outbound data

> Last verified: `[UNVERIFIED]`

Inventário de conexões de saída, integrações externas, uploads, views remotas e dependências externas. Qualquer nova saída fora desta lista altera fronteira de confiança e retorna para aprovação humana (`BLOCKED_BY_DECISION`).

## 1. Inventário de saídas e entradas externas

| ID | Origem → Destino | Dados trafegados | Gatilho / Protocolo | Autenticação e controles |
|---|---|---|---|---|
| E01 | [app → serviço / banco / IdP] | [categorias sem segredos] | [HTTPS / SQL / job] | [mTLS / OAuth / menor privilégio] |

## 2. Políticas de recursos externos

- **CDN, fontes remotas e telemetria:** [proibido / apenas origens aprovadas]
- **Renderização e arquivos (PDF, planilhas, uploads):** [execução local sem SSRF / extensões e limites permitidos]
- **Dados sensíveis / LGPD:** credenciais, tokens, chaves privadas e dados pessoais reais não entram em logs, repositórios nem massa de teste.
