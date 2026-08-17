#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_JSON_PRESERVATION_IMPLEMENT_$TS-STAGE26"

SERVICE="$CURRENT/workspace/operational/ingestion/service"
PARSERS="$SERVICE/parsers"
TESTS="$SERVICE/tests"

REGISTRY="$SERVICE/registry.py"
VALIDATION="$SERVICE/validation.py"
OUTPUTMOD="$SERVICE/output.py"
RUN_ALL="$TESTS/run_all.py"

JSON_PARSER="$PARSERS/json_document.py"
JSON_PARSER_TEST="$TESTS/test_json_parser.py"
JSON_VALIDATION_TEST="$TESTS/test_json_validation.py"
JSON_PIPELINE_TEST="$TESTS/test_json_pipeline.py"

BACKUP="$OUT/pre"
CANDIDATE="$OUT/candidate"
SANDBOX="$OUT/sandbox"

mkdir -p "$BACKUP" "$CANDIDATE" "$SANDBOX"

echo "=== PAN — JSON PRESERVATION IMPLEMENTATION STAGE 26 ==="
echo "CURRENT=$CURRENT"
echo "SERVICE=$SERVICE"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$SERVICE" "$PARSERS" "$TESTS" "$REGISTRY" "$VALIDATION" "$OUTPUTMOD" "$RUN_ALL"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

# -------------------------------------------------------------------
# Evidence gates.
# -------------------------------------------------------------------
LATEST25="$(
  find "$TREE_HOME" -maxdepth 1 -type d \
    -name 'PAN_JSON_NORMALIZATION_EDGE_*-STAGE25' \
    -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | head -1 | cut -d' ' -f2-
)"
[ -n "$LATEST25" ] && [ -d "$LATEST25" ] || {
  echo "BLOCKER: Stage25 evidence missing"
  exit 22
}

DECISION25="$(sed -n 's/^DECISION=//p' "$LATEST25/SUMMARY.txt" | head -1)"
COUNT25="$(sed -n 's/^NORMALIZER_CANDIDATE_COUNT=//p' "$LATEST25/SUMMARY.txt" | head -1)"

[ "$DECISION25" = "SINGLE_SERIALIZATION_NORMALIZER_IDENTIFIED" ] || {
  echo "BLOCKER: Stage25 decision drift: $DECISION25"
  exit 23
}
[ "$COUNT25" = "1" ] || {
  echo "BLOCKER: Stage25 candidate count drift: $COUNT25"
  exit 24
}

LATEST23="$(
  find "$TREE_HOME" -maxdepth 1 -type d \
    -name 'PAN_JSON_KIND_IMPLEMENT_*-STAGE23' \
    -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | head -1 | cut -d' ' -f2-
)"
[ -n "$LATEST23" ] && [ -d "$LATEST23" ] || {
  echo "BLOCKER: Stage23 evidence missing"
  exit 25
}

[ -d "$LATEST23/candidate" ] || {
  echo "BLOCKER: Stage23 candidate directory missing"
  exit 26
}
[ -d "$LATEST23/pre" ] || {
  echo "BLOCKER: Stage23 pre-state directory missing"
  exit 27
}

for x in \
  "$LATEST23/candidate/registry.py" \
  "$LATEST23/candidate/validation.py" \
  "$LATEST23/candidate/run_all.py" \
  "$LATEST23/candidate/json_document.py" \
  "$LATEST23/candidate/test_json_parser.py" \
  "$LATEST23/candidate/test_json_validation.py" \
  "$LATEST23/pre/registry.py" \
  "$LATEST23/pre/validation.py" \
  "$LATEST23/pre/run_all.py"
do
  [ -f "$x" ] || { echo "BLOCKER: missing Stage23 artifact $x"; exit 28; }
done

LATEST22B="$(
  find "$TREE_HOME" -maxdepth 1 -type d \
    -name 'PAN_MANUAL_BATCH_MARKDOWN_PACKAGE_REPLAY_*-STAGE22B' \
    -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | head -1 | cut -d' ' -f2-
)"
[ -n "$LATEST22B" ] && [ -d "$LATEST22B" ] || {
  echo "BLOCKER: Stage22B evidence missing"
  exit 29
}

