#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_MANUAL_BATCH_MARKDOWN_REPLAY_$TS-STAGE22"

INGEST_ROOT="$CURRENT/workspace/operational/ingestion"
SERVICE="$INGEST_ROOT/service"
OUTPUTS="$INGEST_ROOT/output"
BATCH="$SERVICE/batch.py"
VALIDATION="$SERVICE/validation.py"

SANDBOX="$OUT/sandbox"
RECEIPTS="$SANDBOX/receipts"
OUTROOT="$SANDBOX/output"
RUNROOT="$SANDBOX/runroot"

mkdir -p "$OUT" "$RECEIPTS" "$OUTROOT" "$RUNROOT"

echo "=== PAN — MANUAL_BATCH MARKDOWN REPLAY STAGE 22 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$SERVICE" "$OUTPUTS" "$BATCH" "$VALIDATION"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

sha256sum "$BATCH" "$VALIDATION" > "$OUT/00_ACTIVE_HASHES.sha256"

# Recover one historically passing manual_batch + markdown package whose source still exists.
"$PYTHON" - "$OUTPUTS" > "$OUT/01_HISTORICAL_CANDIDATES.tsv" <<'PY'
from pathlib import Path
import json, sys

root = Path(sys.argv[1])

print("package\tsource\tsha256\tkind\tpassed")

for receipt in sorted(root.rglob("metadata/receipt.json")):
    pkg = receipt.parent.parent
    validation = pkg / "reports/validation.json"
    manifest = pkg / "reports/manifest.json"
    provenance = pkg / "provenance/provenance.json"

    if not (validation.is_file() and manifest.is_file()):
        continue

    try:
        r = json.loads(receipt.read_text(encoding="utf-8"))
        v = json.loads(validation.read_text(encoding="utf-8"))
        m = json.loads(manifest.read_text(encoding="utf-8"))
    except Exception:
        continue

    if r.get("source_class") != "manual_batch":
        continue
    if v.get("passed") is not True:
        continue
    if m.get("kind") != "markdown":
        continue

    source = (
        r.get("observed_path")
        or r.get("source_path")
        or r.get("path")
    )
    digest = r.get("sha256") or r.get("source_sha256")

    if not source and provenance.is_file():
        try:
            p = json.loads(provenance.read_text(encoding="utf-8"))
            source = p.get("source_path") or p.get("source")
            digest = digest or p.get("source_sha256")
        except Exception:
            pass

    if source and Path(source).is_file():
        print(f"{pkg}\t{source}\t{digest or ''}\tmarkdown\tTrue")
PY

LINE="$(sed -n '2p' "$OUT/01_HISTORICAL_CANDIDATES.tsv" || true)"
[ -n "$LINE" ] || {
  echo "BLOCKER: no surviving historically passing manual_batch markdown source found"
  exit 22
}

IFS=$'\t' read -r HIST_PKG SOURCE EXPECTED_SHA HIST_KIND HIST_PASS <<< "$LINE"

[ -f "$SOURCE" ] || { echo "BLOCKER: source vanished: $SOURCE"; exit 23; }

echo "HISTORICAL_PACKAGE=$HIST_PKG" > "$OUT/02_SELECTED.txt"
echo "SOURCE=$SOURCE" >> "$OUT/02_SELECTED.txt"
echo "EXPECTED_SHA=$EXPECTED_SHA" >> "$OUT/02_SELECTED.txt"

ACTUAL_SHA="$(sha256sum "$SOURCE" | awk '{print $1}')"
echo "$ACTUAL_SHA  $SOURCE" > "$OUT/03_SOURCE_SHA256.txt"

