#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
LEGACY="$HOME/Difference-Engine-LEGACY-STALE-DECOMPOSED"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_JSON_PARSER_RECOVERY_$TS-STAGE14"

SERVICE="$CURRENT/workspace/operational/ingestion/service"
REGISTRY="$SERVICE/registry.py"
PARSER="$SERVICE/parser.py"

mkdir -p "$OUT"

echo "=== PAN — JSON PARSER RECOVERY STAGE 14 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$LEGACY" "$SERVICE" "$REGISTRY" "$PARSER"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

sha256sum "$REGISTRY" "$PARSER" > "$OUT/00_ACTIVE_SOURCE_HASHES.sha256"

# 1. Exact active registry/parser implementation.
{
  echo "===== registry.py ====="
  sed -n '1,320p' "$REGISTRY"
  echo
  echo "===== parser.py ====="
  sed -n '1,420p' "$PARSER"
} > "$OUT/01_ACTIVE_REGISTRY_AND_PARSER.txt"

# 2. Static AST summary: registrations, functions, imports, mappings.
"$PYTHON" - "$REGISTRY" "$PARSER" > "$OUT/02_ACTIVE_STATIC_INTERFACE.json" <<'PY'
import ast, json, sys
from pathlib import Path

def inspect(path):
    p = Path(path)
    text = p.read_text(encoding="utf-8", errors="replace")
    tree = ast.parse(text, filename=str(p))
    out = {
        "path": str(p),
        "functions": [],
        "classes": [],
        "imports": [],
        "dict_literals": [],
        "calls": [],
    }

    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            out["functions"].append(node.name)
        elif isinstance(node, ast.ClassDef):
            out["classes"].append(node.name)
        elif isinstance(node, ast.Import):
            out["imports"].extend(a.name for a in node.names)
        elif isinstance(node, ast.ImportFrom):
            out["imports"].append((node.module or "") + ":" + ",".join(a.name for a in node.names))
        elif isinstance(node, ast.Dict):
            try:
                v = ast.literal_eval(node)
                if isinstance(v, dict):
                    out["dict_literals"].append(v)
            except Exception:
                pass
        elif isinstance(node, ast.Call):
            try:
                call = ast.unparse(node)
            except Exception:
                continue
            if any(k in call.lower() for k in ("register", "parser", "suffix", "extension")):
                out["calls"].append(call)

    out["functions"] = sorted(set(out["functions"]))
    out["classes"] = sorted(set(out["classes"]))
    out["imports"] = sorted(set(out["imports"]))
    out["calls"] = out["calls"][:500]
    return out

print(json.dumps([inspect(x) for x in sys.argv[1:]], indent=2))
PY

# 3. Active JSON/parser clues anywhere in current ingestion surface.
{
  echo "=== ACTIVE JSON / REGISTRATION CLUES ==="
  grep -RInE \
    'json|\.json|register.*parser|parser.*register|PARSERS|registry|suffix|extension|parser_for' \
    "$CURRENT/workspace/operational/ingestion" \
    "$CURRENT/ade/services/ingestion" \
    --include='*.py' --include='*.md' --include='*.txt' \
    2>/dev/null \
    | grep -v '/recovery/retired_packages/' \
    | head -4000 || true
} > "$OUT/03_ACTIVE_JSON_CLUES.txt"

# 4. Recover historical/retired JSON parser candidates without executing them.
{
  echo "=== HISTORICAL / RETIRED JSON PARSER CANDIDATES ==="
  find "$CURRENT" "$LEGACY" -xdev -type f \
    \( -iname '*json*parser*.py' \
       -o -iname '*parser*json*.py' \
       -o -iname '*registry*.py' \
       -o -iname '*parser*.py' \
       -o -iname '*formatter*.py' \
       -o -iname '*normaliz*.py' \) \
    -print 2>/dev/null | sort
} > "$OUT/04_HISTORICAL_PARSER_CANDIDATES.txt"

# 5. Search historical source for explicit JSON support and test evidence.
{
  echo "=== HISTORICAL JSON SUPPORT REFERENCES ==="
  grep -RInE \
    'No parser registered|\.json|json parser|JSON parser|register.*json|json\.loads|json\.load|parse_json|source.*json|TEST.*JSON|json.*PASS' \
    "$CURRENT" "$LEGACY" \
    --include='*.py' --include='*.md' --include='*.txt' --include='*.json' \
    2>/dev/null | head -6000 || true
} > "$OUT/05_HISTORICAL_JSON_REFERENCES.txt"

# 6. Find tests that exercise parser registry / JSON ingestion.
{
  echo "=== PARSER / JSON TEST CANDIDATES ==="
  find "$CURRENT" "$LEGACY" -xdev -type f \
    \( -path '*/tests/*' \
       -o -path '*/parser_tests/*' \
       -o -path '*/batch_test/*' \) \
    \( -name '*.py' -o -name '*.sh' -o -name '*.json' -o -name '*.txt' \) \
    -print 2>/dev/null \
    | grep -Ei 'json|parser|registry|ingest|pipeline' \
    | sort || true
} > "$OUT/06_TEST_CANDIDATES.txt"

# 7. Compare active parser/registry against same-named retired copies.
{
  echo "=== SAME-NAMED HISTORICAL COPIES ==="
  for name in registry.py parser.py; do
    echo "### $name"
    find "$CURRENT" "$LEGACY" -xdev -type f -name "$name" -print0 2>/dev/null \
      | sort -z | xargs -0 -r sha256sum
    echo
  done
} > "$OUT/07_SAME_NAMED_HASHES.txt"

# 8. Determine next action from evidence presence, not guessed implementation.
ACTIVE_JSON_HITS="$(grep -ciE 'json|\.json' "$OUT/03_ACTIVE_JSON_CLUES.txt" 2>/dev/null || true)"
HIST_JSON_HITS="$(grep -ciE 'json|\.json' "$OUT/05_HISTORICAL_JSON_REFERENCES.txt" 2>/dev/null || true)"
TEST_HITS="$(grep -c . "$OUT/06_TEST_CANDIDATES.txt" 2>/dev/null || true)"

if [ "$ACTIVE_JSON_HITS" -gt 0 ]; then
  NEXT="INSPECT_ACTIVE_JSON_REGISTRATION_EDGE_AND_REPAIR_ONLY_MISSING_WIRING_IF_PROVEN"
elif [ "$HIST_JSON_HITS" -gt 0 ]; then
  NEXT="RECOVER_JSON_PARSER_FROM_HISTORICAL_LINEAGE_AND_VALIDATE_AGAINST_EXISTING_TESTS"
else
  NEXT="DEFINE_MINIMAL_JSON_PARSER_ONLY_FROM_CURRENT_PARSER_CONTRACT_AND_VALIDATE_BEFORE_USE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_JSON_PARSER_RECOVERY_STAGE14
UTC=$TS
ACTIVE_JSON_HITS=$ACTIVE_JSON_HITS
HISTORICAL_JSON_HITS=$HIST_JSON_HITS
PARSER_TEST_CANDIDATES=$TEST_HITS
INGESTION_EXECUTED=NO
SOURCE_MUTATION=NONE
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- active registry/parser clues ---"
head -120 "$OUT/03_ACTIVE_JSON_CLUES.txt" || true
echo
echo "--- parser/json test candidates ---"
head -80 "$OUT/06_TEST_CANDIDATES.txt" || true
echo
echo "STAGE14_COMPLETE=YES"
