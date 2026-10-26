---
name: web-e2e-playwright
description: Descreve o e2e de tela com Playwright para critério de UI ou evidência de cliente. Use quando o Completo exigir imagem do fluxo. O pack não instala a ferramenta.
---

# web-e2e-playwright

Leia o contrato comum em docs/engineering-flow/workflow.md. Plano, aprovação humana, testes aprovados e evidência são requisitos do fluxo. Esta skill é texto e template. O pack não instala Playwright, navegador, bUnit nem Testcontainers.

## Quando usar

- Critério de tela no modo Completo: 1 cenário Playwright por critério, no máximo.
- Evidência de cliente que dependa de tela: a imagem é obrigatória e é gerada pelo Playwright E2E.
- A imagem acompanha o resultado observado. Ela não fecha critério sozinha.
- No Trivial, a evidência continua sendo o resumo curto com o arquivo alterado. E2E só entra se o R0 ou o critério aprovado pedir.

A pirâmide continua unitário, depois integração em xUnit, depois este e2e. Sem teste de integração, isso tem de ser reportado. bUnit e Testcontainers são dependências padrão no texto, nas camadas de componente e de banco isolado, não neste cenário de tela.

## Detecção

1. Procure `playwright.config.*`, `@playwright/test` ou `Microsoft.Playwright` no repo.
2. Se já existir, siga o config, o projeto e os nomes do repo.
3. Se não existir, o template `templates/cenario.fixture.ts` é o ponto de partida. Incluir o pacote no repo é dependência do envelope aprovado. Esta skill não instala nada.

## Configuração mínima

- `baseURL` do ambiente autorizado no envelope. Sem URL de produção.
- Um `test` por critério de tela.
- `screenshot: 'on'` no cenário do critério, para gerar a imagem obrigatória.
- `trace: 'retain-on-failure'`.
- Não grave segredo, senha, token, cookie de sessão real nem dado de cliente além do username de fixture, se o teste precisar.

## Nomes de artefato

Dentro do workspace de planejamento da demanda, em `evidencias/`:

- `C01-<descricao>-passo.png` — passo-chave.
- `C01-<descricao>-final.png` — estado final.
- `C01-<descricao>-trace.zip` — só em falha.

`<descricao>` é um slug curto do critério. Troque `C01` pelo id do critério. Logs de saída ficam em `logs/`.

## R0 de tela

Se o defeito só aparece na tela, o R0 pode ser este e2e: falha antes do fix e passa depois. O planejador (hoje, o Jeff) opina antes. Só o Matheus dispensa, com o motivo no plano. As duas execuções entram na evidência.
