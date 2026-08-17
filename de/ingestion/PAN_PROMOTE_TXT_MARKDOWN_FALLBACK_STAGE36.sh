#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
TESTS="$SERVICE/tests"
CHATGPT_REL="workspace/operational/ingestion/service/parsers/chatgpt.py"
RUN_ALL_REL="workspace/operational/ingestion/service/tests/run_all.py"
TEST_REL="workspace/operational/ingestion/service/tests/test_chatgpt_markdown_fallback.py"
CHATGPT="$CURRENT/$CHATGPT_REL"
RUN_ALL="$CURRENT/$RUN_ALL_REL"
TESTFILE="$CURRENT/$TEST_REL"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_PROMOTE_TXT_MARKDOWN_FALLBACK_$TS-STAGE36"

mkdir -p "$OUT"

echo "=== PAN — PROMOTE TXT MARKDOWN FALLBACK / STAGE 36 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME" "$SERVICE" "$TESTS" "$CHATGPT" "$RUN_ALL" "$TESTFILE"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST35="$(
  "$PYTHON" - "$TREE_HOME" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
hits = []
for d in root.iterdir():
    if not d.is_dir():
        continue
    s = d / "SUMMARY.txt"
    if not s.is_file():
        continue
    t = s.read_text(encoding="utf-8", errors="replace")
    if "PAN_REPAIR_TXT_MARKDOWN_FALLBACK_STAGE35" not in t:
        continue
    if "STATUS=PASS" not in t:
        continue
    if "LIVE_TXT_FIX=VALIDATED_UNCOMMITTED" not in t:
        continue
    if "FULL_REGRESSION=PASS" not in t:
        continue
    if "TXT40_SANDBOX_RETEST=PASS" not in t:
        continue
    if "NEXT=PROMOTE_STAGE35_TXT_FALLBACK_REPAIR_ONLY_AFTER_HASH_RECHECK_AND_PRECOMMIT_REGRESSION" not in t:
        continue
    hits.append((d.stat().st_mtime_ns, d))

if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST35" ] && [ -d "$LATEST35" ] || {
  echo "BLOCKER: passing Stage35 evidence not found"
  exit 22
}

CANDIDATE_HASHES="$(sed -n 's/^CANDIDATE_HASHES=//p' "$LATEST35/SUMMARY.txt" | head -1)"
TXT40_RETEST="$(sed -n 's/^TXT40_RETEST=//p' "$LATEST35/SUMMARY.txt" | head -1)"
CHANGELOG_EVENT="$(sed -n 's/^CHANGELOG_EVENT=//p' "$LATEST35/SUMMARY.txt" | head -1)"

for x in "$CANDIDATE_HASHES" "$TXT40_RETEST" "$CHANGELOG_EVENT"; do
  [ -f "$x" ] || { echo "BLOCKER: missing Stage35 artifact $x"; exit 23; }
done

echo "STAGE35=$LATEST35"
echo "CANDIDATE_HASHES=$CANDIDATE_HASHES"
echo

# -------------------------------------------------------------------
# Gate 0: working tree must contain exactly the validated implementation
# on the three intended paths. Other pre-existing repo drift may exist,
# but it is not staged or committed by this operation.
# -------------------------------------------------------------------
git -C "$CURRENT" status --short --branch > "$OUT/00_GIT_PRE.txt" 2>&1 || true
git -C "$CURRENT" diff -- "$CHATGPT_REL" "$RUN_ALL_REL" "$TEST_REL" \
  > "$OUT/00_TARGET_DIFF_PRE.patch" 2>&1 || true

# The new test is untracked, so preserve its content separately too.
cp -a "$TESTFILE" "$OUT/00_TESTFILE_PRE.py"

# Candidate hash recheck: compare Stage35 recorded hashes to current live files.
if ! "$PYTHON" - "$CANDIDATE_HASHES" "$CURRENT" \
  > "$OUT/01_CANDIDATE_HASH_RECHECK.txt" <<'PY'
from pathlib import Path
import hashlib
import sys

ledger = Path(sys.argv[1])
current = Path(sys.argv[2]).resolve()

records = []
for line in ledger.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    digest, path = line.split(None, 1)
    records.append((digest, Path(path).resolve()))

if len(records) != 3:
    raise SystemExit(f"expected 3 Stage35 candidate hashes, got {len(records)}")

for expected, path in records:
    if not path.is_file():
        raise SystemExit(f"missing candidate file: {path}")
    h = hashlib.sha256(path.read_bytes()).hexdigest()
    if h != expected:
        raise SystemExit(f"candidate hash drift: {path}")
    print(f"PASS\t{h}\t{path}")

print("CANDIDATE_HASHES=PASS")
PY
then
  echo "BLOCKER: Stage35 validated candidate has drifted"
  cat "$OUT/01_CANDIDATE_HASH_RECHECK.txt" || true
  exit 24
