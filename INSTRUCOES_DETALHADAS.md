# Adoção e migração — Engineering Flow 2.0

Instalação e exemplos: [README](README.md) e [manual](MANUAL_DE_USO.md). Versão atual 2.0.0; suporta instalação inicial e atualização de instalações 1.7.0 ou anteriores reconhecidas pelos catálogos. Este pack não instala runtimes nem configura contas externas.

## Instalação inicial

Inspecione com DiscoverOnly/--discover-only, confira Git roots e perfis, faça DryRun/--dry-run e instale dentro do escopo autorizado. Core sempre, web/sqlserver/mobile sugeridos por evidência, quality apenas explícito. Perfil explícito evita autodetecção. Vários repos recebem instalação por Git root; pasta não Git requer AllowNonGit/--allow-non-git. Repo Git vazio recebe instruções e segue new-project para planejar antes de criar aplicação.

Integration/--integration aceita codex,grok,claude; Grok não depende de Codex. Em destino existente, seleção registrada persiste quando omitida. Escolha explícita de integração na atualização muda somente provedores solicitados conforme o plano; não faça isso por inferência. Instruções persistentes requerem recarga conforme host. Respeite regras personalizadas no destino.

## Atualizar versões anteriores e 1.7.0

Use update-engineering-flow com Check antes de Apply. Aliases *-engineering-flow encaminham ao reconciliador *-agent-pack preservado. `.agent-pack/state.txt` continua sendo o formato/local de estado; IDs antigos não foram trocados por branding. Nenhum checkout ativo precisa ser movido. Catálogos 1.1–1.6 existentes são mantidos; o catálogo 1.7 registra hashes normalizados dos arquivos da pré-release 1.7. Ele não afirma que essa versão foi publicada. Bytes próprios ou release anterior diferente não viram arquivo confiável silenciosamente.

| Propriedade | Atualização |
|---|---|
| managed | Arquivo intacto conhecido pode atualizar; conteúdo customizado gera conflito/decisão |
| merge | AGENTS/CLAUDE/config Grok preservados e proposta de diferenças para revisão/merge |
| seed | docs/ai existentes permanecem do projeto; não são sobrescritos por template |

Na instalação existente, não use Force para atualizar. Confira ações propostas, conflitos e seleção de perfis/integrações. KeepLocal registra preferência local; AcceptPack escolhe conteúdo do pack conscientemente; AcceptMerge reconhece merge já revisado. PowerShell recebe listas de IDs de artifact; Bash recebe --keep-local/--accept-pack/--accept-merge com os IDs mostrados pelo Check. Caminhos não são IDs; consulte pack-artifacts.txt, por exemplo guidance.agents e skill.shared.bugfix-dotnet. Não use aceitação ampla sem revisar. Updater faz backups e mantém locks/rollback; não remova locks de uma execução ativa. Update não acrescenta perfil mobile/quality não instalado. Para adicionar perfil use instalador com seleção explícita após revisão; ele preserva seleções existentes.

IDs estáveis permitem renomear destino em versões futuras com reconciliação; aposentadoria exige origem conhecida e tratamento de customização. Artifacts Flutter de 1.5 retirados na 1.6 seguem essa regra; mobile-app é módulo geral novo, não instalação automática de Flutter. Entradas bootstrap-dotnet-repo, bugfix-dotnet, feature-slice-dotnet, legacy-refactor-dotnet, pr-review-dotnet e update-agent-pack permanecem compatíveis. Use novos nomes para workflows gerais e antigos quando a especialização for aplicável.

## Limites verificáveis

Detectores levantam manifests, projetos, CI/scripts e pistas de runtime/provider sem imprimir conexão, script body ou segredo. PowerShell retorna JSON/markdown com metadados; Bash retorna markdown e caminhos para inspeção posterior. Não são parsers universais nem executam app/teste. Verifique versão e comando no repo real. SQL genérico não identifica SQL Server; use provider/T-SQL específico. AndroidManifest, alvos iOS em projeto Xcode, pubspec/MAUI e dependências mobile/híbridas são pistas que precisam confirmação; Kotlin/Swift isolados não selecionam mobile. Tecnologias não reconhecidas continuam investigáveis.

