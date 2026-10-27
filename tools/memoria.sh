#!/usr/bin/env bash
# mem — memória local (engineering-flow 3.1). Sem Git e sem busca semântica.
# Versionamento em Git previsto para a 3.2. A raiz vem de maquinas.conf (EF_MAQUINA).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TEMPLATE="$PACK_ROOT/memory-template"

die() { printf 'mem: %s\n' "$*" >&2; exit 1; }

trim() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

load_conf() {
  local conf="${EF_MAQUINAS_CONF:-$PACK_ROOT/config/maquinas.conf}"
  local line section="" key val blocks=""
  RAIZ_REPOS=""
  [ -f "$conf" ] || die "maquinas.conf ausente (${conf}). Copie config/maquinas.conf.example para config/maquinas.conf. Nenhum caminho foi assumido."
  [ -n "${EF_MAQUINA:-}" ] || die "EF_MAQUINA ausente. Defina EF_MAQUINA com o bloco de maquinas.conf. Sem bloco, o mem não escolhe máquina."
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    line="$(trim "$line")"
    [ -n "$line" ] || continue
    [[ "$line" == \#* ]] && continue
    if [[ "$line" =~ ^\[([A-Za-z0-9_-]+)\]$ ]]; then
      section="${BASH_REMATCH[1]}"
      blocks="${blocks}${section} "
      continue
    fi
    [ "$section" = "$EF_MAQUINA" ] || continue
    [[ "$line" =~ ^([A-Za-z0-9_]+)[[:space:]]*[:=][[:space:]]*(.*)$ ]] || continue
    key="${BASH_REMATCH[1]}"
    val="$(trim "${BASH_REMATCH[2]}")"
    val="${val%\"}"; val="${val#\"}"; val="${val%\'}"; val="${val#\'}"
    if [ "$key" = "raiz_repos" ]; then RAIZ_REPOS="$val"; fi
  done < "$conf"
  if [ -z "$RAIZ_REPOS" ]; then
    if [[ " ${blocks}" == *" ${EF_MAQUINA} "* ]]; then
      die "O bloco [${EF_MAQUINA}] não define raiz_repos."
    fi
    local shown
    shown="$(trim "$blocks")"
    [ -n "$shown" ] || shown='nenhum'
    die "EF_MAQUINA='${EF_MAQUINA}' não é um bloco de maquinas.conf. Blocos: ${shown}."
  fi
  case "$RAIZ_REPOS" in
    *$'\n'*|*'..'*) die "raiz_repos inválida no bloco [${EF_MAQUINA}]." ;;
  esac
}

need_slug() {
  [[ "$1" =~ ^[a-z][a-z0-9-]{0,40}$ ]] || die "sistema inválido: use um slug [a-z0-9-]."
}

need_prefix() {
  [[ "$1" =~ ^[A-Z][A-Z0-9]{1,3}$ ]] || die "prefixo inválido: 2 a 4 letras maiúsculas."
}

mem_dir_for() {
  local sistema="$1"
  need_slug "$sistema"
  printf '%s/%s/conhecimento' "$RAIZ_REPOS" "$sistema"
}

resolve_dir() {
  local dir="" walk="$PWD"
  if [ -n "${MEM_SISTEMA:-}" ]; then
    dir="$(mem_dir_for "$MEM_SISTEMA")"
  else
    while [ "$walk" != "/" ]; do
      if [ -f "$walk/.memoria.conf" ]; then dir="$walk"; break; fi
      walk="$(dirname "$walk")"
    done
  fi
  [ -n "$dir" ] && [ -f "$dir/.memoria.conf" ] || die "memória não encontrada. Rode mem init <sistema> <prefixo> ou passe --sistema."
  case "$dir/" in
    "$RAIZ_REPOS"/*) ;;
    *) die "a memória está fora da raiz configurada para EF_MAQUINA=${EF_MAQUINA}." ;;
  esac
  MEM_DIR="$dir"
  PREFIXO="$(awk -F: '/^prefixo:/{gsub(/^[ \t]+/,"",$2); print $2; exit}' "$MEM_DIR/.memoria.conf")"
  PREFIXO="$(trim "${PREFIXO:-}")"
  [ -n "$PREFIXO" ] || die ".memoria.conf sem prefixo."
}

conf_value() {
  local key="$1" file="$2" raw
  raw="$(awk -F: -v k="$key" '$1==k {sub(/^[^:]*:[[:space:]]*/,""); print; exit}' "$file")"
  trim "${raw:-}"
}

