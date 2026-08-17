#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
TESTS="$SERVICE/tests"
CHATGPT="$SERVICE/parsers/chatgpt.py"
RUN_ALL="$TESTS/run_all.py"
TESTFILE="$TESTS/test_chatgpt_markdown_fallback.py"
PYTHON="/usr/bin/python3"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_REPAIR_TXT_MARKDOWN_FALLBACK_$TS-STAGE35"
BACKUP="$OUT/pre"
SANDBOX="$OUT/sandbox"
mkdir -p "$BACKUP" "$SANDBOX"

echo "=== PAN — REPAIR TXT MARKDOWN FALLBACK / STAGE 35 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME" "$SERVICE" "$TESTS" "$CHATGPT" "$RUN_ALL"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST34="$(
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
    if "PAN_BOUND_TXT_ROUTING_DECISION_STAGE34" not in t:
        continue
    if "STATUS=PASS" not in t:
        continue
    if "TXT_TOTAL=40" not in t:
        continue
    if "NEXT=INTERPRET_STAGE34_CODE_PATH_AND_IF_CONFIRMED_BUILD_MINIMAL_TXT_REGRESSION_FIX" not in t:
        continue
    hits.append((d.stat().st_mtime_ns, d))
if hits:
    print(max(hits)[1])
PY
)"
[ -n "$LATEST34" ] && [ -d "$LATEST34" ] || {
  echo "BLOCKER: passing Stage34 evidence not found"
  exit 22
}

STAGE33="$(sed -n 's/^STAGE33=//p' "$LATEST34/SUMMARY.txt" | head -1)"
DETAIL="$STAGE33/02_TXT_DETAIL.tsv"
[ -n "$STAGE33" ] && [ -d "$STAGE33" ] || {
  echo "BLOCKER: Stage33 path missing from Stage34"
  exit 23
}
[ -f "$DETAIL" ] || {
  echo "BLOCKER: Stage33 TXT detail missing: $DETAIL"
  exit 24
}

"$PYTHON" - "$DETAIL" > "$OUT/00_STAGE33_PREFLIGHT.txt" <<'PY'
import csv, sys
from pathlib import Path
from collections import Counter

p = Path(sys.argv[1])
with p.open("r", encoding="utf-8", newline="") as h:
    rows = list(csv.DictReader(h, delimiter="\t"))

if len(rows) != 40:
    raise SystemExit(f"expected 40 TXT rows, got {len(rows)}")

manifest = Counter((r.get("manifest_kind_live") or "") for r in rows)
classes = Counter((r.get("classification") or "") for r in rows)

print("TXT_TOTAL=" + str(len(rows)))
print("MANIFEST_COUNTS=" + repr(dict(manifest)))
print("CLASS_COUNTS=" + repr(dict(classes)))

if manifest.get("markdown", 0) != 39:
    raise SystemExit("expected 39 markdown manifest cases")
if manifest.get("conversation", 0) != 1:
    raise SystemExit("expected 1 conversation manifest case")
if classes.get("TXT_VALIDATED_AS_CONVERSATION_WITHOUT_TURNS", 0) != 39:
    raise SystemExit("expected 39 no-turn misrouting cases")
if classes.get("TXT_CONVERSATION_SHAPE_WITHOUT_USER_TURN", 0) != 1:
    raise SystemExit("expected 1 genuine conversation missing-user case")

print("STAGE33_PREFLIGHT=PASS")
PY

echo "STAGE34=$LATEST34"
echo "STAGE33=$STAGE33"
cat "$OUT/00_STAGE33_PREFLIGHT.txt"
echo

LATEST22B="$(
  find "$TREE_HOME" -maxdepth 1 -type d \
    -name 'PAN_MANUAL_BATCH_MARKDOWN_PACKAGE_REPLAY_*-STAGE22B' \
    -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | head -1 | cut -d' ' -f2-
)"
[ -n "$LATEST22B" ] && [ -d "$LATEST22B" ] || {
  echo "BLOCKER: Stage22B historical Markdown replay evidence missing"
  exit 25
}
[ "$(sed -n 's/^STATUS=//p' "$LATEST22B/SUMMARY.txt" | head -1)" = "PASS" ] || {
  echo "BLOCKER: Stage22B is not PASS"
  exit 26
}
MD_SOURCE="$(sed -n 's/^PRESERVED_SOURCE_PAYLOAD=//p' "$LATEST22B/SUMMARY.txt" | head -1)"
[ -n "$MD_SOURCE" ] && [ -f "$MD_SOURCE" ] || {
  echo "BLOCKER: Stage22B preserved Markdown payload missing: $MD_SOURCE"
  exit 27
}