if [ -n "$EXPECTED_SHA" ] && [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
  echo "BLOCKER: historical source hash drift"
  echo "EXPECTED=$EXPECTED_SHA"
  echo "ACTUAL=$ACTUAL_SHA"
  exit 24
fi

# Preserve exact current validator for interpretation.
cp -a "$VALIDATION" "$OUT/validation.py"

# Replay with the current live pipeline, sandboxed.
export PAN_STAGE22_SOURCE="$SOURCE"
export PAN_STAGE22_RECEIPTS="$RECEIPTS"
export PAN_STAGE22_OUTPUT="$OUTROOT"

set +e
(
  cd "$RUNROOT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - <<'PY'
import json, os
from pathlib import Path

from workspace.operational.ingestion.service.batch import ingest_sources

source = Path(os.environ["PAN_STAGE22_SOURCE"]).resolve()
receipt_root = Path(os.environ["PAN_STAGE22_RECEIPTS"]).resolve()
output_root = Path(os.environ["PAN_STAGE22_OUTPUT"]).resolve()

outputs = ingest_sources(
    sources=(source,),
    receipt_root=receipt_root,
    output_root=output_root,
    source_class="manual_batch",
)

print(f"SOURCE={source}")
print(f"OUTPUT_COUNT={len(outputs)}")

if len(outputs) != 1:
    raise SystemExit(f"expected one output, got {len(outputs)}")

out = Path(outputs[0]).resolve()
print(f"OUTPUT={out}")

manifest = json.loads((out / "reports/manifest.json").read_text(encoding="utf-8"))
validation = json.loads((out / "reports/validation.json").read_text(encoding="utf-8"))
parsed = json.loads((out / "structure/parsed.json").read_text(encoding="utf-8"))

print("MANIFEST_KIND=" + repr(manifest.get("kind")))
print("VALIDATION=" + repr(validation))
print("PARSED_TYPE=" + type(parsed).__name__)
print("PARSED_KEYS=" + repr(sorted(parsed.keys()) if isinstance(parsed, dict) else None))

if manifest.get("kind") != "markdown":
    raise SystemExit("replay manifest kind is not markdown")
if validation.get("passed") is not True:
    raise SystemExit("manual_batch markdown replay validation failed")
if validation.get("errors") not in ([], None):
    raise SystemExit("manual_batch markdown replay has validation errors")

print("MANUAL_BATCH_MARKDOWN_REPLAY=PASS")
PY
) > "$OUT/04_REPLAY.txt" 2> "$OUT/04_REPLAY.stderr.txt"
RC=$?
set -e

if [ "$RC" -eq 0 ]; then
  STATUS="PASS"
  DECISION="CURRENT_MARKDOWN_GENERIC_PATH_ALREADY_WORKS"
  NEXT="DO_NOT_ADD_SOURCE_CLASS_VALIDATOR_BRANCH_IMPLEMENT_JSON_ONLY_AS_KIND_SPECIFIC_EXTENSION_WITH_ROLLBACK"
else
  STATUS="FAIL"
  DECISION="CURRENT_MARKDOWN_GENERIC_PATH_REGRESSED"
  NEXT="PRESERVE_FAILURE_AND_REPAIR_ONLY_MARKDOWN_VALIDATION_REGRESSION_BEFORE_JSON"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_MANUAL_BATCH_MARKDOWN_REPLAY_STAGE22
UTC=$TS
STATUS=$STATUS
EXIT_CODE=$RC
HISTORICAL_PACKAGE=$HIST_PKG
SOURCE=$SOURCE
SOURCE_SHA256=$ACTUAL_SHA
SOURCE_CLASS=manual_batch
DECISION=$DECISION
SOURCE_MUTATION=NONE
LIVE_REPOSITORY_OUTPUT_MODIFIED=NO
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- replay ---"
cat "$OUT/04_REPLAY.txt" 2>/dev/null || true

if [ "$RC" -ne 0 ]; then
  echo
  echo "--- stderr tail ---"
  tail -80 "$OUT/04_REPLAY.stderr.txt" 2>/dev/null || true
fi

echo
echo "STAGE22_COMPLETE=YES"

exit "$RC"
