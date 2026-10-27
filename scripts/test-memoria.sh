#!/usr/bin/env bash
# Fixtures fictícias. Literais sensíveis são montados em tempo de execução.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
MEM="$PACK_ROOT/tools/memoria.sh"
PROTECT="$SCRIPT_DIR/protect-engineering-flow-files.sh"
INSTALL="$SCRIPT_DIR/install-agent-pack.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ef-mem.XXXXXX")"
cleanup() {
  case "$TMP" in
    "${TMPDIR:-/tmp}"/ef-mem.*) rm -rf -- "$TMP" ;;
    *) printf 'Unsafe test cleanup path\n' >&2; return 1 ;;
  esac
}
trap cleanup EXIT

mkdir -p "$TMP/repos"
cat > "$TMP/maquinas.conf" <<EOF
[fixture]
descricao: temporaria
machine_id: 00000000-0000-4000-8000-000000000099
raiz_repos: $TMP/repos

[semraiz]
descricao: sem raiz
machine_id: 00000000-0000-4000-8000-000000000098
EOF

export EF_MAQUINAS_CONF="$TMP/maquinas.conf"
unset EF_MAQUINA || true

run() { bash "$MEM" "$@"; }

capture() {
  local code=0
  CAPTURE_OUT="$(run "$@" 2>&1)" || code=$?
  CAPTURE_CODE=$code
}

printf '== C07 máquina ==\n'
capture lint
[ "$CAPTURE_CODE" -ne 0 ] || fail 'EF_MAQUINA ausente deveria falhar'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'EF_MAQUINA ausente' || fail 'mensagem de ausência'
pass 'EF_MAQUINA ausente'

export EF_MAQUINA='naoexiste'
capture lint
[ "$CAPTURE_CODE" -ne 0 ] || fail 'bloco inválido deveria falhar'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'não é um bloco' || fail 'mensagem de bloco inválido'
printf '%s\n' "$CAPTURE_OUT" | grep -F -q 'Blocos: fixture semraiz.' || fail 'espaço antes do ponto nos blocos'
pass 'EF_MAQUINA inválida'

export EF_MAQUINA='semraiz'
capture lint
[ "$CAPTURE_CODE" -ne 0 ] || fail 'bloco sem raiz deveria falhar'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'não define raiz_repos' || fail 'mensagem de raiz ausente'
pass 'bloco sem raiz_repos'

export EF_MAQUINA='fixture'
printf '%s\n' "$CAPTURE_OUT"

win_path="$(printf '%s' 'C:\' 'Repositorios')"
nix_path="$(printf '%s' '/mnt/' 'wd500')"
if grep -R -n -F -e "$win_path" -e "$nix_path" "$PACK_ROOT/tools" "$PACK_ROOT/scripts" --include='*.sh' --include='*.ps1'; then
  fail 'caminho literal em script'
fi
pass 'scripts sem caminho literal'

printf '== C04 ciclo ==\n'
capture --sistema sisman init sisman SIS
[ "$CAPTURE_CODE" -eq 0 ] || fail "init: $CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q "raiz_repos=$TMP/repos" || fail 'init não mostrou a raiz'
printf '%s\n' "$CAPTURE_OUT" | grep -q "conhecimento=$TMP/repos/sisman/conhecimento" || fail 'init não mostrou conhecimento'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem init: 1' || fail 'contagem do init'
KNOW="$TMP/repos/sisman/conhecimento"
[ -f "$KNOW/.memoria.conf" ] || fail 'sem .memoria.conf'
grep -q '^prefixo: SIS$' "$KNOW/.memoria.conf" || fail 'prefixo'
grep -q '^sistema: sisman$' "$KNOW/.memoria.conf" || fail 'sistema'
pass 'init'