"$PYTHON" - "$CHATGPT" > "$OUT/01_CHATGPT_PREFLIGHT.txt" <<'PY'
import ast, sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
tree = ast.parse(text, filename=str(p))

fn = next(
    (n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "parse_chatgpt"),
    None,
)
if fn is None:
    raise SystemExit("parse_chatgpt() missing")
if "parse_markdown" not in text:
    raise SystemExit("parse_markdown import/use missing")

anchor = "\n".join([
    '    return {',
    '        "kind": "markdown",',
    '        "document": parse_markdown(source),',
    '    }',
    '',
])
if text.count(anchor) != 1:
    raise SystemExit("BLOCKER: exact dict-markdown fallback anchor not found exactly once")

print("DICT_MARKDOWN_FALLBACK=CONFIRMED")
print("CHATGPT_PREFLIGHT=PASS")
PY

[ ! -e "$TESTFILE" ] || {
  echo "BLOCKER: regression test path already exists: $TESTFILE"
  exit 28
}

cp -a "$CHATGPT" "$BACKUP/chatgpt.py"
cp -a "$RUN_ALL" "$BACKUP/run_all.py"
sha256sum "$CHATGPT" "$RUN_ALL" "$MD_SOURCE" > "$OUT/02_PRE_HASHES.sha256"
git -C "$CURRENT" status --short --branch > "$OUT/02_GIT_PRE.txt" 2>&1 || true

MUTATED=0
SUCCESS=0

rollback() {
  set +e
  if [ "$MUTATED" -eq 1 ]; then
    cp -a "$BACKUP/chatgpt.py" "$CHATGPT"
    cp -a "$BACKUP/run_all.py" "$RUN_ALL"
    rm -f "$TESTFILE"
    rm -f "$SERVICE/parsers/__pycache__/chatgpt."*.pyc 2>/dev/null || true
    rm -f "$TESTS/__pycache__/test_chatgpt_markdown_fallback."*.pyc 2>/dev/null || true
    echo "ROLLBACK=COMPLETE" | tee -a "$OUT/ROLLBACK.txt"
    MUTATED=0
  fi
  set -e
}

unexpected() {
  rc=$?
  if [ "$SUCCESS" -ne 1 ]; then
    echo "UNEXPECTED_FAILURE_EXIT=$rc" >> "$OUT/FAILURE.txt"
    rollback
  fi
  exit "$rc"
}
trap unexpected ERR INT TERM

fail_gate() {
  reason="$1"
  echo "FAIL_REASON=$reason" | tee "$OUT/FAILURE.txt"
  rollback
  cat > "$OUT/SUMMARY.txt" <<EOF
PAN_REPAIR_TXT_MARKDOWN_FALLBACK_STAGE35
UTC=$TS
STATUS=FAIL
FAIL_REASON=$reason
ROLLBACK=COMPLETE
STAGE34=$LATEST34
STAGE33=$STAGE33
SOURCE_MUTATION=NONE_EXPECTED
LIVE_INGESTION_EXECUTED=NO
LIVE_TXT_FIX=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
NEXT=INSPECT_ONLY_RECORDED_STAGE35_FAILED_GATE
EOF
  cat "$OUT/SUMMARY.txt"
  exit 1
}

"$PYTHON" - "$CHATGPT" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")

old = "\n".join([
    '    return {',
    '        "kind": "markdown",',
    '        "document": parse_markdown(source),',
    '    }',
    '',
])
new = "    return parse_markdown(source)\n"

if text.count(old) != 1:
    raise SystemExit("fallback anchor drifted before patch")

p.write_text(text.replace(old, new, 1), encoding="utf-8")
PY

