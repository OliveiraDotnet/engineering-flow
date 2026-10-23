#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: bash ./scripts/install-agent-pack.sh REPO_PATH [--profile core,web,sqlserver,quality,mobile] [--integration grok] [--install-global] [--allow-non-git] [--force] [--dry-run] [--discover-only]"
}

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

repo_input="$1"
shift
requested_profiles=()
requested_integrations=()
install_global=false
allow_non_git=false
force=false
dry_run=false
discover_only=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --integration)
      [ "$#" -ge 2 ] || { echo "Missing value for --integration" >&2; exit 1; }
      IFS=',' read -r -a requested <<< "$2"
      [ "${#requested[@]}" -gt 0 ] || { echo "Empty integration selection" >&2; exit 1; }
      for integration in "${requested[@]}"; do
        case "$integration" in grok) requested_integrations+=("$integration") ;; *) echo "Unknown integration: $integration. Engineering Flow 3.0 is Grok-only." >&2; exit 1 ;; esac
      done
      shift 2
      ;;
    --profile)
      [ "$#" -ge 2 ] || { echo "Missing value for --profile" >&2; exit 1; }
      IFS=',' read -r -a requested <<< "$2"
      for profile in "${requested[@]}"; do
        [ -n "$profile" ] && requested_profiles+=("$profile")
      done
      shift 2
      ;;
    --install-global) install_global=true; shift ;;
    --allow-non-git) allow_non_git=true; shift ;;
    --force) force=true; shift ;;
    --dry-run) dry_run=true; shift ;;
    --discover-only) discover_only=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TEMPLATE_ROOT="$PACK_ROOT/repo-template"
MANIFEST="$PACK_ROOT/pack-manifest.txt"
ARTIFACTS="$PACK_ROOT/pack-artifacts.txt"
VERSION_FILE="$PACK_ROOT/pack-version.txt"
GLOBAL_GUIDANCE="$PACK_ROOT/global/AGENTS.md"
INSPECTOR="$TEMPLATE_ROOT/.agents/skills/bootstrap-repo/scripts/inspect-repo.sh"

[ -d "$repo_input" ] || { echo "Repo path is not a directory: $repo_input" >&2; exit 1; }
[ -d "$TEMPLATE_ROOT" ] || { echo "Template root is missing: $TEMPLATE_ROOT" >&2; exit 1; }
[ -f "$MANIFEST" ] || { echo "Manifest is missing: $MANIFEST" >&2; exit 1; }
[ -f "$ARTIFACTS" ] || { echo "Artifact metadata is missing: $ARTIFACTS" >&2; exit 1; }
[ -f "$VERSION_FILE" ] || { echo "Pack version is missing: $VERSION_FILE" >&2; exit 1; }

PACK_VERSION="$(tr -d '\r' < "$VERSION_FILE" | sed '/^$/d; /^#/d' | head -n 1)"
WORKSPACE_ROOT="$(cd "$repo_input" && pwd -P)"

is_within() {
  local parent="$1" child="$2"
  [ "$child" != "$parent" ] && [[ "$child" == "$parent/"* ]]
}

assert_no_linked_path() {
  local current="$1"
  while [ -n "$current" ] && [ "$current" != / ] && [ "$current" != . ]; do
    [ ! -L "$current" ] || { echo "Linked installation path is not allowed: $current" >&2; exit 1; }
    # Git Bash represents Windows junctions as directories; compare their physical path.
    if [ -d "$current" ]; then
      [ "$(cd "$current" && pwd -P)" = "$current" ] || { echo "Linked installation path is not allowed: $current" >&2; exit 1; }
    fi
    current="$(dirname "$current")"
  done
}

if is_within "$TEMPLATE_ROOT" "$WORKSPACE_ROOT" || is_within "$WORKSPACE_ROOT" "$TEMPLATE_ROOT" || [ "$WORKSPACE_ROOT" = "$TEMPLATE_ROOT" ]; then
  echo "Repo path must not overlap the pack template." >&2
  exit 1
fi

is_git_root() { [ -e "$1/.git" ]; }