STATUS22B="$(sed -n 's/^STATUS=//p' "$LATEST22B/SUMMARY.txt" | head -1)"
MARKDOWN_SOURCE="$(sed -n 's/^PRESERVED_SOURCE_PAYLOAD=//p' "$LATEST22B/SUMMARY.txt" | head -1)"

[ "$STATUS22B" = "PASS" ] || {
  echo "BLOCKER: Stage22B is not PASS: $STATUS22B"
  exit 30
}
[ -n "$MARKDOWN_SOURCE" ] && [ -f "$MARKDOWN_SOURCE" ] || {
  echo "BLOCKER: Stage22B payload missing: $MARKDOWN_SOURCE"
  exit 31
}

JSON_SOURCE="$(
  sed -n 's/^JSON_SOURCE=//p' "$LATEST23/00_PRE_STATE.txt" | head -1
)"
if [ -z "$JSON_SOURCE" ]; then
  JSON_SOURCE="$(
    grep -Rhs '^JSON_SOURCE=' "$LATEST23" 2>/dev/null \
    | head -1 | sed 's/^JSON_SOURCE=//'
  )"
fi

[ -n "$JSON_SOURCE" ] && [ -f "$JSON_SOURCE" ] || {
  echo "BLOCKER: exact Stage13 JSON source missing"
  exit 32
}

case "${JSON_SOURCE,,}" in
  *.json) ;;
  *)
    echo "BLOCKER: Stage13 source is not JSON: $JSON_SOURCE"
    exit 33
    ;;
esac

echo "STAGE25=$LATEST25"
echo "STAGE23=$LATEST23"
echo "STAGE22B=$LATEST22B"
echo "MARKDOWN_SOURCE=$MARKDOWN_SOURCE"
echo "JSON_SOURCE=$JSON_SOURCE"
echo

# -------------------------------------------------------------------
# Require live files to equal the rolled-back Stage23 pre-state.
# Do not overwrite unrelated drift.
# -------------------------------------------------------------------
cmp -s "$REGISTRY" "$LATEST23/pre/registry.py" || {
  echo "BLOCKER: live registry.py drift since Stage23 rollback"
  exit 34
}
cmp -s "$VALIDATION" "$LATEST23/pre/validation.py" || {
  echo "BLOCKER: live validation.py drift since Stage23 rollback"
  exit 35
}
cmp -s "$RUN_ALL" "$LATEST23/pre/run_all.py" || {
  echo "BLOCKER: live run_all.py drift since Stage23 rollback"
  exit 36
}

for x in "$JSON_PARSER" "$JSON_PARSER_TEST" "$JSON_VALIDATION_TEST" "$JSON_PIPELINE_TEST"; do
  if [ -e "$x" ]; then
    echo "BLOCKER: unexpected live JSON artifact: $x"
    exit 37
  fi
done

# Exact Stage25 normalizer preflight.
"$PYTHON" - "$OUTPUTMOD" > "$OUT/00_OUTPUT_PREFLIGHT.txt" <<'PY'
import ast, sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
tree = ast.parse(text, filename=str(p))

write_output = next(
    (n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "write_output"),
    None,
)
if write_output is None:
    raise SystemExit("BLOCKER: write_output() missing")

target = None
for n in ast.walk(write_output):
    if not isinstance(n, ast.If):
        continue
    try:
        test = ast.unparse(n.test).replace(" ", "")
    except Exception:
        continue
    if test == "isinstance(parsed,dict)":
        target = n
        break

if target is None:
    raise SystemExit("BLOCKER: parsed dict normalizer missing")

blob = "\n".join(
    ast.unparse(x)
    for x in target.body
    if isinstance(x, ast.AST)
)
required = (
    'parsed.get("kind")',
    'parsed.get("turns", [])',
    'parsed.get("commands", [])',
)
for r in required:
    if r not in blob:
        raise SystemExit("BLOCKER: output normalizer drift; missing " + r)

