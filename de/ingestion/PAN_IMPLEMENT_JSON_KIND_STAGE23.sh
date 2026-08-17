#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_JSON_KIND_IMPLEMENT_$TS-STAGE23"

SERVICE="$CURRENT/workspace/operational/ingestion/service"
PARSERS="$SERVICE/parsers"
TESTS="$SERVICE/tests"
REGISTRY="$SERVICE/registry.py"
VALIDATION="$SERVICE/validation.py"
RUN_ALL="$TESTS/run_all.py"

JSON_PARSER="$PARSERS/json_document.py"
JSON_PARSER_TEST="$TESTS/test_json_parser.py"
JSON_VALIDATION_TEST="$TESTS/test_json_validation.py"

BACKUP="$OUT/pre"
CANDIDATE="$OUT/candidate"
SANDBOX="$OUT/sandbox"
mkdir -p "$BACKUP" "$CANDIDATE" "$SANDBOX"

echo "=== PAN — JSON KIND IMPLEMENTATION STAGE 23 ==="
echo "CURRENT=$CURRENT"
echo "SERVICE=$SERVICE"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$SERVICE" "$PARSERS" "$TESTS" "$REGISTRY" "$VALIDATION" "$RUN_ALL"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

# -------------------------------------------------------------------
# Recover exact evidence gates.
# -------------------------------------------------------------------
LATEST22B="$(
  find "$TREE_HOME" -maxdepth 1 -type d \
    -name 'PAN_MANUAL_BATCH_MARKDOWN_PACKAGE_REPLAY_*-STAGE22B' \
    -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | head -1 | cut -d' ' -f2-
)"

[ -n "$LATEST22B" ] && [ -d "$LATEST22B" ] || {
  echo "BLOCKER: Stage 22B evidence missing"
  exit 22
}

STATUS22B="$(sed -n 's/^STATUS=//p' "$LATEST22B/SUMMARY.txt" | head -1)"
PAYLOAD22B="$(sed -n 's/^PRESERVED_SOURCE_PAYLOAD=//p' "$LATEST22B/SUMMARY.txt" | head -1)"

[ "$STATUS22B" = "PASS" ] || {
  echo "BLOCKER: Stage22B is not PASS: $STATUS22B"
  exit 23
}
[ -n "$PAYLOAD22B" ] && [ -f "$PAYLOAD22B" ] || {
  echo "BLOCKER: Stage22B payload missing: $PAYLOAD22B"
  exit 24
}

LATEST13="$(
  find "$TREE_HOME" -maxdepth 1 -type d \
    -name 'PAN_FIRST_NONCONVERSATION_INGEST_*-STAGE13' \
    -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | head -1 | cut -d' ' -f2-
)"

[ -n "$LATEST13" ] && [ -d "$LATEST13" ] || {
  echo "BLOCKER: Stage13 evidence missing"
  exit 25
}

JSON_SOURCE="$(
  grep -Rhs '^SOURCE=' "$LATEST13" 2>/dev/null \
  | head -1 | sed 's/^SOURCE=//'
)"

[ -n "$JSON_SOURCE" ] && [ -f "$JSON_SOURCE" ] || {
  echo "BLOCKER: exact Stage13 JSON source not found"
  exit 26
}

case "${JSON_SOURCE,,}" in
  *.json) ;;
  *)
    echo "BLOCKER: Stage13 source is not JSON: $JSON_SOURCE"
    exit 27
    ;;
esac

echo "MARKDOWN_REPLAY_PAYLOAD=$PAYLOAD22B"
echo "JSON_SOURCE=$JSON_SOURCE"

# Stage17 rolled back. Do not overwrite drift.
for x in "$JSON_PARSER" "$JSON_PARSER_TEST" "$JSON_VALIDATION_TEST"; do
  if [ -e "$x" ]; then
    echo "BLOCKER: unexpected existing JSON implementation/test: $x"
    exit 28
  fi
done

