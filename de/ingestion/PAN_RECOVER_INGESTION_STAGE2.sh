#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
LEGACY="$HOME/Difference-Engine-LEGACY-STALE-DECOMPOSED"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_INGESTION_RECOVERY_$TS-STAGE2"

mkdir -p "$OUT"

echo "=== PAN — INGESTION RECOVERY STAGE 2 ==="
echo "CURRENT=$CURRENT"
echo "LEGACY=$LEGACY"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$LEGACY"; do
  [ -d "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done

# Recover known test/baseline/golden-corpus evidence from BOTH estates.
{
  echo "=== EXACT TEST / HARNESS CANDIDATES ==="
  find "$CURRENT" "$LEGACY" -xdev -type f \
    \( -name 'run_all.py' \
       -o -iname '*regression*' \
       -o -iname '*golden*corpus*' \
       -o -iname '*golden*' \
       -o -iname '*baseline*' \
       -o -iname '*milestone*002*' \
       -o -iname '*acceptance*' \
       -o -iname '*verification*' \
       -o -iname '*manifest*' \
       -o -iname '*receipt*' \
       -o -iname '*ingestion*test*' \
       -o -iname '*parser*test*' \) \
    -print 2>/dev/null | sort
} > "$OUT/01_TEST_BASELINE_CANDIDATES.txt"

{
  echo "=== MILESTONE 002 / FROZEN / RECOVERY DIRECTORIES ==="
  find "$CURRENT" "$LEGACY" -xdev -type d \
    \( -iname '*MILESTONE*002*' \
       -o -iname '*FROZEN*' \
       -o -iname '*baseline*' \
       -o -iname '*recovery*' \
       -o -iname '*retired*package*' \
       -o -iname '*parser*test*' \
       -o -iname '*batch*test*' \
       -o -iname '*golden*' \) \
    -print 2>/dev/null | sort
} > "$OUT/02_RECOVERY_DIRECTORIES.txt"

# Recover exact historical module paths if they exist anywhere.
{
  echo "=== HISTORICAL INGESTION MODULES ==="
  for rel in \
    'ade/services/ingestion/pipeline.py' \
    'ade/services/ingestion/batch.py' \
    'ade/services/ingestion/resume.py' \
    'ade/services/ingestion/index.py' \
    'ade/services/ingestion/tests/run_all.py' \
    'workspace/operational/ingestion/discover_conversations.py' \
    'workspace/operational/ingestion/discover_conversation_delta.py'
  do
    echo "### $rel"
    find "$CURRENT" "$LEGACY" -xdev -type f -path "*/$rel" -print 2>/dev/null | sort
    echo
  done
} > "$OUT/03_HISTORICAL_MODULE_PATHS.txt"

# Search textual evidence for the historical test invocation and acceptance markers.
{
  echo "=== HISTORICAL INVOCATION / ACCEPTANCE REFERENCES ==="
  grep -RInE \
    'python -m ade\.services\.ingestion\.tests\.run_all|ALL_PASS|MILESTONE.?002|golden corpus|golden_corpus|regression|acceptance' \
    "$CURRENT" "$LEGACY" \
    2>/dev/null | head -3000 || true
} > "$OUT/04_INVOCATION_REFERENCES.txt"

# Find candidate package/evidence indexes.
{
  echo "=== INDEX / RECEIPT / PROVENANCE SURFACE ==="
  find "$CURRENT" "$LEGACY" -xdev -type f \
    \( -name 'INDEX.json' \
       -o -name 'receipt.json' \
       -o -name 'provenance.json' \
       -o -name 'validation.json' \
       -o -name 'manifest.json' \
       -o -name 'ingestion_report.md' \
       -o -name 'parsed.json' \
       -o -name 'candidates.json' \) \
    -print 2>/dev/null | sort
} > "$OUT/05_OUTPUT_CONTRACT_SURFACE.txt"

# Candidate executable harnesses: do NOT run automatically.
{
  echo "=== EXECUTABLE / PYTHON TEST CANDIDATES ==="
  find "$CURRENT" "$LEGACY" -xdev -type f \
    \( -path '*/tests/*' -o -path '*/parser_tests/*' -o -path '*/batch_test/*' \) \
    \( -name '*.py' -o -name '*.sh' \) \
    -print 2>/dev/null | sort
} > "$OUT/06_TEST_EXECUTABLES.txt"

# Summarize counts and pick safest next action.
RUN_ALL_COUNT="$(grep -c '/run_all.py$' "$OUT/01_TEST_BASELINE_CANDIDATES.txt" 2>/dev/null || true)"
M002_COUNT="$(grep -ci 'milestone.*002\|MILESTONE_002' "$OUT/01_TEST_BASELINE_CANDIDATES.txt" 2>/dev/null || true)"
DIR_COUNT="$(wc -l < "$OUT/02_RECOVERY_DIRECTORIES.txt")"
MODULE_LINES="$(grep -c '^/' "$OUT/03_HISTORICAL_MODULE_PATHS.txt" 2>/dev/null || true)"

if [ "$RUN_ALL_COUNT" -gt 0 ]; then
  NEXT="INSPECT_EXACT_RUN_ALL_AND_PARENT_REPOSITORY_THEN_RUN_RECOVERED_HARNESS"
elif [ "$M002_COUNT" -gt 0 ] || [ "$DIR_COUNT" -gt 0 ]; then
  NEXT="RECOVER_FROZEN_BASELINE_MANIFEST_AND_ACCEPTANCE_RECORD_BEFORE_ANY_NEW_TEST"
else
  NEXT="RECOVER_TEST_CONTRACT_FROM_TEXTUAL_EVIDENCE_AND_RETIRED_PACKAGES"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_INGESTION_RECOVERY_STAGE2
UTC=$TS
RUN_ALL_CANDIDATES=$RUN_ALL_COUNT
MILESTONE_002_FILE_CANDIDATES=$M002_COUNT
RECOVERY_DIRECTORIES=$DIR_COUNT
HISTORICAL_MODULE_PATH_LINES=$MODULE_LINES
EVIDENCE=$OUT
SOURCE_MUTATION=NONE
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- run_all candidates ---"
grep '/run_all.py$' "$OUT/01_TEST_BASELINE_CANDIDATES.txt" 2>/dev/null || true
echo
echo "--- first recovery dirs ---"
head -40 "$OUT/02_RECOVERY_DIRECTORIES.txt" 2>/dev/null || true
echo
echo "STAGE2_COMPLETE=YES"