cat > "$TESTFILE" <<'PY'
from pathlib import Path
from tempfile import TemporaryDirectory

from ..parsers.chatgpt import parse_chatgpt
from ..parsers.markdown import parse_markdown


def main():
    with TemporaryDirectory(
        prefix="difference-engine-txt-fallback-"
    ) as tmp:
        root = Path(tmp)

        plain = root / "plain.txt"
        plain.write_text(
            "# Plain Artifact\n\n"
            "This is ordinary non-conversation text.\n",
            encoding="utf-8",
        )

        expected = parse_markdown(plain)
        actual = parse_chatgpt(plain)

        assert not isinstance(actual, dict)
        assert type(actual) is type(expected)
        assert actual == expected

        chat = root / "chat.txt"
        chat.write_text(
            "User: hello\nAssistant: hi\n",
            encoding="utf-8",
        )

        conversation = parse_chatgpt(chat)
        assert isinstance(conversation, dict)
        assert conversation.get("kind") == "conversation"

    print("PASS")


if __name__ == "__main__":
    main()
PY

TEST_MODULE="$(
"$PYTHON" - "$RUN_ALL" <<'PY'
import ast, sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
tree = ast.parse(text, filename=str(p))

assign = next(
    (
        n for n in tree.body
        if isinstance(n, ast.Assign)
        and any(isinstance(t, ast.Name) and t.id == "TESTS" for t in n.targets)
    ),
    None,
)
if assign is None or not isinstance(assign.value, (ast.Tuple, ast.List)):
    raise SystemExit("TESTS tuple/list not found")

entries = []
for elt in assign.value.elts:
    if not isinstance(elt, ast.Constant) or not isinstance(elt.value, str):
        raise SystemExit("non-string TESTS entry")
    entries.append(elt.value)

prefixes = {x.rsplit(".", 1)[0] for x in entries}
if len(prefixes) != 1:
    raise SystemExit("TESTS namespace not uniform")

prefix = next(iter(prefixes))
target = prefix + ".test_chatgpt_markdown_fallback"
if target in entries:
    raise SystemExit("fallback test already registered")

lines = text.splitlines(keepends=True)
insert_at = assign.end_lineno - 1
lines.insert(insert_at, f'    "{target}",\n')
p.write_text("".join(lines), encoding="utf-8")
print(target)
PY
)"

MUTATED=1
mkdir -p "$OUT/candidate"
cp -a "$CHATGPT" "$OUT/candidate/chatgpt.py"
cp -a "$RUN_ALL" "$OUT/candidate/run_all.py"
cp -a "$TESTFILE" "$OUT/candidate/test_chatgpt_markdown_fallback.py"
sha256sum "$CHATGPT" "$RUN_ALL" "$TESTFILE" > "$OUT/03_CANDIDATE_HASHES.sha256"

if ! "$PYTHON" -m py_compile "$CHATGPT" "$RUN_ALL" "$TESTFILE" > "$OUT/04_COMPILE.txt" 2>&1; then
  fail_gate "COMPILE_FAILED"
fi

if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" -m "$TEST_MODULE"
) > "$OUT/05_TARGETED_FALLBACK_TEST.txt" 2>&1; then
  fail_gate "TARGETED_FALLBACK_TEST_FAILED"
fi

if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" "$RUN_ALL"
) > "$OUT/06_FULL_REGRESSION.txt" 2>&1; then
  fail_gate "FULL_REGRESSION_FAILED"
fi

TXT_REPLAY_ROOT="$SANDBOX/historical-markdown-as-txt"
TXT_REPLAY_SOURCE="$TXT_REPLAY_ROOT/replay.txt"
TXT_REPLAY_RECEIPTS="$TXT_REPLAY_ROOT/receipts"
TXT_REPLAY_OUTPUT="$TXT_REPLAY_ROOT/output"
TXT_REPLAY_RUNROOT="$TXT_REPLAY_ROOT/runroot"
mkdir -p "$TXT_REPLAY_RECEIPTS" "$TXT_REPLAY_OUTPUT" "$TXT_REPLAY_RUNROOT"

