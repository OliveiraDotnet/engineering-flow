#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  session-state.sh init --card <id> [--tier 0|1|2] [--branch <name>] [--phase <name>] [--role <name>] [--criteria <csv>] [--decisions <csv>] [--next-action <text>] [--repo <path>]
  session-state.sh update [--tier 0|1|2] [--branch <name>] [--phase <name>] [--role <name>] [--attempt <n>] [--decisions <csv>] [--criterion-id <id> --criterion-status <status> [--criterion-artifact <path>]] [--dead-end <text>] [--next-action <text>] [--files-touched <csv>] [--increment-blocked] [--increment-envelope-violation] [--repo <path>]
  session-state.sh show [--json] [--repo <path>]
  session-state.sh close [--rework-post-gate2] [--keep-state] [--keep-runtime] [--repo <path>]

Files (gitignored):
  <repo>/.agent-pack/.runtime/session-state.json
  <repo>/.agent-pack/.runtime/metrics.jsonl
USAGE
}

[ $# -ge 1 ] || { usage >&2; exit 2; }
command="$1"; shift
case "$command" in
  init|update|show|close) ;;
  -h|--help) usage; exit 0 ;;
  *) echo "Unknown command: $command" >&2; usage >&2; exit 2 ;;
esac

card=""; tier=""; branch=""; phase=""; role=""; attempt="-1"
criteria=""; decisions=""; criterion_id=""; criterion_status=""; criterion_artifact=""
dead_end=""; next_action=""; files_touched=""
inc_blocked=0; inc_envelope=0; rework_post_gate2=0; keep_state=0; keep_runtime=0; as_json=0
repo="."

while [ $# -gt 0 ]; do
  case "$1" in
    --card) card="${2:?--card requires a value}"; shift 2 ;;
    --tier) tier="${2:?--tier requires a value}"; shift 2 ;;
    --branch) branch="${2:?--branch requires a value}"; shift 2 ;;
    --phase) phase="${2:?--phase requires a value}"; shift 2 ;;
    --role) role="${2:?--role requires a value}"; shift 2 ;;
    --attempt) attempt="${2:?--attempt requires a value}"; shift 2 ;;
    --criteria) criteria="${2:?--criteria requires a value}"; shift 2 ;;
    --decisions) decisions="${2:?--decisions requires a value}"; shift 2 ;;
    --criterion-id) criterion_id="${2:?--criterion-id requires a value}"; shift 2 ;;
    --criterion-status) criterion_status="${2:?--criterion-status requires a value}"; shift 2 ;;
    --criterion-artifact) criterion_artifact="${2:?--criterion-artifact requires a value}"; shift 2 ;;
    --dead-end) dead_end="${2:?--dead-end requires a value}"; shift 2 ;;
    --next-action) next_action="${2:?--next-action requires a value}"; shift 2 ;;
    --files-touched) files_touched="${2:?--files-touched requires a value}"; shift 2 ;;
    --increment-blocked) inc_blocked=1; shift ;;
    --increment-envelope-violation) inc_envelope=1; shift ;;
    --rework-post-gate2) rework_post_gate2=1; shift ;;
    --keep-state) keep_state=1; shift ;;
    --keep-runtime) keep_runtime=1; shift ;;
    --json) as_json=1; shift ;;
    --repo) repo="${2:?--repo requires a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null || (cd "$repo" && pwd))"
RUNTIME_DIR="$REPO_ROOT/.agent-pack/.runtime"
STATE_FILE="$RUNTIME_DIR/session-state.json"
METRICS_FILE="$RUNTIME_DIR/metrics.jsonl"
CURRENT_HEAD="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo none)"
CURRENT_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
NOW_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TODAY_UTC="$(date -u +%Y-%m-%d)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "session-state.sh requires python3 for safe JSON handling." >&2
  exit 1
fi