capture --sistema sisman lint
[ "$CAPTURE_CODE" -eq 0 ] || fail "lint logo após init: $CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem lint: 0' || fail "lint logo após init: $CAPTURE_OUT"
capture --sistema sisman index
[ "$CAPTURE_CODE" -eq 0 ] || fail "index logo após init: $CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q 'index abortado' && fail "index abortou logo após init: $CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem index: 0' || fail "index logo após init: $CAPTURE_OUT"
capture --sistema sisman pendentes
[ "$CAPTURE_CODE" -eq 0 ] || fail "pendentes logo após init: $CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem pendentes: 0' || fail "pendentes logo após init: $CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q 'Uma frase por linha' && fail 'pendentes listou o modelo'
printf '%s\n' "$CAPTURE_OUT" | grep -q '_templates' && fail 'pendentes listou o modelo'
pass 'init não conta README nem _templates'

capture --sistema sisman init sisman SIS
[ "$CAPTURE_CODE" -ne 0 ] || fail 'segundo init deveria falhar'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'já inicializado' || fail 'mensagem de reinicialização'
pass 'init idempotente na falha'

code=0
disc="$(cd "$KNOW" && bash "$MEM" lint 2>&1)" || code=$?
[ "$code" -eq 0 ] || fail "lint no diretório por descoberta: $disc"
printf '%s\n' "$disc" | grep -q 'mem lint: 0' || fail 'descoberta sem contagem'
pass 'resolve a pasta da memória'

capture --sistema sisman novo regra --titulo 'Regra de fixture' --origem bot --tags 'os,regra' --gatilhos 'OS' --corpo 'Texto limpo da regra alfa-fixture.'
[ "$CAPTURE_CODE" -eq 0 ] || fail "novo bot: $CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q 'id=SIS-RN-0001' || fail 'id da regra'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'status=rascunho' || fail 'bot nasce rascunho'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem novo: 1' || fail 'contagem do novo'
pass 'novo bot'

capture --sistema sisman novo contexto --titulo 'Contexto da ordem' --origem ditado --contexto os --tags 'os' --gatilhos 'OS,ordem' --corpo 'Texto limpo do contexto.'
[ "$CAPTURE_CODE" -eq 0 ] || fail "novo ditado: $CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q 'id=SIS-CTX-0001' || fail 'id do contexto'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'status=pendente' || fail 'ditado nasce pendente'
[ -f "$KNOW/contextos/os/CONTEXTO.md" ] || fail 'CONTEXTO.md'
pass 'novo ditado'

capture --sistema sisman novo regra --titulo 'Nao nasce ativa' --origem confirmada --corpo 'nao'
[ "$CAPTURE_CODE" -ne 0 ] || fail 'origem confirmada deveria falhar'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'não nasce confirmada' || fail 'mensagem de nascimento'
pass 'não nasce confirmada'

capture --sistema sisman index
[ "$CAPTURE_CODE" -eq 0 ] || fail "index: $CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem index: 2' || fail 'contagem do index'
grep -q 'SIS-RN-0001' "$KNOW/INDEX.md" || fail 'index sem a regra'
grep -q 'SIS-CTX-0001' "$KNOW/INDEX.md" || fail 'index sem o contexto'
pass 'index'

capture --sistema sisman find --tipo regra
printf '%s\n' "$CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem find: 1' || fail 'find tipo'
capture --sistema sisman find --contexto os --tipo contexto
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem find: 1' || fail 'find contexto'
capture --sistema sisman find --tags os
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem find: 2' || fail 'find tags'
capture --sistema sisman find --status 'rascunho,pendente'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem find: 2' || fail 'find status'
capture --sistema sisman find --tipo regra --status pendente
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem find: 0' || fail 'find vazio'
pass 'find'

capture --sistema sisman grep 'Texto limpo'
printf '%s\n' "$CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem grep: 2' || fail 'grep contagem'
capture --sistema sisman grep 'ALFA-FIXTURE'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem grep: 1' || fail 'grep sem diferenciar maiúsculas'
pass 'grep'

capture --sistema sisman gatilho OS
printf '%s\n' "$CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem gatilho: 2' || fail 'gatilho'
pass 'gatilho'

capture --sistema sisman pendentes
printf '%s\n' "$CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem pendentes: 2' || fail 'pendentes'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'Uma frase por linha' && fail 'pendentes listou o modelo'
printf '%s\n' "$CAPTURE_OUT" | grep -q '_templates' && fail 'pendentes listou o modelo'
pass 'pendentes'