discover_git_roots() {
  local root="$1" gitdir
  discovered_roots=()
  if is_git_root "$root"; then
    discovered_roots+=("$root")
    return
  fi
  while IFS= read -r gitdir; do
    [ -n "$gitdir" ] || continue
    discovered_roots+=("$(cd "$(dirname "$gitdir")" && pwd -P)")
  done < <(find "$root" -maxdepth 4 \( -name node_modules -o -name bin -o -name obj -o -name packages -o -name .vs \) -prune -o -name .git \( -type d -o -type f \) -print 2>/dev/null)
}

valid_profile() {
  case "$1" in core|web|sqlserver|quality|mobile) return 0 ;; *) return 1 ;; esac
}

detect_profiles() {
  local target="$1" suggested
  detected_profiles=()
  [ -f "$INSPECTOR" ] || return 0
  suggested="$(bash "$INSPECTOR" "$target" 2>/dev/null | sed -n 's/^- Suggested profiles: //p' | tail -n 1)"
  for profile in $suggested; do
    case "$profile" in
      web|sqlserver|mobile) detected_profiles+=("$profile") ;;
    esac
  done
}

read_state_values() {
  local target="$1" kind="$2" state_path="$target/.agent-pack/state.txt" line
  assert_no_linked_path "$state_path"
  state_values=()
  [ -f "$state_path" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="$(trim "$line")"
    case "$line" in
      "$kind"|*)
        if [ "${line%%|*}" = "$kind" ]; then
          state_values+=("${line#*|}")
        fi
        ;;
    esac
  done < "$state_path"
}

resolve_profiles() {
  local target="$1" profile
  resolved_profiles=(core)
  if [ "${#requested_profiles[@]}" -gt 0 ]; then
    for profile in "${requested_profiles[@]}"; do
      resolved_profiles+=("$profile")
    done
    read_state_values "$target" profile
    resolved_profiles+=("${state_values[@]+"${state_values[@]}"}")
  else
    read_state_values "$target" profile
    if [ "${#state_values[@]}" -gt 0 ]; then
      resolved_profiles+=("${state_values[@]}")
    else
      detect_profiles "$target"
      resolved_profiles+=("${detected_profiles[@]+"${detected_profiles[@]}"}")
    fi
  fi
  unique_profiles=()
  for profile in "${resolved_profiles[@]}"; do
    profile="$(printf '%s' "$profile" | tr '[:upper:]' '[:lower:]')"
    valid_profile "$profile" || { echo "Unknown profile: $profile" >&2; exit 1; }
    seen=false
    for existing in "${unique_profiles[@]+"${unique_profiles[@]}"}"; do
      [ "$existing" = "$profile" ] && seen=true
    done
    [ "$seen" = true ] || unique_profiles+=("$profile")
  done
  resolved_profiles=("${unique_profiles[@]}")
}

contains_component() {
  local needle="$1"
  for component in "${components[@]}"; do
    [ "$component" = "$needle" ] && return 0
  done
  return 1
}