tipo_code() {
  case "$1" in
    contexto) printf 'CTX' ;;
    regra) printf 'RN' ;;
    decisao) printf 'ADR' ;;
    glossario) printf 'GLO' ;;
    modulo) printf 'MOD' ;;
    armadilha) printf 'ARM' ;;
    contrato) printf 'CTR' ;;
    runbook) printf 'RUN' ;;
    preferencia) printf 'PREF' ;;
    *) die "tipo desconhecido: $1" ;;
  esac
}

slugify() {
  local s
  s="$(printf '%s' "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || printf '%s' "$1")"
  s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/-\{2,\}/-/g; s/^-//; s/-$//' | cut -c1-40)"
  [ -n "$s" ] || s="cartao"
  printf '%s' "$s"
}

cpf_valido() {
  local d="$1" i sum mod dig a
  [[ "$d" =~ ^[0-9]{11}$ ]] || return 1
  [[ "$d" =~ ^([0-9])\1{10}$ ]] && return 1
  sum=0
  for i in 0 1 2 3 4 5 6 7 8; do
    a="${d:i:1}"
    sum=$((sum + a * (10 - i)))
  done
  mod=$((sum % 11))
  if (( mod < 2 )); then dig=0; else dig=$((11 - mod)); fi
  [ "${d:9:1}" = "$dig" ] || return 1
  sum=0
  for i in 0 1 2 3 4 5 6 7 8 9; do
    a="${d:i:1}"
    sum=$((sum + a * (11 - i)))
  done
  mod=$((sum % 11))
  if (( mod < 2 )); then dig=0; else dig=$((11 - mod)); fi
  [ "${d:10:1}" = "$dig" ]
}

luhn_valido() {
  local n="$1" i d sum=0 alt=0 len
  len="${#n}"
  (( len >= 13 && len <= 19 )) || return 1
  for ((i=len-1; i>=0; i--)); do
    d="${n:i:1}"
    if (( alt )); then
      d=$((d * 2))
      (( d > 9 )) && d=$((d - 9))
    fi
    sum=$((sum + d))
    alt=$((1 - alt))
  done
  (( sum % 10 == 0 ))
}

secret_re() {
  local kw cs pem
  kw="$(printf '%s' 'pass' 'word|p' 'wd|se' 'nha|sec' 'ret|api' 'key|api_' 'key|account' 'key|sharedaccess' 'key')"
  cs="$(printf '%s' 'connection' 'strings')"
  pem="$(printf '%s' '-----BEGIN ' 'PRIVATE KEY-----')"
  printf '%s' "(?i)(${kw})[[:space:]]*[=:]|(?i)(server|data[[:space:]]*source)[[:space:]]*=|(?i)${cs}|eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}\\.|${pem}"
}

