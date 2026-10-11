---
name: web-app
description: Plan and validate web UI behavior in the detected stack, including HTML/CSS/JavaScript, SPAs and classic ASP.
---

# web-app

Leia o contrato comum em docs/engineering-flow/workflow.md do repositório quando aplicável. Plano, aprovação humana, testes aprovados e evidência são requisitos do fluxo; autorização existente persiste. Em modo independente o agente ativo entrega; não há delegação automática.

Identifique rotas/screens, runtime, HTML/CSS/JS e backend real, scripts compartilhados e estados de formulário. Para Razor/MVC/Blazor/Web Forms use também web-dotnet quando instalado. ASP clássico requer verificar IIS/runtime e includes, Session, validação server-side, SQL/chamadores e código legado; não migre automaticamente.

Plano define critérios e cenários de navegador com entrada/ação, resultado, persistência e console/rede pertinentes. Detecte ferramentas/runner e ambiente disponíveis; Playwright é opção, não dependência obrigatória nem integração presumida. Execute cenários reais apenas quando aprovados. Screenshot complementa resultado observado, não o substitui. Sem runtime/automação disponível, reporte roteiro manual pendente e limite. Preserve binding, rotas, antiforgery, autorização e validação server-side.
