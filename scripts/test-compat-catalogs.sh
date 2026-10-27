#!/usr/bin/env bash
# Recalcula compat/releases contra tags e prova a atualização 3.0.0 -> pack atual.
set -euo pipefail

LC_ALL=C
export LC_ALL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
passes=0
failures=0

pass() {
  passes=$((passes + 1))
  echo "PASSOU: $*"
}

fail_scenario() {
  failures=$((failures + 1))
  echo "FALHOU: $*" >&2
}

summary_and_exit() {
  echo "test-compat-catalogs: passou=$passes falhou=$failures"
  if [ "$failures" -ne 0 ]; then
    exit 1
  fi
  exit 0
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "AVISO: teste test-compat-catalogs pulado: repositório sem .git (distribuição zip). Catálogos e fixture não foram verificados."
  echo "test-compat-catalogs: passou=0 falhou=0 pulado=1"
  exit 0
fi

if ! command -v sha256sum >/dev/null 2>&1; then
  echo "FALHOU: sha256sum é obrigatório para o hash normalizado." >&2
  echo "test-compat-catalogs: passou=0 falhou=1"
  exit 1
fi

hash_file() {
  local file="$1" prefix output
  if ! iconv -f UTF-8 -t UTF-8 "$file" >/dev/null 2>&1; then
    echo "UTF-8 estrito recusou: $file" >&2
    return 1
  fi
  prefix="$(dd if="$file" bs=1 count=3 2>/dev/null | od -An -tx1 | tr -d ' \r\n')"
  if [ "$prefix" = "efbbbf" ]; then
    output="$(dd if="$file" bs=1 skip=3 2>/dev/null | sed $'s/\r$//' | tr '\r' '\n' | sha256sum)"
  else
    output="$(sed $'s/\r$//' "$file" | tr '\r' '\n' | sha256sum)"
  fi
  printf '%s' "${output%% *}"
}

version_ge_211() {
  local version="$1" major minor rest patch
  IFS=. read -r major minor rest <<< "$version"
  patch="${rest%%[^0-9]*}"
  [ -n "${patch:-}" ] || patch=0
  if [ "$major" -gt 2 ]; then
    return 0
  fi
  if [ "$major" -lt 2 ]; then
    return 1
  fi
  if [ "$minor" -gt 1 ]; then
    return 0
  fi
  if [ "$minor" -lt 1 ]; then
    return 1
  fi
  [ "$patch" -ge 1 ]
}

tag_exists() {
  git -C "$ROOT" rev-parse --verify --quiet "refs/tags/v$1" >/dev/null 2>&1
}

declare -A DEST_SOURCE=()
declare -A ARTIFACT_DEST=()

load_manifest() {
  local file="$1" line component source dest
  DEST_SOURCE=()
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    line="$(trim "$line")"
    [ -n "$line" ] || continue
    [[ "$line" == \#* ]] && continue
    IFS='|' read -r component source dest <<< "$line"
    source="$(trim "$source")"
    dest="$(trim "${dest:-}")"
    [ -n "$dest" ] || dest="$source"
    DEST_SOURCE["$dest"]="$source"
  done < "$file"
}

load_artifacts() {
  local file="$1" line id dest ownership
  ARTIFACT_DEST=()
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    line="$(trim "$line")"
    [ -n "$line" ] || continue
    [[ "$line" == \#* ]] && continue
    IFS='|' read -r id dest ownership <<< "$line"
    id="$(trim "$id")"
    dest="$(trim "$dest")"
    ARTIFACT_DEST["$id"]="$dest"
  done < "$file"
}

materialize_show() {
  local spec="$1" dest="$2" err
  err="$(mktemp)"
  if ! git -C "$ROOT" --no-pager show "$spec" >"$dest" 2>"$err"; then
    echo "git show falhou: $spec" >&2
    cat "$err" >&2
    rm -f "$err"
    return 1
  fi
  rm -f "$err"
}

check_catalog() {
  local version="$1" manifest="$2" artifacts="$3" mode="$4"
  local catalog="$ROOT/compat/releases/$version.txt"
  local line id dest hash source blob real only_catalog only_artifacts
  local -A catalog_ids=()
  local -A catalog_dest=()
  local data_lines=0
  local local_failures=0

  load_manifest "$manifest"
  load_artifacts "$artifacts"

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    line="$(trim "$line")"
    [ -n "$line" ] || continue
    [[ "$line" == \#* ]] && continue
    data_lines=$((data_lines + 1))
    IFS='|' read -r id dest hash <<< "$line"
    id="$(trim "$id")"
    dest="$(trim "$dest")"
    hash="$(trim "$hash")"
    if [ -n "${catalog_ids[$id]+x}" ]; then
      echo "DIVERGENCIA catalogo=$version id=$id destino=$dest hash_catalogo=$hash hash_real=id-repetido"
      local_failures=$((local_failures + 1))
      continue
    fi
    catalog_ids["$id"]=1
    catalog_dest["$id"]="$dest"
    if [ -z "${ARTIFACT_DEST[$id]+x}" ]; then
      echo "DIVERGENCIA catalogo=$version id=$id destino=$dest hash_catalogo=$hash hash_real=id-ausente-em-pack-artifacts"
      local_failures=$((local_failures + 1))
      continue
    fi
    if [ "${ARTIFACT_DEST[$id]}" != "$dest" ]; then
      echo "DIVERGENCIA catalogo=$version id=$id destino=$dest hash_catalogo=$hash hash_real=destino-diverge-de-pack-artifacts:${ARTIFACT_DEST[$id]}"
      local_failures=$((local_failures + 1))
    fi
    if [ -z "${DEST_SOURCE[$dest]+x}" ]; then
      echo "DIVERGENCIA catalogo=$version id=$id destino=$dest hash_catalogo=$hash hash_real=destino-sem-origem-no-manifest"
      local_failures=$((local_failures + 1))
      continue
    fi
    source="${DEST_SOURCE[$dest]}"
    blob="$(mktemp)"
    if [ "$mode" = "git" ]; then
      if ! materialize_show "v${version}:repo-template/${source}" "$blob"; then
        echo "DIVERGENCIA catalogo=$version id=$id destino=$dest hash_catalogo=$hash hash_real=origem-ausente:${source}"
        local_failures=$((local_failures + 1))
        rm -f "$blob"
        continue
      fi
    else
      if [ ! -f "$ROOT/repo-template/$source" ]; then
        echo "DIVERGENCIA catalogo=$version id=$id destino=$dest hash_catalogo=$hash hash_real=origem-ausente:${source}"
        local_failures=$((local_failures + 1))
        rm -f "$blob"
        continue
      fi
      cp "$ROOT/repo-template/$source" "$blob"
    fi
    if ! real="$(hash_file "$blob")"; then
      echo "DIVERGENCIA catalogo=$version id=$id destino=$dest hash_catalogo=$hash hash_real=hash-falhou:${source}"
      local_failures=$((local_failures + 1))
      rm -f "$blob"
      continue
    fi
    rm -f "$blob"
    if [ "$real" != "$hash" ]; then
      echo "DIVERGENCIA catalogo=$version id=$id destino=$dest hash_catalogo=$hash hash_real=$real"
      echo "ESPERADO ${id}|${dest}|${real}"
      local_failures=$((local_failures + 1))
    fi
  done < "$catalog"

  only_catalog=""
  only_artifacts=""
  for id in "${!catalog_ids[@]}"; do
    if [ -z "${ARTIFACT_DEST[$id]+x}" ]; then
      only_catalog="${only_catalog} ${id}"
    fi
  done
  for id in "${!ARTIFACT_DEST[@]}"; do
    if [ -z "${catalog_ids[$id]+x}" ]; then
      only_artifacts="${only_artifacts} ${id}"
    fi
  done
  if [ -n "$only_catalog" ] || [ -n "$only_artifacts" ]; then
    echo "DIVERGENCIA catalogo=$version ids somente_catalogo=${only_catalog:--} somente_pack_artifacts=${only_artifacts:--} hash_catalogo=- hash_real=-"
    local_failures=$((local_failures + 1))
  fi

  echo "catalogo=$version linhas_dados=$data_lines modo=$mode"
  if [ "$local_failures" -eq 0 ]; then
    pass "catalogo $version bate com $mode ($data_lines linhas)"
  else
    fail_scenario "catalogo $version tem $local_failures divergencia(s)"
  fi
}

check_updater_diff() {
  if git -C "$ROOT" diff --exit-code -- scripts/update-agent-pack.ps1 scripts/update-agent-pack.sh >/dev/null; then
    pass "git diff vazio em update-agent-pack.ps1 e update-agent-pack.sh (Test-TrustedBaseline, Read-CompatibilityCatalog e normalizacao)"
  else
    fail_scenario "update-agent-pack.ps1 ou update-agent-pack.sh tem diff; a logica de confianca nao pode mudar"
  fi
}

current=""
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  line="$(trim "$line")"
  [ -n "$line" ] || continue
  [[ "$line" == \#* ]] && continue
  current="$line"
done < "$ROOT/pack-version.txt"
echo "test-compat-catalogs raiz=$ROOT versao_atual=$current"

if [ ! -f "$ROOT/compat/releases/$current.txt" ]; then
  fail_scenario "catalogo da versao atual ausente: compat/releases/$current.txt"
fi

shopt -s nullglob
catalogs=("$ROOT"/compat/releases/*.txt)
shopt -u nullglob
if [ "${#catalogs[@]}" -eq 0 ]; then
  fail_scenario "nenhum catalogo em compat/releases"
fi

for catalog in "${catalogs[@]}"; do
  version="$(basename "$catalog" .txt)"
  if [ "$version" = "$current" ]; then
    check_catalog "$version" "$ROOT/pack-manifest.txt" "$ROOT/pack-artifacts.txt" "work"
    continue
  fi
  if tag_exists "$version"; then
    manifest_file="$(mktemp)"
    artifacts_file="$(mktemp)"
    if materialize_show "v${version}:pack-manifest.txt" "$manifest_file" && materialize_show "v${version}:pack-artifacts.txt" "$artifacts_file"; then
      check_catalog "$version" "$manifest_file" "$artifacts_file" "git"
    else
      fail_scenario "nao foi possivel ler manifest/artifacts da tag v$version"
    fi
    rm -f "$manifest_file" "$artifacts_file"
    continue
  fi
  if version_ge_211 "$version"; then
    fail_scenario "tag ausente: v$version para compat/releases/$version.txt (versao >= 2.1.1). Clone sem tags: git fetch --tags."
  else
    echo "não verificável: compat/releases/$version.txt sem tag v$version"
    pass "catalogo $version não verificável"
  fi
done

check_updater_diff

if [ "$failures" -ne 0 ]; then
  echo "Fixture 3.0.0 nao executada porque a conferencia de catalogo falhou."
  summary_and_exit
fi

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ef311-compat.XXXXXX")"
cleanup() {
  case "$TEMP_ROOT" in
    /tmp/ef311-compat.*|"${TMPDIR:-/tmp}"/ef311-compat.*) rm -rf -- "$TEMP_ROOT" ;;
    *) echo "Unsafe cleanup target: $TEMP_ROOT" >&2 ;;
  esac
}
trap cleanup EXIT

archive="$TEMP_ROOT/v3.0.0"
repo="$TEMP_ROOT/repo"
mkdir -p "$archive" "$repo"
if ! git -C "$ROOT" archive v3.0.0 | tar -x -C "$archive"; then
  fail_scenario "git archive v3.0.0 falhou"
  summary_and_exit
fi
git init -q "$repo"
if ! bash "$archive/scripts/install-agent-pack.sh" "$repo" --profile core --integration grok; then
  fail_scenario "instalador v3.0.0 (core, grok) falhou"
  summary_and_exit
fi
state="$repo/.agent-pack/state.txt"
if [ ! -f "$state" ]; then
  fail_scenario "instalador v3.0.0 nao gravou state.txt"
  summary_and_exit
fi
grep -q '^version|3.0.0$' "$state" || fail_scenario "state da fixture nao tem version|3.0.0"
grep -q '^integration|grok$' "$state" || fail_scenario "state da fixture nao tem integration|grok"
if [ "$failures" -ne 0 ]; then
  summary_and_exit
fi
pass "fixture instalada pela v3.0.0 (core, grok)"

cp "$state" "$TEMP_ROOT/state-before-check.txt"
set +e
check_output="$(bash "$ROOT/scripts/update-agent-pack.sh" "$repo" --check 2>&1)"
check_status=$?
set -e
echo "$check_output"
echo "CA2 check_status=$check_status"
if [ "$check_status" -eq 0 ] && printf '%s\n' "$check_output" | grep -q 'conflicts=0'; then
  pass "updater --check da arvore atual na fixture 3.0.0 (exit 0, conflicts=0)"
else
  fail_scenario "updater --check da fixture 3.0.0 saiu $check_status ou teve conflito"
fi
if cmp -s "$state" "$TEMP_ROOT/state-before-check.txt"; then
  pass "state da fixture byte a byte igual depois do --check"
else
  fail_scenario "state da fixture mudou no --check"
fi
echo "--- state antes do --check ---"
cat "$TEMP_ROOT/state-before-check.txt"
echo "--- state depois do --check ---"
cat "$state"
echo "--- fim do state ---"

managed="$repo/.agents/skills/bugfix/SKILL.md"
if [ ! -f "$managed" ]; then
  fail_scenario "arquivo managed da fixture ausente: .agents/skills/bugfix/SKILL.md"
else
  cp "$managed" "$TEMP_ROOT/managed-before.bin"
  printf 'X' >> "$managed"
  cp "$state" "$TEMP_ROOT/state-before-negative.txt"
  set +e
  negative_output="$(bash "$ROOT/scripts/update-agent-pack.sh" "$repo" --check 2>&1)"
  negative_status=$?
  set -e
  echo "$negative_output"
  echo "CA4 byte check_status=$negative_status"
  if [ "$negative_status" -eq 2 ] && printf '%s\n' "$negative_output" | grep -q 'CONFLICT_LOCAL'; then
    pass "1 byte alterado em managed continua CONFLICT_LOCAL (exit 2)"
  else
    fail_scenario "1 byte alterado nao foi detectado como CONFLICT_LOCAL (exit $negative_status)"
  fi
  if cmp -s "$state" "$TEMP_ROOT/state-before-negative.txt"; then
    pass "state inalterado no teste negativo de 1 byte"
  else
    fail_scenario "teste negativo de 1 byte alterou o state"
  fi
  cp "$TEMP_ROOT/managed-before.bin" "$managed"
fi

mut="$TEMP_ROOT/pack-mut"
mkdir -p "$mut/scripts"
cp "$ROOT/scripts/update-agent-pack.sh" "$ROOT/scripts/protect-engineering-flow-files.sh" "$mut/scripts/"
cp "$ROOT/pack-version.txt" "$ROOT/pack-manifest.txt" "$ROOT/pack-artifacts.txt" "$mut/"
cp -a "$ROOT/compat" "$ROOT/repo-template" "$mut/"
catalog_copy="$mut/compat/releases/3.0.0.txt"
tmp_catalog="$(mktemp)"
mutated=0
mutated_id=""
while IFS= read -r line || [ -n "$line" ]; do
  if [ "$mutated" -eq 0 ] && [ -n "$line" ] && [[ "$line" != \#* ]]; then
    body="${line%$'\r'}"
    hash="${body##*|}"
    rest="${body%|*}"
    if [ "${hash: -1}" = "0" ]; then
      hash="${hash:0:63}1"
    else
      hash="${hash:0:63}0"
    fi
    printf '%s|%s\n' "$rest" "$hash" >> "$tmp_catalog"
    mutated=1
    mutated_id="${rest%%|*}"
    echo "CA4 hash do catalogo temporario alterado: id=$mutated_id"
  else
    printf '%s\n' "$line" >> "$tmp_catalog"
  fi
done < "$catalog_copy"
mv "$tmp_catalog" "$catalog_copy"
cp "$state" "$TEMP_ROOT/state-before-hash.txt"
set +e
hash_output="$(bash "$mut/scripts/update-agent-pack.sh" "$repo" --check 2>&1)"
hash_status=$?
set -e
echo "$hash_output"
echo "CA4 hash check_status=$hash_status"
if [ "$hash_status" -ne 0 ] && printf '%s\n' "$hash_output" | grep -q 'not trusted'; then
  pass "1 hash alterado no catalogo temporario continua nao confiavel (exit $hash_status)"
else
  fail_scenario "1 hash alterado no catalogo temporario nao foi recusado (exit $hash_status)"
fi
if cmp -s "$state" "$TEMP_ROOT/state-before-hash.txt"; then
  pass "state inalterado no teste negativo de hash"
else
  fail_scenario "teste negativo de hash alterou o state"
fi

set +e
apply_output="$(bash "$ROOT/scripts/update-agent-pack.sh" "$repo" --apply 2>&1)"
apply_status=$?
set -e
echo "$apply_output"
echo "CA3 apply_status=$apply_status"
if [ "$apply_status" -eq 0 ] && printf '%s\n' "$apply_output" | grep -q 'Update applied successfully' && grep -q "^version|${current}$" "$state" && grep -q '^integration|grok$' "$state"; then
  pass "Apply da arvore atual gravou version|$current e integration|grok"
else
  fail_scenario "Apply da fixture nao concluiu com version|$current e integration|grok (exit $apply_status)"
fi

set +e
second_output="$(bash "$ROOT/scripts/update-agent-pack.sh" "$repo" --check 2>&1)"
second_status=$?
set -e
echo "$second_output"
echo "CA3 second_check_status=$second_status"
pending=0
while IFS= read -r line; do
  case "$line" in
    ""|Agent\ Pack\ update:*|Repository:*|Profiles:*|Integrations:*|Summary:*) continue ;;
  esac
  kind="${line%% *}"
  case "$kind" in
    UPDATE|ADD|ADD_SEED|ADD_MOVED|WRITE_PACK|REPLACE_ACCEPTED|RESTORE|RETIRE|RETIRE_RENAMED|UPDATE_ADOPTED|CONFLICT_LOCAL|CONFLICT_MERGE_REQUIRED|CONFLICT_DELETED|CONFLICT_UNMANAGED|CONFLICT_REMOVE|CONFLICT_RENAME|CONFLICT_LEGACY_REMOVED)
      echo "acao pendente: $line"
      pending=$((pending + 1))
      ;;
  esac
done <<< "$second_output"
if [ "$second_status" -eq 0 ] && printf '%s\n' "$second_output" | grep -q 'conflicts=0' && [ "$pending" -eq 0 ]; then
  pass "segundo --check sem acao pendente (conflicts=0)"
else
  fail_scenario "segundo --check ainda tem acao pendente (exit $second_status, pendentes=$pending)"
fi

summary_and_exit
