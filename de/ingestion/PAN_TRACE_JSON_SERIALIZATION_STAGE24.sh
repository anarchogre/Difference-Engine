#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_JSON_SERIALIZATION_TRACE_$TS-STAGE24"

SERVICE="$CURRENT/workspace/operational/ingestion/service"
mkdir -p "$OUT/sandbox"

echo "=== PAN — JSON SERIALIZATION TRACE STAGE 24 ==="
echo "CURRENT=$CURRENT"
echo "SERVICE=$SERVICE"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$SERVICE"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST23="$(
  find "$TREE_HOME" -maxdepth 1 -type d \
    -name 'PAN_JSON_KIND_IMPLEMENT_*-STAGE23' \
    -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | head -1 | cut -d' ' -f2-
)"
[ -n "$LATEST23" ] && [ -d "$LATEST23" ] || {
  echo "BLOCKER: Stage23 evidence not found"
  exit 22
}

CANDIDATE_PARSER="$LATEST23/candidate/json_document.py"
[ -f "$CANDIDATE_PARSER" ] || {
  echo "BLOCKER: Stage23 candidate parser missing: $CANDIDATE_PARSER"
  exit 23
}

JSON_SOURCE="$(
  sed -n 's/^JSON_SOURCE=//p' "$LATEST23/00_PRE_STATE.txt" | head -1
)"
if [ -z "$JSON_SOURCE" ]; then
  JSON_SOURCE="$(
    grep -Rhs '^JSON_SOURCE=' "$LATEST23" 2>/dev/null \
    | head -1 | sed 's/^JSON_SOURCE=//'
  )"
fi

[ -n "$JSON_SOURCE" ] && [ -f "$JSON_SOURCE" ] || {
  echo "BLOCKER: Stage23 JSON source not recoverable"
  exit 24
}

case "${JSON_SOURCE,,}" in
  *.json) ;;
  *)
    echo "BLOCKER: source is not JSON: $JSON_SOURCE"
    exit 25
    ;;
esac

echo "STAGE23=$LATEST23"
echo "CANDIDATE_PARSER=$CANDIDATE_PARSER"
echo "JSON_SOURCE=$JSON_SOURCE"

sha256sum "$JSON_SOURCE" "$CANDIDATE_PARSER" > "$OUT/00_HASHES.sha256"

# -------------------------------------------------------------------
# 1. Preserve the exact active serialization path.
# -------------------------------------------------------------------
for f in \
  parser.py pipeline.py output.py manifest.py validation.py \
  assets.py references.py receipt.py provenance.py state.py \
  batch.py registry.py
do
  if [ -f "$SERVICE/$f" ]; then
    cp -a "$SERVICE/$f" "$OUT/$f"
  fi
done

{
  for f in \
    parser.py pipeline.py output.py manifest.py validation.py \
    assets.py references.py receipt.py provenance.py state.py \
    batch.py registry.py
  do
    if [ -f "$SERVICE/$f" ]; then
      echo
      echo "===== $f ====="
      sed -n '1,520p' "$SERVICE/$f"
    fi
  done
} > "$OUT/01_ACTIVE_SERIALIZATION_SOURCE.txt"

# -------------------------------------------------------------------
# 2. Exact line-level clues for the observed mutation:
#    raw parser candidate has {kind, document};
#    serialized output has {kind, turns, commands}.
# -------------------------------------------------------------------
{
  echo "=== ACTIVE SERIALIZATION CLUES ==="
  grep -RInE \
    'commands|turns|document|parsed|kind|write_text|json\.dump|json\.dumps|asdict|dataclass|normalize|canonical|structure/parsed|parsed\.json' \
    "$SERVICE" \
    --include='*.py' \
    2>/dev/null | head -5000 || true
} > "$OUT/02_SERIALIZATION_CLUES.txt"

# -------------------------------------------------------------------
# 3. Directly execute only the candidate parser from Stage23.
#    This proves what the parser itself returns, with no repository mutation.
# -------------------------------------------------------------------
export PAN24_PARSER="$CANDIDATE_PARSER"
export PAN24_SOURCE="$JSON_SOURCE"

"$PYTHON" - <<'PY' > "$OUT/03_DIRECT_PARSER_RESULT.txt"
import importlib.util, json, os
from pathlib import Path

parser_path = Path(os.environ["PAN24_PARSER"])
source = Path(os.environ["PAN24_SOURCE"])