if 'parsed.get("document")' in text or '"document":' in blob:
    raise SystemExit("BLOCKER: JSON document preservation already present unexpectedly")

print(f"NORMALIZER_LINE={target.lineno}")
print("OUTPUT_PREFLIGHT=PASS")
PY

# -------------------------------------------------------------------
# Preserve pre-state.
# -------------------------------------------------------------------
cp -a "$REGISTRY" "$BACKUP/registry.py"
cp -a "$VALIDATION" "$BACKUP/validation.py"
cp -a "$OUTPUTMOD" "$BACKUP/output.py"
cp -a "$RUN_ALL" "$BACKUP/run_all.py"

sha256sum \
  "$REGISTRY" "$VALIDATION" "$OUTPUTMOD" "$RUN_ALL" \
  "$MARKDOWN_SOURCE" "$JSON_SOURCE" \
  > "$OUT/01_PRE_HASHES.sha256"

sha256sum "$MARKDOWN_SOURCE" > "$OUT/01_MARKDOWN_SOURCE.sha256"
sha256sum "$JSON_SOURCE" > "$OUT/01_JSON_SOURCE.sha256"

MUTATED=0
SUCCESS=0

rollback() {
  set +e
  if [ "$MUTATED" -eq 1 ]; then
    cp -a "$BACKUP/registry.py" "$REGISTRY"
    cp -a "$BACKUP/validation.py" "$VALIDATION"
    cp -a "$BACKUP/output.py" "$OUTPUTMOD"
    cp -a "$BACKUP/run_all.py" "$RUN_ALL"

    rm -f \
      "$JSON_PARSER" \
      "$JSON_PARSER_TEST" \
      "$JSON_VALIDATION_TEST" \
      "$JSON_PIPELINE_TEST"

    rm -f "$PARSERS/__pycache__/json_document."*.pyc 2>/dev/null || true
    rm -f "$TESTS/__pycache__/test_json_parser."*.pyc 2>/dev/null || true
    rm -f "$TESTS/__pycache__/test_json_validation."*.pyc 2>/dev/null || true
    rm -f "$TESTS/__pycache__/test_json_pipeline."*.pyc 2>/dev/null || true

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
PAN_JSON_PRESERVATION_IMPLEMENT_STAGE26
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
# Rehydrate the already-tested Stage23 JSON parser / registry /
# validation candidate exactly as preserved.
# -------------------------------------------------------------------
cp -a "$LATEST23/candidate/registry.py" "$REGISTRY"
cp -a "$LATEST23/candidate/validation.py" "$VALIDATION"
cp -a "$LATEST23/candidate/run_all.py" "$RUN_ALL"
cp -a "$LATEST23/candidate/json_document.py" "$JSON_PARSER"
cp -a "$LATEST23/candidate/test_json_parser.py" "$JSON_PARSER_TEST"
cp -a "$LATEST23/candidate/test_json_validation.py" "$JSON_VALIDATION_TEST"

# -------------------------------------------------------------------
# Patch only write_output()'s dict normalization:
#
# JSON dicts preserve the parser's exact JSON-safe payload.
# Existing conversation-shaped dicts keep the exact old conversion.
# Non-dict Markdown/dataclass behavior remains untouched.
# -------------------------------------------------------------------
"$PYTHON" - "$OUTPUTMOD" <<'PY'
import ast, sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
lines = text.splitlines(keepends=True)
tree = ast.parse(text, filename=str(p))

write_output = next(
    (n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "write_output"),
    None,
)
if write_output is None:
    raise SystemExit("write_output() missing")

target = None
for n in ast.walk(write_output):
    if not isinstance(n, ast.If):
        continue
    try:
        test = ast.unparse(n.test).replace(" ", "")
    except Exception:
        continue
    if test == "isinstance(parsed,dict)":
        target = n
        break

if target is None or not target.body:
    raise SystemExit("dict normalizer missing")

if 'parsed.get("kind") == "json"' in text or "parsed.get('kind') == 'json'" in text:
    raise SystemExit("JSON output branch already present")

# Preserve the complete existing dict-normalization body verbatim by
# nesting it one level deeper under an else branch.
body_start = target.body[0].lineno - 1
body_end = target.body[-1].end_lineno - 1

for i in range(body_start, body_end + 1):
    lines[i] = "    " + lines[i]

if_idx = target.lineno - 1
indent = lines[if_idx][:len(lines[if_idx]) - len(lines[if_idx].lstrip())]
inner = indent + "    "

insertion = [
    inner + 'if parsed.get("kind") == "json":\n',
    inner + "    parsed_data = parsed\n",
    inner + "else:\n",
]

lines[if_idx + 1:if_idx + 1] = insertion

candidate = "".join(lines)
ast.parse(candidate, filename=str(p))
p.write_text(candidate, encoding="utf-8")
PY

# -------------------------------------------------------------------
# Permanent pipeline regression test.
# -------------------------------------------------------------------
cat > "$JSON_PIPELINE_TEST" <<'PY'
import json
from pathlib import Path
from tempfile import TemporaryDirectory

from ..batch import ingest_sources


def main():
    expected = {
        "artifact": {
            "identifier": "PAN-JSON-PIPELINE-TEST",
            "title": "JSON pipeline preservation test",
            "nested": {
                "alpha": 1,
                "beta": [True, None, "x"],
            },
        }
    }

    with TemporaryDirectory(
        prefix="difference-engine-json-pipeline-"
    ) as tmp:
        root = Path(tmp)
        source = root / "fixture.json"
        receipt_root = root / "receipts"
        output_root = root / "output"

        source.write_text(
            json.dumps(expected),
            encoding="utf-8",
        )

        outputs = ingest_sources(
            sources=(source,),
            receipt_root=receipt_root,
            output_root=output_root,
            source_class="manual_batch",
        )

        assert len(outputs) == 1
        out = Path(outputs[0])

        parsed = json.loads(
            (out / "structure/parsed.json").read_text(
                encoding="utf-8"
            )
        )
        manifest = json.loads(
            (out / "reports/manifest.json").read_text(
                encoding="utf-8"
            )
        )
        validation = json.loads(
            (out / "reports/validation.json").read_text(
                encoding="utf-8"
            )
        )

        assert parsed["kind"] == "json"
        assert parsed["document"] == expected
        assert manifest["kind"] == "json"
        assert validation["passed"] is True
        assert validation["errors"] == []

    print("PASS")


if __name__ == "__main__":
    main()
PY

# Register the new pipeline test using the existing TESTS namespace.
PIPELINE_TEST_MODULE="$(
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
        and any(
            isinstance(t, ast.Name) and t.id == "TESTS"
            for t in n.targets
        )
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
target = prefix + ".test_json_pipeline"

if target in entries:
    raise SystemExit("JSON pipeline test already registered")

lines = text.splitlines(keepends=True)
insert_at = assign.end_lineno - 1
lines.insert(insert_at, f'    "{target}",\n')

candidate = "".join(lines)
ast.parse(candidate, filename=str(p))
p.write_text(candidate, encoding="utf-8")

print(target)
PY
)"