# -------------------------------------------------------------------
# Preserve pre-state.
# -------------------------------------------------------------------
cp -a "$REGISTRY" "$BACKUP/registry.py"
cp -a "$VALIDATION" "$BACKUP/validation.py"
cp -a "$RUN_ALL" "$BACKUP/run_all.py"

{
  echo "UTC=$TS"
  echo "STAGE22B=$LATEST22B"
  echo "MARKDOWN_REPLAY_PAYLOAD=$PAYLOAD22B"
  echo "STAGE13=$LATEST13"
  echo "JSON_SOURCE=$JSON_SOURCE"
  echo
  echo "=== ACTIVE HASHES ==="
  sha256sum "$REGISTRY" "$VALIDATION" "$RUN_ALL"
  echo
  echo "=== SOURCE HASHES ==="
  sha256sum "$PAYLOAD22B" "$JSON_SOURCE"
  echo
  echo "=== GIT PRE ==="
  git -C "$CURRENT" status --short --branch 2>/dev/null || true
} > "$OUT/00_PRE_STATE.txt"

sha256sum "$PAYLOAD22B" > "$OUT/00_MARKDOWN_SOURCE.sha256"
sha256sum "$JSON_SOURCE" > "$OUT/00_JSON_SOURCE.sha256"

# -------------------------------------------------------------------
# Preflight: require exact runtime parser state and validator primitives.
# Preserve later conversation-validation refinements; do not replace function.
# -------------------------------------------------------------------
(
  cd "$CURRENT"
  PYTHONPATH="$CURRENT${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - <<'PY'
from workspace.operational.ingestion.service import registry

keys = set(registry.PARSERS)
print("RUNTIME_KEYS=" + repr(sorted(keys)))
if keys != {".md", ".txt"}:
    raise SystemExit("BLOCKER: parser registry drift before Stage23")
print("REGISTRY_PREFLIGHT=PASS")
PY
) > "$OUT/01_REGISTRY_PREFLIGHT.txt" 2>&1

"$PYTHON" - "$VALIDATION" > "$OUT/02_VALIDATION_PREFLIGHT.txt" <<'PY'
import ast, sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
tree = ast.parse(text, filename=str(p))

validate = next(
    (n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "validate"),
    None,
)
if validate is None:
    raise SystemExit("BLOCKER: validate() not found")

dict_branch = None
assets_gate = None

for n in ast.walk(validate):
    if isinstance(n, ast.If):
        try:
            test = ast.unparse(n.test)
        except Exception:
            test = ""
        compact = test.replace(" ", "")
        if compact == "isinstance(parsed,dict)":
            dict_branch = n
        if compact in {"notassets", "not(assets)"}:
            assets_gate = n

if dict_branch is None:
    raise SystemExit("BLOCKER: parsed-dict validation branch not found")
if assets_gate is None:
    raise SystemExit("BLOCKER: no_assets gate not found")

required_strings = {
    "invalid_conversation_kind",
    "no_conversation_turns",
    "no_assets",
    "no_queue_candidates",
}
strings = {
    n.value for n in ast.walk(validate)
    if isinstance(n, ast.Constant) and isinstance(n.value, str)
}
missing = required_strings - strings
if missing:
    raise SystemExit("BLOCKER: validator drift; missing " + repr(sorted(missing)))

if "missing_json_document" in strings:
    raise SystemExit("BLOCKER: JSON validator already present unexpectedly")

print(f"DICT_BRANCH_LINE={dict_branch.lineno}")
print(f"ASSETS_GATE_LINE={assets_gate.lineno}")
print("VALIDATION_PREFLIGHT=PASS")
PY

MUTATED=0
SUCCESS=0