code=0
fromdir="$(cd "$KNOW" && bash "$MEM" find --tipo regra 2>&1)" || code=$?
[ "$code" -eq 0 ] || fail "find sem --sistema na pasta: $fromdir"
printf '%s\n' "$fromdir" | grep -q 'mem find: 1' || fail "find sem --sistema na pasta: $fromdir"
code=0
fromsub="$(cd "$KNOW/contextos/os" && bash "$MEM" find --tipo contexto 2>&1)" || code=$?
[ "$code" -eq 0 ] || fail "find sem --sistema na subpasta: $fromsub"
printf '%s\n' "$fromsub" | grep -q 'mem find: 1' || fail "find sem --sistema na subpasta: $fromsub"
pass 'busca sem --sistema na pasta e na subpasta'

capture --sistema sisman dupes
printf '%s\n' "$CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem dupes: 0' || fail 'dupes iniciais'
pass 'dupes zero'

capture --sistema sisman lint
printf '%s\n' "$CAPTURE_OUT"
[ "$CAPTURE_CODE" -eq 0 ] || fail 'lint limpo'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem lint: 0' || fail 'contagem do lint'
pass 'lint zero'

capture --sistema sisman show SIS-RN-0001
printf '%s\n' "$CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem show: 1' || fail 'show'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'status: rascunho' || fail 'show status'
pass 'show'

capture --sistema sisman pacote SIS-CTX-0001 SIS-RN-0001
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem pacote: 2' || fail 'pacote'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'hipótese' || fail 'pacote sem rótulo'
pass 'pacote'

printf '== dupes ==\n'
capture --sistema dup init dup DU
[ "$CAPTURE_CODE" -eq 0 ] || fail "init dup: $CAPTURE_OUT"
run --sistema dup novo regra --titulo 'Preco final do item' --origem bot --contexto vendas --tags 'preco,final' --corpo 'Um.' >/dev/null
run --sistema dup novo regra --titulo 'Outro assunto qualquer' --origem bot --contexto vendas --tags 'preco, final' --corpo 'Dois.' >/dev/null
run --sistema dup novo regra --titulo 'Limite diario de desconto' --origem bot --contexto vendas --tags 'alfa' --corpo 'Tres.' >/dev/null
run --sistema dup novo regra --titulo 'Limite diario de juros' --origem bot --contexto vendas --tags 'beta' --corpo 'Quatro.' >/dev/null
run --sistema dup novo regra --titulo 'Limite diario de desconto' --origem bot --contexto caixa --tags 'alfa' --corpo 'Cinco.' >/dev/null
capture --sistema dup dupes
printf '%s\n' "$CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q 'DUP DU-RN-0001 DU-RN-0002' || fail 'par por tag'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'DUP DU-RN-0003 DU-RN-0004' || fail 'par por título'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem dupes: 2' || fail 'contagem de dupes'
pass 'dupes'

printf '== index omite obsoleta ==\n'
capture --sistema idx init idx IDX
[ "$CAPTURE_CODE" -eq 0 ] || fail "init idx: $CAPTURE_OUT"
run --sistema idx novo regra --titulo 'Cartao ativo' --origem bot --corpo 'Ativo.' >/dev/null
cat > "$TMP/repos/idx/conhecimento/projeto/velho.md" <<'EOF'
---
id: IDX-RN-0099
tipo: regra
titulo: Cartao velho
escopo: projeto
tags: [velho]
status: obsoleta
fonte: [bot]
dono: revisor-entrega
criado: 2026-10-26
atualizado: 2026-10-26
gatilhos: []
---
Fora da lista principal.
EOF
capture --sistema idx index
printf '%s\n' "$CAPTURE_OUT"
[ "$CAPTURE_CODE" -eq 0 ] || fail "index com obsoleta: $CAPTURE_OUT"
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem index: 1' || fail 'obsoleta entrou na contagem'
grep -q 'IDX-RN-0099' "$TMP/repos/idx/conhecimento/INDEX.md" && fail 'obsoleta listada no index'
pass 'index sem obsoleta'

