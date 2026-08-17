#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
FIRST_CORPUS="$HOME/Difference-Engine-LEGACY-STALE-DECOMPOSED"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_JSON_PARSER_IMPLEMENT_$TS-STAGE17"

SERVICE="$CURRENT/workspace/operational/ingestion/service"
PARSERS="$SERVICE/parsers"
TESTS="$SERVICE/tests"
REGISTRY="$SERVICE/registry.py"
RUN_ALL="$TESTS/run_all.py"
JSON_PARSER="$PARSERS/json_document.py"
JSON_TEST="$TESTS/test_json_parser.py"

BACKUP="$OUT/pre"
CANDIDATE="$OUT/candidate"
SANDBOX="$OUT/sandbox"
mkdir -p "$BACKUP" "$CANDIDATE" "$SANDBOX"

echo "=== PAN — IMPLEMENT MINIMAL JSON PARSER STAGE 17 ==="
echo "CURRENT=$CURRENT"
echo "SERVICE=$SERVICE"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$FIRST_CORPUS" "$SERVICE" "$PARSERS" "$TESTS" "$REGISTRY" "$RUN_ALL"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

# Recover the exact Stage 13 source that failed on "No parser registered for .json".
LATEST_STAGE13="$(
  find "$TREE_HOME" -maxdepth 1 -type d \
    -name 'PAN_FIRST_NONCONVERSATION_INGEST_*-STAGE13' \
    -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | head -1 | cut -d' ' -f2-
)"

[ -n "$LATEST_STAGE13" ] && [ -d "$LATEST_STAGE13" ] || {
  echo "BLOCKER: Stage 13 evidence directory not found"
  exit 22
}

SOURCE="$(
  grep -Rhs '^SOURCE=' "$LATEST_STAGE13" 2>/dev/null \
  | head -1 | sed 's/^SOURCE=//'
)"

[ -n "$SOURCE" ] && [ -f "$SOURCE" ] || {
  echo "BLOCKER: exact Stage 13 failed source not recoverable"
  exit 23
}

case "${SOURCE,,}" in
  *.json) ;;
  *)
    echo "BLOCKER: recovered Stage 13 source is not .json: $SOURCE"
    exit 24
    ;;
esac

echo "FAILED_EDGE_SOURCE=$SOURCE"
echo "STAGE13_EVIDENCE=$LATEST_STAGE13"

# Do not overwrite a partially-existing implementation. Drift must be inspected.
if [ -e "$JSON_PARSER" ] || [ -e "$JSON_TEST" ]; then
  echo "BLOCKER: JSON parser/test already exists; inspect drift instead of overwriting"
  echo "JSON_PARSER=$JSON_PARSER"
  echo "JSON_TEST=$JSON_TEST"
  exit 25
fi

# -------------------------------------------------------------------
# 1. Pre-state / provenance.
# -------------------------------------------------------------------
cp -a "$REGISTRY" "$BACKUP/registry.py"
cp -a "$RUN_ALL" "$BACKUP/run_all.py"

{
  echo "UTC=$TS"
  echo "SOURCE=$SOURCE"
  echo "STAGE13_EVIDENCE=$LATEST_STAGE13"
  echo
  echo "=== SOURCE HASH ==="
  sha256sum "$SOURCE"
  echo
  echo "=== ACTIVE FILE HASHES ==="
  sha256sum "$REGISTRY" "$RUN_ALL"
  echo
  echo "=== PARSER TREE ==="
  find "$PARSERS" -maxdepth 2 -type f -printf '%p\n' | sort
  echo
  echo "=== TEST TREE ==="
  find "$TESTS" -maxdepth 2 -type f -printf '%p\n' | sort
  echo
  echo "=== GIT PRE ==="
  git -C "$CURRENT" status --short --branch 2>/dev/null || true
} > "$OUT/00_PRE_STATE.txt"

sha256sum "$SOURCE" > "$OUT/00_SOURCE_PRE.sha256"

