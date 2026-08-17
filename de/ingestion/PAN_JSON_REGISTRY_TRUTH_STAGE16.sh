#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_JSON_REGISTRY_TRUTH_$TS-STAGE16"

SERVICE="$CURRENT/workspace/operational/ingestion/service"
REGISTRY="$SERVICE/registry.py"
PARSER="$SERVICE/parser.py"

mkdir -p "$OUT"

echo "=== PAN — JSON REGISTRY TRUTH STAGE 16 ==="
echo "SERVICE=$SERVICE"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$SERVICE" "$REGISTRY" "$PARSER"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

sha256sum "$REGISTRY" "$PARSER" > "$OUT/00_HASHES.sha256"

# Exact source snapshots.
cp -a "$REGISTRY" "$OUT/registry.py"
cp -a "$PARSER" "$OUT/parser.py"

# 1. Show exact registry source and AST-derived PARSERS mapping keys.
"$PYTHON" - "$REGISTRY" > "$OUT/01_STATIC_REGISTRY_TRUTH.txt" <<'PY'
import ast, sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="replace")
tree = ast.parse(text, filename=str(p))

print("===== EXACT registry.py =====")
print(text)
print("===== AST PARSERS ASSIGNMENT =====")

found = False
for node in tree.body:
    if not isinstance(node, ast.Assign):
        continue
    names = []
    for t in node.targets:
        try:
            names.append(ast.unparse(t))
        except Exception:
            pass
    if "PARSERS" not in names:
        continue

    found = True
    if isinstance(node.value, ast.Dict):
        for k, v in zip(node.value.keys, node.value.values):
            try:
                key = ast.literal_eval(k)
            except Exception:
                key = ast.unparse(k)
            try:
                val = ast.unparse(v)
            except Exception:
                val = "?"
            print(f"{key!r} -> {val}")
    else:
        print("PARSERS is not a dict literal:")
        print(ast.unparse(node.value))

if not found:
    print("PARSERS assignment not found")
PY

# 2. Import the active runtime and inspect actual PARSERS after normal package import.
set +e
(
  cd "$CURRENT"
  PYTHONPATH="$CURRENT${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - <<'PY'
from workspace.operational.ingestion.service import registry
from workspace.operational.ingestion.service import parser

print("RUNTIME_REGISTRY_MODULE=", registry.__file__)
print("RUNTIME_PARSER_MODULE=", parser.__file__)
print("RUNTIME_PARSER_KEYS=", sorted(registry.PARSERS.keys()))
print("RUNTIME_JSON_PRESENT=", ".json" in registry.PARSERS)

for k in sorted(registry.PARSERS):
    fn = registry.PARSERS[k]
    print(f"RUNTIME_MAPPING {k} -> {getattr(fn, '__module__', '?')}.{getattr(fn, '__name__', repr(fn))}")
PY
) > "$OUT/02_RUNTIME_REGISTRY_TRUTH.txt" 2> "$OUT/02_RUNTIME_REGISTRY_TRUTH.stderr.txt"
RUNTIME_RC=$?
set -e

# 3. Ask parser_for directly using an inert .json path; this does not read the file.
set +e
(
  cd "$CURRENT"
  PYTHONPATH="$CURRENT${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - <<'PY'
from pathlib import Path
from workspace.operational.ingestion.service.registry import parser_for

p = Path("/tmp/PAN_REGISTRY_PROBE.json")
try:
    fn = parser_for(p)
    print("PARSER_FOR_JSON=PASS")
    print("PARSER_FOR_JSON_CALLABLE=" + fn.__module__ + "." + fn.__name__)
except Exception as e:
    print("PARSER_FOR_JSON=FAIL")
    print(type(e).__name__ + ": " + str(e))
    raise
PY
) > "$OUT/03_PARSER_FOR_JSON.txt" 2> "$OUT/03_PARSER_FOR_JSON.stderr.txt"
PARSER_FOR_RC=$?
set -e

STATIC_JSON="$("$PYTHON" - "$REGISTRY" <<'PY'
import ast, sys
from pathlib import Path
tree = ast.parse(Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace"))
present = False
for node in tree.body:
    if not isinstance(node, ast.Assign):
        continue
    names = []
    for t in node.targets:
        try:
            names.append(ast.unparse(t))
        except Exception:
            pass
    if "PARSERS" not in names or not isinstance(node.value, ast.Dict):
        continue
    for k in node.value.keys:
        try:
            if ast.literal_eval(k) == ".json":
                present = True
        except Exception:
            pass
print("YES" if present else "NO")
PY
)"

RUNTIME_JSON="$(grep '^RUNTIME_JSON_PRESENT=' "$OUT/02_RUNTIME_REGISTRY_TRUTH.txt" 2>/dev/null | tail -1 | cut -d= -f2- | xargs || true)"

if [ "$STATIC_JSON" = "YES" ] && [ "$RUNTIME_JSON" = "True" ] && [ "$PARSER_FOR_RC" -eq 0 ]; then
  DECISION="JSON_REGISTERED_AND_RUNTIME_VISIBLE"
  NEXT="TRACE_WHY_STAGE13_IMPORTED_DIFFERENT_STATE_OR_STALE_BYTECODE_THEN_RERUN_SINGLE_PROOF"
elif [ "$STATIC_JSON" = "YES" ] && [ "$RUNTIME_JSON" != "True" ]; then
  DECISION="STATIC_JSON_MAPPING_NOT_PRESENT_AT_RUNTIME"
  NEXT="TRACE_IMPORT_OR_MODULE_SHADOWING_ONLY"
elif [ "$STATIC_JSON" = "NO" ]; then
  DECISION="NO_JSON_MAPPING_IN_ACTIVE_REGISTRY"
  NEXT="RECOVER_OR_IMPLEMENT_MINIMAL_JSON_PARSER_AND_ADD_EXACT_REGRESSION_TEST"
else
  DECISION="JSON_REGISTRY_STATE_INCONSISTENT"
  NEXT="PRESERVE_EVIDENCE_AND_TRACE_MODULE_IDENTITY"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_JSON_REGISTRY_TRUTH_STAGE16
UTC=$TS
STATIC_JSON_MAPPING=$STATIC_JSON
RUNTIME_IMPORT_EXIT=$RUNTIME_RC
RUNTIME_JSON_PRESENT=$RUNTIME_JSON
PARSER_FOR_JSON_EXIT=$PARSER_FOR_RC
DECISION=$DECISION
SOURCE_MUTATION=NONE
INGESTION_EXECUTED=NO
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- runtime registry truth ---"
cat "$OUT/02_RUNTIME_REGISTRY_TRUTH.txt" 2>/dev/null || true
echo
echo "--- parser_for(.json) ---"
cat "$OUT/03_PARSER_FOR_JSON.txt" 2>/dev/null || true
echo
echo "STAGE16_COMPLETE=YES"