same_content() { cmp -s "$1" "$2"; }
backup_path() {
  local path="$1" timestamp candidate index
  timestamp="$(date +%Y%m%d%H%M%S)"
  candidate="$path.agent-pack.backup-$timestamp"
  index=1
  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    candidate="$path.agent-pack.backup-$timestamp-$index"
    index=$((index + 1))
  done
  printf '%s' "$candidate"
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

valid_relative_path() {
  local path="$1"
  [ -n "$path" ] || return 1
  case "$path" in
    /*|*\\*|[A-Za-z]:*|..|../*|*/..|*/../*) return 1 ;;
    *) return 0 ;;
  esac
}

HASH_TOOL=""
if command -v sha256sum >/dev/null 2>&1; then
  HASH_TOOL="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  HASH_TOOL="shasum"
elif command -v openssl >/dev/null 2>&1; then
  HASH_TOOL="openssl"
fi

normalized_stream() {
  local file="$1" prefix
  prefix="$(dd if="$file" bs=1 count=3 2>/dev/null | od -An -tx1 | tr -d ' \r\n')"
  if [ "$prefix" = "efbbbf" ]; then
    dd if="$file" bs=1 skip=3 2>/dev/null
  else
    cat "$file"
  fi | sed $'s/\r$//' | tr '\r' '\n'
}

hash_file() {
  local file="$1" output
  HASH_VALUE="-"
  [ -n "$HASH_TOOL" ] || return 0
  case "$HASH_TOOL" in
    sha256sum) output="$(normalized_stream "$file" | sha256sum)"; HASH_VALUE="${output%% *}" ;;
    shasum) output="$(normalized_stream "$file" | shasum -a 256)"; HASH_VALUE="${output%% *}" ;;
    openssl) output="$(normalized_stream "$file" | openssl dgst -sha256)"; HASH_VALUE="${output##* }" ;;
  esac
}

write_state() {
  local target="$1"
  local state_dir="$target/.agent-pack"
  local state_path="$state_dir/state.txt"
  local dest source dest_full source_full ownership id
  if [ "$dry_run" = true ]; then
    printf '%-9s %s\n' "STATE" "$state_path (dry-run)"
    return
  fi
  assert_no_linked_path "$state_path"
  assert_no_linked_path "$state_path.tmp"
  mkdir -p "$state_dir"
  {
    printf 'version|%s\n' "$PACK_VERSION"
    for profile in "${resolved_profiles[@]}"; do
      printf 'profile|%s\n' "$profile"
    done
    [ "$include_grok_effective" = true ] && printf 'integration|grok\n'
    while IFS= read -r line || [ -n "$line" ]; do
      line="$(trim "$line")"
      [ -n "$line" ] || continue
      [[ "$line" = \#* ]] && continue
      IFS='|' read -r id dest ownership <<< "$line"
      id="$(trim "$id")"
      dest="$(trim "$dest")"
      ownership="$(trim "$ownership")"
      source="${destination_sources[$dest]:-}"
      [ -n "$source" ] || continue
      [ -n "${installed_destinations[$dest]:-}" ] || continue
      dest_full="$target/$dest"
      source_full="$TEMPLATE_ROOT/$source"
      [ -f "$source_full" ] || continue
      [ -e "$dest_full" ] || continue
      if [ "$ownership" = "seed" ] || ! same_content "$source_full" "$dest_full"; then
        hash_file "$dest_full"
        printf 'artifact|%s|%s|%s|-|-|keep-local|%s\n' "$id" "$dest" "$ownership" "$HASH_VALUE"
      else
        hash_file "$source_full"
        printf 'artifact|%s|%s|%s|%s|%s|tracked|-\n' "$id" "$dest" "$ownership" "$PACK_VERSION" "$HASH_VALUE"
      fi
    done < "$ARTIFACTS"
  } > "$state_path.tmp"
  mv "$state_path.tmp" "$state_path"
  printf '%-9s %s\n' "STATE" "$state_path"
}

install_one() {
  local REPO_ROOT="$1"
  resolve_profiles "$REPO_ROOT"
  echo
  echo "Target: $REPO_ROOT"
  echo "Profiles: ${resolved_profiles[*]}"
  if [ "$dry_run" = true ]; then
    echo "Dry-run enabled: no files will be written."
  fi
  if [ "$discover_only" = true ]; then
    echo "Discover-only: inspection complete, no files will be written."
    return
  fi

  include_grok_effective=true
  read_state_values "$REPO_ROOT" integration
  for integration in "${state_values[@]+"${state_values[@]}"}" "${requested_integrations[@]+"${requested_integrations[@]}"}"; do
    case "$integration" in
      grok) ;;
      *) echo "Unknown integration in state: $integration. Engineering Flow 3.0 is Grok-only." >&2; exit 1 ;;
    esac
  done

  components=("${resolved_profiles[@]}")
  for profile in "${resolved_profiles[@]}"; do
    components+=("grok-$profile")
  done

  action_state=()
  action_source=()
  action_destination=()
  action_original=()
  declare -A installed_destinations=()

  add_action() {
    local source="$1" destination="$2" state="COPY" effective="$2" sidecar
    [ -f "$source" ] || { echo "Manifest source is missing: $source" >&2; exit 1; }
    assert_no_linked_path "$destination"
    assert_no_linked_path "$destination.agent-pack.new"
    if [ -e "$destination" ] && [ ! -f "$destination" ]; then echo "Installation destination is not a file: $destination" >&2; exit 1; fi
    if [ -e "$destination.agent-pack.new" ] && [ ! -f "$destination.agent-pack.new" ]; then echo "Installation sidecar is not a file: $destination.agent-pack.new" >&2; exit 1; fi
    if [ -e "$destination" ]; then
      if same_content "$source" "$destination"; then
        state="SKIP"
      elif [ "$force" = true ]; then
        state="REPLACE"
      else
        sidecar="$destination.agent-pack.new"
        if [ -e "$sidecar" ]; then
          if same_content "$source" "$sidecar"; then
            state="SKIP"
            effective="$sidecar"
          else
            state="CONFLICT"
            effective="$sidecar"
          fi
        else
          state="SIDECAR"
          effective="$sidecar"
        fi
      fi
    fi
    action_state+=("$state")
    action_source+=("$source")
    action_destination+=("$effective")
    action_original+=("$destination")
  }

  while IFS= read -r line || [ -n "$line" ]; do
    line="$(trim "$line")"
    [ -n "$line" ] || continue
    [[ "$line" = \#* ]] && continue
    separators="${line//[^|]/}"
    [ "${#separators}" -ge 1 ] && [ "${#separators}" -le 2 ] || { echo "Invalid manifest line: $line" >&2; exit 1; }
    IFS='|' read -r component source_relative destination_relative <<< "$line"
    component="$(trim "$component")"
    source_relative="$(trim "$source_relative")"
    destination_relative="$(trim "${destination_relative:-}")"
    [ "${#separators}" -eq 2 ] || destination_relative="$source_relative"
    [ -n "$component" ] || continue
    [ -n "$source_relative" ] || { echo "Invalid manifest line: $line" >&2; exit 1; }
    [ -n "$destination_relative" ] || { echo "Invalid manifest line: $line" >&2; exit 1; }
    contains_component "$component" || continue
    case "$destination_relative" in */agents/openai.yaml) continue ;; esac
    valid_relative_path "$source_relative" || { echo "Manifest source path escapes template: $source_relative" >&2; exit 1; }
    valid_relative_path "$destination_relative" || { echo "Manifest destination path escapes repository: $destination_relative" >&2; exit 1; }
    source="$TEMPLATE_ROOT/$source_relative"
    destination="$REPO_ROOT/$destination_relative"
    is_within "$TEMPLATE_ROOT" "$source" || { echo "Manifest source path escapes template: $source_relative" >&2; exit 1; }
    is_within "$REPO_ROOT" "$destination" || { echo "Manifest destination path escapes repository: $destination_relative" >&2; exit 1; }
    add_action "$source" "$destination"
    installed_destinations["$destination_relative"]=1
  done < "$MANIFEST"

  assert_no_linked_path "$REPO_ROOT/.agent-pack/state.txt"
  assert_no_linked_path "$REPO_ROOT/.agent-pack/state.txt.tmp"

  copy_count=0
  bash "$SCRIPT_DIR/protect-engineering-flow-files.sh" "$REPO_ROOT" check
  skip_count=0
  conflict_count=0
  for index in "${!action_state[@]}"; do
    state="${action_state[$index]}"
    source="${action_source[$index]}"
    destination="${action_destination[$index]}"
    original="${action_original[$index]}"
    printf '%-9s %s\n' "$state" "$destination"
    case "$state" in
      SKIP) skip_count=$((skip_count + 1)); continue ;;
      CONFLICT) conflict_count=$((conflict_count + 1)); continue ;;
    esac
    [ "$dry_run" = true ] && continue
    assert_no_linked_path "$destination"
    mkdir -p "$(dirname "$destination")"
    if [ "$state" = REPLACE ]; then
      backup="$(backup_path "$original")"
      assert_no_linked_path "$backup"
      cp "$original" "$backup"
      printf '%-9s %s\n' "BACKUP" "$backup"
    fi
    cp "$source" "$destination"
    copy_count=$((copy_count + 1))
  done

  write_state "$REPO_ROOT"
  if [ "$dry_run" = true ]; then bash "$SCRIPT_DIR/protect-engineering-flow-files.sh" "$REPO_ROOT" dry-run
  else bash "$SCRIPT_DIR/protect-engineering-flow-files.sh" "$REPO_ROOT"; fi
  echo "Summary: copied=$copy_count skipped=$skip_count conflicts=$conflict_count"
  [ "$conflict_count" -eq 0 ] || echo "Warning: conflicting .agent-pack.new files were preserved; review them before retrying." >&2
}

