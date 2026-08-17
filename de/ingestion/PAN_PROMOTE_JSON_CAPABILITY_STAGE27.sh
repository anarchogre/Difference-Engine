#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_JSON_CAPABILITY_PROMOTION_$TS-STAGE27"

mkdir -p "$OUT"

echo "=== PAN — JSON CAPABILITY PROMOTION STAGE 27 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

[ -d "$CURRENT/.git" ] || { echo "BLOCKER: $CURRENT is not the expected Git worktree"; exit 20; }
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST26B="$(
  find "$TREE_HOME" -maxdepth 1 -type d \
    -name 'PAN_JSON_PRESERVATION_IMPLEMENT_*-STAGE26B' \
    -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | head -1 | cut -d' ' -f2-
)"

[ -n "$LATEST26B" ] && [ -d "$LATEST26B" ] || {
  echo "BLOCKER: Stage26B evidence not found"
  exit 22
}

SUMMARY="$LATEST26B/SUMMARY.txt"
HASHES="$LATEST26B/02_CANDIDATE_HASHES.sha256"

[ -f "$SUMMARY" ] || { echo "BLOCKER: Stage26B summary missing"; exit 23; }
[ -f "$HASHES" ] || { echo "BLOCKER: Stage26B candidate hashes missing"; exit 24; }

getv() {
  local key="$1"
  sed -n "s/^${key}=//p" "$SUMMARY" | head -1
}

for gate in \
  STATUS \
  NORMALIZER_PATCH \
  JSON_PARSER \
  JSON_REGISTRY \
  JSON_VALIDATION \
  JSON_PIPELINE_ROUNDTRIP_TEST \
  FULL_REGRESSION \
  HISTORICAL_MANUAL_BATCH_MARKDOWN_REPLAY \
  EXACT_STAGE13_JSON_ROUNDTRIP \
  MARKDOWN_SOURCE_HASH \
  JSON_SOURCE_HASH
do
  value="$(getv "$gate")"
  if [ "$value" != "PASS" ]; then
    echo "BLOCKER: Stage26B gate $gate=$value"
    exit 25
  fi
done

[ "$(getv LIVE_JSON_CAPABILITY)" = "VALIDATED_UNCOMMITTED" ] || {
  echo "BLOCKER: Stage26B capability state drift: $(getv LIVE_JSON_CAPABILITY)"
  exit 26
}

TARGETS=(
  "workspace/operational/ingestion/service/registry.py"
  "workspace/operational/ingestion/service/validation.py"
  "workspace/operational/ingestion/service/output.py"
  "workspace/operational/ingestion/service/tests/run_all.py"
  "workspace/operational/ingestion/service/parsers/json_document.py"
  "workspace/operational/ingestion/service/tests/test_json_parser.py"
  "workspace/operational/ingestion/service/tests/test_json_validation.py"
  "workspace/operational/ingestion/service/tests/test_json_pipeline.py"
)

for rel in "${TARGETS[@]}"; do
  [ -f "$CURRENT/$rel" ] || {
    echo "BLOCKER: validated target missing: $CURRENT/$rel"
    exit 27
  }
done

# Exact no-drift check against the Stage26B validated candidate.
if ! sha256sum -c "$HASHES" > "$OUT/00_VALIDATED_HASH_RECHECK.txt" 2>&1; then
  echo "BLOCKER: validated implementation drifted after Stage26B"
  cat "$OUT/00_VALIDATED_HASH_RECHECK.txt"
  exit 28
fi

# Do not contaminate or overwrite an existing index.
if [ -n "$(git -C "$CURRENT" diff --cached --name-only)" ]; then
  echo "BLOCKER: Git index already contains staged changes"
  git -C "$CURRENT" diff --cached --name-status | tee "$OUT/01_PREEXISTING_INDEX.txt"
  exit 29
fi

{
  echo "UTC=$TS"
  echo "STAGE26B=$LATEST26B"
  echo "BRANCH=$(git -C "$CURRENT" branch --show-current)"
  echo "HEAD_BEFORE=$(git -C "$CURRENT" rev-parse HEAD)"
  echo
  echo "=== WORKTREE BEFORE ==="
  git -C "$CURRENT" status --short --branch
  echo
  echo "=== TARGET DIFF BEFORE ==="
  git -C "$CURRENT" diff -- "${TARGETS[@]}"
} > "$OUT/02_PRE_PROMOTION.txt"

# Re-run the recovered/full regression harness immediately before promotion.
RUN_ALL="$CURRENT/workspace/operational/ingestion/service/tests/run_all.py"
if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$CURRENT/workspace/operational/ingestion/service${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" "$RUN_ALL"
) > "$OUT/03_PRECOMMIT_REGRESSION.txt" 2>&1
then
  echo "BLOCKER: pre-promotion regression failed"
  tail -80 "$OUT/03_PRECOMMIT_REGRESSION.txt"
  exit 30
