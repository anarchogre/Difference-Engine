#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_JSON_CAPABILITY_PROMOTION_$TS-STAGE27B"
BACKUP="$OUT/pre-whitespace-clean"

mkdir -p "$OUT" "$BACKUP"

echo "=== PAN — JSON CAPABILITY PROMOTION STAGE 27B ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

[ -d "$CURRENT/.git" ] || { echo "BLOCKER: expected Git worktree missing"; exit 20; }
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST26B="$(
  find "$TREE_HOME" -maxdepth 1 -type d \
    -name 'PAN_JSON_PRESERVATION_IMPLEMENT_*-STAGE26B' \
    -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | head -1 | cut -d' ' -f2-
)"
[ -n "$LATEST26B" ] && [ -d "$LATEST26B" ] || {
  echo "BLOCKER: Stage26B evidence missing"
  exit 22
}

SUMMARY26="$LATEST26B/SUMMARY.txt"
HASHES26="$LATEST26B/02_CANDIDATE_HASHES.sha256"

[ -f "$SUMMARY26" ] || { echo "BLOCKER: Stage26B summary missing"; exit 23; }
[ -f "$HASHES26" ] || { echo "BLOCKER: Stage26B hashes missing"; exit 24; }

getv() {
  sed -n "s/^$1=//p" "$SUMMARY26" | head -1
}

for gate in \
  STATUS NORMALIZER_PATCH JSON_PARSER JSON_REGISTRY JSON_VALIDATION \
  JSON_PIPELINE_ROUNDTRIP_TEST FULL_REGRESSION \
  HISTORICAL_MANUAL_BATCH_MARKDOWN_REPLAY EXACT_STAGE13_JSON_ROUNDTRIP \
  MARKDOWN_SOURCE_HASH JSON_SOURCE_HASH
do
  [ "$(getv "$gate")" = "PASS" ] || {
    echo "BLOCKER: Stage26B gate $gate=$(getv "$gate")"
    exit 25
  }
done

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
    echo "BLOCKER: validated target missing: $rel"
    exit 26
  }
done

# Stage27 failure should have left working files untouched.
if ! sha256sum -c "$HASHES26" > "$OUT/00_STAGE26B_HASH_RECHECK.txt" 2>&1; then
  echo "BLOCKER: implementation drift since Stage26B"
  cat "$OUT/00_STAGE26B_HASH_RECHECK.txt"
  exit 27
fi

# No pre-existing staged work.
if [ -n "$(git -C "$CURRENT" diff --cached --name-only)" ]; then
  echo "BLOCKER: Git index already contains staged changes"
  git -C "$CURRENT" diff --cached --name-status
  exit 28
fi

# Preserve exact validated files.
for rel in "${TARGETS[@]}"; do
  mkdir -p "$BACKUP/$(dirname "$rel")"
  cp -a "$CURRENT/$rel" "$BACKUP/$rel"
done

# Record AST before whitespace cleanup.
"$PYTHON" - "$CURRENT" "${TARGETS[@]}" > "$OUT/01_AST_BEFORE.sha256" <<'PY'
import ast, hashlib, sys
from pathlib import Path

root = Path(sys.argv[1])
for rel in sys.argv[2:]:
    p = root / rel
    tree = ast.parse(p.read_text(encoding="utf-8"), filename=str(p))
    canonical = ast.dump(tree, annotate_fields=True, include_attributes=False)
    print(hashlib.sha256(canonical.encode()).hexdigest(), rel)
PY

# Remove ONLY trailing horizontal whitespace from the validated target files.
"$PYTHON" - "$CURRENT" "${TARGETS[@]}" > "$OUT/02_WHITESPACE_CLEANUP.txt" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])

for rel in sys.argv[2:]:
    p = root / rel
    text = p.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)

    cleaned = []
    changed = 0

    for line in lines:
        if line.endswith("\r\n"):
            body, ending = line[:-2], "\r\n"
        elif line.endswith("\n"):
            body, ending = line[:-1], "\n"
        else:
            body, ending = line, ""

        new_body = body.rstrip(" \t")
        if new_body != body:
            changed += 1
        cleaned.append(new_body + ending)

    if changed:
        p.write_text("".join(cleaned), encoding="utf-8")

    print(f"{rel}\ttrailing_whitespace_lines_removed={changed}")
PY

# Require semantic AST identity after cleanup.
"$PYTHON" - "$CURRENT" "${TARGETS[@]}" > "$OUT/03_AST_AFTER.sha256" <<'PY'
import ast, hashlib, sys
from pathlib import Path

root = Path(sys.argv[1])
for rel in sys.argv[2:]:
    p = root / rel
    tree = ast.parse(p.read_text(encoding="utf-8"), filename=str(p))
    canonical = ast.dump(tree, annotate_fields=True, include_attributes=False)
    print(hashlib.sha256(canonical.encode()).hexdigest(), rel)
PY

