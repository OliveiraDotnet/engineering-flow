# Memória local do sistema

Memória local; versionamento em Git previsto para a 3.2. Sem busca semântica nesta versão. Sem Git, sem teto e sem `revalidar_em`.

O piloto é o SISMAN, só no texto. Nada aqui é regra real de sistema.

A raiz dos clones vem de `config/maquinas.conf`, bloco escolhido por `EF_MAQUINA`. O comando `mem` não tem caminho fixo.

## O que nasce onde

- Cartão ditado nasce `pendente` e só fica ativo com o ok do Matheus.
- Captura feita pelo bot nasce `rascunho`.
- `confirmada` exige `confirmado_por` com o ok do Matheus. O `mem novo` não cria cartão ativo.

## Dado de cliente

Dado de cliente só entra se for útil para teste, e no máximo o username. CPF, dado bancário e dado sensível nunca entram.

## Layout

```text
conhecimento/
  README.md
  INDEX.md            gerado por mem index
  .memoria.conf
  _templates/
  contextos/<ctx>/
  projeto/
  repos/<repo>/
  .cache/             ignorado; sem índice semântico na 3.1
```

Consulte com `mem`. Não leia a pasta inteira.
