#!/usr/bin/env bash
set -euo pipefail
repo="${1:?repository path required}"
mode="${2:-apply}"
extra_flag="${3:-}"
path="$repo/.gitignore"
[ ! -L "$path" ] && { [ ! -e "$path" ] || [ -f "$path" ]; } || { echo 'Linked/non-file .gitignore cannot be protected safely.' >&2; exit 1; }
if [ -f "$path" ]; then
  # Never transcode existing bytes. Reject NUL text; verify UTF-8 when iconv exists.
  if ! cmp -s "$path" <(tr -d '\000' < "$path"); then echo 'Non UTF-8 .gitignore needs a reviewed encoding-preserving change.' >&2; exit 1; fi
  if command -v iconv >/dev/null 2>&1 && ! iconv -f UTF-8 -t UTF-8 "$path" >/dev/null 2>&1; then echo 'Non UTF-8 .gitignore needs a reviewed encoding-preserving change.' >&2; exit 1; fi
fi

extract_ignore_source_line() {
  local raw="$1" loc src rest line
  loc="${raw%%$'\t'*}"
  src="${loc%%:*}"
  rest="${loc#*:}"
  line="${rest%%:*}"
  printf '%s:%s' "$src" "$line"
}

if [ "$mode" = "unignore-agents-md" ] || [ "$mode" = "unignore-agents-md-dry-run" ]; then
  unignore_dry_run=false
  if [ "$mode" = "unignore-agents-md-dry-run" ] || [ "$extra_flag" = "--dry-run" ] || [ "$extra_flag" = "dry-run" ]; then
    unignore_dry_run=true
  fi
  command -v git >/dev/null 2>&1 || exit 0
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

  set +e
  git -C "$repo" check-ignore -q -- AGENTS.md
  check_rc=$?
  set -e
  if [ "$check_rc" -eq 1 ]; then
    exit 0
  elif [ "$check_rc" -ne 0 ]; then
    echo "git check-ignore failed with exit code $check_rc" >&2
    exit "$check_rc"
  fi

  ignore_info="$(git -C "$repo" check-ignore -v -- AGENTS.md | head -n 1)"
  source_line="$(extract_ignore_source_line "$ignore_info")"

  if [ "$unignore_dry_run" = true ]; then
    printf 'WOULD-UNIGNORE %s (!AGENTS.md would be appended; was ignored by %s)\n' "$path" "$source_line"
    exit 0
  fi

  if { [ -e "$path" ] && [ ! -w "$path" ]; } || { [ ! -e "$path" ] && [ ! -w "$repo" ]; }; then
    echo '.gitignore is not writable; protection needs a reviewed permission change.' >&2
    exit 1
  fi

  ending=$'\n'
  if [ -f "$path" ] && grep -q $'\r$' "$path"; then ending=$'\r\n'; fi
  {
    if [ -s "$path" ] && [ "$(tail -c 1 "$path" | od -An -tu1 | tr -d ' ')" != 10 ]; then printf '%s' "$ending"; fi
    printf '# Engineering Flow: AGENTS.md must stay versionable%s!AGENTS.md%s' "$ending" "$ending"
  } >> "$path"

  printf 'UNIGNORE %s (!AGENTS.md appended; was ignored by %s)\n' "$path" "$source_line"

  set +e
  git -C "$repo" check-ignore -q -- AGENTS.md
  recheck_rc=$?
  set -e
  if [ "$recheck_rc" -eq 0 ]; then
    recheck_info="$(git -C "$repo" check-ignore -v -- AGENTS.md | head -n 1)"
    recheck_source_line="$(extract_ignore_source_line "$recheck_info")"
    printf 'ERROR: AGENTS.md is still ignored after appending !AGENTS.md (%s)\n' "$recheck_source_line" >&2
    exit 5
  fi
  exit 0
fi

patterns=('*.agent-pack.new' '*.agent-pack.backup-*' '.agent-pack/' '.agent-pack/.runtime/' '.agent-pack/.runtime/task.lock' '.agent-pack/*.tmp' '.agent-pack/*.lock' '.agent-pack/logs/' '.agent-pack/cache/' '.agent-pack/tmp/' '.agent-pack/sessions/' '.agent-pack/worktrees/' '.agent-pack/evidencias/' '.agents/' '.claude/' '.grok/' '.grok/sessions/' '.grok/worktrees/' '.ai-memory.toml' 'docs/engineering-flow/' 'docs/ai/' 'prompts/' '.engineering-flow-evidence/' 'Planejamento/' 'planejamento/')
missing=()
for pattern in "${patterns[@]}"; do
  if [ ! -f "$path" ] || ! grep -F -x -q "$pattern" <(sed $'s/\r$//' "$path"); then missing+=("$pattern"); fi
done
[ "${#missing[@]}" -gt 0 ] || exit 0
if { [ -e "$path" ] && [ ! -w "$path" ]; } || { [ ! -e "$path" ] && [ ! -w "$repo" ]; }; then echo '.gitignore is not writable; protection needs a reviewed permission change.' >&2; exit 1; fi
[ "$mode" != check ] || exit 0
if [ "$mode" = dry-run ]; then printf 'IGNORE    %s (%s rules, dry-run)\n' "$path" "${#missing[@]}"; exit 0; fi
ending=$'\n'
if [ -f "$path" ] && grep -q $'\r$' "$path"; then ending=$'\r\n'; fi
{
  if [ -s "$path" ] && [ "$(tail -c 1 "$path" | od -An -tu1 | tr -d ' ')" != 10 ]; then printf '%s' "$ending"; fi
  printf '%s# Engineering Flow: clean install; only AGENTS.md stays versionable.%s' "$ending" "$ending"
  for pattern in "${missing[@]}"; do printf '%s%s' "$pattern" "$ending"; done
} >> "$path"
printf 'IGNORE    %s (%s generated-file rules added)\n' "$path" "${#missing[@]}"