# -------------------------------------------------------------------
# 2. Stage 16 invariant re-check immediately before mutation.
#    Require exactly the proven .md/.txt registry state.
# -------------------------------------------------------------------
"$PYTHON" - "$REGISTRY" > "$OUT/01_PREFLIGHT_REGISTRY.txt" <<'PY'
import ast, sys
from pathlib import Path

p = Path(sys.argv[1])
tree = ast.parse(p.read_text(encoding="utf-8"), filename=str(p))

found = None
for node in tree.body:
    if not isinstance(node, ast.Assign):
        continue
    names = []
    for t in node.targets:
        try:
            names.append(ast.unparse(t))
        except Exception:
            pass
    if "PARSERS" in names:
        found = node.value
        break

if not isinstance(found, ast.Dict):
    raise SystemExit("BLOCKER: PARSERS is not a dict literal")

mapping = {}
for k, v in zip(found.keys, found.values):
    key = ast.literal_eval(k)
    mapping[key] = ast.unparse(v)

print("STATIC_MAPPING=" + repr(mapping))

expected = {
    ".md": "parse_markdown",
    ".txt": "parse_chatgpt",
}
if mapping != expected:
    raise SystemExit(
        "BLOCKER: registry drift before Stage17; expected "
        + repr(expected) + " got " + repr(mapping)
    )

print("STATIC_PREFLIGHT=PASS")
PY

(
  cd "$CURRENT"
  PYTHONPATH="$CURRENT${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - <<'PY'
from workspace.operational.ingestion.service import registry

keys = set(registry.PARSERS)
print("RUNTIME_KEYS=" + repr(sorted(keys)))
if keys != {".md", ".txt"}:
    raise SystemExit("BLOCKER: runtime registry drift before Stage17")
print("RUNTIME_PREFLIGHT=PASS")
PY
) > "$OUT/02_PREFLIGHT_RUNTIME.txt" 2>&1

# Preserve implementation context for any downstream failure diagnosis.
for f in assets.py references.py queues.py validation.py manifest.py output.py pipeline.py parser.py; do
  [ -f "$SERVICE/$f" ] && cp -a "$SERVICE/$f" "$BACKUP/$f"
done

MUTATED=0
SUCCESS=0

rollback() {
  set +e
  if [ "$MUTATED" -eq 1 ]; then
    cp -a "$BACKUP/registry.py" "$REGISTRY"
    cp -a "$BACKUP/run_all.py" "$RUN_ALL"
    rm -f "$JSON_PARSER" "$JSON_TEST"
    rm -f "$PARSERS/__pycache__/json_document."*.pyc 2>/dev/null || true
    rm -f "$TESTS/__pycache__/test_json_parser."*.pyc 2>/dev/null || true
    MUTATED=0
    echo "ROLLBACK=COMPLETE" | tee -a "$OUT/ROLLBACK.txt"
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
PAN_JSON_PARSER_IMPLEMENT_STAGE17
UTC=$TS
STATUS=FAIL
FAIL_REASON=$reason
ROLLBACK=COMPLETE
SOURCE=$SOURCE
SOURCE_MUTATION=NONE_EXPECTED
LIVE_JSON_PARSER_PROMOTED=NO
EVIDENCE=$OUT
NEXT=INSPECT_ONLY_THE_RECORDED_FAILED_EDGE
EOF
  cat "$OUT/SUMMARY.txt"
  exit "$rc"
}

# -------------------------------------------------------------------
# 3. Minimal implementation candidate.
#    No formatter/canonicalization invention: parse JSON to a native document
#    and identify the representation as kind=json.
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

cat > "$JSON_TEST" <<'PY'
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

# Patch registry with strict textual anchors after AST preflight.
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
    raise SystemExit("json wiring already present unexpectedly")

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

# Add the exact test to the recovered TESTS tuple without assuming namespace.
TEST_MODULE="$(
  "$PYTHON" - "$RUN_ALL" <<'PY'
import ast, sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
tree = ast.parse(text, filename=str(p))

assign = None
for node in tree.body:
    if not isinstance(node, ast.Assign):
        continue
    if any(isinstance(t, ast.Name) and t.id == "TESTS" for t in node.targets):
        assign = node
        break