rollback() {
  set +e
  if [ "$MUTATED" -eq 1 ]; then
    cp -a "$BACKUP/registry.py" "$REGISTRY"
    cp -a "$BACKUP/validation.py" "$VALIDATION"
    cp -a "$BACKUP/run_all.py" "$RUN_ALL"
    rm -f "$JSON_PARSER" "$JSON_PARSER_TEST" "$JSON_VALIDATION_TEST"
    rm -f "$PARSERS/__pycache__/json_document."*.pyc 2>/dev/null || true
    rm -f "$TESTS/__pycache__/test_json_parser."*.pyc 2>/dev/null || true
    rm -f "$TESTS/__pycache__/test_json_validation."*.pyc 2>/dev/null || true
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
  local reason="$1"
  local rc="${2:-1}"
  echo "FAIL_REASON=$reason" | tee "$OUT/FAILURE.txt"
  rollback
  cat > "$OUT/SUMMARY.txt" <<EOF
PAN_JSON_KIND_IMPLEMENT_STAGE23
UTC=$TS
STATUS=FAIL
FAIL_REASON=$reason
ROLLBACK=COMPLETE
LIVE_JSON_CAPABILITY=NO
SOURCE_MUTATION=NONE_EXPECTED
EVIDENCE=$OUT
NEXT=INSPECT_ONLY_RECORDED_FAILED_GATE
EOF
  cat "$OUT/SUMMARY.txt"
  exit "$rc"
}

# -------------------------------------------------------------------
# Implement minimal JSON parser.
# -------------------------------------------------------------------
cat > "$JSON_PARSER" <<'PY'
import json
from pathlib import Path


def parse_json(source: Path):
    with source.open(
        "r",
        encoding="utf-8-sig",
    ) as handle:
        document = json.load(handle)

    return {
        "kind": "json",
        "document": document,
    }
PY

cat > "$JSON_PARSER_TEST" <<'PY'
import json
from pathlib import Path
from tempfile import TemporaryDirectory

from ..parsers.json_document import parse_json
from ..registry import parser_for


def main():
    expected = {
        "alpha": 1,
        "nested": [True, None, "x"],
    }

    with TemporaryDirectory(
        prefix="difference-engine-json-parser-"
    ) as tmp:
        source = Path(tmp) / "fixture.json"
        source.write_text(
            json.dumps(expected),
            encoding="utf-8",
        )

        parsed = parse_json(source)

        assert parsed["kind"] == "json"
        assert parsed["document"] == expected
        assert parser_for(source) is parse_json

    print("PASS")


if __name__ == "__main__":
    main()
PY

# -------------------------------------------------------------------
# Patch registry using strict anchors after runtime preflight.
# -------------------------------------------------------------------
"$PYTHON" - "$REGISTRY" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")

import_anchor = "from .parsers.markdown import parse_markdown\n"
map_anchor = '    ".txt": parse_chatgpt,\n'

if text.count(import_anchor) != 1:
    raise SystemExit("registry import anchor not unique")
if text.count(map_anchor) != 1:
    raise SystemExit("registry mapping anchor not unique")
if ".parsers.json_document" in text or '".json"' in text:
    raise SystemExit("JSON registry wiring already exists")

text = text.replace(
    import_anchor,
    import_anchor + "from .parsers.json_document import parse_json\n",
    1,
)
text = text.replace(
    map_anchor,
    map_anchor + '    ".json": parse_json,\n',
    1,
)

p.write_text(text, encoding="utf-8")
PY

# -------------------------------------------------------------------
# Patch only the JSON kind edge in validation.py.
#
# Existing behavior is preserved:
#   non-dict parsed object -> existing Markdown/title validation
#   dict conversation      -> all existing conversation checks, unchanged
#   unknown dict           -> existing invalid-conversation behavior, unchanged
#
# New behavior:
#   dict with kind=json -> require document key, do not require conversation turns,
#                          and do not require extracted assets.
# -------------------------------------------------------------------
"$PYTHON" - "$VALIDATION" <<'PY'
import ast, sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
lines = text.splitlines(keepends=True)
tree = ast.parse(text, filename=str(p))

validate = next(
    (n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "validate"),
    None,
)
if validate is None:
    raise SystemExit("validate() not found")

dict_branch = None
assets_gate = None