if ! cmp -s "$OUT/01_AST_BEFORE.sha256" "$OUT/03_AST_AFTER.sha256"; then
  echo "BLOCKER: whitespace cleanup changed Python semantics"
  diff -u "$OUT/01_AST_BEFORE.sha256" "$OUT/03_AST_AFTER.sha256" || true
  for rel in "${TARGETS[@]}"; do
    cp -a "$BACKUP/$rel" "$CURRENT/$rel"
  done
  exit 29
fi

# The exact recurring problem must now be gone.
if ! git -C "$CURRENT" diff --check -- "${TARGETS[@]}" > "$OUT/04_WORKTREE_DIFF_CHECK.txt" 2>&1; then
  echo "BLOCKER: whitespace errors remain"
  cat "$OUT/04_WORKTREE_DIFF_CHECK.txt"
  for rel in "${TARGETS[@]}"; do
    cp -a "$BACKUP/$rel" "$CURRENT/$rel"
  done
  exit 30
fi

RUN_ALL="$CURRENT/workspace/operational/ingestion/service/tests/run_all.py"

# Revalidate after cleanup.
if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$CURRENT/workspace/operational/ingestion/service${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" "$RUN_ALL"
) > "$OUT/05_POST_CLEAN_REGRESSION.txt" 2>&1
then
  echo "BLOCKER: regression failed after whitespace cleanup"
  tail -80 "$OUT/05_POST_CLEAN_REGRESSION.txt"
  for rel in "${TARGETS[@]}"; do
    cp -a "$BACKUP/$rel" "$CURRENT/$rel"
  done
  exit 31
fi

# Stage only validated target files.
git -C "$CURRENT" add -- "${TARGETS[@]}"

printf '%s\n' "${TARGETS[@]}" | sort > "$OUT/06_EXPECTED_TARGETS.txt"
git -C "$CURRENT" diff --cached --name-only | sort > "$OUT/06_STAGED_TARGETS.txt"

if ! cmp -s "$OUT/06_EXPECTED_TARGETS.txt" "$OUT/06_STAGED_TARGETS.txt"; then
  echo "BLOCKER: staged file set mismatch"
  git -C "$CURRENT" reset HEAD -- "${TARGETS[@]}" >/dev/null 2>&1 || true
  exit 32
fi

if ! git -C "$CURRENT" diff --cached --check > "$OUT/07_STAGED_DIFF_CHECK.txt" 2>&1; then
  echo "BLOCKER: staged diff check still failed"
  cat "$OUT/07_STAGED_DIFF_CHECK.txt"
  git -C "$CURRENT" reset HEAD -- "${TARGETS[@]}" >/dev/null 2>&1 || true
  exit 33
fi

git -C "$CURRENT" diff --cached --stat > "$OUT/08_STAGED_STAT.txt"
git -C "$CURRENT" diff --cached > "$OUT/08_STAGED_DIFF.patch"

COMMIT_MESSAGE="ingestion: preserve generic JSON documents"

if ! git -C "$CURRENT" commit -m "$COMMIT_MESSAGE" > "$OUT/09_COMMIT.txt" 2>&1; then
  echo "BLOCKER: commit failed"
  cat "$OUT/09_COMMIT.txt"
  git -C "$CURRENT" reset HEAD -- "${TARGETS[@]}" >/dev/null 2>&1 || true
  exit 34
fi

COMMIT="$(git -C "$CURRENT" rev-parse HEAD)"

git -C "$CURRENT" diff-tree --no-commit-id --name-only -r "$COMMIT" | sort \
  > "$OUT/10_COMMIT_TARGETS.txt"

if ! cmp -s "$OUT/06_EXPECTED_TARGETS.txt" "$OUT/10_COMMIT_TARGETS.txt"; then
  echo "BLOCKER: committed file set mismatch"
  echo "COMMIT=$COMMIT"
  exit 35
fi

TREE_REFRESH="NOT_RUN"
if [ -f "$HOME/PAN_REFRESH_FILE_TREE_TEXTS.sh" ]; then
  if bash "$HOME/PAN_REFRESH_FILE_TREE_TEXTS.sh" > "$OUT/11_TREE_REFRESH.txt" 2>&1; then
    TREE_REFRESH="PASS"
  else
    TREE_REFRESH="FAIL_NONBLOCKING"
  fi
else
  TREE_REFRESH="DEFERRED_SCRIPT_NOT_FOUND"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_JSON_CAPABILITY_PROMOTION_STAGE27B
UTC=$TS
STATUS=PASS
STAGE26B=$LATEST26B
TRAILING_WHITESPACE_CLEANUP=PASS
SEMANTIC_AST_IDENTITY=PASS
POST_CLEAN_REGRESSION=PASS
STAGED_DIFF_CHECK=PASS
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
echo "--- cleanup ---"
cat "$OUT/02_WHITESPACE_CLEANUP.txt"
echo
echo "--- commit ---"
cat "$OUT/09_COMMIT.txt"
echo
echo "--- regression tail ---"
tail -30 "$OUT/05_POST_CLEAN_REGRESSION.txt"
echo
echo "STAGE27B_COMPLETE=YES"