lint_line() {
  local file="$1" n="$2" line="$3" re cpf digits cand
  if printf '%s' "$line" | grep -qiE '(^|[[:space:]])revalidar_em[[:space:]]*:'; then
    printf '%s:%s:revalidar_em\n' "$file" "$n"
  fi
  re="$(secret_re)"
  if printf '%s' "$line" | grep -qP "$re"; then
    printf '%s:%s:segredo\n' "$file" "$n"
  fi
  if printf '%s' "$line" | grep -qP '(?<![0-9])[0-9]{3}\.[0-9]{3}\.[0-9]{3}-[0-9]{2}(?![0-9])'; then
    printf '%s:%s:cpf-formatado\n' "$file" "$n"
  fi
  while IFS= read -r cpf; do
    [ -n "$cpf" ] || continue
    if cpf_valido "$cpf"; then printf '%s:%s:cpf-valido\n' "$file" "$n"; fi
  done < <(printf '%s\n' "$line" | grep -oP '(?<![0-9])[0-9]{11}(?![0-9])' || true)
  if printf '%s' "$line" | grep -qP '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'; then
    printf '%s:%s:email\n' "$file" "$n"
  fi
  if printf '%s' "$line" | grep -qP '\([0-9]{2}\)[[:space:]]*[0-9]{4,5}-?[0-9]{4}|\+[0-9]{1,3}[[:space:]]*[0-9]{2}[[:space:]]*[0-9]{4,5}-?[0-9]{4}|\b[0-9]{2}[[:space:]][0-9]{4,5}-[0-9]{4}\b'; then
    printf '%s:%s:telefone\n' "$file" "$n"
  fi
  while IFS= read -r cand; do
    [ -n "$cand" ] || continue
    digits="$(printf '%s' "$cand" | tr -cd '0-9')"
    if luhn_valido "$digits"; then printf '%s:%s:cartao\n' "$file" "$n"; fi
  done < <(printf '%s\n' "$line" | grep -oE '[0-9]([0-9]|[ -][0-9]){12,18}' || true)
  if printf '%s' "$line" | grep -qP '(?i)ag(?:ê|e)ncia[[:space:]]*[:=]?[[:space:]]*[0-9]{3,6}'; then
    printf '%s:%s:agencia\n' "$file" "$n"
  fi
  if printf '%s' "$line" | grep -qP '(?i)\bconta[[:space:]]*[:=][[:space:]]*[0-9][0-9.\-]{3,}|\bconta[[:space:]]+[0-9]{5,}(-[0-9])?\b'; then
    printf '%s:%s:conta\n' "$file" "$n"
  fi
  if printf '%s' "$line" | grep -qP '(?i)\bIBAN[[:space:]]*[:=]?[[:space:]]*[A-Z]{2}[0-9]{2}[A-Z0-9]{8,}'; then
    printf '%s:%s:iban\n' "$file" "$n"
  fi
  if printf '%s' "$line" | grep -qP '(?i)(\bchave[[:space:]]+pix\b|\bpix\b)[[:space:]]*[:=][[:space:]]*\S+'; then
    printf '%s:%s:pix\n' "$file" "$n"
  fi
}

is_card_path() {
  local rel="$1"
  case "$rel" in
    _templates/*|README.md|INDEX.md|.gitignore) return 1 ;;
  esac
  [[ "$rel" == *.md ]]
}

list_files() {
  find "$MEM_DIR" -type f -not -path '*/.cache/*' | LC_ALL=C sort
}

card_files() {
  local file rel
  while IFS= read -r file; do
    rel="${file#"$MEM_DIR"/}"
    if is_card_path "$rel"; then printf '%s\n' "$file"; fi
  done < <(list_files)
}

cmd_init() {
  local sistema="${1:-}" prefixo="${2:-}" dest
  [ -n "$sistema" ] && [ -n "$prefixo" ] || die "uso: mem init <sistema> <prefixo>"
  need_slug "$sistema"
  need_prefix "$prefixo"
  dest="$(mem_dir_for "$sistema")"
  [ ! -e "$dest/.memoria.conf" ] || die "já inicializado: $dest"
  mkdir -p "$dest/contextos" "$dest/projeto" "$dest/repos" "$dest/_templates"
  cp "$TEMPLATE/README.md" "$dest/README.md"
  cp "$TEMPLATE/.gitignore" "$dest/.gitignore"
  cp "$TEMPLATE/_templates/cartao.md" "$dest/_templates/cartao.md"
  sed -e "s/^prefixo:.*/prefixo: ${prefixo}/" -e "s/^sistema:.*/sistema: ${sistema}/" "$TEMPLATE/.memoria.conf" > "$dest/.memoria.conf"
  printf 'raiz_repos=%s\n' "$RAIZ_REPOS"
  printf 'conhecimento=%s\n' "$dest"
  printf 'mem init: 1\n'
}