export EF_CMD="$command" EF_STATE_FILE="$STATE_FILE" EF_METRICS_FILE="$METRICS_FILE"
export EF_RUNTIME_DIR="$RUNTIME_DIR" EF_HEAD="$CURRENT_HEAD" EF_CUR_BRANCH="$CURRENT_BRANCH"
export EF_NOW="$NOW_UTC" EF_TODAY="$TODAY_UTC"
export EF_CARD="$card" EF_TIER="$tier" EF_BRANCH="$branch" EF_PHASE="$phase"
export EF_ROLE="$role" EF_ATTEMPT="$attempt" EF_CRITERIA="$criteria" EF_DECISIONS="$decisions"
export EF_CRIT_ID="$criterion_id" EF_CRIT_STATUS="$criterion_status" EF_CRIT_ARTIFACT="$criterion_artifact"
export EF_DEAD_END="$dead_end" EF_NEXT_ACTION="$next_action" EF_FILES_TOUCHED="$files_touched"
export EF_INC_BLOCKED="$inc_blocked" EF_INC_ENVELOPE="$inc_envelope"
export EF_REWORK="$rework_post_gate2" EF_KEEP_STATE="$keep_state" EF_KEEP_RUNTIME="$keep_runtime" EF_AS_JSON="$as_json"

python3 - <<'PY'
import glob, json, os, sys

cmd = os.environ["EF_CMD"]
state_file = os.environ["EF_STATE_FILE"]
metrics_file = os.environ["EF_METRICS_FILE"]
runtime_dir = os.environ["EF_RUNTIME_DIR"]
now = os.environ["EF_NOW"]
today = os.environ["EF_TODAY"]

def split_csv(raw):
    out = []
    for part in (raw or "").split(","):
        p = part.strip()
        if p and p not in out:
            out.append(p)
    return out

def read_state():
    if not os.path.isfile(state_file):
        return None
    with open(state_file, "r", encoding="utf-8") as fh:
        return json.load(fh)

