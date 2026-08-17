#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_GENERIC_VALIDATION_RECOVERY_$TS-STAGE18"

SERVICE="$CURRENT/workspace/operational/ingestion/service"
VALIDATION="$SERVICE/validation.py"
PIPELINE="$SERVICE/pipeline.py"
MANIFEST="$SERVICE/manifest.py"
ASSETS="$SERVICE/assets.py"
OUTPUTMOD="$SERVICE/output.py"

mkdir -p "$OUT"

echo "=== PAN — GENERIC VALIDATION RECOVERY STAGE 18 ==="
echo "CURRENT=$CURRENT"
echo "SERVICE=$SERVICE"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$SERVICE" "$VALIDATION" "$PIPELINE" "$MANIFEST" "$ASSETS" "$OUTPUTMOD"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST17="$(
  find "$TREE_HOME" -maxdepth 1 -type d \
    -name 'PAN_JSON_PARSER_IMPLEMENT_*-STAGE17' \
    -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | head -1 | cut -d' ' -f2-
)"

[ -n "$LATEST17" ] && [ -d "$LATEST17" ] || {
  echo "BLOCKER: no Stage 17 evidence directory found"
  exit 22
}

# -------------------------------------------------------------------
# 1. Preserve exact current validation/pipeline implementation.
# -------------------------------------------------------------------
sha256sum \
  "$VALIDATION" "$PIPELINE" "$MANIFEST" "$ASSETS" "$OUTPUTMOD" \
  > "$OUT/00_ACTIVE_HASHES.sha256"

for f in validation.py pipeline.py manifest.py assets.py output.py parser.py registry.py receipt.py provenance.py; do
  [ -f "$SERVICE/$f" ] && cp -a "$SERVICE/$f" "$OUT/$f"
done

{
  echo "===== validation.py ====="
  sed -n '1,420p' "$VALIDATION"
  echo
  echo "===== pipeline.py ====="
  sed -n '1,520p' "$PIPELINE"
  echo
  echo "===== manifest.py ====="
  sed -n '1,420p' "$MANIFEST"
  echo
  echo "===== assets.py ====="
  sed -n '1,420p' "$ASSETS"
} > "$OUT/01_ACTIVE_SOURCE_CONTEXT.txt"

# -------------------------------------------------------------------
# 2. Exact Stage 17 downstream evidence.
# -------------------------------------------------------------------
{
  echo "=== STAGE17 FILES ==="
  find "$LATEST17" -type f -printf '%p\n' | sort
  echo
  echo "=== STAGE17 EXACT RETEST STDOUT ==="
  cat "$LATEST17/08_EXACT_STAGE13_RETEST.txt" 2>/dev/null || true
  echo
  echo "=== STAGE17 EXACT RETEST STDERR ==="
  cat "$LATEST17/08_EXACT_STAGE13_RETEST.stderr.txt" 2>/dev/null || true
} > "$OUT/02_STAGE17_EDGE.txt"

# Copy exact sandbox validation artifacts if they survived rollback.
find "$LATEST17/sandbox" -type f \
  \( -name 'validation.json' -o -name 'manifest.json' -o -name 'parsed.json' -o -name 'receipt.json' -o -name 'assets.json' \) \
  -print 2>/dev/null | sort > "$OUT/03_STAGE17_ARTIFACT_PATHS.txt"

# -------------------------------------------------------------------
# 3. Static function signatures + hard-coded validation rules.
# -------------------------------------------------------------------
"$PYTHON" - "$VALIDATION" "$PIPELINE" "$MANIFEST" "$ASSETS" \
  > "$OUT/04_STATIC_CONTRACT.json" <<'PY'
import ast, json, sys
from pathlib import Path

def inspect(path):
    p = Path(path)
    text = p.read_text(encoding="utf-8", errors="replace")
    tree = ast.parse(text, filename=str(p))
    out = {
        "path": str(p),
        "functions": {},
        "classes": [],
        "string_literals": [],
        "comparisons": [],
        "calls": [],
    }

    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            args = [a.arg for a in node.args.args]
            out["functions"][node.name] = args
        elif isinstance(node, ast.ClassDef):
            out["classes"].append(node.name)
        elif isinstance(node, ast.Constant) and isinstance(node.value, str):
            s = node.value
            if any(k in s.lower() for k in (
                "conversation", "turn", "asset", "kind", "source_class",
                "invalid", "validation", "manual", "artifact"
            )):
                out["string_literals"].append(s)
        elif isinstance(node, ast.Compare):
            try:
                out["comparisons"].append(ast.unparse(node))
            except Exception:
                pass
        elif isinstance(node, ast.Call):
            try:
                c = ast.unparse(node)
            except Exception:
                continue
            if any(k in c.lower() for k in (
                "validate", "manifest", "assets", "source_class",
                "conversation", "receipt"
            )):
                out["calls"].append(c)

    out["classes"] = sorted(set(out["classes"]))
    out["string_literals"] = sorted(set(out["string_literals"]))
    out["comparisons"] = out["comparisons"][:500]
    out["calls"] = out["calls"][:500]
    return out

