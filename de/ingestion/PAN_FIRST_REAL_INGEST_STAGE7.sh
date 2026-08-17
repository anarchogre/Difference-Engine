#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"

LATEST="$(find "$TREE_HOME" -maxdepth 1 -type d -name 'PAN_FIRST_CORPUS_DELTA_*' \
  -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"

[ -n "$LATEST" ] && [ -d "$LATEST" ] || {
  echo "BLOCKER: no PAN_FIRST_CORPUS_DELTA_* directory found"
  exit 20
}

CENSUS_MD="$LATEST/delta/legacy_stale_decomposed/DELTA_CENSUS.md"
CENSUS_JSON="$LATEST/delta/legacy_stale_decomposed/DELTA_CENSUS.json"

[ -f "$CENSUS_MD" ] || { echo "BLOCKER: missing $CENSUS_MD"; exit 21; }
[ -f "$CENSUS_JSON" ] || { echo "BLOCKER: missing $CENSUS_JSON"; exit 22; }
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 23; }

OUT="$TREE_HOME/PAN_FIRST_REAL_INGEST_$TS"
SANDBOX="$OUT/sandbox"
RECEIPTS="$SANDBOX/receipts"
OUTPUT="$SANDBOX/output"
mkdir -p "$OUT" "$RECEIPTS" "$OUTPUT"

echo "=== PAN — FIRST REAL INGEST STAGE 7 ==="
echo "CENSUS=$CENSUS_MD"
echo "EVIDENCE=$OUT"
echo

# Extract strong candidates conservatively from the census markdown.
"$PYTHON" - "$CENSUS_MD" "$OUT/01_STRONG_CANDIDATES.txt" <<'PY'
from pathlib import Path
import re, sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])

supported = {".txt", ".md", ".json"}

candidates = []
for line in src.read_text(encoding="utf-8", errors="replace").splitlines():
    if "**strong**" not in line.lower():
        continue

    # Prefer backticked absolute paths.
    m = re.search(r"`(/[^`]+)`", line)
    if not m:
        # Fallback: absolute path between dash separators.
        m = re.search(r"(/home/[^\s].*?)(?:\s+[—-]\s+|$)", line)

    if not m:
        continue

    path = Path(m.group(1).strip())
    suffix = path.suffix.lower()

    # Some preserved sources use names like *.md.txt; final suffix .txt is okay.
    if suffix not in supported:
        continue
    if not path.is_file():
        continue
    candidates.append(str(path))

# Preserve order, deduplicate exact paths.
seen = set()
ordered = []
for x in candidates:
    if x not in seen:
        seen.add(x)
        ordered.append(x)

dst.write_text("\n".join(ordered) + ("\n" if ordered else ""), encoding="utf-8")
print(f"STRONG_SUPPORTED_CANDIDATES={len(ordered)}")
for x in ordered[:20]:
    print(x)
PY

CANDIDATE="$(head -1 "$OUT/01_STRONG_CANDIDATES.txt" 2>/dev/null || true)"
if [ -z "$CANDIDATE" ]; then
  echo "BLOCKER: no supported strong candidate recovered from census"
  exit 24
fi

echo "SELECTED=$CANDIDATE" | tee "$OUT/02_SELECTED.txt"
sha256sum "$CANDIDATE" > "$OUT/03_SELECTED.sha256"

# Perform ONE real ingestion using the recovered active batch primitive.
# Output is sandboxed under Forge-File-Tree-Directories for qualification.
set +e
(
  cd "$CURRENT"
  PYTHONPATH="$CURRENT${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - "$CANDIDATE" "$RECEIPTS" "$OUTPUT" <<'PY'
from pathlib import Path
import sys

from workspace.operational.ingestion.service.batch import ingest_sources

source = Path(sys.argv[1])
receipt_root = Path(sys.argv[2])
output_root = Path(sys.argv[3])

outputs = ingest_sources(
    sources=[source],
    receipt_root=receipt_root,
    output_root=output_root,
    source_class="conversation",
)

print(f"SOURCE={source}")
print(f"OUTPUT_COUNT={len(outputs)}")
for out in outputs:
    print(f"OUTPUT={out}")
PY
) > "$OUT/04_INGEST_RUN.txt" 2> "$OUT/04_INGEST_RUN.stderr.txt"
RC=$?
set -e

# Inventory emitted sandbox artifacts.
find "$SANDBOX" -type f -printf '%p\n' 2>/dev/null | sort > "$OUT/05_OUTPUT_FILES.txt"

PKG_COUNT="$(find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
RECEIPT_COUNT="$(find "$RECEIPTS" -maxdepth 1 -type f 2>/dev/null | wc -l)"

# Check expected contract surfaces without assuming exact filenames beyond recovered package model.
EXPECTED_FOUND=0
for pat in \
  '*/source/*' \
  '*/metadata/receipt.json' \
  '*/provenance/provenance.json' \
  '*/reports/validation.json' \
  '*/reports/manifest.json'
do
  if find "$OUTPUT" -path "$pat" -type f -print -quit 2>/dev/null | grep -q .; then
    EXPECTED_FOUND=$((EXPECTED_FOUND + 1))
  fi
done

if [ "$RC" -eq 0 ] && [ "$PKG_COUNT" -ge 1 ] && [ "$RECEIPT_COUNT" -ge 1 ]; then
  STATUS="PASS"
  NEXT="BULK_INGEST_STRONG_SUPPORTED_CANDIDATES_WITH_RECOVERED_BATCH_PRIMITIVE"
else
  STATUS="FAIL"
  NEXT="PRESERVE_FAILURE_AND_REPAIR_ONLY_FIRST_REAL_INGEST_EDGE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_FIRST_REAL_INGEST_STAGE7
UTC=$TS
STATUS=$STATUS
EXIT_CODE=$RC
SOURCE=$CANDIDATE
PACKAGE_COUNT=$PKG_COUNT
RECEIPT_COUNT=$RECEIPT_COUNT
EXPECTED_CONTRACT_SURFACES_FOUND=$EXPECTED_FOUND
LIVE_SOURCE_MODIFIED=NO_INTENTIONAL_MUTATION
LIVE_REPOSITORY_OUTPUT_MODIFIED=NO
SANDBOX=$SANDBOX
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- ingest run ---"
cat "$OUT/04_INGEST_RUN.txt" 2>/dev/null || true

if [ "$RC" -ne 0 ]; then
  echo
  echo "--- stderr tail ---"
  tail -80 "$OUT/04_INGEST_RUN.stderr.txt" 2>/dev/null || true
fi

echo
echo "STAGE7_COMPLETE=YES"

exit "$RC"
