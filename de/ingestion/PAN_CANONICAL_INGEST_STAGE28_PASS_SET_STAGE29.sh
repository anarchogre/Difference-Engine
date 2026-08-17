#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_CANONICAL_INGEST_STAGE28_PASS_SET_$TS-STAGE29"

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"
RUN_ALL="$SERVICE/tests/run_all.py"

mkdir -p "$OUT" "$RECEIPTS" "$OUTPUT"

echo "=== PAN — CANONICAL INGEST STAGE28 PASS SET / STAGE 29 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME" "$SERVICE" "$RUN_ALL"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST28="$(
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
    text = s.read_text(encoding="utf-8", errors="replace")
    if "PAN_FIRST_CORPUS_TEXTLIKE_DRYRUN_STAGE28" not in text:
        continue
    if "STATUS=PASS" not in text:
        continue
    if "SOURCE_HASHES=PASS" not in text:
        continue
    if "LIVE_REPOSITORY_OUTPUT_MODIFIED=NO" not in text:
        continue
    hits.append((d.stat().st_mtime_ns, d))

if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST28" ] && [ -d "$LATEST28" ] || {
  echo "BLOCKER: passing Stage28 evidence not found"
  exit 22
}

PASS_SET="$(sed -n 's/^PASS_SET=//p' "$LATEST28/SUMMARY.txt" | head -1)"
FAIL_SET="$(sed -n 's/^FAIL_SET=//p' "$LATEST28/SUMMARY.txt" | head -1)"
EXPECTED_PASS="$(sed -n 's/^PASS_COUNT=//p' "$LATEST28/SUMMARY.txt" | head -1)"
EXPECTED_FAIL="$(sed -n 's/^FAIL_COUNT=//p' "$LATEST28/SUMMARY.txt" | head -1)"
EXPECTED_TOTAL="$(sed -n 's/^TOTAL_CANDIDATES=//p' "$LATEST28/SUMMARY.txt" | head -1)"
PROMOTED_COMMIT="$(sed -n 's/^PROMOTED_COMMIT=//p' "$LATEST28/SUMMARY.txt" | head -1)"
HASH_LEDGER="$LATEST28/07_SOURCE_HASHES_BEFORE.tsv"

for x in "$PASS_SET" "$FAIL_SET" "$HASH_LEDGER"; do
  [ -f "$x" ] || { echo "BLOCKER: missing Stage28 artifact $x"; exit 23; }
done

ACTUAL_PASS="$(grep -c . "$PASS_SET" 2>/dev/null || true)"
ACTUAL_FAIL="$(grep -c . "$FAIL_SET" 2>/dev/null || true)"

[ "$ACTUAL_PASS" = "$EXPECTED_PASS" ] || {
  echo "BLOCKER: Stage28 pass-set count drift expected=$EXPECTED_PASS actual=$ACTUAL_PASS"
  exit 24
}

[ "$ACTUAL_FAIL" = "$EXPECTED_FAIL" ] || {
  echo "BLOCKER: Stage28 fail-set count drift expected=$EXPECTED_FAIL actual=$ACTUAL_FAIL"
  exit 25
}

[ "$((ACTUAL_PASS + ACTUAL_FAIL))" = "$EXPECTED_TOTAL" ] || {
  echo "BLOCKER: Stage28 total-count drift"
  exit 26
}

[ -n "$PROMOTED_COMMIT" ] || {
  echo "BLOCKER: Stage28 promoted commit missing"
  exit 27
}

git -C "$CURRENT" cat-file -e "$PROMOTED_COMMIT^{commit}" 2>/dev/null || {
  echo "BLOCKER: promoted commit not present: $PROMOTED_COMMIT"
  exit 28
}

git -C "$CURRENT" merge-base --is-ancestor "$PROMOTED_COMMIT" HEAD || {
  echo "BLOCKER: promoted JSON commit is not ancestor of HEAD"
  exit 29
}

echo "STAGE28=$LATEST28"
echo "PASS_SET=$PASS_SET"
echo "PASS_COUNT=$ACTUAL_PASS"
echo "FAIL_SET_HELD_BACK=$ACTUAL_FAIL"
echo "PROMOTED_COMMIT=$PROMOTED_COMMIT"
echo