next_id() {
  local code="$1" max=0 file id n
  while IFS= read -r file; do
    id="$(conf_value id "$file")"
    [[ "$id" =~ ^${PREFIXO}-${code}-([0-9]{4})$ ]] || continue
    n=$((10#${BASH_REMATCH[1]}))
    (( n > max )) && max=$n
  done < <(card_files || true)
  printf '%s-%s-%04d' "$PREFIXO" "$code" "$((max + 1))"
}

cmd_novo() {
  local tipo="${1:-}" titulo="" origem="" ctx="" tags="" gatilhos="" escopo="projeto" corpo="" code id slug dest dir hoje status
  [ -n "$tipo" ] || die "uso: mem novo <tipo> --titulo ... --origem ditado|bot"
  shift || true
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --titulo) titulo="${2:-}"; shift 2 ;;
      --origem) origem="${2:-}"; shift 2 ;;
      --contexto) ctx="${2:-}"; shift 2 ;;
      --tags) tags="${2:-}"; shift 2 ;;
      --gatilhos) gatilhos="${2:-}"; shift 2 ;;
      --escopo) escopo="${2:-}"; shift 2 ;;
      --corpo) corpo="${2:-}"; shift 2 ;;
      *) die "argumento desconhecido em novo: $1" ;;
    esac
  done
  [ -n "$titulo" ] || die "novo exige --titulo."
  case "$origem" in
    ditado) status="pendente" ;;
    bot) status="rascunho" ;;
    *) die "novo exige --origem ditado ou --origem bot. Cartão não nasce confirmada." ;;
  esac
  case "$escopo" in
    projeto|repo|global) ;;
    *) die "escopo inválido." ;;
  esac
  [ -z "$ctx" ] || [[ "$ctx" =~ ^[a-z0-9-]{1,40}$ ]] || die "contexto inválido."
  code="$(tipo_code "$tipo")"
  id="$(next_id "$code")"
  slug="$(slugify "$titulo")"
  hoje="$(date +%F)"
  [ -n "$tags" ] || tags="geral"
  tags="$(printf '%s' "$tags" | sed 's/[[:space:]]*,[[:space:]]*/, /g')"
  [ -n "$gatilhos" ] || gatilhos=""
  gatilhos="$(printf '%s' "$gatilhos" | sed 's/[[:space:]]*,[[:space:]]*/, /g')"
  [ -n "$corpo" ] || corpo="Cartão fictício."
  if [ "$tipo" = "contexto" ]; then
    [ -n "$ctx" ] || die "tipo contexto exige --contexto."
    dir="$MEM_DIR/contextos/$ctx"
    mkdir -p "$dir"
    dest="$dir/CONTEXTO.md"
    [ ! -e "$dest" ] || die "contexto já existe: $ctx"
  elif [ -n "$ctx" ]; then
    dir="$MEM_DIR/contextos/$ctx"
    mkdir -p "$dir"
    dest="$dir/${id}--${slug}.md"
  else
    dest="$MEM_DIR/projeto/${id}--${slug}.md"
  fi
  {
    printf '%s\n' '---'
    printf 'id: %s\n' "$id"
    printf 'tipo: %s\n' "$tipo"
    printf 'titulo: %s\n' "$titulo"
    printf 'escopo: %s\n' "$escopo"
    printf 'tags: [%s]\n' "$tags"
    printf 'status: %s\n' "$status"
    printf 'fonte: [%s]\n' "$origem"
    printf 'dono: revisor-entrega\n'
    printf 'criado: %s\n' "$hoje"
    printf 'atualizado: %s\n' "$hoje"
    [ -n "$ctx" ] && printf 'contexto: %s\n' "$ctx"
    printf 'gatilhos: [%s]\n' "$gatilhos"
    printf '%s\n' '---'
    printf '%s\n' "$corpo"
  } > "$dest"
  local hits
  hits="$(lint_one_file "$dest" || true)"
  if [ -n "$hits" ]; then
    rm -f "$dest"
    printf '%s\n' "$hits" >&2
    die "escrita bloqueada pelo lint. O arquivo não foi mantido."
  fi
  printf 'id=%s\n' "$id"
  printf 'status=%s\n' "$status"
  printf 'mem novo: 1\n'
}

lint_one_file() {
  local file="$1" rel n=0 line
  rel="${file#"$MEM_DIR"/}"
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    lint_line "$rel" "$n" "$line"
  done < "$file"
}

cmd_lint() {
  local hits count
  hits="$(lint_scan || true)"
  count="$(printf '%s\n' "$hits" | sed '/^$/d' | wc -l | tr -d ' ')"
  [ -n "$hits" ] && printf '%s\n' "$hits"
  printf 'mem lint: %s\n' "$count"
  [ "$count" -eq 0 ]
}

