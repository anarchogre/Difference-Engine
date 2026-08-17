#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_HISTORICAL_GENERIC_VALIDATOR_$TS-STAGE19"

ACTIVE="$CURRENT/workspace/operational/ingestion/service/validation.py"

mkdir -p "$OUT/candidates"

echo "=== PAN — HISTORICAL GENERIC VALIDATOR RECOVERY STAGE 19 ==="
echo "CURRENT=$CURRENT"
echo "ACTIVE=$ACTIVE"
echo "EVIDENCE=$OUT"
echo

[ -d "$CURRENT" ] || { echo "BLOCKER: missing $CURRENT"; exit 20; }
[ -f "$ACTIVE" ] || { echo "BLOCKER: missing $ACTIVE"; exit 21; }
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 22; }

LATEST18="$(
  find "$TREE_HOME" -maxdepth 1 -type d \
    -name 'PAN_GENERIC_VALIDATION_RECOVERY_*-STAGE18' \
    -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | head -1 | cut -d' ' -f2-
)"
[ -n "$LATEST18" ] && [ -d "$LATEST18" ] || {
  echo "BLOCKER: Stage 18 evidence not found"
  exit 23
}

CORR="$LATEST18/08_HISTORICAL_VALIDATION_CORRELATION.tsv"
[ -f "$CORR" ] || { echo "BLOCKER: missing $CORR"; exit 24; }

sha256sum "$ACTIVE" > "$OUT/00_ACTIVE_VALIDATOR.sha256"
cp -a "$ACTIVE" "$OUT/active_validation.py"

# 1. Prove the historical behavior we are trying to recover.
"$PYTHON" - "$CORR" > "$OUT/01_HISTORICAL_TARGET.txt" <<'PY'
from pathlib import Path
from collections import Counter
import sys

p = Path(sys.argv[1])
rows = []
for i, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines()):
    if i == 0 or not line.strip():
        continue
    parts = line.split("\t", 4)
    if len(parts) == 5:
        rows.append(parts)

target = [r for r in rows if r[1] == "manual_batch" and r[2] == "True"]
counts = Counter(r[3] for r in target)

print(f"MANUAL_BATCH_PASS_TOTAL={len(target)}")
for kind, n in sorted(counts.items()):
    print(f"MANUAL_BATCH_PASS_KIND={kind} COUNT={n}")

if not target:
    raise SystemExit("BLOCKER: no historical manual_batch PASS evidence")
PY

# 2. Find every validation.py in current + recovery/history surfaces.
find "$CURRENT" -type f -name 'validation.py' -print 2>/dev/null | sort \
  > "$OUT/02_VALIDATION_CANDIDATES.txt"

# Hash them and copy unique variants into evidence.
"$PYTHON" - "$OUT/02_VALIDATION_CANDIDATES.txt" "$OUT/candidates" \
  > "$OUT/03_VARIANTS.tsv" <<'PY'
from pathlib import Path
import hashlib, shutil, sys

listing = Path(sys.argv[1])
dest = Path(sys.argv[2])

seen = {}
print("sha256\tbytes\tpath\tcopy")

for line in listing.read_text(encoding="utf-8", errors="replace").splitlines():
    p = Path(line.strip())
    if not p.is_file():
        continue
    data = p.read_bytes()
    h = hashlib.sha256(data).hexdigest()
    copy = ""
    if h not in seen:
        copy = f"validation-{h[:16]}.py"
        shutil.copy2(p, dest / copy)
        seen[h] = str(p)
    print(f"{h}\t{len(data)}\t{p}\t{copy}")
PY

# 3. Classify each unique validator by explicit rules.
"$PYTHON" - "$OUT/candidates" > "$OUT/04_VARIANT_CLASSIFICATION.tsv" <<'PY'
from pathlib import Path
import ast, hashlib, re, sys

root = Path(sys.argv[1])

print("sha256\tfile\tconversation_hardcoded\tsource_class_aware\tmarkdown_aware\tjson_aware\tfunctions")

for p in sorted(root.glob("validation-*.py")):
    text = p.read_text(encoding="utf-8", errors="replace")
    h = hashlib.sha256(p.read_bytes()).hexdigest()
    low = text.lower()
    try:
        tree = ast.parse(text, filename=str(p))
        funcs = sorted({
            n.name for n in ast.walk(tree)
            if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))
        })
    except Exception:
        funcs = []

    conversation_hardcoded = any(x in low for x in (
        "invalid conversation kind",
        "no conversation turns",
        'kind") != "conversation"',
        "kind'] != 'conversation'",
    ))
    source_class_aware = "source_class" in low
    markdown_aware = "markdown" in low or '".md"' in low or "'.md'" in low
    json_aware = '".json"' in low or "'.json'" in low or "kind == \"json\"" in low or "kind == 'json'" in low

    print(
        f"{h}\t{p.name}\t"
        f"{conversation_hardcoded}\t{source_class_aware}\t"
        f"{markdown_aware}\t{json_aware}\t{','.join(funcs)}"
    )
