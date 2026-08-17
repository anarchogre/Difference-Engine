#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_BULK_INGEST_STRONG_$TS"
SANDBOX="$OUT/sandbox"
RECEIPTS="$SANDBOX/receipts"
OUTPUT="$SANDBOX/output"
LOGS="$OUT/logs"

mkdir -p "$OUT" "$RECEIPTS" "$OUTPUT" "$LOGS"

LATEST_STAGE7="$(find "$TREE_HOME" -maxdepth 1 -type d -name 'PAN_FIRST_REAL_INGEST_*' \
  -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"

[ -n "$LATEST_STAGE7" ] && [ -d "$LATEST_STAGE7" ] || {
  echo "BLOCKER: no PAN_FIRST_REAL_INGEST_* evidence found"
  exit 20
}

CANDIDATES="$LATEST_STAGE7/01_STRONG_CANDIDATES.txt"
SELECTED="$LATEST_STAGE7/02_SELECTED.txt"

[ -f "$CANDIDATES" ] || { echo "BLOCKER: missing $CANDIDATES"; exit 21; }
[ -f "$SELECTED" ] || { echo "BLOCKER: missing $SELECTED"; exit 22; }
[ -d "$CURRENT" ] || { echo "BLOCKER: missing $CURRENT"; exit 23; }
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 24; }

ALREADY="$(sed -n 's/^SELECTED=//p' "$SELECTED" | head -1)"
TOTAL="$(grep -c . "$CANDIDATES" || true)"

LEDGER="$OUT/INGEST_LEDGER.tsv"
printf 'index\tstatus\tsha256\toutput_count\tsource\n' > "$LEDGER"

echo "=== PAN — BULK STRONG-CANDIDATE INGEST STAGE 8 ==="
echo "CANDIDATES=$TOTAL"
echo "ALREADY_PROVEN=$ALREADY"
echo "EVIDENCE=$OUT"
echo

PASS=0
SKIP=0
FAIL=0
INDEX=0
FAILED_SOURCE=""

while IFS= read -r SOURCE; do
  [ -n "$SOURCE" ] || continue
  INDEX=$((INDEX + 1))

  if [ "$SOURCE" = "$ALREADY" ]; then
    HASH="$(sha256sum "$SOURCE" | awk '{print $1}')"
    printf '%s\tSKIP_ALREADY_PROVEN\t%s\t0\t%s\n' \
      "$INDEX" "$HASH" "$SOURCE" >> "$LEDGER"
    SKIP=$((SKIP + 1))
    continue
  fi

  if [ ! -f "$SOURCE" ]; then
    printf '%s\tFAIL_MISSING_SOURCE\t-\t0\t%s\n' \
      "$INDEX" "$SOURCE" >> "$LEDGER"
    FAIL=$((FAIL + 1))
    FAILED_SOURCE="$SOURCE"
    break
  fi

  HASH="$(sha256sum "$SOURCE" | awk '{print $1}')"
  RUNLOG="$LOGS/$(printf '%05d' "$INDEX").stdout.txt"
  ERRLOG="$LOGS/$(printf '%05d' "$INDEX").stderr.txt"
  RESULT="$LOGS/$(printf '%05d' "$INDEX").result.txt"

  printf '[%s/%s] %s ... ' "$INDEX" "$TOTAL" "$(basename "$SOURCE")"

  set +e
  (
    cd "$CURRENT"
    PYTHONPATH="$CURRENT${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" - "$SOURCE" "$RECEIPTS" "$OUTPUT" "$RESULT" <<'PY'
from pathlib import Path
import sys

from workspace.operational.ingestion.service.batch import ingest_sources

source = Path(sys.argv[1])
receipt_root = Path(sys.argv[2])
output_root = Path(sys.argv[3])
result_path = Path(sys.argv[4])

outputs = ingest_sources(
    sources=[source],
    receipt_root=receipt_root,
    output_root=output_root,
    source_class="conversation",
)

result_path.write_text(
    "OUTPUT_COUNT=" + str(len(outputs)) + "\n" +
    "".join(f"OUTPUT={x}\n" for x in outputs),
    encoding="utf-8",
)

print(f"SOURCE={source}")
print(f"OUTPUT_COUNT={len(outputs)}")
for out in outputs:
    print(f"OUTPUT={out}")
PY
  ) > "$RUNLOG" 2> "$ERRLOG"
  RC=$?
  set -e

  OUTPUT_COUNT="$(sed -n 's/^OUTPUT_COUNT=//p' "$RESULT" 2>/dev/null | head -1)"
  OUTPUT_COUNT="${OUTPUT_COUNT:-0}"

  if [ "$RC" -eq 0 ] && [ "$OUTPUT_COUNT" -ge 1 ]; then
    printf 'PASS\n'
    printf '%s\tPASS\t%s\t%s\t%s\n' \
      "$INDEX" "$HASH" "$OUTPUT_COUNT" "$SOURCE" >> "$LEDGER"
    PASS=$((PASS + 1))
  else
    printf 'FAIL\n'
    printf '%s\tFAIL_EXIT_%s\t%s\t%s\t%s\n' \
      "$INDEX" "$RC" "$HASH" "$OUTPUT_COUNT" "$SOURCE" >> "$LEDGER"
    FAIL=$((FAIL + 1))
    FAILED_SOURCE="$SOURCE"
    break
  fi
done < "$CANDIDATES"

PACKAGE_COUNT="$(find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
RECEIPT_COUNT="$(find "$RECEIPTS" -maxdepth 1 -type f 2>/dev/null | wc -l)"

if [ "$FAIL" -eq 0 ]; then
  STATUS="PASS"
  NEXT="QUALIFY_REMAINING_PROVISIONAL_AND_NONCONVERSATION_FIRST_CORPUS_ARTIFACTS"
else
  STATUS="FAIL"
  NEXT="PRESERVE_FAILURE_AND_REPAIR_ONLY_FAILED_SOURCE_EDGE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_BULK_INGEST_STRONG_STAGE8
UTC=$TS
STATUS=$STATUS
TOTAL_STRONG_SUPPORTED=$TOTAL
PASS=$PASS
SKIP_ALREADY_PROVEN=$SKIP
FAIL=$FAIL
FAILED_SOURCE=$FAILED_SOURCE
PACKAGE_COUNT=$PACKAGE_COUNT
RECEIPT_COUNT=$RECEIPT_COUNT
LIVE_SOURCE_MODIFIED=NO_INTENTIONAL_MUTATION
LIVE_REPOSITORY_OUTPUT_MODIFIED=NO
SANDBOX=$SANDBOX
LEDGER=$LEDGER
EVIDENCE=$OUT
NEXT=$NEXT
EOF

echo
cat "$OUT/SUMMARY.txt"

if [ "$FAIL" -ne 0 ]; then
  echo
  echo "--- failed source stderr tail ---"
  tail -60 "$LOGS/$(printf '%05d' "$INDEX").stderr.txt" 2>/dev/null || true
fi

echo
echo "STAGE8_COMPLETE=YES"

[ "$FAIL" -eq 0 ]