MUTATED=1

# Preserve exact candidate.
cp -a "$REGISTRY" "$CANDIDATE/registry.py"
cp -a "$VALIDATION" "$CANDIDATE/validation.py"
cp -a "$OUTPUTMOD" "$CANDIDATE/output.py"
cp -a "$RUN_ALL" "$CANDIDATE/run_all.py"
cp -a "$JSON_PARSER" "$CANDIDATE/json_document.py"
cp -a "$JSON_PARSER_TEST" "$CANDIDATE/test_json_parser.py"
cp -a "$JSON_VALIDATION_TEST" "$CANDIDATE/test_json_validation.py"
cp -a "$JSON_PIPELINE_TEST" "$CANDIDATE/test_json_pipeline.py"

sha256sum \
  "$REGISTRY" "$VALIDATION" "$OUTPUTMOD" "$RUN_ALL" \
  "$JSON_PARSER" "$JSON_PARSER_TEST" \
  "$JSON_VALIDATION_TEST" "$JSON_PIPELINE_TEST" \
  > "$OUT/02_CANDIDATE_HASHES.sha256"

# -------------------------------------------------------------------
# Gate 1: compile.
# -------------------------------------------------------------------
if ! "$PYTHON" -m py_compile \
  "$REGISTRY" "$VALIDATION" "$OUTPUTMOD" "$RUN_ALL" \
  "$JSON_PARSER" "$JSON_PARSER_TEST" \
  "$JSON_VALIDATION_TEST" "$JSON_PIPELINE_TEST" \
  > "$OUT/03_COMPILE.txt" 2>&1