PY

# 4. Extract exact validation logic from every unique variant.
{
  for f in "$OUT"/candidates/validation-*.py; do
    [ -f "$f" ] || continue
    echo
    echo "===== $(basename "$f") ====="
    sed -n '1,420p' "$f"
  done
} > "$OUT/05_ALL_VARIANT_SOURCE.txt"

# 5. Search nearby retired package files for tests/contracts tied to generic/manual_batch validation.
{
  echo "=== GENERIC / MANUAL_BATCH VALIDATION REFERENCES ==="
  grep -RInE \
    'manual_batch|source_class|kind.*markdown|markdown.*kind|validate|validation|no conversation turns|invalid conversation kind' \
    "$CURRENT/workspace/operational/ingestion/recovery" \
    "$CURRENT/workspace/operational/ingestion/service/tests" \
    --include='*.py' --include='*.md' --include='*.txt' --include='*.json' \
    2>/dev/null | head -6000 || true
} > "$OUT/06_GENERIC_VALIDATION_REFERENCES.txt"

# 6. Compare every unique variant to active.
ACTIVE_HASH="$(sha256sum "$ACTIVE" | awk '{print $1}')"
{
  echo "ACTIVE_HASH=$ACTIVE_HASH"
  for f in "$OUT"/candidates/validation-*.py; do
    [ -f "$f" ] || continue
    H="$(sha256sum "$f" | awk '{print $1}')"
    echo
    echo "===== VARIANT $H ====="
    if [ "$H" = "$ACTIVE_HASH" ]; then
      echo "IDENTITY=ACTIVE"
    else
      echo "IDENTITY=HISTORICAL_DIFFERENT"
      diff -u "$ACTIVE" "$f" || true
    fi
  done
} > "$OUT/07_DIFFS_FROM_ACTIVE.txt"

# 7. Evidence-based decision.
DECISION="$(
"$PYTHON" - \
  "$OUT/04_VARIANT_CLASSIFICATION.tsv" \
  "$OUT/06_GENERIC_VALIDATION_REFERENCES.txt" <<'PY'
from pathlib import Path
import sys

classif = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace").splitlines()
refs = Path(sys.argv[2]).read_text(encoding="utf-8", errors="replace").lower()

rows = []
for line in classif[1:]:
    if not line.strip():
        continue
    parts = line.split("\t")
    if len(parts) < 7:
        continue
    rows.append({
        "hash": parts[0],
        "file": parts[1],
        "conversation": parts[2] == "True",
        "source_class": parts[3] == "True",
        "markdown": parts[4] == "True",
        "json": parts[5] == "True",
    })

historical_generic = [
    r for r in rows
    if (r["source_class"] or r["markdown"]) and not r["conversation"]
]

if historical_generic:
    print("RECOVERABLE_GENERIC_VALIDATOR_VARIANT_EXISTS")
elif "manual_batch" in refs and "validation" in refs:
    print("GENERIC_VALIDATION_CONTRACT_REFERENCES_EXIST_BUT_CODE_VARIANT_NOT_IDENTIFIED")
else:
    print("NO_GENERIC_VALIDATOR_VARIANT_RECOVERED")
PY
)"

case "$DECISION" in
  RECOVERABLE_GENERIC_VALIDATOR_VARIANT_EXISTS)
    NEXT="SELECT_EXACT_HISTORICAL_GENERIC_VALIDATOR_AND_PROVE_AGAINST_MANUAL_BATCH_MARKDOWN_BEFORE_JSON"
    ;;
  GENERIC_VALIDATION_CONTRACT_REFERENCES_EXIST_BUT_CODE_VARIANT_NOT_IDENTIFIED)
    NEXT="RECOVER_GENERIC_VALIDATION_CONTRACT_FROM_REFERENCES_AND_TESTS_BEFORE_IMPLEMENTATION"
    ;;
  *)
    NEXT="IMPLEMENT_MINIMAL_SOURCE_CLASS_AWARE_GENERIC_VALIDATION_FROM_HISTORICAL_OUTPUT_INVARIANTS_WITH_ROLLBACK"
    ;;
esac

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_HISTORICAL_GENERIC_VALIDATOR_STAGE19
UTC=$TS
DECISION=$DECISION
SOURCE_MUTATION=NONE
INGESTION_EXECUTED=NO
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- historical target ---"
cat "$OUT/01_HISTORICAL_TARGET.txt"
echo
echo "--- validator variants ---"
cat "$OUT/04_VARIANT_CLASSIFICATION.tsv"
echo
echo "STAGE19_COMPLETE=YES"