fi

# -------------------------------------------------------------------
# Gate 1: validate exact intended code shape.
# -------------------------------------------------------------------
if ! "$PYTHON" - "$CHATGPT" "$RUN_ALL" "$TESTFILE" \
  > "$OUT/02_SHAPE_RECHECK.txt" <<'PY'
from pathlib import Path
import ast
import sys

chatgpt = Path(sys.argv[1])
run_all = Path(sys.argv[2])
testfile = Path(sys.argv[3])

ct = chatgpt.read_text(encoding="utf-8")
if 'return parse_markdown(source)' not in ct:
    raise SystemExit("native Markdown fallback missing")
if '"kind": "markdown"' in ct and '"document": parse_markdown(source)' in ct:
    raise SystemExit("old dict Markdown fallback still present")

rt = run_all.read_text(encoding="utf-8")
if "test_chatgpt_markdown_fallback" not in rt:
    raise SystemExit("regression test not registered")

ast.parse(ct, filename=str(chatgpt))
ast.parse(rt, filename=str(run_all))
ast.parse(testfile.read_text(encoding="utf-8"), filename=str(testfile))

print("IMPLEMENTATION_SHAPE=PASS")
PY
then
  echo "BLOCKER: implementation shape recheck failed"
  cat "$OUT/02_SHAPE_RECHECK.txt" || true
  exit 25
fi

# -------------------------------------------------------------------
# Gate 2: compile and full regression immediately before commit.
# -------------------------------------------------------------------
if ! "$PYTHON" -m py_compile "$CHATGPT" "$RUN_ALL" "$TESTFILE" \
  > "$OUT/03_COMPILE.txt" 2>&1
then
  echo "BLOCKER: compile failed"
  cat "$OUT/03_COMPILE.txt" || true
  exit 26
fi

if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" "$RUN_ALL"
) > "$OUT/04_PRECOMMIT_FULL_REGRESSION.txt" 2>&1
then
  echo "BLOCKER: precommit full regression failed"
  tail -80 "$OUT/04_PRECOMMIT_FULL_REGRESSION.txt" || true
  exit 27
fi

# -------------------------------------------------------------------
# Gate 3: Stage35 TXT40 evidence must still say the representation bug
# is eliminated before promotion.
# -------------------------------------------------------------------
for required in \
  "TXT40_RETEST=PASS" \
  "MARKDOWN_KIND_PRESERVED=39" \
  "MARKDOWN_CASES_WITH_CONVERSATION_ERRORS=0" \
  "GENUINE_CONVERSATION_KIND_PRESERVED=1"
do
  grep -Fq "$required" "$TXT40_RETEST" || {
    echo "BLOCKER: Stage35 TXT40 evidence missing: $required"
    exit 28
  }
done

# -------------------------------------------------------------------
# Stage only the three validated implementation paths.
# -------------------------------------------------------------------
git -C "$CURRENT" reset --quiet
git -C "$CURRENT" add -- "$CHATGPT_REL" "$RUN_ALL_REL" "$TEST_REL"

git -C "$CURRENT" diff --cached --name-only > "$OUT/05_STAGED_PATHS.txt"

EXPECTED_PATHS="$OUT/05_EXPECTED_PATHS.txt"
printf '%s\n' \
  "$CHATGPT_REL" \
  "$RUN_ALL_REL" \
  "$TEST_REL" \
  | sort > "$EXPECTED_PATHS"

sort "$OUT/05_STAGED_PATHS.txt" > "$OUT/05_STAGED_PATHS.sorted.txt"

if ! cmp -s "$EXPECTED_PATHS" "$OUT/05_STAGED_PATHS.sorted.txt"; then
  echo "BLOCKER: staged path set is not exactly the validated repair"
  echo "--- expected ---"
  cat "$EXPECTED_PATHS"
  echo "--- staged ---"
  cat "$OUT/05_STAGED_PATHS.sorted.txt"
  git -C "$CURRENT" reset --quiet
  exit 29
fi

git -C "$CURRENT" diff --cached > "$OUT/06_STAGED_DIFF.patch"

# -------------------------------------------------------------------
# Commit narrow repair.
# -------------------------------------------------------------------
COMMIT_MESSAGE="ingestion: normalize non-chat TXT fallback to markdown"

if ! git -C "$CURRENT" commit -m "$COMMIT_MESSAGE" \
  > "$OUT/07_COMMIT.txt" 2>&1
then
  echo "BLOCKER: commit failed"
  cat "$OUT/07_COMMIT.txt" || true
  git -C "$CURRENT" reset --quiet
  exit 30
fi

COMMIT="$(git -C "$CURRENT" rev-parse HEAD)"
git -C "$CURRENT" show --stat --oneline --decorate --no-renames "$COMMIT" \
  > "$OUT/08_COMMIT_SHOW.txt"

