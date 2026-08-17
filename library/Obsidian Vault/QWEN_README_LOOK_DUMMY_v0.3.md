# QWEN ON FORGE — LOOK, DUMMY EDITION
## Qwen-only offline roadmap — v0.3

This is the whole job. Do not build Pan yet. Do not install AirLLM yet. Do not touch the DifferenceEngine repository.

## 0. WHAT FORGE ALREADY HAS

From the 2026-08-10 Forge/Pan-Qwen file trees:

- llama.cpp binaries:
  `~/.local/libexec/Difference-Engine/llama.cpp/`
- expected binaries:
  `llama-cli`, `llama-bench`, `llama-server`
- Qwen model asset appears at:
  `~/.local/share/Difference-Engine/models/qwen3.5-4b/Qwen3.5-4B-Q4_K_M.gguf`

The file existing is NOT proof that Qwen works.

Success begins only when:
1. SHA-256 is correct.
2. llama.cpp loads it.
3. inference produces sane output.

Expected SHA-256:

`00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4`

## 1. HASH FIRST. DO NOT COPY ANOTHER 2.7 GB FILE YET.

Run:

```bash
sha256sum ~/.local/share/Difference-Engine/models/qwen3.5-4b/Qwen3.5-4B-Q4_K_M.gguf
```

You want the first field to be exactly:

```text
00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4
```

If it matches: good. Stop moving giant files around.

If it does not match: do NOT run the model. Transfer the completed phone copy, verify that copy, and only then replace the bad file.

Do not merge an interrupted download by guesswork.

## 2. NAP-SAFE TEST

Put `QWEN_NAP_RUN.sh` on Forge and run:

```bash
bash QWEN_NAP_RUN.sh
```

Then go nap.

It:
- verifies the model hash,
- checks llama.cpp,
- records RAM/swap,
- benchmarks 4 vs 8 threads,
- runs one tiny smoke-test prompt,
- writes evidence under:
  `~/.local/state/Difference-Engine/qwen/`

It does NOT:
- install packages,
- use the Internet,
- touch the DifferenceEngine repository,
- start a permanent server,
- install Pan/Ada/Babbage governance,
- install another model.

## 3. WHEN YOU WAKE UP

Run:

```bash
R="$(ls -dt ~/.local/state/Difference-Engine/qwen/* | head -1)"
cat "$R/SUMMARY.txt"
```

You want:

```text
MODEL_HASH=PASS
BENCHMARK=PASS
SMOKE_TEST=PASS
```

If anything says FAIL/BLOCKED, stop. Preserve that directory.

## 4. FIRST ACTUAL CONVERSATION

Only after the nap-safe test passes:

```bash
~/.local/libexec/Difference-Engine/llama.cpp/llama-cli \
  -m ~/.local/share/Difference-Engine/models/qwen3.5-4b/Qwen3.5-4B-Q4_K_M.gguf \
  -t 4 \
  -c 4096 \
  --jinja \
  -cnv \
  -rea auto
```

Question being tested:

> Does local Qwen work well enough to be useful?

No DE authority yet.

## 5. LOCAL BROWSER CHAT

After CLI works:

```bash
bash QWEN_START_UI.sh
```

Open Firefox to:

```text
http://127.0.0.1:8080
```

No Internet is required for `127.0.0.1`.

Stop it with:

```bash
bash QWEN_STOP_UI.sh
```

## 6. QWEN PHASE 1 IS DONE WHEN

- [ ] SHA-256 matches
- [ ] llama.cpp loads the model
- [ ] benchmark completes
- [ ] smoke prompt produces sensible text
- [ ] interactive local chat works with Internet disconnected

That is it.

## 7. NOT TODAY

- no AirLLM
- no layer-wise giant model
- no second LLM
- no RAG/vector database
- no LoRA/adapters
- no autonomous shell access
- no VS Code agent wiring
- no Pan/Babbage/Ada/branch identity installation
- no canonical DE changes

First prove the potato can potato.

## 8. IF THE PHONE DIES

Use this file.

```text
HASH
  ↓
QWEN_NAP_RUN.sh
  ↓
READ SUMMARY.txt
  ↓
CLI CHAT
  ↓
OPTIONAL LOCAL WEB UI
```

If something fails:

```text
STOP
PRESERVE OUTPUT
DO NOT RANDOMLY FIX SHIT
```

The evidence will be there when ChatGPT is available again.
