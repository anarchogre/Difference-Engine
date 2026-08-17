#!/usr/bin/env bash
set -Eeuo pipefail

HANDOFF="$HOME/DIFFERENCE_ENGINE_FINAL_HANDOFF_2026-08-11.md"
SUCCESSOR="$HOME/DIFFERENCE_ENGINE_SUCCESSOR_CHAT_BOOTSTRAP_FINAL_2026-08-11.md"
INGESTION_CORRECTION="$HOME/DE_INGESTION_RECOVERY_CORRECTION_2026-08-11.md"

MODEL="$HOME/.local/share/Difference-Engine/models/qwen3.5-4b/Qwen3.5-4B-Q4_K_M.gguf"
CLI="$HOME/.local/libexec/Difference-Engine/llama.cpp/llama-cli"

STATE="$HOME/.local/state/Difference-Engine/quinn"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN="$STATE/$TS-initialization"
mkdir -p "$RUN"

SYSTEM_PROMPT="$RUN/QUINN_SYSTEM.md"
FIRST_TURN="$RUN/QUINN_INITIAL_HANDOFF.md"
RAW="$RUN/raw-output.txt"
ERR="$RUN/stderr.txt"
REPORT="$RUN/INITIALIZATION_REPORT.txt"

for x in "$HANDOFF" "$SUCCESSOR" "$INGESTION_CORRECTION" "$MODEL" "$CLI"; do
  if [ ! -e "$x" ]; then
    echo "BLOCKER: missing $x"
    exit 20
  fi
done

cat > "$SYSTEM_PROMPT" <<'EOF'
You are Quinn, the resident bounded reasoning worker attached to the Difference Engine.

You are not the Difference Engine, not canonical truth, and not Pan by declaration.
You operate from governed state and remain subordinate to human authority, evidence, provenance, validation, and the human operator.

Operational order:
Reality -> Constraint -> Observation -> Evidence -> Knowledge -> Governance -> Operations -> Implementation.

Rules:
- Evidence before interpretation.
- Interpretation before promotion.
- Promotion only after validation.
- Recover before redesign.
- Search before recreation.
- Preserve provenance, contradiction, supersession, uncertainty, and rollback.
- Never invent repository state, authority, file contents, machine state, or tool access.
- If something is not actually available in context, say UNKNOWN or MISSING.
- Do not expose chain-of-thought or narrate analysis.
- Do not repeatedly reconsider a settled conclusion.
- Output only the requested report.

Your response must use exactly these headings, in this order:
LOADED
MISSING
DRIFT
CONFLICTS
BLOCKERS
ACTIVE_MISSION
CURRENT_MILESTONE
EXACT_NEXT_OPERATION
UNKNOWN

Under LOADED, distinguish material actually present in context from material merely referenced by path.
Do not claim live filesystem/tool access unless actually available.
EOF

{
  echo "# QUINN INITIAL HANDOFF"
  echo
  echo "HANDOFF_PATH=$HANDOFF"
  echo "INGESTION_CORRECTION_PATH=$INGESTION_CORRECTION"
  echo "SUCCESSOR_CHAT_BOOTSTRAP_PATH=$SUCCESSOR"
  echo
  echo "The successor-chat bootstrap is for ChatGPT continuity/provenance only."
  echo "Do not adopt its ChatGPT-specific identity instructions."
  echo
  echo "----- BEGIN FINAL HANDOFF -----"
  cat "$HANDOFF"
  echo
  echo "----- END FINAL HANDOFF -----"
  echo
  echo "----- BEGIN INGESTION RECOVERY CORRECTION -----"
  cat "$INGESTION_CORRECTION"
  echo
  echo "----- END INGESTION RECOVERY CORRECTION -----"
  echo
  echo "----- CURRENT LIVE-EVIDENCE CORRECTION -----"
  cat <<'EOF'
This later live evidence supersedes stale technical state in the handoff:

MODEL_HASH=PASS
BENCHMARK=PASS
SMOKE_TEST=PASS
MULTI_TURN_CONTEXT=PASS
INTERACTIVE_LOCAL_CHAT=PASS
MILESTONE_A=PASS

Validated smoke repair:
timeout --foreground + llama-cli --simple-io

The preceding failure was a Unix job-control/process-group stop.
The repaired smoke returned EXIT_CODE=0 in about 14 seconds.

Interactive validation proved:
- local model load
- real response generation
- prior-turn context use
- coherent multi-turn reasoning
- clean /exit to shell

Observed baseline:
Prompt ~18-21 tokens/sec
Generation ~6.4-6.5 tokens/sec

Observed non-blocking behavioral constraint:
SELF_REFINEMENT=EXCESSIVE_ON_SOME_REASONING_PROMPTS
STOPPING_BEHAVIOR=NEEDS_LATER_TUNING

CURRENT ACTIVE MISSION:
Recover the complete existing ingestion subsystem, prove the live baseline, and begin corpus ingestion so durable Difference Engine competence no longer depends on ChatGPT reconstruction.

CURRENT NEXT CONSTRUCTION TARGET:
Recover the actual discovery/delta-discovery/formatter/parser/Repository-Object/provenance/state/recovery implementation from live Forge/repository evidence before creating anything new.

Do not rerun Qwen viability gates without contradictory evidence.
EOF
  echo "----- END CURRENT LIVE-EVIDENCE CORRECTION -----"
  echo
  echo "Output only the required final initialization report."
} > "$FIRST_TURN"

printf 'QUINN: loading current Difference Engine state. Output suppressed until report is ready...\n'

set +e
"$CLI" \
  -m "$MODEL" \
  -t 4 \
  -c 12288 \
  -n 1024 \
  --jinja \
  --simple-io \
  --single-turn \
  --no-display-prompt \
  --no-show-timings \
  -rea off \
  -sysf "$SYSTEM_PROMPT" \
  -f "$FIRST_TURN" \
  >"$RAW" 2>"$ERR"
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
  echo "QUINN_INITIALIZATION=FAIL"
  echo "EXIT_CODE=$RC"
  echo "EVIDENCE=$RUN"
  echo "--- stderr tail ---"
  tail -40 "$ERR" || true
  exit "$RC"
fi

# Show only the final report, not model banner/prompt internals.
awk '
  BEGIN {show=0}
  /^LOADED[[:space:]]*$/ {show=1}
  show {print}
' "$RAW" > "$REPORT"

if [ ! -s "$REPORT" ]; then
  # Fallback: preserve everything, but still avoid losing evidence.
  cp "$RAW" "$REPORT"
fi

echo
cat "$REPORT"
echo
echo "QUINN_INITIALIZATION=PASS"
echo "EVIDENCE=$RUN"