for n in ast.walk(validate):
    if not isinstance(n, ast.If):
        continue
    try:
        test = ast.unparse(n.test)
    except Exception:
        test = ""
    compact = test.replace(" ", "")
    if compact == "isinstance(parsed,dict)":
        dict_branch = n
    if compact in {"notassets", "not(assets)"}:
        assets_gate = n

if dict_branch is None or not dict_branch.body:
    raise SystemExit("parsed dict branch not found")
if assets_gate is None:
    raise SystemExit("assets gate not found")

# Do not double-patch.
if "missing_json_document" in text:
    raise SystemExit("JSON validation already present")

# Indent the complete current body of the dict branch by one level.
# This preserves any later conversation-validation refinements verbatim.
body_start = dict_branch.body[0].lineno - 1
body_end = dict_branch.body[-1].end_lineno - 1

for i in range(body_start, body_end + 1):
    lines[i] = "    " + lines[i]

if_line_index = dict_branch.lineno - 1
indent = lines[if_line_index][:len(lines[if_line_index]) - len(lines[if_line_index].lstrip())]
inner = indent + "    "

insertion = [
    inner + 'if parsed.get("kind") == "json":\n',
    inner + '    if "document" not in parsed:\n',
    inner + '        errors.append("missing_json_document")\n',
    inner + "else:\n",
]

# Insert after `if isinstance(parsed, dict):`
lines[if_line_index + 1:if_line_index + 1] = insertion

# The prior insertion shifts the assets gate down.
shift = len(insertion)
assets_line_index = assets_gate.lineno - 1 + shift
original = lines[assets_line_index]
assets_indent = original[:len(original) - len(original.lstrip())]

if original.strip() != "if not assets:":
    raise SystemExit(
        "assets gate line drift after insertion: " + repr(original)
    )

lines[assets_line_index] = (
    assets_indent
    + 'if not assets and not (isinstance(parsed, dict) and parsed.get("kind") == "json"):\n'
)

candidate = "".join(lines)
ast.parse(candidate, filename=str(p))
p.write_text(candidate, encoding="utf-8")
PY

cat > "$JSON_VALIDATION_TEST" <<'PY'
from types import SimpleNamespace

from ..validation import validate


def main():
    receipt = SimpleNamespace(receipt_id="TEST-JSON-VALIDATION")

    valid = validate(
        receipt,
        {
            "kind": "json",
            "document": {
                "alpha": 1,
            },
        },
        [],
        [],
        [],
    )
    assert valid.passed is True
    assert valid.errors == []

    missing_document = validate(
        receipt,
        {
            "kind": "json",
        },
        [],
        [],
        [],
    )
    assert missing_document.passed is False
    assert "missing_json_document" in missing_document.errors

    # Preserve the pre-existing unknown-dict behavior.
    unknown = validate(
        receipt,
        {
            "kind": "not-a-supported-kind",
        },
        [],
        [],
        [],
    )
    assert unknown.passed is False
    assert "invalid_conversation_kind" in unknown.errors
    assert "no_conversation_turns" in unknown.errors
    assert "no_assets" in unknown.errors

    print("PASS")


if __name__ == "__main__":
    main()
PY

# -------------------------------------------------------------------
# Add both tests to existing TESTS tuple/list without assuming namespace.
# -------------------------------------------------------------------
TEST_MODULES="$(
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
        raise SystemExit("TESTS contains non-string entry")
    entries.append(elt.value)

prefixes = {x.rsplit(".", 1)[0] for x in entries}
if len(prefixes) != 1:
    raise SystemExit("TESTS namespace is not uniform")

prefix = next(iter(prefixes))
targets = [
    prefix + ".test_json_parser",
    prefix + ".test_json_validation",
]

for target in targets:
    if target in entries:
        raise SystemExit("test already registered: " + target)

lines = text.splitlines(keepends=True)
insert_at = assign.end_lineno - 1