spec = importlib.util.spec_from_file_location("pan_stage24_json_parser", parser_path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

parsed = mod.parse_json(source)

print("TYPE=" + type(parsed).__name__)
print("KEYS=" + repr(sorted(parsed.keys()) if isinstance(parsed, dict) else None))
print("KIND=" + repr(parsed.get("kind") if isinstance(parsed, dict) else None))
print("HAS_DOCUMENT=" + repr(isinstance(parsed, dict) and "document" in parsed))

if isinstance(parsed, dict) and "document" in parsed:
    doc = parsed["document"]
    print("DOCUMENT_TYPE=" + type(doc).__name__)
    if isinstance(doc, dict):
        print("DOCUMENT_KEYS=" + repr(sorted(doc.keys())[:100]))
    elif isinstance(doc, list):
        print("DOCUMENT_LENGTH=" + str(len(doc)))

print("RAW_RESULT=")
print(json.dumps(parsed, indent=2, ensure_ascii=False)[:12000])
PY

# -------------------------------------------------------------------
# 4. Runtime-only monkeypatch:
#    add .json parser to registry in memory; write nothing into repo.
#    Re-run current pipeline in a sandbox and compare raw parser result
#    with structure/parsed.json.
# -------------------------------------------------------------------
RUNTIME="$OUT/sandbox/runtime"
mkdir -p "$RUNTIME/runroot" "$RUNTIME/receipts" "$RUNTIME/output"

export PAN24_CURRENT="$CURRENT"
export PAN24_SERVICE="$SERVICE"
export PAN24_RUNTIME="$RUNTIME"

set +e
(
  cd "$RUNTIME/runroot"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - <<'PY'
import importlib.util
import json
import os
from pathlib import Path

from workspace.operational.ingestion.service import registry
from workspace.operational.ingestion.service import parser as parser_mod
from workspace.operational.ingestion.service.batch import ingest_sources

source = Path(os.environ["PAN24_SOURCE"]).resolve()
runtime = Path(os.environ["PAN24_RUNTIME"]).resolve()
candidate = Path(os.environ["PAN24_PARSER"]).resolve()

spec = importlib.util.spec_from_file_location("pan_stage24_json_parser_runtime", candidate)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

# Runtime only. No source file mutation.
registry.PARSERS[".json"] = mod.parse_json

raw = parser_mod.parse(source)
print("RAW_PARSE_TYPE=" + type(raw).__name__)
print("RAW_PARSE_KEYS=" + repr(sorted(raw.keys()) if isinstance(raw, dict) else None))
print("RAW_PARSE_HAS_DOCUMENT=" + repr(isinstance(raw, dict) and "document" in raw))

outputs = ingest_sources(
    sources=(source,),
    receipt_root=runtime / "receipts",
    output_root=runtime / "output",
    source_class="manual_batch",
)

print("OUTPUT_COUNT=" + str(len(outputs)))
if len(outputs) != 1:
    raise SystemExit("unexpected output count")

out = Path(outputs[0]).resolve()
serialized_path = out / "structure/parsed.json"
manifest_path = out / "reports/manifest.json"
validation_path = out / "reports/validation.json"

serialized = json.loads(serialized_path.read_text(encoding="utf-8"))
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
validation = json.loads(validation_path.read_text(encoding="utf-8"))

print("OUTPUT=" + str(out))
print("SERIALIZED_KEYS=" + repr(sorted(serialized.keys()) if isinstance(serialized, dict) else None))
print("SERIALIZED_KIND=" + repr(serialized.get("kind") if isinstance(serialized, dict) else None))
print("SERIALIZED_HAS_DOCUMENT=" + repr(isinstance(serialized, dict) and "document" in serialized))
print("SERIALIZED_HAS_TURNS=" + repr(isinstance(serialized, dict) and "turns" in serialized))
print("SERIALIZED_HAS_COMMANDS=" + repr(isinstance(serialized, dict) and "commands" in serialized))
print("MANIFEST_KIND=" + repr(manifest.get("kind")))
print("VALIDATION=" + repr(validation))
print("SERIALIZED_RESULT=")
print(json.dumps(serialized, indent=2, ensure_ascii=False)[:12000])
PY
) > "$OUT/04_RUNTIME_TRACE.txt" 2> "$OUT/04_RUNTIME_TRACE.stderr.txt"
TRACE_RC=$?
set -e

# -------------------------------------------------------------------
# 5. Static AST call graph around parse -> output.
# -------------------------------------------------------------------
"$PYTHON" - "$SERVICE" > "$OUT/05_AST_CALL_GRAPH.txt" <<'PY'
import ast, sys
from pathlib import Path

root = Path(sys.argv[1])

targets = {
    "parser.py", "pipeline.py", "output.py", "manifest.py",
    "validation.py", "batch.py"
}

for p in sorted(root.glob("*.py")):
    if p.name not in targets:
        continue

    text = p.read_text(encoding="utf-8", errors="replace")
    try:
        tree = ast.parse(text, filename=str(p))
    except Exception as e:
        print(f"===== {p.name} PARSE_ERROR {e!r} =====")
        continue

    print(f"===== {p.name} =====")
    for node in tree.body:
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        args = [a.arg for a in node.args.args]
        print(f"FUNCTION {node.name}({', '.join(args)})")
        for child in ast.walk(node):
            if isinstance(child, ast.Call):
                try:
                    call = ast.unparse(child)
                except Exception:
                    continue
                low = call.lower()
                if any(k in low for k in (
                    "parse", "output", "manifest", "validation",
                    "write", "json", "asset", "reference"
                )):
                    print("  CALL " + call[:500])
        print()
PY

# -------------------------------------------------------------------
# 6. Deterministic classification.
# -------------------------------------------------------------------
DIRECT_HAS_DOC="$(
  sed -n 's/^HAS_DOCUMENT=//p' "$OUT/03_DIRECT_PARSER_RESULT.txt" | head -1
)"
RAW_HAS_DOC="$(
  sed -n 's/^RAW_PARSE_HAS_DOCUMENT=//p' "$OUT/04_RUNTIME_TRACE.txt" | head -1
)"
SER_HAS_DOC="$(
  sed -n 's/^SERIALIZED_HAS_DOCUMENT=//p' "$OUT/04_RUNTIME_TRACE.txt" | head -1
)"
SER_HAS_TURNS="$(
  sed -n 's/^SERIALIZED_HAS_TURNS=//p' "$OUT/04_RUNTIME_TRACE.txt" | head -1
)"
SER_HAS_COMMANDS="$(
  sed -n 's/^SERIALIZED_HAS_COMMANDS=//p' "$OUT/04_RUNTIME_TRACE.txt" | head -1
)"