then
  fail_gate "COMPILE_FAILED"
fi

# -------------------------------------------------------------------
# Gate 2: targeted JSON tests.
# -------------------------------------------------------------------
JSON_TEST_MODULES="$(
"$PYTHON" - "$RUN_ALL" <<'PY'
import ast, sys
from pathlib import Path

p = Path(sys.argv[1])
tree = ast.parse(p.read_text(encoding="utf-8"), filename=str(p))

assign = next(
    (
        n for n in tree.body
        if isinstance(n, ast.Assign)
        and any(
            isinstance(t, ast.Name) and t.id == "TESTS"
            for t in n.targets
        )
    ),
    None,
)
if assign is None:
    raise SystemExit("TESTS missing")

for elt in assign.value.elts:
    if isinstance(elt, ast.Constant) and isinstance(elt.value, str):
        if elt.value.endswith((
            ".test_json_parser",
            ".test_json_validation",
            ".test_json_pipeline",
        )):
            print(elt.value)
PY
)"

COUNT_JSON_TESTS="$(printf '%s\n' "$JSON_TEST_MODULES" | sed '/^$/d' | wc -l)"
[ "$COUNT_JSON_TESTS" -eq 3 ] || fail_gate "EXPECTED_THREE_JSON_TEST_MODULES"

while IFS= read -r TEST_MODULE; do
  [ -n "$TEST_MODULE" ] || continue

  if ! (
    cd "$CURRENT"
    PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
      "$PYTHON" -m "$TEST_MODULE"
  ) >> "$OUT/04_TARGETED_JSON_TESTS.txt" 2>&1
  then
    fail_gate "TARGETED_JSON_TEST_FAILED"
  fi
done <<< "$JSON_TEST_MODULES"

# -------------------------------------------------------------------
# Gate 3: runtime registry.
# -------------------------------------------------------------------
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
    raise SystemExit("unexpected parser registry")

fn = parser_for(Path("/tmp/PAN_STAGE26.json"))
print("JSON_PARSER=" + fn.__module__ + "." + fn.__name__)

if fn.__name__ != "parse_json":
    raise SystemExit("JSON parser binding mismatch")

print("RUNTIME_REGISTRY=PASS")
PY
) > "$OUT/05_RUNTIME_REGISTRY.txt" 2>&1
then
  fail_gate "RUNTIME_REGISTRY_FAILED"
fi

# -------------------------------------------------------------------
# Gate 4: full existing regression suite + all new JSON tests.
# -------------------------------------------------------------------
if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" "$RUN_ALL"
) > "$OUT/06_FULL_REGRESSION.txt" 2>&1
then
  fail_gate "FULL_REGRESSION_FAILED"
fi

# -------------------------------------------------------------------
# Gate 5: replay proven historical manual_batch Markdown payload.
# -------------------------------------------------------------------
MD_RUNROOT="$SANDBOX/markdown/runroot"
MD_RECEIPTS="$SANDBOX/markdown/receipts"
MD_OUTPUT="$SANDBOX/markdown/output"
mkdir -p "$MD_RUNROOT" "$MD_RECEIPTS" "$MD_OUTPUT"

export PAN26_MD_SOURCE="$MARKDOWN_SOURCE"
export PAN26_MD_RECEIPTS="$MD_RECEIPTS"
export PAN26_MD_OUTPUT="$MD_OUTPUT"