declare -A destination_sources=()
while IFS= read -r line || [ -n "$line" ]; do
  line="$(trim "$line")"
  [ -n "$line" ] || continue
  [[ "$line" = \#* ]] && continue
  separators="${line//[^|]/}"
  IFS='|' read -r component source_relative destination_relative <<< "$line"
  source_relative="$(trim "$source_relative")"
  destination_relative="$(trim "${destination_relative:-}")"
  [ "${#separators}" -eq 2 ] || destination_relative="$source_relative"
  destination_sources["$destination_relative"]="$source_relative"
done < "$MANIFEST"

discover_git_roots "$WORKSPACE_ROOT"
if [ "${#discovered_roots[@]}" -eq 0 ]; then
  if [ "$allow_non_git" = true ]; then
    discovered_roots=("$WORKSPACE_ROOT")
  else
    echo "Repo path is not a Git root and no Git repositories were found underneath it. Point at a repository, a workspace folder that contains repositories, or pass --allow-non-git." >&2
    exit 1
  fi
elif [ "${#discovered_roots[@]}" -eq 1 ] && [ "${discovered_roots[0]}" = "$WORKSPACE_ROOT" ]; then
  if [ "$allow_non_git" != true ]; then
    command -v git >/dev/null 2>&1 || { echo "Git is required; use --allow-non-git explicitly when intentional." >&2; exit 1; }
    git_root="$(git -C "$WORKSPACE_ROOT" rev-parse --show-toplevel 2>/dev/null || true)"
    [ -n "$git_root" ] || { echo "Repo path is not a Git repository root; use --allow-non-git explicitly when intentional." >&2; exit 1; }
    git_root="$(cd "$git_root" && pwd -P)"
    [ "$git_root" = "$WORKSPACE_ROOT" ] || { echo "Repo path must be the Git root, not a subdirectory: $git_root" >&2; exit 1; }
  fi
fi

echo "Installing Engineering Flow $PACK_VERSION"
echo "Workspace path: $WORKSPACE_ROOT"
echo "Repositories: ${discovered_roots[*]}"
echo "Grok Build project support enabled."

for target in "${discovered_roots[@]}"; do
  install_one "$target"
done

if [ "$install_global" = true ] && [ "$discover_only" != true ]; then
  GROK_HOME_RESOLVED="${GROK_HOME:-$HOME/.grok}"
  action_state=()
  action_source=()
  action_destination=()
  action_original=()
  add_global() {
    local source="$1" destination="$2" state="COPY" effective="$2" sidecar
    [ -f "$source" ] || { echo "Manifest source is missing: $source" >&2; exit 1; }
    assert_no_linked_path "$destination"
    assert_no_linked_path "$destination.agent-pack.new"
    if [ -e "$destination" ]; then
      if same_content "$source" "$destination"; then
        state="SKIP"
      elif [ "$force" = true ]; then
        state="REPLACE"
      else
        sidecar="$destination.agent-pack.new"
        if [ -e "$sidecar" ]; then
          if same_content "$source" "$sidecar"; then
            state="SKIP"
            effective="$sidecar"
          else
            state="CONFLICT"
            effective="$sidecar"
          fi
        else
          state="SIDECAR"
          effective="$sidecar"
        fi
      fi
    fi
    printf '%-9s %s\n' "$state" "$effective"
    [ "$state" = SKIP ] && return
    [ "$state" = CONFLICT ] && return
    [ "$dry_run" = true ] && return
    mkdir -p "$(dirname "$destination")"
    if [ "$state" = REPLACE ]; then
      backup="$(backup_path "$destination")"
      cp "$destination" "$backup"
      printf '%-9s %s\n' "BACKUP" "$backup"
    fi
    cp "$source" "$effective"
  }
  add_global "$GLOBAL_GUIDANCE" "$GROK_HOME_RESOLVED/AGENTS.md"
fi
