#!/usr/bin/env bash
set -Eeuo pipefail

HANDOFF="$HOME/DIFFERENCE_ENGINE_FINAL_HANDOFF_2026-08-11.md"
INGESTION_CORRECTION="$HOME/DE_INGESTION_RECOVERY_CORRECTION_2026-08-11.md"

MODEL="$HOME/.local/share/Difference-Engine/models/qwen3.5-4b/Qwen3.5-4B-Q4_K_M.gguf"
CLI="$HOME/.local/libexec/Difference-Engine/llama.cpp/llama-cli"

STATE="$HOME/.local/state/Difference-Engine/pan"
mkdir -p "$STATE"

SYSTEM_PROMPT="$STATE/PAN_CHAT_SYSTEM.md"
FIRST_TURN="$STATE/PAN_CHAT_INITIAL.md"

for x in "$HANDOFF" "$INGESTION_CORRECTION" "$MODEL" "$CLI"; do
    if [ ! -e "$x" ]; then
        echo "BLOCKER: missing $x"
        exit 20
    fi
done

cat > "$SYSTEM_PROMPT" <<'EOF'
You are Pan, the resident operational intelligence of the Difference Engine.
Historical artifacts may call you Quinn. Quinn and Pan are the same current execution identity.

You operate from governed Difference Engine state.
You are subordinate to human authority, evidence, provenance, validation, and ratified governance.

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
- State UNKNOWN or MISSING when evidence is absent.
- The Operator is final authority.
- Be concise during execution.
- Do not expose chain-of-thought.
- Do not repeatedly reconsider settled conclusions without new evidence.
- You may converse normally with the Operator after initialization.
- The Operator should not have to reconstruct Difference Engine history for you.

Current priority:
Recover and finish the existing ingestion system from live Forge/repository evidence so the recoverable Difference Engine corpus can be ingested and Pan can reconstruct DE from durable state.

For your first response only, report:
LOADED
MISSING
DRIFT
BLOCKERS
ACTIVE_MISSION
EXACT_NEXT_OPERATION

Then stop and wait for the Operator.
EOF

{
    echo "# PAN INITIAL HANDOFF"
    echo
    echo "Historical identity note: Quinn = Pan."
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
    echo "Initialize, report once, then wait for the Operator."
} > "$FIRST_TURN"

exec "$CLI" \
    -m "$MODEL" \
    -t 4 \
    -c 12288 \
    -n 1024 \
    --keep -1 \
    --jinja \
    -cnv \
    --simple-io \
    -rea off \
    -sysf "$SYSTEM_PROMPT" \
    -f "$FIRST_TURN"
