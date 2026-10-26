---
name: web-app
description: Plan and validate web UI behavior in the detected stack, including HTML/CSS/JavaScript, SPAs and classic ASP.
---

# web-app

Leia o contrato comum em docs/engineering-flow/workflow.md do repositório quando aplicável. Plano, aprovação humana, testes aprovados e evidência são requisitos do fluxo; autorização existente persiste. Em modo independente o agente ativo entrega; não há delegação automática.

Identifique rotas/screens, runtime, HTML/CSS/JS e backend real, scripts compartilhados e estados de formulário. Para Razor/MVC/Blazor/Web Forms use também web-dotnet quando instalado. ASP clássico requer verificar IIS/runtime e includes, Session, validação server-side, SQL/chamadores e código legado; não migre automaticamente.

Plano define critérios e cenários de navegador com entrada/ação, resultado, persistência e console/rede pertinentes. A pirâmide é unitário, integração em xUnit e e2e em Playwright. Playwright, bUnit e Testcontainers são dependências padrão no texto; o pack não as instala e não presume a mesma integração em todo agente. Sem teste de integração, isso tem de ser reportado. Execute cenários reais apenas quando aprovados. No Completo, a imagem é obrigatória em critério de tela ou em evidência de cliente, gerada pelo Playwright E2E; a imagem acompanha o resultado observado e não o substitui. No Trivial, a evidência é um resumo curto com o arquivo alterado. Sem runtime/automação disponível, reporte roteiro manual pendente e limite. Preserve binding, rotas, antiforgery, autorização e validação server-side.