print(json.dumps([inspect(x) for x in sys.argv[1:]], indent=2))
PY

# -------------------------------------------------------------------
# 4. Active line-level validation routing evidence.
# -------------------------------------------------------------------
{
  echo "=== ACTIVE VALIDATION / ROUTING REFERENCES ==="
  grep -RInE \
    'invalid conversation kind|no conversation turns|no assets|source_class|manual_batch|manual|conversation|validate|validation|kind|assets|turns' \
    "$SERVICE" \
    --include='*.py' \
    2>/dev/null | head -5000 || true
} > "$OUT/05_ACTIVE_VALIDATION_REFERENCES.txt"

# -------------------------------------------------------------------
# 5. Active tests and historical/retired validator lineage.
# -------------------------------------------------------------------
{
  echo "=== ACTIVE TEST REFERENCES ==="
  grep -RInE \
    'validation|passed|invalid conversation kind|no conversation turns|no assets|manual_batch|source_class|kind' \
    "$SERVICE/tests" \
    --include='*.py' \
    2>/dev/null | head -4000 || true
} > "$OUT/06_ACTIVE_TEST_REFERENCES.txt"

{
  echo "=== SAME-NAMED VALIDATION COPIES ==="
  find "$CURRENT" -type f -name 'validation.py' -print0 2>/dev/null \
    | sort -z | xargs -0 -r sha256sum
  echo
  echo "=== RETIRED/HISTORICAL GENERIC VALIDATION CLUES ==="
  grep -RInE \
    'invalid conversation kind|no conversation turns|no assets|manual_batch|source_class|artifact.*valid|generic.*valid|validate.*artifact|validation.*kind' \
    "$CURRENT/workspace/operational/ingestion/recovery" \
    --include='*.py' --include='*.md' --include='*.txt' --include='*.json' \
    2>/dev/null | head -6000 || true
} > "$OUT/07_HISTORICAL_VALIDATION_LINEAGE.txt"

# -------------------------------------------------------------------
# 6. Correlate historical receipts with validation results.
#    This determines whether manual/manual_batch ever passed and under what kind.
# -------------------------------------------------------------------
"$PYTHON" - "$CURRENT/workspace/operational/ingestion" \
  > "$OUT/08_HISTORICAL_VALIDATION_CORRELATION.tsv" <<'PY'
import json, sys
from pathlib import Path

root = Path(sys.argv[1])

print("package\tsource_class\tvalidation_passed\tkind\terrors")

for receipt in sorted(root.rglob("metadata/receipt.json")):
    if "/recovery/retired_packages/" in str(receipt):
        continue
    pkg = receipt.parent.parent
    validation = pkg / "reports/validation.json"
    manifest = pkg / "reports/manifest.json"
    if not validation.is_file():
        continue

    try:
        r = json.loads(receipt.read_text(encoding="utf-8"))
        v = json.loads(validation.read_text(encoding="utf-8"))
    except Exception:
        continue

    m = {}
    if manifest.is_file():
        try:
            m = json.loads(manifest.read_text(encoding="utf-8"))
        except Exception:
            pass

    source_class = r.get("source_class")
    passed = v.get("passed")
    kind = m.get("kind")
    errors = v.get("errors")
    print(
        f"{pkg}\t{source_class}\t{passed}\t{kind}\t"
        + json.dumps(errors, ensure_ascii=False)
    )
PY

"$PYTHON" - "$OUT/08_HISTORICAL_VALIDATION_CORRELATION.tsv" \
  > "$OUT/09_CORRELATION_SUMMARY.txt" <<'PY'
from collections import Counter, defaultdict
from pathlib import Path
import sys

p = Path(sys.argv[1])
rows = []
for i, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines()):
    if i == 0 or not line.strip():
        continue
    parts = line.split("\t", 4)
    if len(parts) != 5:
        continue
    rows.append(parts)

counts = Counter((r[1], r[2], r[3]) for r in rows)

print("SOURCE_CLASS_VALIDATION_KIND_COUNTS=")
for (source_class, passed, kind), n in sorted(
    counts.items(),
    key=lambda kv: (-kv[1], kv[0])
):
    print(f"{source_class}\tpassed={passed}\tkind={kind}\tcount={n}")

print()
for cls in ("manual_batch", "manual", "file_library_upload", "conversation"):
    matching = [r for r in rows if r[1] == cls]
    passed = [r for r in matching if r[2] == "True"]
    print(f"{cls}: total={len(matching)} pass={len(passed)}")
    for r in passed[:10]:
        print("  " + "\t".join(r))