# Preserve pre-state.
git -C "$CURRENT" status --short --branch > "$OUT/00_GIT_PRE.txt" 2>&1 || true
find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/00_OUTPUT_PACKAGE_COUNT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/00_RECEIPT_COUNT_PRE.txt"

# Gate on the active regression suite immediately before live canonical writes.
if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" "$RUN_ALL"
) > "$OUT/01_PRE_INGEST_REGRESSION.txt" 2>&1
then
  echo "BLOCKER: active ingestion regression failed"
  tail -80 "$OUT/01_PRE_INGEST_REGRESSION.txt" || true
  exit 30
fi

# Verify every Stage28 pass source is byte-identical to the dry-run input.
if ! "$PYTHON" - "$PASS_SET" "$HASH_LEDGER" \
  > "$OUT/02_PASS_SET_HASH_VERIFY_PRE.txt" <<'PY'
from pathlib import Path
import hashlib
import sys

pass_set = Path(sys.argv[1])
ledger = Path(sys.argv[2])

expected = {}
for line in ledger.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    parts = line.split("\t", 2)
    if len(parts) != 3:
        raise SystemExit("malformed Stage28 hash ledger")
    digest, size, path = parts
    expected[str(Path(path).resolve())] = (digest, int(size))

sources = [
    Path(x).resolve()
    for x in pass_set.read_text(encoding="utf-8").splitlines()
    if x.strip()
]

for source in sources:
    key = str(source)
    if key not in expected:
        raise SystemExit(f"missing Stage28 hash record: {source}")
    if not source.is_file():
        raise SystemExit(f"source missing: {source}")

    h = hashlib.sha256()
    with source.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)

    digest, size = expected[key]
    if h.hexdigest() != digest:
        raise SystemExit(f"hash drift: {source}")
    if source.stat().st_size != size:
        raise SystemExit(f"size drift: {source}")

print(f"VERIFIED={len(sources)}")
print("SOURCE_HASHES_PRE=PASS")
PY
then
  echo "BLOCKER: Stage28 pass-set source drift"
  cat "$OUT/02_PASS_SET_HASH_VERIFY_PRE.txt" || true
  exit 31
fi

LEDGER="$OUT/03_CANONICAL_INGEST_LEDGER.tsv"
PROGRESS="$OUT/03_CANONICAL_INGEST_PROGRESS.txt"

export PAN29_CURRENT="$CURRENT"
export PAN29_SERVICE="$SERVICE"
export PAN29_PASS_SET="$PASS_SET"
export PAN29_RECEIPTS="$RECEIPTS"
export PAN29_OUTPUT="$OUTPUT"
export PAN29_LEDGER="$LEDGER"

