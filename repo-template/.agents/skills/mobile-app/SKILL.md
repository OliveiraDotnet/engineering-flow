---
name: mobile-app
description: Plan, implement and validate native, hybrid or cross-platform mobile apps using detected platform tooling and authorized devices.
---

# mobile-app

Leia o contrato comum em docs/engineering-flow/workflow.md do repositório quando aplicável. Plano, aprovação humana, testes aprovados e evidência são requisitos do fluxo; autorização existente persiste. Em modo independente o agente ativo entrega; não há delegação automática.

Identifique app novo/existente, plataformas, framework/SDK/versões, toolchain, testes/harness, CI, emuladores/simuladores/dispositivos e acesso autorizado. Preserve arquitetura e contratos existentes. Apps novos seguem new-project; não presuma Flutter, MAUI ou framework obrigatório.

Plano inclui critérios de UI e lógica, navegação, ciclo de vida, permissões, armazenamento/offline e bridges nativas quando afetados; selecione apenas cenários pertinentes. Verifique ferramentas antes do uso; instalação, download de imagens/SDK ou novo acesso requer inclusão aprovada.

Após aprovação implemente e execute unitários/integração/UI apropriados no ambiente autorizado. Declare plataforma/versão/dispositivo, entrada/ação, esperado/observado e artefato. UI web híbrida não comprova a parte nativa. Sem ambiente suportado, entregue como não verificado com roteiro e preparo faltante; não substitua execução nativa por screenshots de navegador. Corrija falhas e repita no envelope aprovado.
