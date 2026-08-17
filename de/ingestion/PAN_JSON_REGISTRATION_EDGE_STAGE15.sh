#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_JSON_REGISTRATION_EDGE_$TS-STAGE15"

SERVICE="$CURRENT/workspace/operational/ingestion/service"
REGISTRY="$SERVICE/registry.py"
PARSER="$SERVICE/parser.py"

mkdir -p "$OUT"

echo "=== PAN — JSON REGISTRATION EDGE STAGE 15 ==="
echo "SERVICE=$SERVICE"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$SERVICE" "$REGISTRY" "$PARSER"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

sha256sum "$REGISTRY" "$PARSER" > "$OUT/00_ACTIVE_HASHES.sha256"

# Exact active source, preserved.
cp -a "$REGISTRY" "$OUT/registry.py"
cp -a "$PARSER" "$OUT/parser.py"

# 1. Targeted AST inspection of active service only.
"$PYTHON" - "$SERVICE" > "$OUT/01_ACTIVE_JSON_EDGE.json" <<'PY'
import ast, json, sys
from pathlib import Path

root = Path(sys.argv[1])
records = []

for p in sorted(root.glob("*.py")):
    text = p.read_text(encoding="utf-8", errors="replace")
    try:
        tree = ast.parse(text, filename=str(p))
    except Exception as e:
        records.append({"path": str(p), "parse_error": repr(e)})
        continue

    rec = {
        "path": str(p),
        "imports": [],
        "functions": [],
        "classes": [],
        "json_named_symbols": [],
        "json_string_literals": [],
        "register_like_calls": [],
        "dict_extension_maps": [],
    }

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            rec["imports"].extend(a.name for a in node.names)
        elif isinstance(node, ast.ImportFrom):
            rec["imports"].append((node.module or "") + ":" + ",".join(a.name for a in node.names))
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            rec["functions"].append(node.name)
            if "json" in node.name.lower():
                rec["json_named_symbols"].append(node.name)
        elif isinstance(node, ast.ClassDef):
            rec["classes"].append(node.name)
            if "json" in node.name.lower():
                rec["json_named_symbols"].append(node.name)
        elif isinstance(node, ast.Constant) and isinstance(node.value, str):
            if ".json" in node.value.lower() or node.value.lower() == "json":
                rec["json_string_literals"].append(node.value)
        elif isinstance(node, ast.Call):
            try:
                s = ast.unparse(node)
            except Exception:
                s = ""
            low = s.lower()
            if "register" in low or "parser_for" in low or ".json" in low:
                rec["register_like_calls"].append(s)
        elif isinstance(node, ast.Dict):
            try:
                d = ast.literal_eval(node)
            except Exception:
                continue
            if isinstance(d, dict):
                keys = [str(k) for k in d.keys()]
                if any(".json" in k.lower() for k in keys):
                    rec["dict_extension_maps"].append(d)

    rec["imports"] = sorted(set(rec["imports"]))
    rec["functions"] = sorted(set(rec["functions"]))
    rec["classes"] = sorted(set(rec["classes"]))
    rec["json_named_symbols"] = sorted(set(rec["json_named_symbols"]))
    rec["json_string_literals"] = sorted(set(rec["json_string_literals"]))
    rec["register_like_calls"] = rec["register_like_calls"][:500]
    records.append(rec)

print(json.dumps(records, indent=2))
PY

# 2. Exact line-level evidence in active source/tests.
{
  echo "=== ACTIVE SERVICE .json / registry references ==="
  grep -RInE \
    '(\.json|json|register|parser_for|PARSERS|REGISTRY)' \
    "$SERVICE" \
    --include='*.py' \
    2>/dev/null | head -3000 || true
  echo
  echo "=== ACTIVE TEST EXPECTATIONS ==="
  grep -RInE \
    '(\.json|json|parser_for|register|No parser registered)' \
    "$SERVICE/tests" \
    --include='*.py' \
    2>/dev/null | head -2000 || true
} > "$OUT/02_ACTIVE_LINE_EVIDENCE.txt"

# 3. Compare active registry/parser with retired copies, targeted only.
{
  echo "=== RETIRED SAME-NAMED registry.py / parser.py ==="
  find "$CURRENT/workspace/operational/ingestion/recovery/retired_packages" \
    -type f \( -name 'registry.py' -o -name 'parser.py' \) \
    -print0 2>/dev/null | sort -z | xargs -0 -r sha256sum
  echo
  echo "=== RETIRED JSON REGISTRATION CLUES ==="
  grep -RInE \
    '(\.json|json|register|parser_for|PARSERS|REGISTRY)' \
    "$CURRENT/workspace/operational/ingestion/recovery/retired_packages" \
    --include='registry.py' --include='parser.py' --include='*.py' \
    2>/dev/null | head -4000 || true
} > "$OUT/03_RETIRED_JSON_EDGE.txt"