set +e
(
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - <<'PY'
from pathlib import Path
import csv
import hashlib
import json
import os
import sys

from workspace.operational.ingestion.service.batch import ingest_sources

pass_set = Path(os.environ["PAN29_PASS_SET"])
receipt_root = Path(os.environ["PAN29_RECEIPTS"]).resolve()
output_root = Path(os.environ["PAN29_OUTPUT"]).resolve()
ledger_path = Path(os.environ["PAN29_LEDGER"])

sources = [
    Path(x).resolve()
    for x in pass_set.read_text(encoding="utf-8").splitlines()
    if x.strip()
]

def source_from_package(pkg: Path):
    receipt = pkg / "metadata/receipt.json"
    provenance = pkg / "provenance/provenance.json"

    data = {}
    if receipt.is_file():
        try:
            data = json.loads(receipt.read_text(encoding="utf-8"))
        except Exception:
            data = {}

    value = (
        data.get("observed_path")
        or data.get("source_path")
        or data.get("path")
    )
    if value:
        return Path(value).resolve()

    if provenance.is_file():
        try:
            p = json.loads(provenance.read_text(encoding="utf-8"))
        except Exception:
            p = {}
        value = p.get("source_path") or p.get("source")
        if value:
            return Path(value).resolve()

    return None

def find_existing(source: Path):
    for pkg in sorted(output_root.iterdir()) if output_root.exists() else []:
        if not pkg.is_dir():
            continue
        try:
            observed = source_from_package(pkg)
        except Exception:
            continue
        if observed != source:
            continue

        validation_path = pkg / "reports/validation.json"
        manifest_path = pkg / "reports/manifest.json"
        if not validation_path.is_file() or not manifest_path.is_file():
            continue

        try:
            validation = json.loads(validation_path.read_text(encoding="utf-8"))
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except Exception:
            continue

        if validation.get("passed") is True:
            return pkg.resolve(), manifest, validation

    return None, None, None

new_count = 0
existing_count = 0
fail_count = 0
failed_source = ""

with ledger_path.open("w", encoding="utf-8", newline="") as h:
    w = csv.writer(h, delimiter="\t")
    w.writerow([
        "index",
        "status",
        "sha256",
        "bytes",
        "manifest_kind",
        "validation_passed",
        "source",
        "output",
        "exception",
    ])

    for i, source in enumerate(sources, start=1):
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        status = "FAIL"
        kind = ""
        validation_passed = ""
        output = ""
        exc = ""

        try:
            existing_pkg, existing_manifest, existing_validation = find_existing(source)

            if existing_pkg is not None:
                status = "ALREADY_CANONICAL"
                output = str(existing_pkg)
                kind = existing_manifest.get("kind", "")
                validation_passed = existing_validation.get("passed", "")
                existing_count += 1
            else:
                outputs = ingest_sources(
                    sources=(source,),
                    receipt_root=receipt_root,
                    output_root=output_root,
                    source_class="manual_batch",
                )

                if len(outputs) != 1:
                    # A zero-output result is valid only if canonical completion
                    # became visible through the live output contract.
                    pkg, manifest, validation = find_existing(source)
                    if len(outputs) == 0 and pkg is not None:
                        status = "ALREADY_CANONICAL"
                        output = str(pkg)
                        kind = manifest.get("kind", "")
                        validation_passed = validation.get("passed", "")
                        existing_count += 1
                    else:
                        raise RuntimeError(
                            f"expected one output or verified existing package, got {len(outputs)}"
                        )
                else:
                    pkg = Path(outputs[0]).resolve()
                    manifest_path = pkg / "reports/manifest.json"
                    validation_path = pkg / "reports/validation.json"

                    manifest = json.loads(
                        manifest_path.read_text(encoding="utf-8")
                    )
                    validation = json.loads(
                        validation_path.read_text(encoding="utf-8")
                    )

                    if validation.get("passed") is not True:
                        raise RuntimeError(
                            "canonical output validation did not pass"
                        )

                    status = "NEW_CANONICAL"
                    output = str(pkg)
                    kind = manifest.get("kind", "")
                    validation_passed = True
                    new_count += 1

        except Exception as e:
            exc = f"{type(e).__name__}: {e}"
            fail_count += 1
            failed_source = str(source)

        w.writerow([
            i,
            status,
            digest,
            source.stat().st_size if source.exists() else "",
            kind,
            validation_passed,
            source,
            output,
            exc,
        ])

        print(
            f"[{i}/{len(sources)}] {status} {source.name}",
            flush=True,
        )

        if status == "FAIL":
            break

print(f"TOTAL_TARGET={len(sources)}")
print(f"NEW_CANONICAL={new_count}")
print(f"ALREADY_CANONICAL={existing_count}")
print(f"FAIL={fail_count}")
print(f"FAILED_SOURCE={failed_source}")

if fail_count:
    raise SystemExit(1)
if new_count + existing_count != len(sources):
    raise SystemExit("completion count mismatch")
PY
) | tee "$PROGRESS"
INGEST_RC=${PIPESTATUS[0]}
set -e

# Verify pass-set sources again after canonical ingestion.
set +e
"$PYTHON" - "$PASS_SET" "$HASH_LEDGER" \
  > "$OUT/04_PASS_SET_HASH_VERIFY_POST.txt" <<'PY'
from pathlib import Path
import hashlib
import sys

pass_set = Path(sys.argv[1])
ledger = Path(sys.argv[2])

expected = {}
for line in ledger.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    digest, size, path = line.split("\t", 2)
    expected[str(Path(path).resolve())] = (digest, int(size))

