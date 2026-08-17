#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_MANUAL_BATCH_MARKDOWN_PACKAGE_REPLAY_$TS-STAGE22B"

INGEST_ROOT="$CURRENT/workspace/operational/ingestion"
OUTPUTS="$INGEST_ROOT/output"
SERVICE="$INGEST_ROOT/service"

SANDBOX="$OUT/sandbox"
RECEIPTS="$SANDBOX/receipts"
OUTROOT="$SANDBOX/output"
RUNROOT="$SANDBOX/runroot"
mkdir -p "$OUT" "$RECEIPTS" "$OUTROOT" "$RUNROOT"

echo "=== PAN — MANUAL_BATCH MARKDOWN PACKAGE REPLAY STAGE 22B ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$OUTPUTS" "$SERVICE"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

# Find one historically passing manual_batch markdown package.
"$PYTHON" - "$OUTPUTS" > "$OUT/01_PASSING_PACKAGES.tsv" <<'PY'
from pathlib import Path
import json, sys

root = Path(sys.argv[1])
print("package\tsource_class\tkind\tpassed")

for receipt in sorted(root.rglob("metadata/receipt.json")):
    pkg = receipt.parent.parent
    validation = pkg / "reports/validation.json"
    manifest = pkg / "reports/manifest.json"
    if not (validation.is_file() and manifest.is_file()):
        continue
    try:
        r = json.loads(receipt.read_text(encoding="utf-8"))
        v = json.loads(validation.read_text(encoding="utf-8"))
        m = json.loads(manifest.read_text(encoding="utf-8"))
    except Exception:
        continue
    if r.get("source_class") == "manual_batch" and v.get("passed") is True and m.get("kind") == "markdown":
        print(f"{pkg}\tmanual_batch\tmarkdown\tTrue")
PY

LINE="$(sed -n '2p' "$OUT/01_PASSING_PACKAGES.tsv" || true)"
[ -n "$LINE" ] || {
  echo "BLOCKER: no historically passing manual_batch markdown package found"
  exit 22
}
IFS=$'\t' read -r HIST_PKG _ _ _ <<< "$LINE"

echo "HISTORICAL_PACKAGE=$HIST_PKG" | tee "$OUT/02_SELECTED.txt"

# Inventory every surviving file in the package.
find "$HIST_PKG" -type f -printf '%P\t%s\t%p\n' | sort > "$OUT/03_PACKAGE_FILES.tsv"

# Extract source clues from receipt/provenance/manifest recursively.
"$PYTHON" - "$HIST_PKG" > "$OUT/04_SOURCE_CLUES.txt" <<'PY'
from pathlib import Path
import json, sys

pkg = Path(sys.argv[1])

for rel in (
    "metadata/receipt.json",
    "provenance/provenance.json",
    "reports/manifest.json",
):
    p = pkg / rel
    if not p.is_file():
        continue
    print(f"===== {rel} =====")
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:
        print("PARSE_ERROR", repr(e))
        continue

    def walk(x, path="$"):
        if isinstance(x, dict):
            for k,v in x.items():
                lk = k.lower()
                if any(t in lk for t in ("source", "path", "sha", "hash", "name", "original")):
                    print(f"{path}.{k}={v!r}")
                walk(v, f"{path}.{k}")
        elif isinstance(x, list):
            for i,v in enumerate(x):
                walk(v, f"{path}[{i}]")
    walk(data)
PY

# Look for preserved original/source payloads inside the package.
"$PYTHON" - "$HIST_PKG" > "$OUT/05_PAYLOAD_CANDIDATES.tsv" <<'PY'
from pathlib import Path
import mimetypes, sys

pkg = Path(sys.argv[1])
preferred_dirs = {"source", "sources", "original", "raw", "input", "payload", "content"}

rows = []
for p in pkg.rglob("*"):
    if not p.is_file():
        continue
    rel = p.relative_to(pkg)
    parts = {x.lower() for x in rel.parts[:-1]}
    suffix = p.suffix.lower()
    score = 0
    if parts & preferred_dirs:
        score += 10
    if suffix in {".md", ".markdown", ".txt"}:
        score += 5
    if p.name.lower() not in {"receipt.json","manifest.json","validation.json","parsed.json","assets.json","references.json","provenance.json"}:
        score += 1
    if score:
        rows.append((score, p.stat().st_size, str(rel), str(p)))

print("score\tbytes\trelpath\tpath")
for row in sorted(rows, key=lambda r:(-r[0], r[1], r[2])):
    print("\t".join(map(str,row)))
PY