fi

# Stage only the validated capability files.
git -C "$CURRENT" add -- "${TARGETS[@]}"

EXPECTED_SORTED="$OUT/04_EXPECTED_TARGETS.txt"
ACTUAL_SORTED="$OUT/04_STAGED_TARGETS.txt"

printf '%s\n' "${TARGETS[@]}" | sort > "$EXPECTED_SORTED"
git -C "$CURRENT" diff --cached --name-only | sort > "$ACTUAL_SORTED"

if ! cmp -s "$EXPECTED_SORTED" "$ACTUAL_SORTED"; then
  echo "BLOCKER: staged file set differs from validated target set"
  echo "--- expected ---"
  cat "$EXPECTED_SORTED"
  echo "--- actual ---"
  cat "$ACTUAL_SORTED"
  git -C "$CURRENT" reset HEAD -- "${TARGETS[@]}" >/dev/null 2>&1 || true
  exit 31
fi

if ! git -C "$CURRENT" diff --cached --check > "$OUT/05_DIFF_CHECK.txt" 2>&1; then
  echo "BLOCKER: staged diff check failed"
  cat "$OUT/05_DIFF_CHECK.txt"
  git -C "$CURRENT" reset HEAD -- "${TARGETS[@]}" >/dev/null 2>&1 || true
  exit 32
fi

git -C "$CURRENT" diff --cached --stat > "$OUT/06_STAGED_STAT.txt"
git -C "$CURRENT" diff --cached > "$OUT/06_STAGED_DIFF.patch"

COMMIT_MESSAGE="ingestion: preserve generic JSON documents"

if ! git -C "$CURRENT" commit -m "$COMMIT_MESSAGE" > "$OUT/07_COMMIT.txt" 2>&1; then
  echo "BLOCKER: Git commit failed"
  cat "$OUT/07_COMMIT.txt"
  git -C "$CURRENT" reset HEAD -- "${TARGETS[@]}" >/dev/null 2>&1 || true
  exit 33
fi

COMMIT="$(git -C "$CURRENT" rev-parse HEAD)"

# Verify the commit contains exactly the intended target set.
git -C "$CURRENT" diff-tree --no-commit-id --name-only -r "$COMMIT" | sort \
  > "$OUT/08_COMMIT_TARGETS.txt"

if ! cmp -s "$EXPECTED_SORTED" "$OUT/08_COMMIT_TARGETS.txt"; then
  echo "BLOCKER: committed file set does not equal intended target set"
  echo "COMMIT=$COMMIT"
  echo "Manual review required; commit is preserved, not rewritten."
  exit 34
fi

TREE_REFRESH="NOT_RUN"
if [ -f "$HOME/PAN_REFRESH_FILE_TREE_TEXTS.sh" ]; then
  if bash "$HOME/PAN_REFRESH_FILE_TREE_TEXTS.sh" > "$OUT/09_TREE_REFRESH.txt" 2>&1; then
    TREE_REFRESH="PASS"
  else
    TREE_REFRESH="FAIL_NONBLOCKING"
  fi
else
  TREE_REFRESH="DEFERRED_SCRIPT_NOT_FOUND"
fi

{
  echo "=== COMMIT ==="
  git -C "$CURRENT" show --stat --oneline --decorate --no-renames "$COMMIT"
  echo
  echo "=== WORKTREE AFTER ==="
  git -C "$CURRENT" status --short --branch
} > "$OUT/10_POST_PROMOTION.txt"

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_JSON_CAPABILITY_PROMOTION_STAGE27
UTC=$TS
STATUS=PASS
STAGE26B=$LATEST26B
VALIDATED_HASH_RECHECK=PASS
PRECOMMIT_REGRESSION=PASS
STAGED_TARGET_SET=PASS
DIFF_CHECK=PASS
GIT_COMMIT=PASS
COMMIT=$COMMIT
COMMIT_MESSAGE=$COMMIT_MESSAGE
COMMITTED_TARGET_SET=PASS
TREE_REFRESH=$TREE_REFRESH
JSON_CAPABILITY=PROMOTED
EVIDENCE=$OUT
NEXT=BULK_INGEST_PROVEN_JSON_MD_TXT_NONCONVERSATION_REMAINDER
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- commit ---"
cat "$OUT/07_COMMIT.txt"
echo
echo "--- regression tail ---"
tail -30 "$OUT/03_PRECOMMIT_REGRESSION.txt"
echo
echo "STAGE27_COMPLETE=YES"
