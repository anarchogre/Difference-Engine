#!/usr/bin/env bash
set -Eeuo pipefail

PAN_NAME="Pan"
CURRENT="$HOME/Difference-Engine"
FIRST_CORPUS="$HOME/Difference-Engine-LEGACY-STALE-DECOMPOSED"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_INGESTION_RECOVERY_$TS"

mkdir -p "$OUT"

echo "=== PAN — INGESTION RECOVERY STAGE 1 ==="
echo "CURRENT=$CURRENT"
echo "FIRST_CORPUS=$FIRST_CORPUS"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$FIRST_CORPUS"; do
  if [ ! -d "$x" ]; then
    echo "BLOCKER: missing directory $x"
    exit 20
  fi
done

# -------------------------------------------------------------------
# 1. Reality census
# -------------------------------------------------------------------
{
  echo "UTC=$TS"
  echo "PAN_NAME=$PAN_NAME"
  echo "CURRENT=$CURRENT"
  echo "FIRST_CORPUS=$FIRST_CORPUS"
  echo "TREE_HOME=$TREE_HOME"
  echo
  echo "=== SYSTEM ==="
  uname -a || true
  echo
  echo "=== MEMORY ==="
  free -h || true
  echo
  echo "=== SWAP ==="
  swapon --show --bytes || true
  echo
  echo "=== STORAGE ==="
  df -hT "$HOME" || true
} > "$OUT/00_SYSTEM.txt" 2>&1

# -------------------------------------------------------------------
# 2. Full metadata-rich trees.
#    Preserve these under the operator-selected Forge-File-Tree-Directories.
# -------------------------------------------------------------------
census_root() {
  local root="$1"
  local tag="$2"

  {
    echo "ROOT=$root"
    du -sh "$root" 2>/dev/null || true
    printf 'FILES='
    find "$root" -xdev -type f -printf . 2>/dev/null | wc -c
    printf 'DIRS='
    find "$root" -xdev -type d -printf . 2>/dev/null | wc -c
    printf 'SYMLINKS='
    find "$root" -xdev -type l -printf . 2>/dev/null | wc -c
  } > "$OUT/${tag}_SUMMARY.txt"

  find "$root" -xdev \
    -printf '%y\t%m\t%u\t%g\t%s\t%TY-%Tm-%TdT%TH:%TM:%TS\t%p\t%l\n' \
    2>/dev/null | sort > "$OUT/${tag}_METADATA_TREE.tsv"

  if command -v tree >/dev/null 2>&1; then
    tree -a -h --du --dirsfirst --noreport "$root" \
      > "$OUT/${tag}_TREE.txt" 2>&1 || true
  fi
}

census_root "$CURRENT" "01_CURRENT_DE"
census_root "$FIRST_CORPUS" "02_FIRST_CORPUS"

# -------------------------------------------------------------------
# 3. Git/repository state
# -------------------------------------------------------------------
{
  echo "=== CURRENT DE GIT ==="
  git -C "$CURRENT" rev-parse --show-toplevel 2>/dev/null || true
  git -C "$CURRENT" branch --show-current 2>/dev/null || true
  git -C "$CURRENT" rev-parse HEAD 2>/dev/null || true
  git -C "$CURRENT" status --short --branch 2>/dev/null || true
  echo
  echo "=== REMOTES ==="
  git -C "$CURRENT" remote -v 2>/dev/null || true
} > "$OUT/03_GIT_STATE.txt" 2>&1

# -------------------------------------------------------------------
# 4. Recover the COMPLETE ingestion surface, not only Milestone 002.
# -------------------------------------------------------------------
{
  echo "=== KNOWN INGESTION / DISCOVERY / FORMATTER / PARSER SURFACE ==="
  find "$CURRENT" -xdev -type f \
    \( -path '*/ade/services/ingestion/*' \
       -o -path '*/workspace/operational/ingestion/*' \
       -o -iname '*discover*conversation*' \
       -o -iname '*formatter*' \
       -o -iname '*parser*' \
       -o -iname '*repository*object*' \
       -o -iname '*provenance*' \
       -o -iname '*receipt*' \
       -o -iname '*schema*' \
       -o -iname '*template*' \
       -o -iname '*manifest*' \
       -o -iname '*invariant*' \) \
    -print 2>/dev/null | sort
} > "$OUT/04_INGESTION_SURFACE_FILES.txt"