def write_state(data):
    os.makedirs(runtime_dir, exist_ok=True)
    with open(state_file, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

def clear_transient_runtime():
    removed = 0
    for name in ("TASK_SPEC.md", "test-status.json", "NEXT_PROMPT.md"):
        p = os.path.join(runtime_dir, name)
        if os.path.isfile(p):
            os.remove(p)
            removed += 1
    for pattern in ("implementor-prompt-*.md", "tester-prompt-*.md"):
        for p in glob.glob(os.path.join(runtime_dir, pattern)):
            if os.path.isfile(p):
                os.remove(p)
                removed += 1
    return removed

if cmd == "init":
    card = os.environ["EF_CARD"].strip()
    if not card:
        sys.stderr.write("init requires --card <id>\n")
        sys.exit(2)
    tier_raw = os.environ["EF_TIER"].strip()
    tier = int(tier_raw) if tier_raw in ("0", "1", "2") else 1
    branch = os.environ["EF_BRANCH"].strip() or os.environ["EF_CUR_BRANCH"]
    role = os.environ["EF_ROLE"].strip() or "Engenheiro-Chefe"
    phase = os.environ["EF_PHASE"].strip() or "triagem"
    attempt = int(os.environ["EF_ATTEMPT"])
    if attempt < 0:
        attempt = 0
    state = {
        "schemaVersion": "6.0",
        "card": card,
        "tier": tier,
        "branch": branch,
        "phase": phase,
        "activeRole": role,
        "headCommit": os.environ["EF_HEAD"],
        "attempt": attempt,
        "criteria": [{"id": c, "status": "pending", "artifact": None} for c in split_csv(os.environ["EF_CRITERIA"])],
        "decisionsInScope": split_csv(os.environ["EF_DECISIONS"]),
        "deadEnds": [],
        "filesTouched": split_csv(os.environ["EF_FILES_TOUCHED"]),
        "blockedDecisions": 0,
        "envelopeViolations": 0,
        "nextAction": os.environ["EF_NEXT_ACTION"].strip(),
        "createdAt": now,
        "updatedAt": now,
    }
    write_state(state)
    print(f"Session state initialized: {state_file} (card={card}, tier={tier}, role={role})")

elif cmd == "update":
    state = read_state()
    if state is None:
        sys.stderr.write(f"No session state found at {state_file}. Run 'init' first.\n")
        sys.exit(3)
    if os.environ["EF_TIER"].strip() in ("0", "1", "2"):
        state["tier"] = int(os.environ["EF_TIER"].strip())
    if os.environ["EF_BRANCH"].strip():
        state["branch"] = os.environ["EF_BRANCH"].strip()
    if os.environ["EF_PHASE"].strip():
        state["phase"] = os.environ["EF_PHASE"].strip()
    if os.environ["EF_ROLE"].strip():
        state["activeRole"] = os.environ["EF_ROLE"].strip()
    attempt = int(os.environ["EF_ATTEMPT"])
    if attempt >= 0:
        state["attempt"] = attempt
    if os.environ["EF_NEXT_ACTION"].strip():
        state["nextAction"] = os.environ["EF_NEXT_ACTION"].strip()
    if os.environ["EF_INC_BLOCKED"] == "1":
        state["blockedDecisions"] = int(state.get("blockedDecisions", 0)) + 1
    if os.environ["EF_INC_ENVELOPE"] == "1":
        state["envelopeViolations"] = int(state.get("envelopeViolations", 0)) + 1
    for d in split_csv(os.environ["EF_DECISIONS"]):
        if d not in state["decisionsInScope"]:
            state["decisionsInScope"].append(d)
    for f in split_csv(os.environ["EF_FILES_TOUCHED"]):
        if f not in state["filesTouched"]:
            state["filesTouched"].append(f)
    dead_end = os.environ["EF_DEAD_END"].strip()
    if dead_end and dead_end not in state["deadEnds"]:
        state["deadEnds"].append(dead_end)
    cid = os.environ["EF_CRIT_ID"].strip()
    if cid:
        cstatus = os.environ["EF_CRIT_STATUS"].strip() or "pending"
        cart = os.environ["EF_CRIT_ARTIFACT"].strip() or None
        found = False
        for item in state["criteria"]:
            if item["id"] == cid:
                item["status"] = cstatus
                if cart is not None:
                    item["artifact"] = cart
                found = True
                break
        if not found:
            state["criteria"].append({"id": cid, "status": cstatus, "artifact": cart})
    state["headCommit"] = os.environ["EF_HEAD"]
    state["updatedAt"] = now
    write_state(state)
    print(f"Session state updated: card={state['card']} phase={state['phase']} role={state['activeRole']} attempt={state['attempt']}")

elif cmd == "show":
    state = read_state()
    if state is None:
        print("no active session-state")
        sys.exit(0)
    if os.environ["EF_AS_JSON"] == "1":
        print(json.dumps(state, indent=2, ensure_ascii=False))
        sys.exit(0)
    print(f"Session: {state['card']} | Tier {state['tier']} | Branch: {state['branch']} | HEAD: {state['headCommit']}")
    print(f"Phase: {state['phase']} | Active Role: {state['activeRole']} | Attempt: {state['attempt']}")
    if state.get("decisionsInScope"):
        print("Decisions in scope: " + ", ".join(state["decisionsInScope"]))
    if state.get("criteria"):
        print("Criteria: " + ", ".join(f"{c['id']}={c['status']}" for c in state["criteria"]))
    if state.get("deadEnds"):
        print("Dead ends (DO NOT REPEAT):")
        for d in state["deadEnds"]:
            print(f"  - {d}")
    if state.get("filesTouched"):
        print("Files touched: " + ", ".join(state["filesTouched"]))
    if state.get("nextAction"):
        print(f"Next action: {state['nextAction']}")

elif cmd == "close":
    state = read_state()
    if state is None:
        print("no active session-state to close")
        sys.exit(0)
    os.makedirs(runtime_dir, exist_ok=True)
    metric = {
        "date": today,
        "closed_at": now,
        "card": state["card"],
        "tier": state["tier"],
        "branch": state["branch"],
        "harness_attempts": state.get("attempt", 0),
        "envelope_violations": state.get("envelopeViolations", 0),
        "blocked_decisions": state.get("blockedDecisions", 0),
        "dead_ends_count": len(state.get("deadEnds", [])),
        "rework_post_gate2": os.environ["EF_REWORK"] == "1",
    }
    with open(metrics_file, "a", encoding="utf-8", newline="\n") as fh:
        fh.write(json.dumps(metric, separators=(",", ":"), ensure_ascii=False) + "\n")
    if os.environ["EF_KEEP_STATE"] != "1" and os.path.isfile(state_file):
        os.remove(state_file)
    cleaned = 0
    if os.environ["EF_KEEP_STATE"] != "1" and os.environ["EF_KEEP_RUNTIME"] != "1":
        cleaned = clear_transient_runtime()
    print(f"Session closed and metric recorded: {metrics_file} (card={state['card']}, tier={state['tier']}, attempts={state.get('attempt', 0)}, runtime_cleaned={cleaned})")
PY
