#!/usr/bin/env bash
set -Eeuo pipefail

MODEL="$HOME/.local/share/Difference-Engine/models/qwen3.5-4b/Qwen3.5-4B-Q4_K_M.gguf"
CLI="$HOME/.local/libexec/Difference-Engine/llama.cpp/llama-cli"

[ -x "$CLI" ] || { echo "BLOCKER: llama-cli missing: $CLI"; exit 2; }
[ -f "$MODEL" ] || { echo "BLOCKER: model missing: $MODEL"; exit 3; }

echo "=== QWEN INTERACTIVE LOCAL CHAT ==="
echo "MODEL=$MODEL"
echo "Exit with /exit or Ctrl+C."
echo

exec "$CLI" \
  -m "$MODEL" \
  -t 4 \
  -c 4096 \
  --jinja \
  -cnv \
  -rea auto