if ! (
  cd "$MD_RUNROOT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - <<'PY'
import json
import os
from pathlib import Path

from workspace.operational.ingestion.service.batch import ingest_sources

source = Path(os.environ["PAN26_MD_SOURCE"]).resolve()

outputs = ingest_sources(
    sources=(source,),
    receipt_root=Path(os.environ["PAN26_MD_RECEIPTS"]).resolve(),
    output_root=Path(os.environ["PAN26_MD_OUTPUT"]).resolve(),
    source_class="manual_batch",
)

if len(outputs) != 1:
    raise SystemExit("markdown replay output count mismatch")

out = Path(outputs[0])

manifest = json.loads(
    (out / "reports/manifest.json").read_text(encoding="utf-8")
)
validation = json.loads(
    (out / "reports/validation.json").read_text(encoding="utf-8")
)

print("MANIFEST_KIND=" + repr(manifest.get("kind")))
print("VALIDATION=" + repr(validation))

if manifest.get("kind") != "markdown":
    raise SystemExit("markdown kind drift")
if validation.get("passed") is not True:
    raise SystemExit("markdown validation regression")
if validation.get("errors") not in ([], None):
    raise SystemExit("markdown validation errors")

print("HISTORICAL_MANUAL_BATCH_MARKDOWN_REPLAY=PASS")
PY
) > "$OUT/07_MARKDOWN_REPLAY.txt" 2> "$OUT/07_MARKDOWN_REPLAY.stderr.txt"
then
  fail_gate "MARKDOWN_REPLAY_REGRESSION"
fi

# -------------------------------------------------------------------
# Gate 6: exact Stage13 JSON source.
# Require full payload round-trip, not just kind/validation.
# -------------------------------------------------------------------
JSON_RUNROOT="$SANDBOX/json/runroot"
JSON_RECEIPTS="$SANDBOX/json/receipts"
JSON_OUTPUT="$SANDBOX/json/output"
mkdir -p "$JSON_RUNROOT" "$JSON_RECEIPTS" "$JSON_OUTPUT"

export PAN26_JSON_SOURCE="$JSON_SOURCE"
export PAN26_JSON_RECEIPTS="$JSON_RECEIPTS"
export PAN26_JSON_OUTPUT="$JSON_OUTPUT"