cp --reflink=auto "$MD_SOURCE" "$TXT_REPLAY_SOURCE" 2>/dev/null || cp "$MD_SOURCE" "$TXT_REPLAY_SOURCE"
cmp -s "$MD_SOURCE" "$TXT_REPLAY_SOURCE" || fail_gate "HISTORICAL_PAYLOAD_COPY_MISMATCH"

export PAN35_REPLAY_SOURCE="$TXT_REPLAY_SOURCE"
export PAN35_REPLAY_RECEIPTS="$TXT_REPLAY_RECEIPTS"
export PAN35_REPLAY_OUTPUT="$TXT_REPLAY_OUTPUT"

if ! (
  cd "$TXT_REPLAY_RUNROOT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - <<'PY'
import json, os
from pathlib import Path
from workspace.operational.ingestion.service.batch import ingest_sources

source = Path(os.environ["PAN35_REPLAY_SOURCE"]).resolve()
outputs = ingest_sources(
    sources=(source,),
    receipt_root=Path(os.environ["PAN35_REPLAY_RECEIPTS"]).resolve(),
    output_root=Path(os.environ["PAN35_REPLAY_OUTPUT"]).resolve(),
    source_class="manual_batch",
)

print("OUTPUT_COUNT=" + str(len(outputs)))
if len(outputs) != 1:
    raise SystemExit("expected exactly one replay output")

out = Path(outputs[0])
manifest = json.loads((out / "reports/manifest.json").read_text(encoding="utf-8"))
validation = json.loads((out / "reports/validation.json").read_text(encoding="utf-8"))

print("MANIFEST_KIND=" + repr(manifest.get("kind")))
print("VALIDATION=" + repr(validation))

if manifest.get("kind") != "markdown":
    raise SystemExit("TXT replay did not converge on markdown manifest kind")
if validation.get("passed") is not True:
    raise SystemExit("historical markdown payload failed through TXT fallback")
if validation.get("errors") not in ([], None):
    raise SystemExit("historical TXT replay produced validation errors")

print("HISTORICAL_MARKDOWN_AS_TXT_REPLAY=PASS")
PY
) > "$OUT/07_HISTORICAL_MARKDOWN_AS_TXT_REPLAY.txt" 2>&1; then
  fail_gate "HISTORICAL_MARKDOWN_AS_TXT_REPLAY_FAILED"
fi

export PAN35_DETAIL="$DETAIL"
export PAN35_SANDBOX="$SANDBOX/txt40"

if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter
import csv
import hashlib
import json
import os

from workspace.operational.ingestion.service.batch import ingest_sources

detail = Path(os.environ["PAN35_DETAIL"])
root = Path(os.environ["PAN35_SANDBOX"])
root.mkdir(parents=True, exist_ok=True)

with detail.open("r", encoding="utf-8", newline="") as h:
    rows = list(csv.DictReader(h, delimiter="\t"))
if len(rows) != 40:
    raise SystemExit(f"expected 40 rows, got {len(rows)}")

ledger = root / "RETEST.tsv"
result_rows = []
hash_fail = []
exceptions = []