# Choose highest-ranked likely source payload.
PAYLOAD="$(
  awk -F'\t' 'NR==2 {print $4}' "$OUT/05_PAYLOAD_CANDIDATES.tsv" 2>/dev/null || true
)"

if [ -z "$PAYLOAD" ] || [ ! -f "$PAYLOAD" ]; then
  cat > "$OUT/SUMMARY.txt" <<EOF
PAN_MANUAL_BATCH_MARKDOWN_PACKAGE_REPLAY_STAGE22B
UTC=$TS
STATUS=BLOCKED
HISTORICAL_PACKAGE=$HIST_PKG
PRESERVED_SOURCE_PAYLOAD=NOT_FOUND
SOURCE_MUTATION=NONE
INGESTION_EXECUTED=NO
EVIDENCE=$OUT
NEXT=USE_CURRENT_VALID_MARKDOWN_FIXTURE_TO_TEST_MANUAL_BATCH_ROUTING_WITHOUT_CLAIMING_HISTORICAL_SOURCE_REPLAY
EOF
  cat "$OUT/SUMMARY.txt"
  echo
  echo "--- package inventory ---"
  head -80 "$OUT/03_PACKAGE_FILES.tsv"
  echo
  echo "--- source clues ---"
  cat "$OUT/04_SOURCE_CLUES.txt"
  exit 0
fi

echo "PRESERVED_SOURCE_PAYLOAD=$PAYLOAD" | tee -a "$OUT/02_SELECTED.txt"
sha256sum "$PAYLOAD" > "$OUT/06_PAYLOAD.sha256"

# Replay preserved payload through current pipeline, sandboxed.
export PAN22B_SOURCE="$PAYLOAD"
export PAN22B_RECEIPTS="$RECEIPTS"
export PAN22B_OUTPUT="$OUTROOT"

set +e
(
  cd "$RUNROOT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - <<'PY'
import json, os
from pathlib import Path
from workspace.operational.ingestion.service.batch import ingest_sources

source = Path(os.environ["PAN22B_SOURCE"]).resolve()
receipt_root = Path(os.environ["PAN22B_RECEIPTS"]).resolve()
output_root = Path(os.environ["PAN22B_OUTPUT"]).resolve()

outputs = ingest_sources(
    sources=(source,),
    receipt_root=receipt_root,
    output_root=output_root,
    source_class="manual_batch",
)

print("SOURCE=" + str(source))
print("OUTPUT_COUNT=" + str(len(outputs)))
if len(outputs) != 1:
    raise SystemExit(f"expected one output, got {len(outputs)}")

out = Path(outputs[0]).resolve()
manifest = json.loads((out / "reports/manifest.json").read_text(encoding="utf-8"))
validation = json.loads((out / "reports/validation.json").read_text(encoding="utf-8"))

print("OUTPUT=" + str(out))
print("MANIFEST_KIND=" + repr(manifest.get("kind")))
print("VALIDATION=" + repr(validation))

if manifest.get("kind") != "markdown":
    raise SystemExit("manifest kind is not markdown")
if validation.get("passed") is not True:
    raise SystemExit("validation failed")
if validation.get("errors") not in ([], None):
    raise SystemExit("validation errors not empty")

print("MANUAL_BATCH_MARKDOWN_PACKAGE_REPLAY=PASS")
PY
) > "$OUT/07_REPLAY.txt" 2> "$OUT/07_REPLAY.stderr.txt"
RC=$?
set -e

if [ "$RC" -eq 0 ]; then
  STATUS="PASS"
  NEXT="IMPLEMENT_ONLY_JSON_KIND_VALIDATION_EXTENSION_WITH_ROLLBACK"
else
  STATUS="FAIL"
  NEXT="PRESERVE_FAILURE_AND_INSPECT_ONLY_CURRENT_MARKDOWN_VALIDATION_REGRESSION"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_MANUAL_BATCH_MARKDOWN_PACKAGE_REPLAY_STAGE22B
UTC=$TS
STATUS=$STATUS
EXIT_CODE=$RC
HISTORICAL_PACKAGE=$HIST_PKG
PRESERVED_SOURCE_PAYLOAD=$PAYLOAD
SOURCE_CLASS=manual_batch
SOURCE_MUTATION=NONE
LIVE_REPOSITORY_OUTPUT_MODIFIED=NO
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- replay ---"
cat "$OUT/07_REPLAY.txt" 2>/dev/null || true
if [ "$RC" -ne 0 ]; then
  echo
  echo "--- stderr tail ---"
  tail -80 "$OUT/07_REPLAY.stderr.txt" 2>/dev/null || true
fi
echo
echo "STAGE22B_COMPLETE=YES"

exit "$RC"