if assign is None or not isinstance(assign.value, (ast.Tuple, ast.List)):
    raise SystemExit("TESTS tuple/list not found")

entries = []
for elt in assign.value.elts:
    if not isinstance(elt, ast.Constant) or not isinstance(elt.value, str):
        raise SystemExit("TESTS contains non-string entry")
    entries.append(elt.value)

if not entries:
    raise SystemExit("TESTS is empty")

prefixes = {x.rsplit(".", 1)[0] for x in entries}
if len(prefixes) != 1:
    raise SystemExit("TESTS namespace is not uniform")

target = next(iter(prefixes)) + ".test_json_parser"
if target in entries:
    raise SystemExit("JSON test already registered unexpectedly")

lines = text.splitlines(keepends=True)
insert_at = assign.end_lineno - 1
indent = "    "
lines.insert(insert_at, f'{indent}"{target}",\n')
p.write_text("".join(lines), encoding="utf-8")
print(target)
PY
)"

MUTATED=1

# Preserve candidate before tests so rollback never destroys the proposed change.
cp -a "$REGISTRY" "$CANDIDATE/registry.py"
cp -a "$RUN_ALL" "$CANDIDATE/run_all.py"
cp -a "$JSON_PARSER" "$CANDIDATE/json_document.py"
cp -a "$JSON_TEST" "$CANDIDATE/test_json_parser.py"

{
  echo "TEST_MODULE=$TEST_MODULE"
  sha256sum "$REGISTRY" "$RUN_ALL" "$JSON_PARSER" "$JSON_TEST"
} > "$OUT/03_CANDIDATE_HASHES.txt"

# -------------------------------------------------------------------
# 4. Compile + exact parser registry proof.
# -------------------------------------------------------------------
if ! "$PYTHON" -m py_compile \
  "$REGISTRY" "$RUN_ALL" "$JSON_PARSER" "$JSON_TEST" \
  > "$OUT/04_PY_COMPILE.txt" 2>&1
then
  fail_gate "PY_COMPILE_FAILED"
fi

if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" -m "$TEST_MODULE"
) > "$OUT/05_JSON_TEST.txt" 2>&1
then
  fail_gate "JSON_UNIT_REGRESSION_FAILED"
fi

if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" - <<'PY'
from pathlib import Path
from workspace.operational.ingestion.service import registry
from workspace.operational.ingestion.service.registry import parser_for

keys = sorted(registry.PARSERS)
print("RUNTIME_KEYS=" + repr(keys))
print("JSON_PRESENT=" + repr(".json" in registry.PARSERS))
fn = parser_for(Path("/tmp/PAN_STAGE17.json"))
print("PARSER_FOR_JSON=" + fn.__module__ + "." + fn.__name__)

if set(keys) != {".md", ".txt", ".json"}:
    raise SystemExit("unexpected runtime parser key set")
if fn.__name__ != "parse_json":
    raise SystemExit("parser_for(.json) did not resolve parse_json")
PY
) > "$OUT/06_RUNTIME_JSON_PROOF.txt" 2>&1
then
  fail_gate "RUNTIME_JSON_REGISTRATION_FAILED"
fi

# -------------------------------------------------------------------
# 5. Full recovered baseline, now including the JSON regression test.
# -------------------------------------------------------------------
if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" "$RUN_ALL"
) > "$OUT/07_FULL_REGRESSION.txt" 2>&1
then
  fail_gate "FULL_INGESTION_REGRESSION_FAILED"
fi

# -------------------------------------------------------------------
# 6. Re-run the exact Stage 13 failed source in an isolated working dir.
#    pipeline.py's relative state path therefore lands inside SANDBOX/runroot,
#    not the live repository.
# -------------------------------------------------------------------
RUNROOT="$SANDBOX/runroot"
RECEIPTS="$SANDBOX/receipts"
OUTPUT_ROOT="$SANDBOX/output"
mkdir -p "$RUNROOT" "$RECEIPTS" "$OUTPUT_ROOT"