for i, r in enumerate(rows, start=1):
    source = Path(r["source"]).resolve()
    expected_hash = (r.get("sha256_now") or r.get("sha256_stage30") or "").strip()

    before = hashlib.sha256(source.read_bytes()).hexdigest()
    if before != expected_hash:
        hash_fail.append(str(source))
        continue

    case = root / f"{i:03d}"
    receipts = case / "receipts"
    output = case / "output"
    runroot = case / "runroot"
    receipts.mkdir(parents=True)
    output.mkdir(parents=True)
    runroot.mkdir(parents=True)

    old_cwd = Path.cwd()
    try:
        os.chdir(runroot)
        outs = ingest_sources(
            sources=(source,),
            receipt_root=receipts,
            output_root=output,
            source_class="manual_batch",
        )
    except Exception as e:
        exceptions.append((str(source), f"{type(e).__name__}: {e}"))
        outs = []
    finally:
        os.chdir(old_cwd)

    after = hashlib.sha256(source.read_bytes()).hexdigest()
    if after != before:
        hash_fail.append(str(source))

    manifest_kind = ""
    errors = []
    passed = False
    outpath = ""

    if outs:
        outpath = str(Path(outs[0]).resolve())
        pkg = Path(outs[0])
        try:
            manifest = json.loads((pkg / "reports/manifest.json").read_text(encoding="utf-8"))
            validation = json.loads((pkg / "reports/validation.json").read_text(encoding="utf-8"))
            manifest_kind = str(manifest.get("kind", ""))
            errors = [str(x) for x in (validation.get("errors") or [])]
            passed = validation.get("passed") is True
        except Exception as e:
            exceptions.append((str(source), f"artifact-read:{type(e).__name__}: {e}"))

    result_rows.append({
        "source": str(source),
        "old_manifest_kind": r.get("manifest_kind_live", ""),
        "new_manifest_kind": manifest_kind,
        "old_failure_signature": r.get("failure_signature", ""),
        "new_passed": passed,
        "new_errors": json.dumps(errors, ensure_ascii=False, sort_keys=True),
        "invalid_conversation_kind": "invalid_conversation_kind" in errors,
        "no_conversation_turns": "no_conversation_turns" in errors,
        "missing_user_turn": "missing_user_turn" in errors,
        "output": outpath,
    })

if hash_fail:
    raise SystemExit("source hash drift: " + repr(hash_fail))
if exceptions:
    print("EXCEPTIONS=" + repr(exceptions))
    raise SystemExit(f"{len(exceptions)} sandbox retest exceptions")

with ledger.open("w", encoding="utf-8", newline="") as h:
    fields = list(result_rows[0].keys())
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(result_rows)

old_md = [x for x in result_rows if x["old_manifest_kind"] == "markdown"]
old_conv = [x for x in result_rows if x["old_manifest_kind"] == "conversation"]
if len(old_md) != 39 or len(old_conv) != 1:
    raise SystemExit("Stage33 39/1 partition drift")

md_kind_ok = sum(x["new_manifest_kind"] == "markdown" for x in old_md)
md_bad_conv_error = sum(
    x["invalid_conversation_kind"] or x["no_conversation_turns"]
    for x in old_md
)
conv_kind_ok = sum(x["new_manifest_kind"] == "conversation" for x in old_conv)
pass_count = sum(bool(x["new_passed"]) for x in result_rows)
fail_count = len(result_rows) - pass_count

new_error_counts = Counter()
for x in result_rows:
    for e in json.loads(x["new_errors"]):
        new_error_counts[e] += 1

print(f"TXT_TOTAL={len(result_rows)}")
print(f"PRIOR_MARKDOWN_CASES={len(old_md)}")
print(f"PRIOR_CONVERSATION_CASES={len(old_conv)}")
print(f"MARKDOWN_KIND_PRESERVED={md_kind_ok}")
print(f"MARKDOWN_CASES_WITH_CONVERSATION_ERRORS={md_bad_conv_error}")
print(f"GENUINE_CONVERSATION_KIND_PRESERVED={conv_kind_ok}")
print(f"NEW_PASS_COUNT={pass_count}")
print(f"NEW_FAIL_COUNT={fail_count}")
print("NEW_ERROR_COUNTS=" + repr(dict(new_error_counts)))
print(f"LEDGER={ledger}")

if md_kind_ok != 39:
    raise SystemExit("not all 39 fallback cases remained markdown")
if md_bad_conv_error != 0:
    raise SystemExit("conversation-only validation errors remain on markdown fallback")
if conv_kind_ok != 1:
    raise SystemExit("genuine conversation case lost conversation kind")

print("TXT40_RETEST=PASS")
PY
) > "$OUT/08_TXT40_RETEST.txt" 2>&1; then
  fail_gate "TXT40_SANDBOX_RETEST_FAILED"
fi

if ! "$PYTHON" - "$DETAIL" > "$OUT/09_SOURCE_HASH_RECHECK.txt" <<'PY'
import csv, hashlib, sys
from pathlib import Path

p = Path(sys.argv[1])
with p.open("r", encoding="utf-8", newline="") as h:
    rows = list(csv.DictReader(h, delimiter="\t"))

