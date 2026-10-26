# Diretriz: entrega pelo papel revisor/entrega, hoje o bot de projeto (complemento ao engineering-flow 3.0, tag v3.0.0)

Aprovada pelo Matheus Oliveira em 26/10/2026. Revisão 2 (26/10/2026, 10h BRT): esclarece que a restrição de merge vale só para main/master.
Revisão 3 (26/10/2026, Gate 1 às 15h52): só troca a forma de nomear os papéis por papéis genéricos. Nenhuma regra de segurança, gate, branch ou exceção por projeto mudou.
Substitui, nos passos 9 e 10 do fluxo, o papel do Jow (publicador).

## Papéis
As diretrizes seguem o engineering-flow, mas o método é nosso. Os nomes entre parênteses são a instanciação atual, dada como exemplo e não como requisito.
- **Aprovador humano** (Matheus): dá o ok explícito em cada gate e na ida para produção. Não é delegável.
- **Planejador** (Matheus com o Jeff): entende a demanda e fecha o plano e o envelope do Gate 1 com o aprovador.
- **Implementador** (Grok Build): executa o envelope aprovado e é o único que comita, depois do Gate 2.
- **Revisor/entrega** (bot de projeto, um por repositório): confere o commit e conduz push, PR e merge como descrito abaixo.
- **Publicador opcional** (Jow): camada opcional, nas condições abaixo.

## O que muda
Cada revisor/entrega (hoje, o bot de projeto) é responsável pelo ciclo completo de entrega no SEU repositório, de forma independente:
1. Confere o commit do implementador (hoje, o Grok Build): diff contra o escopo aprovado no Gate 1, tabela de evidências do Gate 2, ausência de segredos e de arquivos fora do escopo, branch correta.
2. Faz o push da branch da tarefa.
3. Abre o PR da branch da tarefa para a branch de integração do repositório.
4. Faz o merge da branch da tarefa na branch de integração. Isso faz parte do ciclo normal do revisor/entrega, depois do commit aprovado no Gate 2.
5. Com o ok explícito do Matheus, dado depois de ele ver a evidência, o revisor/entrega PODE fazer o merge da branch de integração na branch principal (main/master), a que vai para produção.

O Jow (publicador) passa a ser uma camada opcional. Os revisores/entrega só pedem ajuda ao Jow em caso extremo, e qualquer envolvimento do Jow exige a confirmação explícita do Matheus antes.

## Regras travadas (não negociáveis)
- Merge em main/master só com ok explícito do Matheus, depois da evidência. Sem esse ok, nunca.
- Nenhum trabalho, commit ou push direto em main/master. Main/master só recebe merge vindo da branch de integração.
- Nunca force push.
- Todo repositório tem uma branch de integração que não é main nem master (por exemplo dev, hml, develop ou feature/...). O PR da tarefa sempre aponta para ela.
- Quem comita continua sendo só o implementador (hoje, o Grok Build), depois do Gate 2. O LOCK expira no commit.
- Se um push, PR ou merge for bloqueado ou falhar, o revisor/entrega para e avisa o Matheus. Nada de contornar.

## Fluxo atualizado (passos 8 a 10)
8. Gate 2: com o ok explícito do Matheus após ver a evidência, o implementador (hoje, o Grok Build) comita na branch da tarefa.
9. O revisor/entrega (hoje, o bot de projeto) confere o commit, faz o push, abre o PR para a branch de integração e faz o merge da tarefa na integração.
10. Ida para produção: com o ok explícito do Matheus após a evidência, o revisor/entrega faz o merge da integração na main/master.

## Exceções e convenções por projeto
Quando houver conflito, a regra do projeto prevalece sobre o texto geral acima.

### GA (SEAL, cliente Durr): ajuste do Matheus por voz em 26/10/2026, às 10h06, registrado pelo bot-ga
- O bot-ga confere o commit, faz o push da branch da tarefa e abre o PR para a `ajustes-durr-convergint`.
- O merge desse PR só acontece com o ok explícito do Matheus, depois da evidência.
- Enquanto durar a migração da Durr, nenhum PR nem merge vai da `ajustes-durr-convergint` para main/master, porque a main é o repositório da Cial.
- Todo o trabalho do GA fica na `ajustes-durr-convergint`.

### B2TI (b2ti-gestaodepv): convenção de branches definida pelo Matheus por ligação em 26/10/2026, às 10h14, registrada pelo bot-b2ti
1. `main` é a branch de produção, e `develop` é a de integração. A `hml` é a de homologação.
2. A `dev` não é usada para nada e fica parada. Se alguém quiser excluí-la, a equipe exclui; nenhum bot mexe nela.
3. O desenvolvimento segue assim: uma branch de tarefa criada a partir da `develop`, o PR da tarefa para a `develop` e o merge na `develop`.
4. Nunca commit nem push direto em `develop`; ela só recebe código por PR da branch de tarefa.
5. EXCEÇÃO (Matheus, 26/10/2026, 10h26): no B2TI, o merge da branch de tarefa na `develop` SEMPRE precisa do ok explícito do Matheus, mesmo em mudança trivial. O item 4 do texto geral não vale aqui. <!-- agent-pack:allow-mojibake -->
6. Diretriz do projeto: `C:\Repositorios\b2ti-gestaodepv\planejamento\diretrizes\diretriz-branches-b2ti.md` (a pasta `planejamento` é ignorada no .gitignore).

### SISMAN (Web e App)
- Branch de integração: `develop`, nos dois repos, registrada pelo bot-sisman em 26/10/2026.

### FASTCRED (SOS Dinheiro)
- Branch de integração: `hom`.
