#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_INGESTION_RECOVERY_$TS-STAGE3-PY3"

PRIMARY="$CURRENT/workspace/operational/ingestion/service/tests/run_all.py"
RETIRED_ROOT="$CURRENT/workspace/operational/ingestion/recovery/retired_packages"
PYTHON="/usr/bin/python3"

mkdir -p "$OUT"

echo "=== PAN — INGESTION RECOVERY STAGE 3 / PYTHON3 ==="
echo "CURRENT=$CURRENT"
echo "PRIMARY=$PRIMARY"
echo "PYTHON=$PYTHON"
echo "EVIDENCE=$OUT"
echo

[ -d "$CURRENT" ] || { echo "BLOCKER: missing $CURRENT"; exit 20; }
[ -f "$PRIMARY" ] || { echo "BLOCKER: primary recovered harness missing: $PRIMARY"; exit 21; }
[ -x "$PYTHON" ] || { echo "BLOCKER: python3 missing: $PYTHON"; exit 22; }

{
  echo "=== PRIMARY HARNESS ==="
  sha256sum "$PRIMARY"
  stat "$PRIMARY" || true
  echo
  echo "=== RETIRED RUN_ALL COPIES ==="
  find "$RETIRED_ROOT" -type f -name run_all.py -print0 2>/dev/null \
    | sort -z \
    | xargs -0 -r sha256sum
} > "$OUT/01_HARNESS_IDENTITY.txt" 2>&1

{
  echo "=== PRIMARY HARNESS HEAD ==="
  sed -n '1,260p' "$PRIMARY"
  echo
  echo "=== IMPORTS / PATH / ENTRYPOINT CLUES ==="
  grep -nE '^(from|import) |sys\.path|PYTHONPATH|subprocess|os\.chdir|__main__|def main|unittest|pytest' \
    "$PRIMARY" 2>/dev/null || true
} > "$OUT/02_HARNESS_CONTRACT.txt" 2>&1

find "$CURRENT/workspace/operational/ingestion/service" \
  -maxdepth 4 -type f -print 2>/dev/null | sort \
  > "$OUT/03_SERVICE_TREE.txt"

set +e
(
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$CURRENT/workspace/operational/ingestion/service${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" "$PRIMARY"
) > "$OUT/04_BASELINE_RUN.txt" 2>&1
RC=$?
set -e

{
  echo "=== GIT AFTER BASELINE ==="
  git -C "$CURRENT" status --short --branch 2>/dev/null || true
} > "$OUT/05_GIT_AFTER.txt" 2>&1

if [ "$RC" -eq 0 ]; then
  STATUS="PASS"
  NEXT="RECOVER_DISCOVERY_AND_DELTA_INTERFACES_FOR_FIRST_CORPUS"
else
  STATUS="FAIL_EXIT_$RC"
  NEXT="PRESERVE_FAILURE_AND_REPAIR_ONLY_THIS_RECOVERED_HARNESS_EDGE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_INGESTION_RECOVERY_STAGE3_PY3
UTC=$TS
PRIMARY_HARNESS=$PRIMARY
PYTHON=$PYTHON
BASELINE_STATUS=$STATUS
EXIT_CODE=$RC
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- baseline tail ---"
tail -80 "$OUT/04_BASELINE_RUN.txt" 2>/dev/null || true
echo
echo "STAGE3_PY3_COMPLETE=YES"

exit "$RC"