# 4. Recover initialization/import wiring around registry/parser.
{
  echo "=== ACTIVE IMPORT WIRING ==="
  grep -RInE \
    '(from .*registry|import .*registry|from .*parser|import .*parser|parser_for|register)' \
    "$SERVICE" \
    --include='*.py' \
    2>/dev/null | head -3000 || true
} > "$OUT/04_IMPORT_WIRING.txt"

# 5. Deterministic decision.
"$PYTHON" - "$OUT/01_ACTIVE_JSON_EDGE.json" \
  "$OUT/02_ACTIVE_LINE_EVIDENCE.txt" \
  "$OUT/03_RETIRED_JSON_EDGE.txt" \
  > "$OUT/05_DECISION.txt" <<'PY'
import json, re, sys
from pathlib import Path

active = json.load(open(sys.argv[1], encoding="utf-8"))
active_lines = Path(sys.argv[2]).read_text(encoding="utf-8", errors="replace")
retired = Path(sys.argv[3]).read_text(encoding="utf-8", errors="replace")

active_json_literal = False
active_json_symbol = False
active_register_json = False

for rec in active:
    if any(".json" in str(x).lower() for x in rec.get("json_string_literals", [])):
        active_json_literal = True
    if rec.get("json_named_symbols"):
        active_json_symbol = True
    for call in rec.get("register_like_calls", []):
        low = call.lower()
        if ".json" in low and ("register" in low or "parser" in low):
            active_register_json = True

# line-level backup
if re.search(r'(register|parser_for|PARSERS|REGISTRY).{0,120}\.json|\.json.{0,120}(register|parser_for|PARSERS|REGISTRY)',
             active_lines, re.I | re.S):
    active_register_json = True

retired_register_json = bool(re.search(
    r'(register|parser_for|PARSERS|REGISTRY).{0,120}\.json|\.json.{0,120}(register|parser_for|PARSERS|REGISTRY)',
    retired, re.I | re.S
))

print(f"ACTIVE_JSON_LITERAL={active_json_literal}")
print(f"ACTIVE_JSON_NAMED_SYMBOL={active_json_symbol}")
print(f"ACTIVE_JSON_REGISTRATION={active_register_json}")
print(f"RETIRED_JSON_REGISTRATION={retired_register_json}")

if active_register_json:
    print("DECISION=ACTIVE_JSON_WIRING_EXISTS_FAILURE_IS_INITIALIZATION_OR_REGISTRATION_ORDER")
elif active_json_symbol or active_json_literal:
    print("DECISION=ACTIVE_JSON_SUPPORT_EXISTS_BUT_REGISTRATION_NOT_PROVEN")
elif retired_register_json:
    print("DECISION=RECOVER_JSON_REGISTRATION_FROM_RETIRED_LINEAGE")
else:
    print("DECISION=NO_JSON_PARSER_EDGE_RECOVERED")
PY

DECISION="$(sed -n 's/^DECISION=//p' "$OUT/05_DECISION.txt" | tail -1)"

case "$DECISION" in
  ACTIVE_JSON_WIRING_EXISTS_FAILURE_IS_INITIALIZATION_OR_REGISTRATION_ORDER)
    NEXT="TRACE_ACTIVE_REGISTRY_INITIALIZATION_ORDER_AND_REPAIR_ONLY_WIRING"
    ;;
  ACTIVE_JSON_SUPPORT_EXISTS_BUT_REGISTRATION_NOT_PROVEN)
    NEXT="IDENTIFY_ACTIVE_JSON_CALLABLE_AND_BIND_ONLY_JSON_SUFFIX_WITH_TEST"
    ;;
  RECOVER_JSON_REGISTRATION_FROM_RETIRED_LINEAGE)
    NEXT="COMPARE_RETIRED_JSON_PARSER_CONTRACT_TO_ACTIVE_PARSER_CONTRACT_THEN_RECOVER"
    ;;
  *)
    NEXT="IMPLEMENT_MINIMAL_JSON_PARSER_TO_ACTIVE_PARSED_CONTRACT_AND_ADD_REGRESSION_TEST"
    ;;
esac

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_JSON_REGISTRATION_EDGE_STAGE15
UTC=$TS
DECISION=$DECISION
SOURCE_MUTATION=NONE
INGESTION_EXECUTED=NO
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- decision evidence ---"
cat "$OUT/05_DECISION.txt"
echo
echo "--- active json edge snippets ---"
grep -nEi 'json|register|parser_for|PARSERS|REGISTRY' "$OUT/02_ACTIVE_LINE_EVIDENCE.txt" | head -120 || true
echo
echo "STAGE15_COMPLETE=YES"