lint_scan() {
  local file rel n line id list=""
  while IFS= read -r file; do
    rel="${file#"$MEM_DIR"/}"
    n=0
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      lint_line "$rel" "$n" "$line"
    done < "$file"
    if is_card_path "$rel"; then
      id="$(conf_value id "$file")"
      local tipo titulo escopo tags status fonte dono criado atualizado conf
      tipo="$(conf_value tipo "$file")"
      titulo="$(conf_value titulo "$file")"
      escopo="$(conf_value escopo "$file")"
      tags="$(conf_value tags "$file")"
      status="$(conf_value status "$file")"
      fonte="$(conf_value fonte "$file")"
      dono="$(conf_value dono "$file")"
      criado="$(conf_value criado "$file")"
      atualizado="$(conf_value atualizado "$file")"
      if [ -z "$id" ] || [ -z "$tipo" ] || [ -z "$titulo" ] || [ -z "$escopo" ] || [ -z "$tags" ] || [ -z "$status" ] || [ -z "$fonte" ] || [ -z "$dono" ] || [ -z "$criado" ] || [ -z "$atualizado" ]; then
        printf '%s:1:front-matter\n' "$rel"
      fi
      case "${status:-}" in
        pendente|rascunho|confirmada|conflito|obsoleta|substituida) ;;
        *) printf '%s:1:front-matter\n' "$rel" ;;
      esac
      if [ "${status:-}" = "confirmada" ]; then
        conf="$(conf_value confirmado_por "$file")"
        printf '%s' "$conf" | grep -q '^matheus:' || printf '%s:1:confirmada-sem-ok\n' "$rel"
      fi
      if [ -n "$id" ]; then
        if printf '%s\n' "$list" | grep -Fxq "$id"; then
          printf '%s:1:id-duplicado\n' "$rel"
        fi
        list="${list}${id}"$'\n'
      fi
    fi
  done < <(list_files)
}

row_of() {
  local file="$1"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(conf_value id "$file")" \
    "$(conf_value tipo "$file")" \
    "$(conf_value status "$file")" \
    "$(conf_value contexto "$file")" \
    "$(conf_value tags "$file")" \
    "$(conf_value titulo "$file")" \
    "$(conf_value gatilhos "$file")"
}

cmd_index() {
  local hits count rows id tipo status ctx tags titulo gat
  hits="$(lint_scan || true)"
  count="$(printf '%s\n' "$hits" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "$count" -ne 0 ]; then
    printf '%s\n' "$hits" >&2
    printf 'mem lint: %s\n' "$count" >&2
    die "index abortado: o lint bloqueou."
  fi
  rows="$(while IFS= read -r file; do row_of "$file"; done < <(card_files) | LC_ALL=C sort)"
  {
    printf '%s\n' '# INDEX'
    printf '\n'
    printf '%s\n' 'Gerado por mem index. Não editar à mão.'
    printf '%s\n' 'Memória local; versionamento em Git previsto para a 3.2.'
    printf 'sistema: %s\n' "$(conf_value sistema "$MEM_DIR/.memoria.conf")"
    printf 'prefixo: %s\n' "$PREFIXO"
    printf '\n'
    printf '%s\n' '## Contextos e gatilhos'
    if [ -n "$rows" ]; then
      while IFS=$'\t' read -r id tipo status ctx tags titulo gat; do
        [ "$tipo" = "contexto" ] || continue
        printf -- '- %s | %s | gatilhos: %s | %s\n' "$id" "${ctx:-}" "${gat:-}" "$titulo"
      done <<< "$rows"
    fi
    printf '\n'
    printf '%s\n' '## Cartões'
    count=0
    if [ -n "$rows" ]; then
      while IFS=$'\t' read -r id tipo status ctx tags titulo gat; do
        case "$status" in
          obsoleta|substituida) continue ;;
        esac
        printf '%s | %s | %s | %s | %s | %s\n' "$id" "$tipo" "$status" "${ctx:-}" "${tags:-}" "$titulo"
        count=$((count + 1))
      done <<< "$rows"
    fi
  } > "$MEM_DIR/INDEX.md"
  printf 'index=%s\n' "$MEM_DIR/INDEX.md"
  printf 'mem index: %s\n' "$count"
}

