#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_JSON_NORMALIZATION_EDGE_$TS-STAGE25"
SERVICE="$CURRENT/workspace/operational/ingestion/service"

mkdir -p "$OUT"

echo "=== PAN — LOCATE JSON NORMALIZATION EDGE STAGE 25 ==="
echo "CURRENT=$CURRENT"
echo "SERVICE=$SERVICE"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$SERVICE"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST24="$(
  find "$TREE_HOME" -maxdepth 1 -type d \
    -name 'PAN_JSON_SERIALIZATION_TRACE_*-STAGE24' \
    -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | head -1 | cut -d' ' -f2-
)"
[ -n "$LATEST24" ] && [ -d "$LATEST24" ] || {
  echo "BLOCKER: Stage24 evidence missing"
  exit 22
}

DECISION24="$(sed -n 's/^DECISION=//p' "$LATEST24/SUMMARY.txt" | head -1)"
[ "$DECISION24" = "JSON_PAYLOAD_LOST_BETWEEN_PARSE_AND_SERIALIZED_OUTPUT" ] || {
  echo "BLOCKER: Stage24 decision drift: $DECISION24"
  exit 23
}

sha256sum "$SERVICE"/*.py 2>/dev/null > "$OUT/00_SERVICE_HASHES.sha256" || true

# Exact line-level hits around the observed canonical conversation-shaped output.
grep -RInE \
  '["'\'']commands["'\'']|["'\'']turns["'\'']|["'\'']kind["'\'']|parsed\.json|structure/parsed|write_text|json\.dump|json\.dumps' \
  "$SERVICE" \
  --include='*.py' \
  2>/dev/null > "$OUT/01_TEXT_HITS.txt" || true

# AST-locate dict literals that can produce {kind, turns, commands}, and
# report their containing function plus return/call context.
"$PYTHON" - "$SERVICE" > "$OUT/02_AST_NORMALIZATION_CANDIDATES.txt" <<'PY'
import ast
import sys
from pathlib import Path

root = Path(sys.argv[1])

def const_key(node):
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return node.value
    return None

def parents(tree):
    out = {}
    for parent in ast.walk(tree):
        for child in ast.iter_child_nodes(parent):
            out[child] = parent
    return out

for p in sorted(root.glob("*.py")):
    text = p.read_text(encoding="utf-8", errors="replace")
    try:
        tree = ast.parse(text, filename=str(p))
    except Exception:
        continue
    pm = parents(tree)

    for node in ast.walk(tree):
        if not isinstance(node, ast.Dict):
            continue
        keys = [const_key(k) for k in node.keys]
        keyset = {k for k in keys if k is not None}
        if not {"kind", "turns", "commands"}.issubset(keyset):
            continue

        cur = node
        fn = None
        while cur in pm:
            cur = pm[cur]
            if isinstance(cur, (ast.FunctionDef, ast.AsyncFunctionDef)):
                fn = cur
                break

        print(f"FILE={p}")
        print(f"LINE={node.lineno}")
        print(f"FUNCTION={fn.name if fn else 'MODULE'}")
        try:
            print("DICT=" + ast.unparse(node))
        except Exception:
            pass

        if fn:
            print("FUNCTION_SOURCE=")
            start = fn.lineno - 1
            end = fn.end_lineno
            for i, line in enumerate(text.splitlines()[start:end], start=fn.lineno):
                print(f"{i}:{line}")

        print("-----")
PY

# Also find assignments/returns whose target/value names suggest normalization.
"$PYTHON" - "$SERVICE" > "$OUT/03_AST_DATAFLOW.txt" <<'PY'
import ast
import sys
from pathlib import Path

root = Path(sys.argv[1])
needles = ("parsed", "structure", "output", "turns", "commands", "manifest")

for p in sorted(root.glob("*.py")):
    text = p.read_text(encoding="utf-8", errors="replace")
    try:
        tree = ast.parse(text, filename=str(p))
    except Exception:
        continue

    print(f"===== {p.name} =====")
    for node in ast.walk(tree):
        if isinstance(node, (ast.Assign, ast.AnnAssign, ast.Return, ast.Call)):
            try:
                s = ast.unparse(node)
            except Exception:
                continue
            low = s.lower()
            if any(n in low for n in needles):
                lineno = getattr(node, "lineno", "?")
                print(f"{lineno}: {s[:1200]}")
PY

# Deterministic summary from exact AST candidate count.
COUNT="$(grep -c '^FILE=' "$OUT/02_AST_NORMALIZATION_CANDIDATES.txt" || true)"

if [ "$COUNT" -eq 1 ]; then
  DECISION="SINGLE_SERIALIZATION_NORMALIZER_IDENTIFIED"
  NEXT="PATCH_ONLY_IDENTIFIED_NORMALIZER_TO_PRESERVE_JSON_DOCUMENT_WITH_REGRESSION_AND_ROLLBACK"
elif [ "$COUNT" -gt 1 ]; then
  DECISION="MULTIPLE_SERIALIZATION_NORMALIZER_CANDIDATES"
  NEXT="TRACE_CALL_PATH_AMONG_IDENTIFIED_CANDIDATES_BEFORE_MUTATION"
else
  DECISION="NO_LITERAL_NORMALIZER_IDENTIFIED"
  NEXT="INSPECT_DATAFLOW_FOR_CONSTRUCTOR_OR_DATACLASS_NORMALIZATION_BEFORE_MUTATION"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_JSON_NORMALIZATION_EDGE_STAGE25
UTC=$TS
STAGE24_DECISION=$DECISION24
NORMALIZER_CANDIDATE_COUNT=$COUNT
DECISION=$DECISION
SOURCE_MUTATION=NONE
INGESTION_EXECUTED=NO
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- exact candidates ---"
cat "$OUT/02_AST_NORMALIZATION_CANDIDATES.txt"
echo
echo "STAGE25_COMPLETE=YES"
