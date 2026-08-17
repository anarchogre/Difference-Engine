#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_GENERIC_INGEST_CONTRACT_$TS-STAGE11"

BATCH="$CURRENT/workspace/operational/ingestion/service/batch.py"
PROV="$CURRENT/workspace/operational/ingestion/service/provenance.py"
TESTROOT="$CURRENT/workspace/operational/ingestion"

mkdir -p "$OUT"

echo "=== PAN — GENERIC INGEST CONTRACT STAGE 11 ==="
echo "BATCH=$BATCH"
echo "PROVENANCE=$PROV"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$BATCH" "$PROV"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST_STAGE10="$(find "$TREE_HOME" -maxdepth 1 -type d -name 'PAN_UNIVERSAL_PIPELINE_RECOVERY_*-STAGE10' \
  -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"

[ -n "$LATEST_STAGE10" ] && [ -d "$LATEST_STAGE10" ] || {
  echo "BLOCKER: no Stage 10 evidence found"
  exit 22
}

SAFE="$LATEST_STAGE10/08_SAFE_SOURCE_CANDIDATES.txt"
[ -f "$SAFE" ] || { echo "BLOCKER: missing $SAFE"; exit 23; }

sha256sum "$BATCH" "$PROV" > "$OUT/00_SOURCE_HASHES.sha256"

# Recover the exact callable contract from source without running ingestion.
"$PYTHON" - "$BATCH" "$PROV" > "$OUT/01_STATIC_CONTRACT.json" <<'PY'
import ast, json, sys
from pathlib import Path

def inspect(path):
    p = Path(path)
    text = p.read_text(encoding="utf-8", errors="replace")
    tree = ast.parse(text, filename=str(p))
    out = {"path": str(p), "functions": {}, "classes": []}

    for node in tree.body:
        if isinstance(node, ast.ClassDef):
            out["classes"].append(node.name)
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            args = []
            defaults = [None] * (len(node.args.args) - len(node.args.defaults))
            defaults += list(node.args.defaults)
            for arg, default in zip(node.args.args, defaults):
                if default is None:
                    d = None
                else:
                    try:
                        d = ast.literal_eval(default)
                    except Exception:
                        try:
                            d = ast.unparse(default)
                        except Exception:
                            d = "?"
                args.append({"name": arg.arg, "default": d})
            out["functions"][node.name] = {
                "args": args,
                "vararg": node.args.vararg.arg if node.args.vararg else None,
                "kwarg": node.args.kwarg.arg if node.args.kwarg else None,
            }
    return out

print(json.dumps([inspect(x) for x in sys.argv[1:]], indent=2))
PY

# Recover actual historical/test calls and source_class values.
{
  echo "=== INGEST_SOURCES CALL SITES ==="
  grep -RInE 'ingest_sources[[:space:]]*\(' "$TESTROOT" \
    --include='*.py' 2>/dev/null | head -1000 || true
  echo
  echo "=== INGEST_DIRECTORY CALL SITES ==="
  grep -RInE 'ingest_directory[[:space:]]*\(' "$TESTROOT" \
    --include='*.py' 2>/dev/null | head -1000 || true
  echo
  echo "=== SOURCE_CLASS VALUES ==="
  grep -RInE 'source_class[[:space:]]*=' "$TESTROOT" \
    --include='*.py' 2>/dev/null | head -1000 || true
} > "$OUT/02_CALL_SITES.txt"

# Parse source_class evidence and determine whether a generic class is proven.
"$PYTHON" - "$OUT/02_CALL_SITES.txt" "$OUT/01_STATIC_CONTRACT.json" > "$OUT/03_CONTRACT_DECISION.txt" <<'PY'
import json, re, sys
from collections import Counter
from pathlib import Path

calls = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
contract = json.load(open(sys.argv[2], encoding="utf-8"))

batch = next((x for x in contract if x["path"].endswith("/batch.py")), {})
sig = batch.get("functions", {}).get("ingest_sources", {})
args = sig.get("args", [])

source_class_default = None
source_class_present = False
for a in args:
    if a["name"] == "source_class":
        source_class_present = True
        source_class_default = a["default"]

values = re.findall(r"source_class\s*=\s*['\"]([^'\"]+)['\"]", calls)
counts = Counter(values)
nonconv = [v for v, _ in counts.most_common() if v.lower() != "conversation"]

print(f"SOURCE_CLASS_PARAMETER_PRESENT={source_class_present}")
print(f"SOURCE_CLASS_DEFAULT={source_class_default!r}")
print("OBSERVED_SOURCE_CLASS_VALUES=" + ",".join(f"{k}:{v}" for k,v in counts.items()))

if not source_class_present:
    print("GENERIC_CLASS_DECISION=NO_SOURCE_CLASS_PARAMETER")
elif source_class_default not in (None, "conversation"):
    print(f"GENERIC_CLASS_DECISION=USE_DEFAULT:{source_class_default}")
elif nonconv:
    print(f"GENERIC_CLASS_DECISION=USE_OBSERVED:{nonconv[0]}")
else:
    print("GENERIC_CLASS_DECISION=NOT_PROVEN")
PY

# Select one real remainder source, but do not ingest unless class contract is proven.
SOURCE="$(head -1 "$SAFE" 2>/dev/null || true)"
[ -n "$SOURCE" ] && [ -f "$SOURCE" ] || {
  echo "BLOCKER: no safe remainder source found"
  exit 24
}

echo "SELECTED_SOURCE=$SOURCE" > "$OUT/04_SELECTED_SOURCE.txt"
sha256sum "$SOURCE" > "$OUT/04_SELECTED_SOURCE.sha256"

DECISION="$(grep '^GENERIC_CLASS_DECISION=' "$OUT/03_CONTRACT_DECISION.txt" | cut -d= -f2-)"

case "$DECISION" in
  USE_DEFAULT:*)
    CLASS="${DECISION#USE_DEFAULT:}"
    NEXT="RUN_ONE_SANDBOXED_GENERIC_INGEST_WITH_RECOVERED_DEFAULT_CLASS"
    ;;
  USE_OBSERVED:*)
    CLASS="${DECISION#USE_OBSERVED:}"
    NEXT="RUN_ONE_SANDBOXED_GENERIC_INGEST_WITH_OBSERVED_CLASS"
    ;;
  NO_SOURCE_CLASS_PARAMETER)
    CLASS=""
    NEXT="RUN_ONE_SANDBOXED_GENERIC_INGEST_WITHOUT_SOURCE_CLASS"
    ;;
  *)
    CLASS=""
    NEXT="RECOVER_GENERIC_CLASS_SEMANTICS_FROM_CONTRACTS_BEFORE_EXECUTION"
    ;;
esac

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_GENERIC_INGEST_CONTRACT_STAGE11
UTC=$TS
SELECTED_SOURCE=$SOURCE
GENERIC_CLASS_DECISION=$DECISION
GENERIC_CLASS=$CLASS
INGESTION_EXECUTED=NO
SOURCE_MUTATION=NONE
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- recovered ingest_sources signature ---"
"$PYTHON" - "$OUT/01_STATIC_CONTRACT.json" <<'PY'
import json, sys
d=json.load(open(sys.argv[1], encoding="utf-8"))
for rec in d:
    if rec["path"].endswith("/batch.py"):
        print(json.dumps(rec.get("functions",{}).get("ingest_sources",{}), indent=2))
PY
echo
echo "--- source_class evidence ---"
cat "$OUT/03_CONTRACT_DECISION.txt"
echo
echo "STAGE11_COMPLETE=YES"