match_tags() {
  local have="$1" want="$2" one
  [ -z "$want" ] && return 0
  IFS=',' read -r -a parts <<< "$want"
  for one in "${parts[@]}"; do
    one="$(trim "$one")"
    printf '%s' "$have" | grep -F -q -i -- "$one" && return 0
  done
  return 1
}

cmd_find() {
  local ctx="" tipo="" tags="" repo="" status="" count=0 id t s c g titulo gat file
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --contexto) ctx="${2:-}"; shift 2 ;;
      --tipo) tipo="${2:-}"; shift 2 ;;
      --tags) tags="${2:-}"; shift 2 ;;
      --repo) repo="${2:-}"; shift 2 ;;
      --status) status="${2:-}"; shift 2 ;;
      *) die "argumento desconhecido em find: $1" ;;
    esac
  done
  while IFS= read -r file; do
    id="$(conf_value id "$file")"
    t="$(conf_value tipo "$file")"
    s="$(conf_value status "$file")"
    c="$(conf_value contexto "$file")"
    g="$(conf_value tags "$file")"
    titulo="$(conf_value titulo "$file")"
    [ -z "$ctx" ] || [ "$c" = "$ctx" ] || continue
    [ -z "$tipo" ] || [ "$t" = "$tipo" ] || continue
    [ -z "$status" ] || [[ ",$status," == *",$s,"* ]] || continue
    if [ -n "$repo" ]; then
      conf_value repos "$file" | grep -F -q -i -- "$repo" || continue
    fi
    match_tags "$g" "$tags" || continue
    printf '%s | %s | %s | %s | %s | %s\n' "$id" "$t" "$s" "$c" "$g" "$titulo"
    count=$((count + 1))
  done < <(card_files | while IFS= read -r f; do printf '%s\t%s\n' "$(conf_value id "$f")" "$f"; done | LC_ALL=C sort | cut -f2-)
  printf 'mem find: %s\n' "$count"
}

cmd_grep() {
  local term="${1:-}" file id n=0 line count=0
  [ -n "$term" ] || die "uso: mem grep <termo>"
  while IFS= read -r file; do
    id="$(conf_value id "$file")"
    [ -n "$id" ] || id="$(basename "$file")"
    n=0
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      if printf '%s' "$line" | grep -F -q -i -- "$term"; then
        printf '%s:%s:%s\n' "$id" "$n" "$line"
        count=$((count + 1))
      fi
    done < "$file"
  done < <(card_files)
  printf 'mem grep: %s\n' "$count"
}

find_id() {
  local want="$1" file id
  while IFS= read -r file; do
    id="$(conf_value id "$file")"
    if [ "$id" = "$want" ]; then printf '%s\n' "$file"; return 0; fi
  done < <(card_files)
  return 1
}

cmd_show() {
  local id file count=0
  [ "$#" -gt 0 ] || die "uso: mem show <id>..."
  for id in "$@"; do
    file="$(find_id "$id" || true)"
    [ -n "$file" ] || die "id não encontrado: $id"
    printf '===== %s =====\n' "$id"
    cat "$file"
    printf '\n'
    count=$((count + 1))
  done
  printf 'mem show: %s\n' "$count"
}

cmd_pacote() {
  local id file count=0
  [ "$#" -gt 0 ] || die "uso: mem pacote <id>..."
  printf '%s\n' '# Pacote para a ordem de serviço'
  printf '%s\n' 'confirmada = regra; rascunho ou pendente = hipótese.'
  for id in "$@"; do
    file="$(find_id "$id" || true)"
    [ -n "$file" ] || die "id não encontrado: $id"
    printf '\n## %s (%s)\n\n' "$id" "$(conf_value status "$file")"
    cat "$file"
    printf '\n'
    count=$((count + 1))
  done
  printf 'mem pacote: %s\n' "$count"
}

cmd_gatilho() {
  local palavra="${1:-}" file id gat count=0
  [ -n "$palavra" ] || die "uso: mem gatilho <palavra>"
  while IFS= read -r file; do
    gat="$(conf_value gatilhos "$file")"
    [ -n "$gat" ] || continue
    if printf '%s' "$gat" | grep -F -q -i -- "$palavra"; then
      id="$(conf_value id "$file")"
      printf '%s | %s | %s\n' "$id" "$(conf_value contexto "$file")" "$gat"
      count=$((count + 1))
    fi
  done < <(card_files | while IFS= read -r f; do printf '%s\t%s\n' "$(conf_value id "$f")" "$f"; done | LC_ALL=C sort | cut -f2-)
  printf 'mem gatilho: %s\n' "$count"
}