PY

# -------------------------------------------------------------------
# 7. Deterministic decision: do we have a generic validator contract already?
# -------------------------------------------------------------------
DECISION="$(
  "$PYTHON" - \
    "$OUT/04_STATIC_CONTRACT.json" \
    "$OUT/07_HISTORICAL_VALIDATION_LINEAGE.txt" \
    "$OUT/09_CORRELATION_SUMMARY.txt" <<'PY'
import json, re, sys
from pathlib import Path

static = json.load(open(sys.argv[1], encoding="utf-8"))
hist = Path(sys.argv[2]).read_text(encoding="utf-8", errors="replace")
corr = Path(sys.argv[3]).read_text(encoding="utf-8", errors="replace")

validation = next(
    (x for x in static if x["path"].endswith("/validation.py")),
    {}
)

strings = " ".join(validation.get("string_literals", [])).lower()
comparisons = " ".join(validation.get("comparisons", [])).lower()
calls = " ".join(validation.get("calls", [])).lower()
active_blob = strings + "\n" + comparisons + "\n" + calls

conversation_hardcoded = (
    "invalid conversation kind" in active_blob
    or "no conversation turns" in active_blob
)
source_class_aware = "source_class" in active_blob

hist_generic = bool(re.search(
    r"(generic|artifact|manual_batch|source_class).{0,180}(valid|validation)",
    hist,
    re.I | re.S
))

manual_batch_pass = bool(re.search(
    r"manual_batch: total=\d+ pass=[1-9]\d*",
    corr
))

print(f"ACTIVE_CONVERSATION_HARDCODED={conversation_hardcoded}", file=sys.stderr)
print(f"ACTIVE_SOURCE_CLASS_AWARE={source_class_aware}", file=sys.stderr)
print(f"HISTORICAL_GENERIC_VALIDATION_CLUE={hist_generic}", file=sys.stderr)
print(f"HISTORICAL_MANUAL_BATCH_PASS={manual_batch_pass}", file=sys.stderr)

if conversation_hardcoded and not source_class_aware and manual_batch_pass:
    print("HISTORICAL_MANUAL_BATCH_PASS_WITH_CONVERSATION_VALIDATOR")
elif conversation_hardcoded and not source_class_aware and hist_generic:
    print("ACTIVE_VALIDATOR_CONVERSATION_ONLY_GENERIC_LINEAGE_EXISTS")
elif conversation_hardcoded and not source_class_aware:
    print("ACTIVE_VALIDATOR_CONVERSATION_ONLY_NO_GENERIC_BRANCH")
elif source_class_aware:
    print("ACTIVE_VALIDATOR_HAS_SOURCE_CLASS_BRANCH_INSPECT_ROUTING")
else:
    print("VALIDATION_CONTRACT_UNRESOLVED")
PY
  2> "$OUT/10_DECISION_EVIDENCE.txt"
)"

case "$DECISION" in
  HISTORICAL_MANUAL_BATCH_PASS_WITH_CONVERSATION_VALIDATOR)
    NEXT="INSPECT_HISTORICAL_MANUAL_BATCH_PASSED_KIND_AND_REUSE_PROVEN_CONTRACT"
    ;;
  ACTIVE_VALIDATOR_CONVERSATION_ONLY_GENERIC_LINEAGE_EXISTS)
    NEXT="RECOVER_GENERIC_VALIDATOR_FROM_HISTORICAL_LINEAGE_AND_COMPARE_TO_ACTIVE_CONTRACT"
    ;;
  ACTIVE_VALIDATOR_CONVERSATION_ONLY_NO_GENERIC_BRANCH)
    NEXT="DEFINE_MINIMAL_GENERIC_ARTIFACT_VALIDATION_FROM_EXISTING_OUTPUT_INVARIANTS_AND_ADD_REGRESSION_TEST"
    ;;
  ACTIVE_VALIDATOR_HAS_SOURCE_CLASS_BRANCH_INSPECT_ROUTING)
    NEXT="TRACE_SOURCE_CLASS_ROUTING_AND_REPAIR_ONLY_MANUAL_BATCH_BRANCH"
    ;;
  *)
    NEXT="INSPECT_VALIDATION_CONTRACT_BEFORE_ANY_IMPLEMENTATION"
    ;;
esac

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_GENERIC_VALIDATION_RECOVERY_STAGE18
UTC=$TS
DECISION=$DECISION
INGESTION_EXECUTED=NO
SOURCE_MUTATION=NONE
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- decision evidence ---"
cat "$OUT/10_DECISION_EVIDENCE.txt"
echo
echo "--- historical validation correlation summary ---"
cat "$OUT/09_CORRELATION_SUMMARY.txt"
echo
echo "STAGE18_COMPLETE=YES"