cpf_base="$(printf '%s' '529982247')"
cpf_ok="${cpf_base}$(printf '%s' '25')"
sum=0
for i in 0 1 2 3 4 5 6 7 8; do
  sum=$((sum + ${cpf_ok:i:1} * (10 - i)))
done
mod=$((sum % 11))
if (( mod < 2 )); then dig=0; else dig=$((11 - mod)); fi
[ "${cpf_ok:9:1}" = "$dig" ] || fail 'vetor de CPF não confere no primeiro dígito'
sum=0
for i in 0 1 2 3 4 5 6 7 8 9; do
  sum=$((sum + ${cpf_ok:i:1} * (11 - i)))
done
mod=$((sum % 11))
if (( mod < 2 )); then dig=0; else dig=$((11 - mod)); fi
[ "${cpf_ok:10:1}" = "$dig" ] || fail 'vetor de CPF não confere no segundo dígito'

md_count() { find "$1" -name '*.md' | wc -l | tr -d ' '; }

block() {
  local name="$1" class="$2" body="$3" before after
  before="$(md_count "$LAB")"
  capture --sistema lab novo regra --titulo "Bloqueio $name" --origem bot --corpo "$body"
  after="$(md_count "$LAB")"
  [ "$CAPTURE_CODE" -ne 0 ] || fail "$name deveria bloquear"
  printf '%s\n' "$CAPTURE_OUT" | grep -q "$class" || { printf '%s\n' "$CAPTURE_OUT" >&2; fail "$name sem $class"; }
  [ "$before" = "$after" ] || fail "$name manteve arquivo"
  printf 'PASS: bloqueia %s (%s)\n' "$name" "$class"
  printf '%s\n' "$CAPTURE_OUT"
}

allow() {
  local name="$1" body="$2"
  capture --sistema lab novo regra --titulo "Livre $name" --origem bot --corpo "$body"
  [ "$CAPTURE_CODE" -eq 0 ] || { printf '%s\n' "$CAPTURE_OUT" >&2; fail "allow $name"; }
  printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem novo: 1' || fail "allow $name contagem"
  printf 'PASS: aceita %s\n' "$name"
  printf '%s\n' "$CAPTURE_OUT"
}

printf '== C05 e C06 lint ==\n'
capture --sistema lab init lab LAB
[ "$CAPTURE_CODE" -eq 0 ] || fail "init lab: $CAPTURE_OUT"
LAB="$TMP/repos/lab/conhecimento"

block cpf-fmt cpf-formatado "$(printf '%s' '529.' '982.' '247-' '00')"
block cpf-ok cpf-valido "$cpf_ok"
block email email "$(printf '%s' 'usuario.teste' '@' 'example.com')"
block fone telefone "$(printf '%s' '(' '11' ') ' '90000' '-' '0000')"
block luhn cartao "$(printf '%s' '4111' '1111' '1111' '1111')"
block ag agencia "$(printf '%s' 'ag' 'encia ' '1234')"
block conta conta "$(printf '%s' 'conta ' '12345-6')"
block iban iban "$(printf '%s' 'IBAN ' 'BR00' '000000' '000000' '000000' '000C')"
block pix pix "$(printf '%s' 'pix' ': ' 'fixture-chave')"
block kw segredo "$(printf '%s' 'se' 'nha: ' 'fixture')"
block server segredo "$(printf '%s' 'server' '=' 'fixture-host')"
block datasource segredo "$(printf '%s' 'data source' '=' 'fixture')"
block cs segredo "$(printf '%s' 'connection' 'strings')"
block jwt segredo "$(printf '%s' 'eyJ' 'abcdefghijk' '.' 'abcdefghijk' '.')"
block pem segredo "$(printf '%s' '-----BEGIN ' 'PRIVATE KEY-----')"
block reval revalidar_em "$(printf '%s' 'revalidar_em' ': 2026-10-26')"