{
  echo "=== ENTRYPOINT / CLI CLUES ==="
  grep -RInE \
    'if __name__ ==|argparse|def main|click\.command|typer\.|add_argument|subparsers|--help' \
    "$CURRENT/ade/services/ingestion" \
    "$CURRENT/workspace/operational/ingestion" \
    2>/dev/null | head -1000 || true
} > "$OUT/05_ENTRYPOINT_CLUES.txt"

# Exact named recovery markers.
{
  for name in \
    discover_conversations.py \
    discover_conversation_delta.py \
    pipeline.py \
    batch.py \
    resume.py \
    run_all.py
  do
    echo "### $name"
    find "$CURRENT" -xdev -type f -name "$name" -print 2>/dev/null | sort
    echo
  done
} > "$OUT/06_NAMED_MARKERS.txt"

# -------------------------------------------------------------------
# 5. Existing baseline test harness.
#    Do not invent a new test. Run only the recovered known harness if present.
# -------------------------------------------------------------------
TEST_RC=127
TEST_PATH=""

if [ -f "$CURRENT/ade/services/ingestion/tests/run_all.py" ]; then
  TEST_PATH="$CURRENT/ade/services/ingestion/tests/run_all.py"
  (
    cd "$CURRENT"
    set +e
    PYTHONPATH=. python -m ade.services.ingestion.tests.run_all \
      > "$OUT/07_BASELINE_TEST.txt" 2>&1
    echo $? > "$OUT/07_BASELINE_TEST.rc"
  )
  TEST_RC="$(cat "$OUT/07_BASELINE_TEST.rc")"
else
  TEST_PATH="$(find "$CURRENT" -xdev -type f \
    -path '*/ingestion/tests/run_all.py' -print -quit 2>/dev/null || true)"
  if [ -n "$TEST_PATH" ]; then
    echo "RECOVERED_TEST_PATH=$TEST_PATH" > "$OUT/07_BASELINE_TEST.txt"
    echo "NOT_RUN_NONCANONICAL_PATH" >> "$OUT/07_BASELINE_TEST.txt"
    TEST_RC=126
  else
    echo "NO_EXISTING_RUN_ALL_TEST_FOUND" > "$OUT/07_BASELINE_TEST.txt"
  fi
fi

# -------------------------------------------------------------------
# 6. Search first corpus for legacy ingestion lineage/specs too.
# -------------------------------------------------------------------
{
  echo "=== FIRST CORPUS INGESTION LINEAGE CANDIDATES ==="
  find "$FIRST_CORPUS" -xdev -type f \
    \( -iname '*ingest*' \
       -o -iname '*formatter*' \
       -o -iname '*parser*' \
       -o -iname '*repository*object*' \
       -o -iname '*provenance*' \
       -o -iname '*schema*' \
       -o -iname '*template*' \
       -o -iname '*invariant*' \
       -o -iname '*conversation*' \) \
    -print 2>/dev/null | sort
} > "$OUT/08_FIRST_CORPUS_LINEAGE.txt"

# -------------------------------------------------------------------
# 7. Summary / exact next step
# -------------------------------------------------------------------
case "$TEST_RC" in
  0)
    BASELINE="PASS"
    NEXT="INSPECT_EXISTING_DISCOVERY_AND_BATCH_INTERFACES_THEN_START_FIRST_CORPUS"
    ;;
  126)
    BASELINE="RECOVERED_TEST_NONCANONICAL_PATH_NOT_RUN"
    NEXT="INSPECT_RECOVERED_TEST_PATH_BEFORE_EXECUTION"
    ;;
  127)
    BASELINE="NO_EXISTING_TEST_HARNESS_FOUND"
    NEXT="RECOVER_TEST_OR_GOLDEN_CORPUS_FROM_EVIDENCE_BEFORE_FULL_INGEST"
    ;;
  *)
    BASELINE="FAIL_EXIT_$TEST_RC"
    NEXT="PRESERVE_FAILURE_AND_REPAIR_ONLY_FAILED_EDGE"
    ;;
esac

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_INGESTION_RECOVERY_STAGE1
UTC=$TS
PAN_NAME=Pan
CURRENT=$CURRENT
FIRST_CORPUS=$FIRST_CORPUS
FILE_TREE_HOME=$TREE_HOME
BASELINE_TEST=$BASELINE
TEST_PATH=$TEST_PATH
EVIDENCE=$OUT
MUTATED_SOURCE_ESTATES=NO_INTENTIONAL_MUTATION
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- baseline test tail ---"
tail -60 "$OUT/07_BASELINE_TEST.txt" 2>/dev/null || true
echo
echo "STAGE1_COMPLETE=YES"
