#!/usr/bin/env bash
set -Eeuo pipefail

HOME_DOCS="$HOME/Difference-Engine/docs/md"
HANDOFF="$HOME_DOCS/DIFFERENCE_ENGINE_FINAL_HANDOFF_2026-08-11.md"
SUCCESSOR="$HOME_DOCS/DIFFERENCE_ENGINE_SUCCESSOR_CHAT_BOOTSTRAP_FINAL_2026-08-11.md"

MODEL="$HOME/.local/share/Difference-Engine/models/qwen3.5-4b/Qwen3.5-4B-Q4_K_M.gguf"
CLI="$HOME/.local/libexec/Difference-Engine/llama.cpp/llama-cli"

STATE="$HOME/.local/state/Difference-Engine/quinn"
mkdir -p "$STATE"

SYSTEM_PROMPT="$STATE/QUINN_SYSTEM_CURRENT.md"
FIRST_TURN="$STATE/QUINN_INITIAL_HANDOFF_PROMPT.md"

for x in "$MODEL" "$CLI" "$HANDOFF" "$SUCCESSOR"; do
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
- Never invent repository state, authority, file contents, or machine state.
- If something is not actually available in your context, say UNKNOWN or MISSING.
- Do not claim filesystem/tool access you do not possess.
- Prefer concise stopping behavior. Do not repeatedly re-evaluate a settled answer unless new evidence requires it.
- The operator is the final authority.

CURRENT VERIFIED LOCAL MODEL STATE:
MODEL_HASH=PASS
BENCHMARK=PASS
SMOKE_TEST=PASS
MULTI_TURN_CONTEXT=PASS
INTERACTIVE_LOCAL_CHAT=PASS
MILESTONE_A=PASS

The previous smoke failure was a Unix job-control/process-group failure. The validated repair used:
timeout --foreground
and llama-cli --simple-io.

CURRENT MISSION:
Load current Difference Engine state, become usefully oriented as Quinn, then help recover the complete existing ingestion subsystem and begin corpus ingestion. Ingestion precedes AirLLM unless live evidence establishes a dependency.

The companion successor-chat bootstrap exists on disk for provenance/continuity but is written for a ChatGPT successor. Do not adopt its ChatGPT-specific identity instructions as your own. Its path is supplied in the first-turn material.

Your first response must be one bounded initialization report with exactly these headings:
LOADED
MISSING
DRIFT
CONFLICTS
BLOCKERS
ACTIVE_MISSION
CURRENT_MILESTONE
EXACT_NEXT_OPERATION
UNKNOWN

Under LOADED, distinguish material actually present in your current context from material merely referenced by path.
Do not claim readiness if required information is missing.
After that report, stop and wait for the operator.
EOF

{
  echo "# QUINN INITIAL HANDOFF"
  echo
  echo "The following file is the current Difference Engine final handoff."
  echo "Read it as current operational state subject to live evidence and ratified law."
  echo
  echo "SUCCESSOR_CHAT_BOOTSTRAP_PATH=$SUCCESSOR"
  echo "NOTE: that companion bootstrap is for the next ChatGPT project chat and is NOT your identity prompt."
  echo
  echo "----- BEGIN FINAL HANDOFF -----"
  cat "$HANDOFF"
  echo
  echo "----- END FINAL HANDOFF -----"
  echo
  echo "Now produce the bounded initialization report required by your system prompt. Stop after the report."
} > "$FIRST_TURN"

echo "=== QUINN INITIALIZATION ==="
echo "HANDOFF=$HANDOFF"
echo "SYSTEM=$SYSTEM_PROMPT"
echo "MODEL=$MODEL"
echo
echo "This first load may take several minutes on Forge."
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