if [ "$TRACE_RC" -eq 0 ] \
   && [ "$DIRECT_HAS_DOC" = "True" ] \
   && [ "$RAW_HAS_DOC" = "True" ] \
   && [ "$SER_HAS_DOC" = "False" ] \
   && [ "$SER_HAS_TURNS" = "True" ] \
   && [ "$SER_HAS_COMMANDS" = "True" ]
then
  DECISION="JSON_PAYLOAD_LOST_BETWEEN_PARSE_AND_SERIALIZED_OUTPUT"
  NEXT="PATCH_ONLY_SERIALIZATION_NORMALIZATION_EDGE_TO_PRESERVE_JSON_DOCUMENT_THEN_REPLAY_STAGE23_GATES"
elif [ "$DIRECT_HAS_DOC" != "True" ]; then
  DECISION="CANDIDATE_JSON_PARSER_DOES_NOT_RETURN_DOCUMENT"
  NEXT="REPAIR_PARSER_CANDIDATE_ONLY"
elif [ "$RAW_HAS_DOC" != "True" ]; then
  DECISION="PARSER_DISPATCH_TRANSFORMS_JSON_BEFORE_PIPELINE"
  NEXT="TRACE_PARSER_DISPATCH_ONLY"
elif [ "$SER_HAS_DOC" = "True" ]; then
  DECISION="JSON_DOCUMENT_PRESERVED_SERIALIZATION_ACCEPTANCE_MISMATCH_ONLY"
  NEXT="REPAIR_STAGE23_ACCEPTANCE_ASSERTION_ONLY"
else
  DECISION="JSON_SERIALIZATION_EDGE_UNRESOLVED"
  NEXT="INSPECT_RUNTIME_TRACE_AND_AST_CALL_GRAPH_NO_MUTATION"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_JSON_SERIALIZATION_TRACE_STAGE24
UTC=$TS
TRACE_EXIT_CODE=$TRACE_RC
DIRECT_PARSER_HAS_DOCUMENT=$DIRECT_HAS_DOC
PIPELINE_RAW_PARSE_HAS_DOCUMENT=$RAW_HAS_DOC
SERIALIZED_HAS_DOCUMENT=$SER_HAS_DOC
SERIALIZED_HAS_TURNS=$SER_HAS_TURNS
SERIALIZED_HAS_COMMANDS=$SER_HAS_COMMANDS
DECISION=$DECISION
SOURCE_MUTATION=NONE
LIVE_REPOSITORY_OUTPUT_MODIFIED=NO
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- direct parser result ---"
head -80 "$OUT/03_DIRECT_PARSER_RESULT.txt"
echo
echo "--- runtime trace ---"
cat "$OUT/04_RUNTIME_TRACE.txt" 2>/dev/null || true
if [ "$TRACE_RC" -ne 0 ]; then
  echo
  echo "--- runtime stderr tail ---"
  tail -80 "$OUT/04_RUNTIME_TRACE.stderr.txt" 2>/dev/null || true
fi
echo
echo "STAGE24_COMPLETE=YES"