cmd_pendentes() {
  local file id status count=0
  while IFS= read -r file; do
    status="$(conf_value status "$file")"
    case "$status" in
      pendente|rascunho|conflito)
        id="$(conf_value id "$file")"
        printf '%s | %s | %s\n' "$id" "$status" "$(conf_value titulo "$file")"
        count=$((count + 1))
        ;;
    esac
  done < <(card_files | while IFS= read -r f; do printf '%s\t%s\n' "$(conf_value id "$f")" "$f"; done | LC_ALL=C sort | cut -f2-)
  printf 'mem pendentes: %s\n' "$count"
}

norm_words() {
  local raw stop=" de da do das dos a o e em no na nos nas para com por um uma que se os as "
  raw="$(printf '%s' "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || printf '%s' "$1")"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z' ' ')"
  local out="" w
  for w in $raw; do
    case "$stop" in
      *" $w "*) ;;
      *) out="$out $w" ;;
    esac
  done
  trim "$out"
}

cmd_dupes() {
  local tmp count=0 i j n id1 id2 t1 t2 c1 c2 g1 g2 w1 w2
  tmp="$(mktemp)"
  while IFS= read -r file; do
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$(conf_value id "$file")" \
      "$(conf_value tipo "$file")" \
      "$(conf_value contexto "$file")" \
      "$(conf_value tags "$file" | tr -d '[:space:]')" \
      "$(norm_words "$(conf_value titulo "$file")")"
  done < <(card_files) | LC_ALL=C sort > "$tmp"
  n="$(wc -l < "$tmp" | tr -d ' ')"
  if [ "$n" -gt 1 ]; then
    for ((i=1; i<n; i++)); do
      for ((j=i+1; j<=n; j++)); do
        IFS=$'\t' read -r id1 t1 c1 g1 w1 <<< "$(sed -n "${i}p" "$tmp")"
        IFS=$'\t' read -r id2 t2 c2 g2 w2 <<< "$(sed -n "${j}p" "$tmp")"
        [ "$t1" = "$t2" ] && [ "$c1" = "$c2" ] || continue
        local hit=0 shared=0 union=0 ww
        if [ -n "$g1" ] && [ "$g1" != "[]" ] && [ "$g1" = "$g2" ]; then hit=1; fi
        if [ "$hit" -eq 0 ] && [ -n "$w1" ] && [ -n "$w2" ]; then
          shared=0
          for ww in $w1; do
            case " $w2 " in
              *" $ww "*) shared=$((shared + 1)) ;;
            esac
          done
          union=$(( $(printf '%s %s\n' "$w1" "$w2" | tr ' ' '\n' | sed '/^$/d' | sort -u | wc -l) ))
          if (( shared >= 2 && union > 0 && shared * 2 >= union )); then hit=1; fi
        fi
        if [ "$hit" -eq 1 ]; then
          printf 'DUP %s %s\n' "$id1" "$id2"
          count=$((count + 1))
        fi
      done
    done
  fi
  rm -f "$tmp"
  printf 'mem dupes: %s\n' "$count"
}

usage() {
  cat <<'EOF'
uso: mem <comando> [args]
comandos: init, novo, index, find, grep, show, gatilho, pacote, pendentes, dupes, lint
EF_MAQUINA escolhe o bloco. EF_MAQUINAS_CONF aponta o arquivo (padrão: config/maquinas.conf).
EOF
}

MEM_SISTEMA=""
args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --sistema)
      [ -n "${2:-}" ] || die "--sistema exige um slug."
      MEM_SISTEMA="$2"
      shift 2
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done
if [ "${#args[@]}" -eq 0 ]; then
  usage >&2
  exit 1
fi
set -- "${args[@]}"

load_conf
cmd="$1"
shift
case "$cmd" in
  init) cmd_init "$@" ;;
  novo|index|find|grep|show|gatilho|pacote|pendentes|dupes|lint)
    resolve_dir
    "cmd_${cmd}" "$@"
    ;;
  *) die "comando desconhecido: $cmd" ;;
esac