for target in targets:
    lines.insert(insert_at, f'    "{target}",\n')
    insert_at += 1

p.write_text("".join(lines), encoding="utf-8")
print("\n".join(targets))
PY
)"

MUTATED=1

# Preserve candidate immediately.
cp -a "$REGISTRY" "$CANDIDATE/registry.py"
cp -a "$VALIDATION" "$CANDIDATE/validation.py"
cp -a "$RUN_ALL" "$CANDIDATE/run_all.py"
cp -a "$JSON_PARSER" "$CANDIDATE/json_document.py"
cp -a "$JSON_PARSER_TEST" "$CANDIDATE/test_json_parser.py"
cp -a "$JSON_VALIDATION_TEST" "$CANDIDATE/test_json_validation.py"

sha256sum \
  "$REGISTRY" "$VALIDATION" "$RUN_ALL" \
  "$JSON_PARSER" "$JSON_PARSER_TEST" "$JSON_VALIDATION_TEST" \
  > "$OUT/03_CANDIDATE_HASHES.sha256"

# -------------------------------------------------------------------
# Gate 1: compile.
# -------------------------------------------------------------------
if ! "$PYTHON" -m py_compile \
  "$REGISTRY" "$VALIDATION" "$RUN_ALL" \
  "$JSON_PARSER" "$JSON_PARSER_TEST" "$JSON_VALIDATION_TEST" \
  > "$OUT/04_COMPILE.txt" 2>&1
then
  fail_gate "COMPILE_FAILED"
fi

# Gate 2: targeted new tests.
while IFS= read -r TEST_MODULE; do
  [ -n "$TEST_MODULE" ] || continue
  if ! (
    cd "$CURRENT"
    PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
      "$PYTHON" -m "$TEST_MODULE"
  ) >> "$OUT/05_TARGETED_TESTS.txt" 2>&1
  then
    fail_gate "TARGETED_JSON_TEST_FAILED"
  fi
done <<< "$TEST_MODULES"

# Gate 3: runtime registry.
if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - <<'PY'
from pathlib import Path
from workspace.operational.ingestion.service import registry
from workspace.operational.ingestion.service.registry import parser_for

keys = set(registry.PARSERS)
print("RUNTIME_KEYS=" + repr(sorted(keys)))
if keys != {".md", ".txt", ".json"}:
    raise SystemExit("unexpected runtime registry")

fn = parser_for(Path("/tmp/PAN_STAGE23.json"))
print("JSON_PARSER=" + fn.__module__ + "." + fn.__name__)
if fn.__name__ != "parse_json":
    raise SystemExit("JSON parser binding mismatch")
PY
) > "$OUT/06_RUNTIME_REGISTRY.txt" 2>&1
then
  fail_gate "RUNTIME_REGISTRY_FAILED"
fi

# Gate 4: entire existing regression suite + new tests.
if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" "$RUN_ALL"
) > "$OUT/07_FULL_REGRESSION.txt" 2>&1
then
  fail_gate "FULL_REGRESSION_FAILED"
fi

# -------------------------------------------------------------------
# Gate 5: replay the proven historical manual_batch Markdown payload.
# This proves the JSON extension did not regress the existing generic path.
# -------------------------------------------------------------------
MD_RUNROOT="$SANDBOX/markdown/runroot"
MD_RECEIPTS="$SANDBOX/markdown/receipts"
MD_OUTPUT="$SANDBOX/markdown/output"
mkdir -p "$MD_RUNROOT" "$MD_RECEIPTS" "$MD_OUTPUT"

export PAN23_MD_SOURCE="$PAYLOAD22B"
export PAN23_MD_RECEIPTS="$MD_RECEIPTS"
export PAN23_MD_OUTPUT="$MD_OUTPUT"