if ! (
  cd "$JSON_RUNROOT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - <<'PY'
import json
import os
from pathlib import Path

from workspace.operational.ingestion.service.batch import ingest_sources

source = Path(os.environ["PAN26_JSON_SOURCE"]).resolve()

with source.open("r", encoding="utf-8-sig") as handle:
    expected_document = json.load(handle)

outputs = ingest_sources(
    sources=(source,),
    receipt_root=Path(os.environ["PAN26_JSON_RECEIPTS"]).resolve(),
    output_root=Path(os.environ["PAN26_JSON_OUTPUT"]).resolve(),
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

parsed = json.loads(
    (out / "structure/parsed.json").read_text(encoding="utf-8")
)
manifest = json.loads(
    (out / "reports/manifest.json").read_text(encoding="utf-8")
)
validation = json.loads(
    (out / "reports/validation.json").read_text(encoding="utf-8")
)

print("PARSED_KEYS=" + repr(sorted(parsed.keys())))
print("PARSED_KIND=" + repr(parsed.get("kind")))
print("HAS_DOCUMENT=" + repr("document" in parsed))
print("MANIFEST_KIND=" + repr(manifest.get("kind")))
print("VALIDATION=" + repr(validation))

if parsed.get("kind") != "json":
    raise SystemExit("parsed kind is not json")
if "document" not in parsed:
    raise SystemExit("serialized JSON document missing")
if parsed["document"] != expected_document:
    raise SystemExit("JSON document round-trip mismatch")
if manifest.get("kind") != "json":
    raise SystemExit("manifest kind is not json")
if validation.get("passed") is not True:
    raise SystemExit("JSON validation failed")
if validation.get("errors") not in ([], None):
    raise SystemExit("JSON validation errors not empty")

print("EXACT_STAGE13_JSON_ROUNDTRIP=PASS")
PY
) > "$OUT/08_EXACT_JSON_RETEST.txt" 2> "$OUT/08_EXACT_JSON_RETEST.stderr.txt"
then
  fail_gate "EXACT_STAGE13_JSON_RETEST_FAILED"
fi

# -------------------------------------------------------------------
# Gate 7: source immutability.
# -------------------------------------------------------------------
if ! sha256sum -c "$OUT/01_MARKDOWN_SOURCE.sha256" \
  > "$OUT/09_MARKDOWN_HASH_VERIFY.txt" 2>&1
then
  fail_gate "MARKDOWN_SOURCE_HASH_CHANGED"
fi

if ! sha256sum -c "$OUT/01_JSON_SOURCE.sha256" \
  > "$OUT/09_JSON_HASH_VERIFY.txt" 2>&1
then
  fail_gate "JSON_SOURCE_HASH_CHANGED"
fi

# -------------------------------------------------------------------
# Success: validated, uncommitted live capability.
# -------------------------------------------------------------------
{
  echo "=== POST HASHES ==="
  sha256sum \
    "$REGISTRY" "$VALIDATION" "$OUTPUTMOD" "$RUN_ALL" \
    "$JSON_PARSER" "$JSON_PARSER_TEST" \
    "$JSON_VALIDATION_TEST" "$JSON_PIPELINE_TEST"

  echo
  echo "=== GIT STATUS ==="
  git -C "$CURRENT" status --short --branch 2>/dev/null || true

  echo
  echo "=== TARGETED DIFF ==="
  git -C "$CURRENT" diff -- \
    "workspace/operational/ingestion/service/registry.py" \
    "workspace/operational/ingestion/service/validation.py" \
    "workspace/operational/ingestion/service/output.py" \
    "workspace/operational/ingestion/service/tests/run_all.py" \
    "workspace/operational/ingestion/service/parsers/json_document.py" \
    "workspace/operational/ingestion/service/tests/test_json_parser.py" \
    "workspace/operational/ingestion/service/tests/test_json_validation.py" \
    "workspace/operational/ingestion/service/tests/test_json_pipeline.py" \
    2>/dev/null || true
} > "$OUT/10_POST_STATE.txt"

SUCCESS=1
trap - ERR INT TERM

TREE_REFRESH="NOT_RUN"
if [ -f "$HOME/PAN_REFRESH_FILE_TREE_TEXTS.sh" ]; then
  if bash "$HOME/PAN_REFRESH_FILE_TREE_TEXTS.sh" \
    > "$OUT/11_TREE_REFRESH.txt" 2>&1
  then
    TREE_REFRESH="PASS"
  else
    TREE_REFRESH="FAIL_NONBLOCKING"
  fi
else
  TREE_REFRESH="DEFERRED_SCRIPT_NOT_FOUND"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_JSON_PRESERVATION_IMPLEMENT_STAGE26
UTC=$TS
STATUS=PASS
NORMALIZER_PATCH=PASS
JSON_PARSER=PASS
JSON_REGISTRY=PASS
JSON_VALIDATION=PASS
JSON_PIPELINE_ROUNDTRIP_TEST=PASS
FULL_REGRESSION=PASS
HISTORICAL_MANUAL_BATCH_MARKDOWN_REPLAY=PASS
EXACT_STAGE13_JSON_ROUNDTRIP=PASS
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
echo "--- targeted JSON tests ---"
cat "$OUT/04_TARGETED_JSON_TESTS.txt"

echo
echo "--- markdown replay ---"
cat "$OUT/07_MARKDOWN_REPLAY.txt"

echo
echo "--- exact JSON roundtrip ---"
cat "$OUT/08_EXACT_JSON_RETEST.txt"

echo
echo "--- full regression tail ---"
tail -40 "$OUT/06_FULL_REGRESSION.txt"

echo
echo "STAGE26_COMPLETE=YES"
