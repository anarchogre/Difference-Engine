#!/usr/bin/env bash
set -Eeuo pipefail

echo "TASK=STAGE49A_LIVE_RECOVERY_GATE"

REPO=""
for d in "$HOME/Difference-Engine" "$HOME/difference-engine"; do
    if [ -f "$d/workspace/operational/ingestion/service/tests/run_all.py" ]; then
        REPO="$d"
        break
    fi
done

if [ -z "$REPO" ]; then
    REPO="$(
        find "$HOME" -maxdepth 4 -type f \
          -path '*/workspace/operational/ingestion/service/tests/run_all.py' \
          -print -quit 2>/dev/null |
        sed 's#/workspace/operational/ingestion/service/tests/run_all.py$##'
    )"
fi

SCRIPT="$(
    find "$HOME" -maxdepth 4 -type f \
      -name 'PAN_BUILD_SANDBOX_DOCX_ADAPTER_RETRY_STAGE49A.sh' \
      -print -quit 2>/dev/null || true
)"

COMPLETE=""
for root in \
    "$HOME/Forge-File-Tree-Directories" \
    "${REPO:+$REPO/workspace/operational/ingestion}"
do
    [ -d "$root" ] || continue
    hit="$(
        grep -RIl \
          --include='SUMMARY.txt' \
          --include='*.txt' \
          'STAGE49A_COMPLETE=YES' \
          "$root" 2>/dev/null |
        head -1 || true
    )"
    if [ -n "$hit" ]; then
        COMPLETE="$hit"
        break
    fi
done

STAGE48=""
if [ -d "$HOME/Forge-File-Tree-Directories" ]; then
    STAGE48="$(
        grep -RIl \
          --include='SUMMARY.txt' \
          'STAGE48_COMPLETE=YES' \
          "$HOME/Forge-File-Tree-Directories" 2>/dev/null |
        sort |
        tail -1 || true
    )"
fi

echo "REPO=${REPO:-NOT_FOUND}"
echo "STAGE49A_SCRIPT=${SCRIPT:-NOT_FOUND}"
echo "STAGE48_EVIDENCE=${STAGE48:-NOT_FOUND}"

if [ -n "$COMPLETE" ]; then
    echo "STATUS=PASS"
    echo "STAGE49A_ALREADY_COMPLETE=YES"
    echo "STAGE49A_EVIDENCE=$COMPLETE"
    grep -E '^(STATUS|STAGE49A_COMPLETE|CANDIDATE_NEXT|NEXT)=' \
      "$COMPLETE" 2>/dev/null || true
    echo "NEXT=READ_COMPLETED_STAGE49A_AND_ADVANCE"
elif [ -n "$SCRIPT" ]; then
    echo "STATUS=PASS"
    echo "STAGE49A_ALREADY_COMPLETE=NO_EVIDENCE"
    echo "NEXT=EXECUTE_SURVIVING_STAGE49A"
else
    echo "STATUS=BLOCKED"
    echo "STAGE49A_ALREADY_COMPLETE=NO_EVIDENCE"
    echo "BLOCKER=STAGE49A_SCRIPT_NOT_FOUND_ON_FORGE"
    echo "NEXT=RESTORE_STAGE49A_FROM_RECOVERED_SOURCE"
fi
