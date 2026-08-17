#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
FIRST_CORPUS="$HOME/Difference-Engine-LEGACY-STALE-DECOMPOSED"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_INGESTION_RECOVERY_$TS-STAGE5"

mkdir -p "$OUT"

echo "=== PAN — DISCOVERY CONTRACT RECOVERY STAGE 5 ==="
echo "CURRENT=$CURRENT"
echo "FIRST_CORPUS=$FIRST_CORPUS"
echo "EVIDENCE=$OUT"
echo

[ -d "$CURRENT" ] || { echo "BLOCKER: missing $CURRENT"; exit 20; }
[ -d "$FIRST_CORPUS" ] || { echo "BLOCKER: missing $FIRST_CORPUS"; exit 21; }
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 22; }

STAGE4="$(find "$TREE_HOME" -maxdepth 1 -type d -name 'PAN_INGESTION_RECOVERY_*-STAGE4' \
  -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"

if [ -z "$STAGE4" ] || [ ! -d "$STAGE4" ]; then
  echo "BLOCKER: no Stage 4 evidence directory found"
  exit 23
fi

STATIC="$STAGE4/02_STATIC_INTERFACE.json"
DISCOVER_COPY="$STAGE4/discover_conversations.py"
DELTA_COPY="$STAGE4/discover_conversation_delta.py"

for x in "$STATIC" "$DISCOVER_COPY" "$DELTA_COPY"; do
  [ -f "$x" ] || { echo "BLOCKER: missing Stage 4 artifact $x"; exit 24; }
done

cp -a "$STATIC" "$OUT/02_STATIC_INTERFACE.json"
cp -a "$DISCOVER_COPY" "$OUT/discover_conversations.py"
cp -a "$DELTA_COPY" "$OUT/discover_conversation_delta.py"

"$PYTHON" - "$STATIC" "$DISCOVER_COPY" "$DELTA_COPY" "$FIRST_CORPUS" > "$OUT/01_CONTRACT_REPORT.txt" <<'PY'
import ast, json, sys
from pathlib import Path

static_path, discover_path, delta_path, first_corpus = sys.argv[1:]
static = json.load(open(static_path, encoding="utf-8"))

def source_info(path):
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    tree = ast.parse(text, filename=path)
    top_level_calls = []
    assignments = {}
    parse_args_targets = []
    arg_calls = []

    for node in tree.body:
        if isinstance(node, ast.Assign):
            try:
                lhs = ",".join(ast.unparse(t) for t in node.targets)
                rhs = ast.unparse(node.value)
                assignments[lhs] = rhs
            except Exception:
                pass
        if isinstance(node, ast.Expr) and isinstance(node.value, ast.Call):
            try:
                top_level_calls.append(ast.unparse(node.value.func))
            except Exception:
                pass

    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and isinstance(node.value, ast.Call):
            try:
                fn = ast.unparse(node.value.func)
            except Exception:
                fn = ""
            if fn.endswith(".parse_args"):
                try:
                    targets = [ast.unparse(t) for t in node.targets]
                except Exception:
                    targets = ["?"]
                parse_args_targets.extend(targets)

        if isinstance(node, ast.Call):
            try:
                fn = ast.unparse(node.func)
            except Exception:
                fn = ""
            if fn.endswith(".add_argument"):
                args, kwargs = [], {}
                for a in node.args:
                    try:
                        args.append(ast.literal_eval(a))
                    except Exception:
                        try:
                            args.append(ast.unparse(a))
                        except Exception:
                            args.append("?")
                for kw in node.keywords:
                    if kw.arg is None:
                        continue
                    try:
                        kwargs[kw.arg] = ast.literal_eval(kw.value)
                    except Exception:
                        try:
                            kwargs[kw.arg] = ast.unparse(kw.value)
                        except Exception:
                            kwargs[kw.arg] = "?"
                arg_calls.append({"args": args, "kwargs": kwargs})

    return {
        "text": text,
        "assignments": assignments,
        "top_level_calls": top_level_calls,
        "parse_args_targets": parse_args_targets,
        "arg_calls": arg_calls,
    }

discover = source_info(discover_path)
delta = source_info(delta_path)

print("STAGE4_STATIC_INTERFACE=")
print(json.dumps(static, indent=2))
print()
print("DISCOVER_TOP_LEVEL_ASSIGNMENTS=")
for k, v in sorted(discover["assignments"].items()):
    if any(token in k.upper() for token in ("ROOT", "OUTPUT", "SHARED", "EXCLUDED")):
        print(f"{k} = {v}")
print()
print("DELTA_ARGUMENT_CONTRACT=")
print(json.dumps(delta["arg_calls"], indent=2))
print()
print("DELTA_PARSE_ARGS_TARGETS=", delta["parse_args_targets"])
print()

# Conservative targetability classification.
sourceish = []
for call in delta["arg_calls"]:
    names = [str(x) for x in call.get("args", [])]
    kw = call.get("kwargs", {})
    blob = " ".join(names + [str(kw.get("dest","")), str(kw.get("help",""))]).lower()
    if any(t in blob for t in ("root", "source", "path", "corpus", "input", "directory", "dir")):
        sourceish.append(call)

print("FIRST_CORPUS=", first_corpus)
print("SOURCE_LIKE_ARGUMENTS=", json.dumps(sourceish, indent=2))

if sourceish:
    print("TARGETABILITY=LIKELY")
else:
    print("TARGETABILITY=NOT_PROVEN")
PY

# Extract the exact argparse lines and nearby context for human inspection.
{
  echo "=== DISCOVER ROOT / OUTPUT DEFINITIONS ==="
  grep -nE '^(SHARED|ROOTS|EXCLUDED|output)[[:space:]]*=' "$DISCOVER_COPY" || true
  echo
  echo "=== DELTA ARGPARSE / MAIN CONTRACT ==="
  grep -nE 'ArgumentParser|add_argument|parse_args|def main|__main__|root|source|path|corpus|baseline|output|delta' \
    "$DELTA_COPY" | head -600 || true
} > "$OUT/02_SOURCE_CONTRACT_CLUES.txt"

# Build a PLAN only. Do not execute discovery yet.
TARGETABILITY="$(grep '^TARGETABILITY=' "$OUT/01_CONTRACT_REPORT.txt" | tail -1 | cut -d= -f2-)"

case "$TARGETABILITY" in
  LIKELY)
    NEXT="BUILD_SANDBOXED_FIRST_CORPUS_DISCOVERY_RUN_FROM_EXACT_ARGUMENT"
    ;;
  *)
    NEXT="DO_NOT_EXECUTE_DISCOVERY_YET_RECOVER_OR_ADAPT_ROOT_BINDING_WITH_PROVENANCE"
    ;;
esac

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_DISCOVERY_CONTRACT_RECOVERY_STAGE5
UTC=$TS
STAGE4=$STAGE4
FIRST_CORPUS=$FIRST_CORPUS
TARGETABILITY=$TARGETABILITY
SOURCE_MUTATION=NONE
DISCOVERY_EXECUTED=NO
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- delta argument contract ---"
awk '
  /DELTA_ARGUMENT_CONTRACT=/{show=1; next}
  /DELTA_PARSE_ARGS_TARGETS=/{show=0}
  show {print}
' "$OUT/01_CONTRACT_REPORT.txt" | head -100
echo
echo "--- discover root clues ---"
grep -nE '^(SHARED|ROOTS|EXCLUDED|output)[[:space:]]*=' "$DISCOVER_COPY" || true
echo
echo "STAGE5_COMPLETE=YES"
