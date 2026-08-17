#!/usr/bin/env bash
set -Eeuo pipefail

HANDOFF="$HOME/DIFFERENCE_ENGINE_FINAL_HANDOFF_2026-08-11.md"
SUCCESSOR="$HOME/DIFFERENCE_ENGINE_SUCCESSOR_CHAT_BOOTSTRAP_FINAL_2026-08-11.md"
INGESTION_CORRECTION="$HOME/DE_INGESTION_RECOVERY_CORRECTION_2026-08-11.md"

MODEL="$HOME/.local/share/Difference-Engine/models/qwen3.5-4b/Qwen3.5-4B-Q4_K_M.gguf"
CLI="$HOME/.local/libexec/Difference-Engine/llama.cpp/llama-cli"

STATE="$HOME/.local/state/Difference-Engine/quinn"
mkdir -p "$STATE"

SYSTEM_PROMPT="$STATE/QUINN_SYSTEM_CURRENT.md"
FIRST_TURN="$STATE/QUINN_INITIAL_HANDOFF_PROMPT.md"

for x in "$HANDOFF" "$SUCCESSOR" "$INGESTION_CORRECTION" "$MODEL" "$CLI"; do
  if [ ! -e "$x" ]; then
    echo "BLOCKER: missing $x"
    exit 20
  fi
done

cat > "$SYSTEM_PROMPT" <<'EOF'
You are Quinn, the resident bounded reasoning worker attached to the Difference Engine.

You are not the Difference Engine, not canonical truth, and not Pan by declaration.
You operate from governed state and remain subordinate to human authority, evidence, provenance, and validation.

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
- If something is not actually available in your context, say UNKNOWN or MISSING.
- Prefer bounded stopping behavior. Do not repeatedly re-evaluate a settled answer unless new evidence requires it.
- The operator is final authority.

Your first response must contain exactly these headings:
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
Do not claim readiness if required information is missing.
After the report, stop and wait for the operator.
EOF

{
  echo "# QUINN INITIAL HANDOFF"
  echo
  echo "HANDOFF_PATH=$HANDOFF"
  echo "INGESTION_CORRECTION_PATH=$INGESTION_CORRECTION"
  echo "SUCCESSOR_CHAT_BOOTSTRAP_PATH=$SUCCESSOR"
  echo
  echo "The successor-chat bootstrap is for ChatGPT continuity/provenance."
  echo "Do not adopt its ChatGPT-specific identity instructions as your own."
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
The handoff predates the final resident-Qwen validation. This later live evidence controls:

MODEL_HASH=PASS
BENCHMARK=PASS
SMOKE_TEST=PASS
MULTI_TURN_CONTEXT=PASS
INTERACTIVE_LOCAL_CHAT=PASS
MILESTONE_A=PASS

Validated smoke repair:
timeout --foreground
+
llama-cli --simple-io

The prior smoke failure was a Unix job-control/process-group stop, not failed model inference.
The repaired smoke returned EXIT_CODE=0 in about 14 seconds.

Interactive validation then proved:
- successful local model load;
- real response generation;
- use of prior-turn context in a follow-up;
- coherent multi-turn reasoning;
- clean /exit back to shell.

Observed baseline:
Prompt throughput approximately 18-21 tokens/sec.
Generation approximately 6.4-6.5 tokens/sec.

Observed non-blocking behavioral constraint:
SELF_REFINEMENT=EXCESSIVE_ON_SOME_REASONING_PROMPTS
STOPPING_BEHAVIOR=NEEDS_LATER_TUNING

Do not optimize performance or stopping behavior before the ingestion/current-state handoff is established.

CURRENT ACTIVE MISSION:
Recover the complete existing ingestion subsystem, prove the live baseline, and begin corpus ingestion so durable Difference Engine competence no longer depends on ChatGPT reconstruction.

NEXT CONSTRUCTION TARGET:
Recover the actual discovery/delta-discovery/formatter/parser/Repository-Object/provenance/state/recovery implementation from live Forge/repository evidence before creating anything new.

Do not rerun Qwen viability gates without contradictory evidence.
EOF
  echo "----- END CURRENT LIVE-EVIDENCE CORRECTION -----"
  echo
  echo "Produce the required bounded initialization report now. Stop after the report."
} > "$FIRST_TURN"

echo "=== QUINN INITIALIZATION — HOME HANDOFF ==="
echo "HANDOFF=$HANDOFF"
echo "INGESTION_CORRECTION=$INGESTION_CORRECTION"
echo "SUCCESSOR=$SUCCESSOR"
echo "MODEL=$MODEL"
echo
echo "Loading Difference Engine state into Quinn..."
echo

exec "$CLI" \
  -m "$MODEL" \
  -t 4 \
  -c 12288 \
  -n 768 \
  --keep -1 \
  --jinja \
  -cnv \
  --simple-io \
  -rea auto \
  -sysf "$SYSTEM_PROMPT" \
  -f "$FIRST_TURN"