for r in rows:
    source = Path(r["source"]).resolve()
    expected = (r.get("sha256_now") or r.get("sha256_stage30") or "").strip()
    actual = hashlib.sha256(source.read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f"hash drift: {source}")

print(f"VERIFIED={len(rows)}")
print("SOURCE_HASHES=PASS")
PY
then
  fail_gate "TXT_SOURCE_HASH_RECHECK_FAILED"
fi

{
  echo "=== CANDIDATE HASHES ==="
  cat "$OUT/03_CANDIDATE_HASHES.sha256"
  echo
  echo "=== TARGETED DIFF ==="
  git -C "$CURRENT" diff -- \
    "workspace/operational/ingestion/service/parsers/chatgpt.py" \
    "workspace/operational/ingestion/service/tests/run_all.py" \
    "workspace/operational/ingestion/service/tests/test_chatgpt_markdown_fallback.py" \
    2>/dev/null || true
  echo
  echo "=== GIT POST ==="
  git -C "$CURRENT" status --short --branch 2>/dev/null || true
} > "$OUT/10_POST_STATE.txt"

SUCCESS=1
trap - ERR INT TERM

cat > "$OUT/CHANGELOG_EVENT.txt" <<EOF
UTC=$TS
EVENT=TXT_MARKDOWN_FALLBACK_REPRESENTATION_REPAIR_VALIDATED
CLASSIFICATION=VALIDATED_UNCOMMITTED_IMPLEMENTATION
CAUSE_EVIDENCE=39_TXT_MARKDOWN_MANIFEST_CASES_ENTERED_DICT_CONVERSATION_VALIDATION
REPAIR=NONCHAT_TXT_FALLBACK_RETURNS_NATIVE_MARKDOWN_REPRESENTATION
VALIDATOR_BROADENED=NO
CONVERSATION_GRAMMAR_CHANGED=NO
FULL_REGRESSION=PASS
HISTORICAL_MARKDOWN_AS_TXT_REPLAY=PASS
TXT40_SANDBOX_RETEST=PASS
SOURCE_HASHES=PASS
COMMIT_CREATED=NO
EOF

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_REPAIR_TXT_MARKDOWN_FALLBACK_STAGE35
UTC=$TS
STATUS=PASS
STAGE34=$LATEST34
STAGE33=$STAGE33
TXT_TOTAL=40
ROOT_CAUSE_BOUND=DICT_MARKDOWN_FALLBACK_CROSSED_CONVERSATION_VALIDATION_CONTRACT
REPAIR=RETURN_NATIVE_MARKDOWN_REPRESENTATION_FROM_NONCHAT_TXT_FALLBACK
TARGETED_REGRESSION=PASS
FULL_REGRESSION=PASS
HISTORICAL_MARKDOWN_AS_TXT_REPLAY=PASS
TXT40_SANDBOX_RETEST=PASS
SOURCE_HASHES=PASS
SOURCE_MUTATION=NONE
LIVE_INGESTION_EXECUTED=NO
VALIDATOR_BROADENED=NO
CONVERSATION_GRAMMAR_CHANGED=NO
LIVE_TXT_FIX=VALIDATED_UNCOMMITTED
ROLLBACK=NOT_REQUIRED
COMMIT_CREATED=NO
EVIDENCE=$OUT
CANDIDATE_HASHES=$OUT/03_CANDIDATE_HASHES.sha256
TXT40_RETEST=$OUT/08_TXT40_RETEST.txt
TXT40_LEDGER=$SANDBOX/txt40/RETEST.tsv
CHANGELOG_EVENT=$OUT/CHANGELOG_EVENT.txt
NEXT=PROMOTE_STAGE35_TXT_FALLBACK_REPAIR_ONLY_AFTER_HASH_RECHECK_AND_PRECOMMIT_REGRESSION
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- TXT40 retest ---"
cat "$OUT/08_TXT40_RETEST.txt"
echo
echo "--- historical Markdown as TXT replay ---"
cat "$OUT/07_HISTORICAL_MARKDOWN_AS_TXT_REPLAY.txt"
echo
echo "--- full regression tail ---"
tail -40 "$OUT/06_FULL_REGRESSION.txt"
echo
echo "STAGE35_COMPLETE=YES"
