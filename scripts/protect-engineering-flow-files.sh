#!/usr/bin/env bash
set -euo pipefail
repo="${1:?repository path required}"
mode="${2:-apply}"
path="$repo/.gitignore"
[ ! -L "$path" ] && { [ ! -e "$path" ] || [ -f "$path" ]; } || { echo 'Linked/non-file .gitignore cannot be protected safely.' >&2; exit 1; }
if [ -f "$path" ]; then
  # Never transcode existing bytes. Reject NUL text; verify UTF-8 when iconv exists.
  if ! cmp -s "$path" <(tr -d '\000' < "$path"); then echo 'Non UTF-8 .gitignore needs a reviewed encoding-preserving change.' >&2; exit 1; fi
  if command -v iconv >/dev/null 2>&1 && ! iconv -f UTF-8 -t UTF-8 "$path" >/dev/null 2>&1; then echo 'Non UTF-8 .gitignore needs a reviewed encoding-preserving change.' >&2; exit 1; fi
fi
patterns=('*.agent-pack.new' '*.agent-pack.backup-*' '.agent-pack/.runtime/' '.agent-pack/.runtime/task.lock' '.agent-pack/*.tmp' '.agent-pack/*.lock' '.agent-pack/logs/' '.agent-pack/cache/' '.agent-pack/tmp/' '.agent-pack/sessions/' '.agent-pack/worktrees/' '.engineering-flow-evidence/' '.grok/sessions/' '.grok/worktrees/' 'Planejamento/' 'planejamento/' 'conhecimento/')
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
  printf '%s# Engineering Flow: generated files only; state.txt and project guidance stay versionable.%s' "$ending" "$ending"
  for pattern in "${missing[@]}"; do printf '%s%s' "$pattern" "$ending"; done
} >> "$path"
printf 'IGNORE    %s (%s generated-file rules added)\n' "$path" "${#missing[@]}"