if ! (
  cd "$MD_RUNROOT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - <<'PY'
import json, os
from pathlib import Path
from workspace.operational.ingestion.service.batch import ingest_sources

source = Path(os.environ["PAN23_MD_SOURCE"]).resolve()
outputs = ingest_sources(
    sources=(source,),
    receipt_root=Path(os.environ["PAN23_MD_RECEIPTS"]).resolve(),
    output_root=Path(os.environ["PAN23_MD_OUTPUT"]).resolve(),
    source_class="manual_batch",
)

if len(outputs) != 1:
    raise SystemExit("markdown replay output count mismatch")

out = Path(outputs[0])
manifest = json.loads((out / "reports/manifest.json").read_text(encoding="utf-8"))
validation = json.loads((out / "reports/validation.json").read_text(encoding="utf-8"))

print("MANIFEST_KIND=" + repr(manifest.get("kind")))
print("VALIDATION=" + repr(validation))

if manifest.get("kind") != "markdown":
    raise SystemExit("markdown kind drift")
if validation.get("passed") is not True or validation.get("errors") not in ([], None):
    raise SystemExit("markdown validation regression")

print("MARKDOWN_REPLAY=PASS")
PY
) > "$OUT/08_MARKDOWN_REPLAY.txt" 2> "$OUT/08_MARKDOWN_REPLAY.stderr.txt"
then
  fail_gate "MARKDOWN_REPLAY_REGRESSION"
fi

# -------------------------------------------------------------------
# Gate 6: exact Stage13 JSON source through manual_batch.
# -------------------------------------------------------------------
JSON_RUNROOT="$SANDBOX/json/runroot"
JSON_RECEIPTS="$SANDBOX/json/receipts"
JSON_OUTPUT="$SANDBOX/json/output"
mkdir -p "$JSON_RUNROOT" "$JSON_RECEIPTS" "$JSON_OUTPUT"

export PAN23_JSON_SOURCE="$JSON_SOURCE"
export PAN23_JSON_RECEIPTS="$JSON_RECEIPTS"
export PAN23_JSON_OUTPUT="$JSON_OUTPUT"

if ! (
  cd "$JSON_RUNROOT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - <<'PY'
import json, os
from pathlib import Path
from workspace.operational.ingestion.service.batch import ingest_sources

source = Path(os.environ["PAN23_JSON_SOURCE"]).resolve()
outputs = ingest_sources(
    sources=(source,),
    receipt_root=Path(os.environ["PAN23_JSON_RECEIPTS"]).resolve(),
    output_root=Path(os.environ["PAN23_JSON_OUTPUT"]).resolve(),
    source_class="manual_batch",
)

print("SOURCE=" + str(source))
print("OUTPUT_COUNT=" + str(len(outputs)))

if len(outputs) != 1:
    raise SystemExit("JSON output count mismatch")

out = Path(outputs[0]).resolve()
required = (
    out / "metadata/receipt.json",
    out / "provenance/provenance.json",
    out / "structure/parsed.json",
    out / "reports/manifest.json",
    out / "reports/validation.json",
)

for path in required:
    print(f"REQUIRED {path} EXISTS={path.is_file()}")
    if not path.is_file():
        raise SystemExit("missing required output: " + str(path))

parsed = json.loads((out / "structure/parsed.json").read_text(encoding="utf-8"))
manifest = json.loads((out / "reports/manifest.json").read_text(encoding="utf-8"))
validation = json.loads((out / "reports/validation.json").read_text(encoding="utf-8"))

print("PARSED_KIND=" + repr(parsed.get("kind")))
print("MANIFEST_KIND=" + repr(manifest.get("kind")))
print("VALIDATION=" + repr(validation))

if parsed.get("kind") != "json":
    raise SystemExit("parsed kind is not json")
if "document" not in parsed:
    raise SystemExit("parsed JSON document missing")
if manifest.get("kind") != "json":
    raise SystemExit("manifest kind is not json")
if validation.get("passed") is not True:
    raise SystemExit("JSON validation failed")
if validation.get("errors") not in ([], None):
    raise SystemExit("JSON validation errors not empty")

print("EXACT_STAGE13_JSON=PASS")
PY
) > "$OUT/09_EXACT_JSON_RETEST.txt" 2> "$OUT/09_EXACT_JSON_RETEST.stderr.txt"
then
  fail_gate "EXACT_STAGE13_JSON_RETEST_FAILED"
