#!/usr/bin/env bash
set -u

MODEL="$HOME/.local/share/Difference-Engine/models/qwen3.5-4b/Qwen3.5-4B-Q4_K_M.gguf"
BIN="$HOME/.local/libexec/Difference-Engine/llama.cpp"
ROOT="$HOME/.local/state/Difference-Engine/qwen"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN="$ROOT/${TS}-smoke-jobctrl-fix"

mkdir -p "$RUN"

echo "=== QWEN SMOKE — JOB CONTROL FIX ===" | tee "$RUN/run.log"

if pgrep -x llama-cli >/dev/null 2>&1; then
  echo "STATUS=BLOCKED_OLD_LLAMA_PROCESS" | tee -a "$RUN/run.log"
  ps -o pid,ppid,pgid,sid,stat,etime,wchan:24,cmd -C llama-cli \
    | tee "$RUN/old-llama-process.txt"
  exit 20
fi

for x in "$MODEL" "$BIN/llama-cli"; do
  if [ ! -e "$x" ]; then
    echo "STATUS=BLOCKED_MISSING_PATH" | tee -a "$RUN/run.log"
    echo "MISSING=$x" | tee -a "$RUN/run.log"
    exit 21
  fi
done

{
  echo "UTC=$TS"
  echo "MODEL=$MODEL"
  echo "BIN=$BIN"
  echo
  echo "=== MEMORY BEFORE ==="
  free -h || true
  echo
  echo "=== SWAP BEFORE ==="
  swapon --show --bytes || true
} > "$RUN/preflight.txt" 2>&1

START="$(date +%s)"

set +e
timeout --foreground --verbose -k 30s 10m \
  "$BIN/llama-cli" \
    -m "$MODEL" \
    -t 4 \
    -c 2048 \
    -n 64 \
    --single-turn \
    --simple-io \
    -p "Reply with one short sentence saying local Qwen inference is working." \
    > "$RUN/smoke-output.txt" \
    2> "$RUN/smoke.stderr.txt"
RC=$?
set -e 2>/dev/null || true

END="$(date +%s)"
ELAPSED="$((END - START))"

free -h > "$RUN/memory-after.txt" 2>&1 || true
swapon --show --bytes > "$RUN/swap-after.txt" 2>&1 || true
ps -o pid,ppid,pgid,sid,stat,etime,wchan:24,cmd -C llama-cli \
  > "$RUN/llama-after.txt" 2>&1 || true

case "$RC" in
  0)   STATUS="PASS" ;;
  124) STATUS="FAIL_TIMEOUT_TERM" ;;
  137) STATUS="FAIL_TIMEOUT_KILL" ;;
  20)  STATUS="BLOCKED_OLD_LLAMA_PROCESS" ;;
  *)   STATUS="FAIL_EXIT_$RC" ;;
esac

cat > "$RUN/SUMMARY.txt" <<EOF
QWEN SMOKE — JOB CONTROL FIX
UTC=$TS
STATUS=$STATUS
EXIT_CODE=$RC
ELAPSED_SECONDS=$ELAPSED
MODEL_HASH=PREVIOUSLY_PASS_NOT_RERUN
BENCHMARK=PREVIOUSLY_PASS_NOT_RERUN
FIX=timeout--foreground + llama-cli--simple-io
EVIDENCE=$RUN
EOF

cat "$RUN/SUMMARY.txt"
echo
echo "--- smoke output ---"
cat "$RUN/smoke-output.txt" 2>/dev/null || true
echo
echo "--- smoke stderr tail ---"
tail -60 "$RUN/smoke.stderr.txt" 2>/dev/null || true
echo
echo "--- llama process after ---"
cat "$RUN/llama-after.txt" 2>/dev/null || true

exit "$RC"