export PAN_STAGE17_SOURCE="$SOURCE"
export PAN_STAGE17_RECEIPTS="$RECEIPTS"
export PAN_STAGE17_OUTPUT="$OUTPUT_ROOT"

if ! (
  cd "$RUNROOT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" - <<'PY'
import json
import os
from pathlib import Path

from workspace.operational.ingestion.service.batch import ingest_sources

source = Path(os.environ["PAN_STAGE17_SOURCE"]).resolve()
receipt_root = Path(os.environ["PAN_STAGE17_RECEIPTS"]).resolve()
output_root = Path(os.environ["PAN_STAGE17_OUTPUT"]).resolve()

outputs = ingest_sources(
    sources=(source,),
    receipt_root=receipt_root,
    output_root=output_root,
    source_class="manual_batch",
)

print("SOURCE=" + str(source))
print("OUTPUT_COUNT=" + str(len(outputs)))

if len(outputs) != 1:
    raise SystemExit(f"expected exactly one output, got {len(outputs)}")

out = Path(outputs[0]).resolve()
print("OUTPUT=" + str(out))

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

print("PARSED_KIND=" + repr(parsed.get("kind")))
print("MANIFEST_KIND=" + repr(manifest.get("kind")))
print("VALIDATION=" + repr(validation))

if parsed.get("kind") != "json":
    raise SystemExit("parsed kind is not json")
if manifest.get("kind") != "json":
    raise SystemExit("manifest kind is not json")
if validation.get("passed") is not True:
    raise SystemExit("validation did not pass")

print("EXACT_STAGE13_EDGE=PASS")
PY
) > "$OUT/08_EXACT_STAGE13_RETEST.txt" 2> "$OUT/08_EXACT_STAGE13_RETEST.stderr.txt"
then
  fail_gate "EXACT_STAGE13_PIPELINE_RETEST_FAILED"
fi

if ! sha256sum -c "$OUT/00_SOURCE_PRE.sha256" \
  > "$OUT/09_SOURCE_HASH_VERIFY.txt" 2>&1
then
  fail_gate "SOURCE_HASH_CHANGED"
fi

# -------------------------------------------------------------------
# 7. Success evidence. No commit; source change remains visible for review.
# -------------------------------------------------------------------
{
  echo "=== POST HASHES ==="
  sha256sum "$REGISTRY" "$RUN_ALL" "$JSON_PARSER" "$JSON_TEST"
  echo
  echo "=== GIT POST ==="
  git -C "$CURRENT" status --short --branch 2>/dev/null || true
  echo
  echo "=== TARGETED DIFF ==="
  git -C "$CURRENT" diff -- \
    "workspace/operational/ingestion/service/registry.py" \
    "workspace/operational/ingestion/service/tests/run_all.py" \
    "workspace/operational/ingestion/service/parsers/json_document.py" \
    "workspace/operational/ingestion/service/tests/test_json_parser.py" \
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
PAN_JSON_PARSER_IMPLEMENT_STAGE17
UTC=$TS
STATUS=PASS
JSON_PARSER_EDGE=PASS
STATIC_REGISTRY=.md,.txt,.json
JSON_TEST_IN_RUN_ALL=YES
FULL_REGRESSION=PASS
EXACT_STAGE13_RETEST=PASS
SOURCE_HASH=PASS
SOURCE_MUTATION=NONE
ROLLBACK=NOT_REQUIRED
LIVE_JSON_PARSER_PROMOTED=YES_VALIDATED_UNCOMMITTED
GIT_COMMIT_PERFORMED=NO
TREE_REFRESH=$TREE_REFRESH
SOURCE=$SOURCE
EVIDENCE=$OUT
NEXT=BULK_INGEST_PROVEN_TEXTLIKE_NONCONVERSATION_FORMATS_JSON_MD_TXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- exact Stage13 retest ---"
cat "$OUT/08_EXACT_STAGE13_RETEST.txt"
echo
echo "--- full regression tail ---"
tail -40 "$OUT/07_FULL_REGRESSION.txt"
echo
echo "STAGE17_COMPLETE=YES"