Testes do pack exercitam scripts, instalação, atualização/ownership/seleções, rollback e fixtures. Checks de contrato são estáticos, não prova de obediência de modelos. Browser real, banco, app desktop ou device mobile só são verificados quando executados e autorizados na tarefa. Zero testes, ambiente ausente, falha e evidência incompleta são estados distintos. [Capabilities](repo-template/docs/engineering-flow/capabilities.md) define evidência por área.

## Extensão e proteção de contexto

Outros agentes podem consumir o contrato e skills se a ferramenta tiver mecanismo verificado; o pack só fornece instalação direta para integrações declaradas. Skills específicas do repo somente para procedimento recorrente confirmado, com frontmatter e recursos mínimos. Handoff real usa agent-work-order e ferramentas disponíveis, sem API entre provedores inventada. Escritores concorrentes precisam isolamento/contexto local preservado. Não usar clean ref que omita alterações necessárias.

Evidências transitórias usam diretório temporário externo por padrão. Estado `.agent-pack` no destino inclui controle de atualização, backups e conflitos; não é memória do produto e não deve ser commitado com dados sensíveis. Conhecimento durável em docs/ai é confirmado, redigido e ligado à fonte/data. Não armazenar tokens, connection strings, sessões ou dumps. Documentação oficial é opcional/sob demanda, não pesquisa obrigatória por tarefa nem motivo para modernizar legado.

## Higiene Git no destino

Instalação e atualização acrescentam somente padrões faltantes de resíduos do pack ao .gitignore existente, preservando conteúdo e bytes originais. DryRun/WhatIf e Check não escrevem. A proteção é aplicada após instalação/reconciliação bem-sucedida; a checagem prévia rejeita arquivo vinculado, encoding incompatível ou bloqueio de escrita identificado. Se uma escrita de proteção falhar depois da reconciliação, reporte esse passo como falho e confira o estado/diff: não presuma rollback da etapa já concluída.

Permanecem versionáveis AGENTS.md, skills/configurações de projeto em .agents/.codex/.claude/.grok, docs/ai úteis e .agent-pack/state.txt (IDs/hashes/seleção para futuras atualizações). Não se ignora nenhuma dessas árvores inteira. Ignore .agent-pack/.runtime (backups/retired/locks/staging), state temporário, caches/logs/sessões/worktrees operacionais, .engineering-flow-evidence e propostas/backups *.agent-pack.new / *.agent-pack.backup-* em qualquer diretório. Revise uma proposta ignorada explicitamente pelo caminho antes de aceitar; Git status não é inventário de conflitos.

Regras próprias preexistentes não são removidas nem sobrepostas. Se já ignorarem state.txt ou instruções necessárias, use git check-ignore -v para localizar a regra e decidir a correção. Arquivos operacionais já rastreados continuam rastreados: .gitignore não os retira do índice; remoção do histórico/índice exige revisão específica. Outros diretórios de saída particulares do projeto/host precisam de regras confirmadas; não se adicionam padrões globais para esconder dados desconhecidos. Segredos/dados continuam sujeitos à revisão, sem promessa de sanitização automática.

A versão 1.7 tinha regras gerais de build/testes/segredos no checkout do pack e proteção local criada pelo updater em .agent-pack/.runtime/.gitignore. Essa proteção não cobria propostas/backups do instalador em diretórios irmãos e deixava o próprio .runtime/.gitignore visível. A 2.0 amplia a proteção no destino mantendo state.txt visível. PowerShell valida UTF-8 e preserva BOM/CRLF ao acrescentar; Bash preserva bytes, rejeita NUL e verifica UTF-8 quando iconv está disponível. Encoding legado incompatível precisa de mudança revisada; não há transcodificação automática.