fi

# Gate 7: both source hashes unchanged.
if ! sha256sum -c "$OUT/00_MARKDOWN_SOURCE.sha256" \
  > "$OUT/10_MARKDOWN_HASH_VERIFY.txt" 2>&1
then
  fail_gate "MARKDOWN_SOURCE_HASH_CHANGED"
fi

if ! sha256sum -c "$OUT/00_JSON_SOURCE.sha256" \
  > "$OUT/10_JSON_HASH_VERIFY.txt" 2>&1
then
  fail_gate "JSON_SOURCE_HASH_CHANGED"
fi

# -------------------------------------------------------------------
# Success: leave validated implementation uncommitted for inspection/promotion.
# -------------------------------------------------------------------
{
  echo "=== POST HASHES ==="
  sha256sum \
    "$REGISTRY" "$VALIDATION" "$RUN_ALL" \
    "$JSON_PARSER" "$JSON_PARSER_TEST" "$JSON_VALIDATION_TEST"
  echo
  echo "=== GIT POST ==="
  git -C "$CURRENT" status --short --branch 2>/dev/null || true
  echo
  echo "=== TARGETED DIFF ==="
  git -C "$CURRENT" diff -- \
    "workspace/operational/ingestion/service/registry.py" \
    "workspace/operational/ingestion/service/validation.py" \
    "workspace/operational/ingestion/service/tests/run_all.py" \
    "workspace/operational/ingestion/service/parsers/json_document.py" \
    "workspace/operational/ingestion/service/tests/test_json_parser.py" \
    "workspace/operational/ingestion/service/tests/test_json_validation.py" \
    2>/dev/null || true
} > "$OUT/11_POST_STATE.txt"

SUCCESS=1
trap - ERR INT TERM

TREE_REFRESH="NOT_RUN"
if [ -f "$HOME/PAN_REFRESH_FILE_TREE_TEXTS.sh" ]; then
  if bash "$HOME/PAN_REFRESH_FILE_TREE_TEXTS.sh" \
    > "$OUT/12_TREE_REFRESH.txt" 2>&1
  then
    TREE_REFRESH="PASS"
  else
    TREE_REFRESH="FAIL_NONBLOCKING"
  fi
else
  TREE_REFRESH="DEFERRED_SCRIPT_NOT_FOUND"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_JSON_KIND_IMPLEMENT_STAGE23
UTC=$TS
STATUS=PASS
JSON_PARSER=PASS
JSON_REGISTRY=PASS
JSON_VALIDATION=PASS
FULL_REGRESSION=PASS
HISTORICAL_MANUAL_BATCH_MARKDOWN_REPLAY=PASS
EXACT_STAGE13_JSON_RETEST=PASS
MARKDOWN_SOURCE_HASH=PASS
JSON_SOURCE_HASH=PASS
SOURCE_MUTATION=NONE
ROLLBACK=NOT_REQUIRED
LIVE_JSON_CAPABILITY=VALIDATED_UNCOMMITTED
GIT_COMMIT_PERFORMED=NO
TREE_REFRESH=$TREE_REFRESH
JSON_SOURCE=$JSON_SOURCE
EVIDENCE=$OUT
NEXT=BULK_INGEST_PROVEN_JSON_MD_TXT_NONCONVERSATION_REMAINDER_THEN_QUALIFY_NEXT_FORMAT_CLASS
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- markdown replay ---"
cat "$OUT/08_MARKDOWN_REPLAY.txt"
echo
echo "--- exact JSON retest ---"
cat "$OUT/09_EXACT_JSON_RETEST.txt"
echo
echo "--- full regression tail ---"
tail -40 "$OUT/07_FULL_REGRESSION.txt"
echo
echo "STAGE23_COMPLETE=YES"