allow cpf-ruim "$(printf '%s' '529982247' '00')"
allow repetido "$(printf '%s' '111111111' '11')"
allow username "$(printf '%s' 'username ' 'fixture.user')"
allow limpo 'Texto limpo de fixture, sem numero.'
allow luhn-ruim "$(printf '%s' '4111' '1111' '1111' '1112')"
allow senha-solta "$(printf '%s' 'se' 'nha sem separador')"

capture --sistema lab lint
[ "$CAPTURE_CODE" -eq 0 ] || { printf '%s\n' "$CAPTURE_OUT" >&2; fail 'lint do lab'; }
printf '%s\n' "$CAPTURE_OUT" | grep -q 'mem lint: 0' || fail 'lab não ficou limpo'
pass 'lint do lab'

cat > "$LAB/projeto/confirmada-sem.md" <<'EOF'
---
id: LAB-RN-0098
tipo: regra
titulo: Sem ok
escopo: projeto
tags: [ok]
status: confirmada
fonte: [bot]
dono: revisor-entrega
criado: 2026-10-26
atualizado: 2026-10-26
gatilhos: []
---
Sem marcador.
EOF
capture --sistema lab lint
[ "$CAPTURE_CODE" -ne 0 ] || fail 'confirmada sem ok deveria falhar'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'confirmada-sem-ok' || fail 'classe confirmada-sem-ok'
printf '%s\n' "$CAPTURE_OUT"
rm -f "$LAB/projeto/confirmada-sem.md"
cat > "$LAB/projeto/confirmada-ok.md" <<'EOF'
---
id: LAB-RN-0097
tipo: regra
titulo: Com ok
escopo: projeto
tags: [ok]
status: confirmada
fonte: [bot]
dono: revisor-entrega
confirmado_por: matheus: ok
criado: 2026-10-26
atualizado: 2026-10-26
gatilhos: []
---
Com marcador.
EOF
capture --sistema lab lint
[ "$CAPTURE_CODE" -eq 0 ] || { printf '%s\n' "$CAPTURE_OUT" >&2; fail 'confirmada com ok'; }
pass 'confirmada só com ok do Matheus'

printf '%s\n' "$(printf '%s' 'server' '=')fixture" >> "$LAB/projeto/confirmada-ok.md"
capture --sistema lab index
[ "$CAPTURE_CODE" -ne 0 ] || fail 'index deveria abortar'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'index abortado' || fail 'mensagem de aborto do index'
printf '%s\n' "$CAPTURE_OUT" | grep -q 'segredo' || fail 'index sem a classe'
printf '%s\n' "$CAPTURE_OUT"
pass 'index aborta com lint'

printf '== C08 gitignore ==\n'
prot="$TMP/protegido"
mkdir -p "$prot"
git -C "$prot" init -q
printf '\357\273\277# custom\r\nkeep\r\n' > "$prot/.gitignore"
before="$TMP/before.gitignore"
cp "$prot/.gitignore" "$before"
bash "$PROTECT" "$prot"
bash "$PROTECT" "$prot"
blen="$(wc -c < "$before" | tr -d ' ')"
cmp -n "$blen" "$before" "$prot/.gitignore" || fail 'protect alterou o prefixo'
for line in 'Planejamento/' 'planejamento/' 'conhecimento/'; do
  n="$(grep -c -F -x "$line" <(sed $'s/\r$//' "$prot/.gitignore") || true)"
  [ "$n" = "1" ] || fail "$line apareceu $n vezes no protect"
done
pass 'protect idempotente e preserva BOM/CRLF'

inst="$TMP/instalado"
mkdir -p "$inst"
git -C "$inst" init -q
bash "$INSTALL" "$inst" --profile core
snap="$TMP/gitignore.snap"
cp "$inst/.gitignore" "$snap"
bash "$INSTALL" "$inst" --profile core
cmp "$snap" "$inst/.gitignore" || fail 'segunda instalação alterou o .gitignore'
for line in 'Planejamento/' 'planejamento/' 'conhecimento/'; do
  n="$(grep -c -F -x "$line" "$inst/.gitignore" || true)"
  [ "$n" = "1" ] || fail "$line apareceu $n vezes na instalação"
done
pass 'instalador idempotente'

printf 'TEST_MEMORIA_SH_OK\n'