# -------------------------------------------------------------------
# Post-commit regression: promotion is not accepted until current HEAD
# passes the same harness.
# -------------------------------------------------------------------
if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" "$RUN_ALL"
) > "$OUT/09_POSTCOMMIT_FULL_REGRESSION.txt" 2>&1
then
  cat > "$OUT/SUMMARY.txt" <<EOF
PAN_PROMOTE_TXT_MARKDOWN_FALLBACK_STAGE36
UTC=$TS
STATUS=FAIL_POSTCOMMIT_REGRESSION
STAGE35=$LATEST35
COMMIT=$COMMIT
COMMIT_CREATED=YES
POSTCOMMIT_REGRESSION=FAIL
EVIDENCE=$OUT
NEXT=REVERT_ONLY_STAGE36_COMMIT_AND_PRESERVE_FAILURE_EVIDENCE
EOF
  cat "$OUT/SUMMARY.txt"
  tail -80 "$OUT/09_POSTCOMMIT_FULL_REGRESSION.txt" || true
  exit 31
fi

# -------------------------------------------------------------------
# Verify commit scope and candidate hashes at committed HEAD.
# -------------------------------------------------------------------
git -C "$CURRENT" diff-tree --no-commit-id --name-only -r "$COMMIT" \
  | sort > "$OUT/10_COMMIT_PATHS.txt"

if ! cmp -s "$EXPECTED_PATHS" "$OUT/10_COMMIT_PATHS.txt"; then
  cat > "$OUT/SUMMARY.txt" <<EOF
PAN_PROMOTE_TXT_MARKDOWN_FALLBACK_STAGE36
UTC=$TS
STATUS=FAIL_COMMIT_SCOPE
STAGE35=$LATEST35
COMMIT=$COMMIT
COMMIT_CREATED=YES
POSTCOMMIT_REGRESSION=PASS
COMMIT_SCOPE=FAIL
EVIDENCE=$OUT
NEXT=REVERT_ONLY_STAGE36_COMMIT_AND_PRESERVE_FAILURE_EVIDENCE
EOF
  cat "$OUT/SUMMARY.txt"
  exit 32
fi

git -C "$CURRENT" status --short --branch > "$OUT/11_GIT_POST.txt" 2>&1 || true

# Changelog event: preserve provenance in Stage36 evidence without inventing
# a canonical changelog destination not yet recovered in this operation.
cat > "$OUT/CHANGELOG_EVENT.txt" <<EOF
UTC=$TS
EVENT=TXT_MARKDOWN_FALLBACK_REPAIR_PROMOTED
CLASSIFICATION=PROMOTED_IMPLEMENTATION
STAGE35=$LATEST35
COMMIT=$COMMIT
COMMIT_MESSAGE=$COMMIT_MESSAGE
REPAIR=NONCHAT_TXT_FALLBACK_RETURNS_NATIVE_MARKDOWN_REPRESENTATION
REGRESSION_TEST=$TEST_REL
PRECOMMIT_FULL_REGRESSION=PASS
POSTCOMMIT_FULL_REGRESSION=PASS
STAGE35_TXT40_RETEST=PASS
MARKDOWN_CASES_WITH_CONVERSATION_ERRORS=0
VALIDATOR_BROADENED=NO
CONVERSATION_GRAMMAR_CHANGED=NO
EOF

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_PROMOTE_TXT_MARKDOWN_FALLBACK_STAGE36
UTC=$TS
STATUS=PASS
STAGE35=$LATEST35
COMMIT=$COMMIT
COMMIT_MESSAGE=$COMMIT_MESSAGE
CANDIDATE_HASH_RECHECK=PASS
IMPLEMENTATION_SHAPE=PASS
PRECOMMIT_FULL_REGRESSION=PASS
POSTCOMMIT_FULL_REGRESSION=PASS
STAGE35_TXT40_RETEST=PASS
COMMIT_SCOPE=PASS
PROMOTED_PATH_COUNT=3
VALIDATOR_BROADENED=NO
CONVERSATION_GRAMMAR_CHANGED=NO
SOURCE_MUTATION=NONE
COMMIT_CREATED=YES
EVIDENCE=$OUT
STAGED_DIFF=$OUT/06_STAGED_DIFF.patch
COMMIT_SHOW=$OUT/08_COMMIT_SHOW.txt
CHANGELOG_EVENT=$OUT/CHANGELOG_EVENT.txt
NEXT=REQUALIFY_REMAINING_STAGE28_FAILURE_SET_AGAINST_PROMOTED_STAGE36_BEFORE_ANY_MARKDOWN_REPAIR
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- commit ---"
cat "$OUT/08_COMMIT_SHOW.txt"
echo
echo "--- postcommit regression tail ---"
tail -40 "$OUT/09_POSTCOMMIT_FULL_REGRESSION.txt"
echo
echo "STAGE36_COMPLETE=YES"