sources = [
    Path(x).resolve()
    for x in pass_set.read_text(encoding="utf-8").splitlines()
    if x.strip()
]

for source in sources:
    key = str(source)
    if key not in expected or not source.is_file():
        raise SystemExit(f"source missing/hash record missing: {source}")

    h = hashlib.sha256()
    with source.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)

    digest, size = expected[key]
    if h.hexdigest() != digest or source.stat().st_size != size:
        raise SystemExit(f"source drift: {source}")

print(f"VERIFIED={len(sources)}")
print("SOURCE_HASHES_POST=PASS")
PY
HASH_POST_RC=$?
set -e

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/05_OUTPUT_PACKAGE_COUNT_POST.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/05_RECEIPT_COUNT_POST.txt"

git -C "$CURRENT" status --short --branch > "$OUT/06_GIT_POST.txt" 2>&1 || true

NEW_CANONICAL="$(sed -n 's/^NEW_CANONICAL=//p' "$PROGRESS" | tail -1)"
ALREADY_CANONICAL="$(sed -n 's/^ALREADY_CANONICAL=//p' "$PROGRESS" | tail -1)"
FAIL_COUNT="$(sed -n 's/^FAIL=//p' "$PROGRESS" | tail -1)"
FAILED_SOURCE="$(sed -n 's/^FAILED_SOURCE=//p' "$PROGRESS" | tail -1)"

NEW_CANONICAL="${NEW_CANONICAL:-0}"
ALREADY_CANONICAL="${ALREADY_CANONICAL:-0}"
FAIL_COUNT="${FAIL_COUNT:-1}"

PRE_PACKAGES="$(cat "$OUT/00_OUTPUT_PACKAGE_COUNT_PRE.txt")"
POST_PACKAGES="$(cat "$OUT/05_OUTPUT_PACKAGE_COUNT_POST.txt")"
PRE_RECEIPTS="$(cat "$OUT/00_RECEIPT_COUNT_PRE.txt")"
POST_RECEIPTS="$(cat "$OUT/05_RECEIPT_COUNT_POST.txt")"

if [ "$INGEST_RC" -eq 0 ] && [ "$HASH_POST_RC" -eq 0 ] && [ "$FAIL_COUNT" -eq 0 ]; then
  STATUS="PASS"
  NEXT="QUALIFY_STAGE28_FAILURE_SET"
else
  STATUS="FAIL"
  NEXT="PRESERVE_AND_REPAIR_ONLY_FAILED_STAGE29_CANONICAL_INGEST_EDGE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_CANONICAL_INGEST_STAGE28_PASS_SET_STAGE29
UTC=$TS
STATUS=$STATUS
STAGE28=$LATEST28
PROMOTED_COMMIT=$PROMOTED_COMMIT
TARGET_PASS_SET=$ACTUAL_PASS
HELD_BACK_STAGE28_FAILURES=$ACTUAL_FAIL
NEW_CANONICAL=$NEW_CANONICAL
ALREADY_CANONICAL=$ALREADY_CANONICAL
FAIL_COUNT=$FAIL_COUNT
FAILED_SOURCE=$FAILED_SOURCE
SOURCE_HASHES_PRE=PASS
SOURCE_HASHES_POST=$([ "$HASH_POST_RC" -eq 0 ] && echo PASS || echo FAIL)
PRE_OUTPUT_PACKAGES=$PRE_PACKAGES
POST_OUTPUT_PACKAGES=$POST_PACKAGES
PRE_RECEIPTS=$PRE_RECEIPTS
POST_RECEIPTS=$POST_RECEIPTS
LIVE_REPOSITORY_OUTPUT_MODIFIED=$([ "$NEW_CANONICAL" -gt 0 ] && echo YES || echo NO_ALREADY_COMPLETE)
STAGE28_FAILURE_SET_TOUCHED=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
LEDGER=$LEDGER
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"

if [ "$STATUS" = "PASS" ]; then
  echo
  echo "STAGE29_COMPLETE=YES"
  exit 0
fi

echo
echo "--- failure tail ---"
tail -20 "$LEDGER" 2>/dev/null || true
echo
echo "STAGE29_COMPLETE=NO"
exit 1
