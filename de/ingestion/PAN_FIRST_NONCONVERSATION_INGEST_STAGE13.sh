#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"

OUT="$TREE_HOME/PAN_FIRST_NONCONVERSATION_INGEST_$TS-STAGE13"
SANDBOX="$OUT/sandbox"
RECEIPTS="$SANDBOX/receipts"
OUTPUT="$SANDBOX/output"

mkdir -p "$OUT" "$RECEIPTS" "$OUTPUT"

LATEST_STAGE11="$(find "$TREE_HOME" -maxdepth 1 -type d -name 'PAN_GENERIC_INGEST_CONTRACT_*-STAGE11' \
  -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"

LATEST_STAGE12="$(find "$TREE_HOME" -maxdepth 1 -type d -name 'PAN_SOURCE_CLASS_SEMANTICS_*-STAGE12' \
  -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"

for x in "$CURRENT" "$LATEST_STAGE11" "$LATEST_STAGE12"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

SOURCE="$(sed -n 's/^SELECTED_SOURCE=//p' "$LATEST_STAGE11/SUMMARY.txt" | head -1)"
CLASS="$(sed -n 's/^GENERIC_CLASS=//p' "$LATEST_STAGE12/SUMMARY.txt" | head -1)"
DECISION="$(sed -n 's/^GENERIC_CLASS_DECISION=//p' "$LATEST_STAGE12/SUMMARY.txt" | head -1)"

[ -n "$SOURCE" ] && [ -f "$SOURCE" ] || {
  echo "BLOCKER: selected source missing or invalid: $SOURCE"
  exit 22
}

if [ "$DECISION" != "USE_MANUAL_BATCH" ] || [ "$CLASS" != "manual_batch" ]; then
  echo "BLOCKER: Stage 12 did not prove manual_batch"
  echo "DECISION=$DECISION"
  echo "CLASS=$CLASS"
  exit 23
fi

echo "=== PAN — FIRST NON-CONVERSATION INGEST STAGE 13 ==="
echo "SOURCE=$SOURCE"
echo "SOURCE_CLASS=$CLASS"
echo "EVIDENCE=$OUT"
echo

sha256sum "$SOURCE" > "$OUT/00_SOURCE.sha256"

set +e
(
  cd "$CURRENT"
  PYTHONPATH="$CURRENT${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - "$SOURCE" "$RECEIPTS" "$OUTPUT" "$CLASS" <<'PY'
from pathlib import Path
import sys

from workspace.operational.ingestion.service.batch import ingest_sources

source = Path(sys.argv[1])
receipt_root = Path(sys.argv[2])
output_root = Path(sys.argv[3])
source_class = sys.argv[4]

outputs = ingest_sources(
    sources=[source],
    receipt_root=receipt_root,
    output_root=output_root,
    source_class=source_class,
)

print(f"SOURCE={source}")
print(f"SOURCE_CLASS={source_class}")
print(f"OUTPUT_COUNT={len(outputs)}")
for out in outputs:
    print(f"OUTPUT={out}")
PY
) > "$OUT/01_INGEST_RUN.txt" 2> "$OUT/01_INGEST_RUN.stderr.txt"
RC=$?
set -e

find "$SANDBOX" -type f -printf '%p\n' 2>/dev/null | sort > "$OUT/02_OUTPUT_FILES.txt"

PACKAGE_COUNT="$(find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
RECEIPT_COUNT="$(find "$RECEIPTS" -maxdepth 1 -type f 2>/dev/null | wc -l)"

CONTRACT_FOUND=0
for pat in \
  '*/source/*' \
  '*/metadata/receipt.json' \
  '*/provenance/provenance.json' \
  '*/reports/validation.json' \
  '*/reports/manifest.json'
do
  if find "$OUTPUT" -path "$pat" -type f -print -quit 2>/dev/null | grep -q .; then
    CONTRACT_FOUND=$((CONTRACT_FOUND + 1))
  fi
done

if [ "$RC" -eq 0 ] && [ "$PACKAGE_COUNT" -ge 1 ] && [ "$RECEIPT_COUNT" -ge 1 ]; then
  STATUS="PASS"
  NEXT="BULK_INGEST_SAFE_NONCONVERSATION_TEXTLIKE_REMAINDER_WITH_MANUAL_BATCH"
else
  STATUS="FAIL"
  NEXT="PRESERVE_FAILURE_AND_REPAIR_ONLY_FIRST_NONCONVERSATION_INGEST_EDGE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_FIRST_NONCONVERSATION_INGEST_STAGE13
UTC=$TS
STATUS=$STATUS
EXIT_CODE=$RC
SOURCE=$SOURCE
SOURCE_CLASS=$CLASS
PACKAGE_COUNT=$PACKAGE_COUNT
RECEIPT_COUNT=$RECEIPT_COUNT
EXPECTED_CONTRACT_SURFACES_FOUND=$CONTRACT_FOUND
LIVE_SOURCE_MODIFIED=NO_INTENTIONAL_MUTATION
LIVE_REPOSITORY_OUTPUT_MODIFIED=NO
SANDBOX=$SANDBOX
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- ingest run ---"
cat "$OUT/01_INGEST_RUN.txt" 2>/dev/null || true

if [ "$RC" -ne 0 ]; then
  echo
  echo "--- stderr tail ---"
  tail -80 "$OUT/01_INGEST_RUN.stderr.txt" 2>/dev/null || true
fi

echo
echo "STAGE13_COMPLETE=YES"

exit "$RC"
