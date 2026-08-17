#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_CANONICAL_INGEST_STAGE44_PENDING5_$TS-STAGE45"

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"
RUN_ALL="$SERVICE/tests/run_all.py"

mkdir -p "$OUT" "$RECEIPTS" "$OUTPUT"

echo "=== PAN — CANONICAL INGEST STAGE44 PENDING 5 / STAGE 45 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME" "$SERVICE" "$RUN_ALL"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

# -------------------------------------------------------------------
# Recover latest successful Stage44.
# -------------------------------------------------------------------
LATEST44="$(
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
    if (
        "PAN_CLOSE_ORIGINAL_HELD_BACK_SET_STAGE44" in t
        and "STATUS=PASS" in t
        and "ACCOUNTED=106" in t
        and "UNCLASSIFIED=0" in t
        and "VALIDATED_PENDING_CANONICAL_INGEST=5" in t
        and "NEXT=CANONICAL_INGEST_STAGE37_NOW_PASSING_5_ONLY" in t
    ):
        hits.append((d.stat().st_mtime_ns, d))
if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST44" ] && [ -d "$LATEST44" ] || {
  echo "BLOCKER: passing Stage44 evidence not found"
  exit 22
}

PENDING_LEDGER="$LATEST44/02_STAGE37_NOW_PASSING_5.tsv"
PENDING_SET="$LATEST44/02_STAGE37_NOW_PASSING_5.txt"

for x in "$PENDING_LEDGER" "$PENDING_SET"; do
  [ -f "$x" ] || { echo "BLOCKER: missing Stage44 pending-five artifact $x"; exit 23; }
done

PENDING_COUNT="$(grep -c . "$PENDING_SET" 2>/dev/null || true)"
[ "$PENDING_COUNT" = "5" ] || {
  echo "BLOCKER: expected exactly 5 pending sources; got $PENDING_COUNT"
  exit 24
}

echo "STAGE44=$LATEST44"
echo "PENDING_SET=$PENDING_SET"
echo "PENDING_COUNT=$PENDING_COUNT"
echo

# -------------------------------------------------------------------
# Pre-state.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true
git -C "$CURRENT" status --short --branch > "$OUT/00_GIT_PRE.txt" 2>&1 || true

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/00_OUTPUT_COUNT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/00_RECEIPT_COUNT_PRE.txt"

# -------------------------------------------------------------------
# Gate 1: current regression before live writes.
# -------------------------------------------------------------------
if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" "$RUN_ALL"
) > "$OUT/01_PRE_INGEST_REGRESSION.txt" 2>&1
then
  echo "BLOCKER: pre-ingest regression failed"
  tail -80 "$OUT/01_PRE_INGEST_REGRESSION.txt" || true
  exit 25
fi

# -------------------------------------------------------------------
# Gate 2: verify exact Stage44 hashes before live ingest.
# -------------------------------------------------------------------
if ! "$PYTHON" - "$PENDING_LEDGER" > "$OUT/02_SOURCE_HASHES_PRE.txt" <<'PY'
from pathlib import Path
import csv
import hashlib
import sys

ledger = Path(sys.argv[1])

with ledger.open("r", encoding="utf-8", newline="") as h:
    rows = list(csv.DictReader(h, delimiter="\t"))

if len(rows) != 5:
    raise SystemExit(f"expected 5 pending rows, got {len(rows)}")

seen = set()
for r in rows:
    source = Path(r["source"]).resolve()
    expected = (r.get("sha256") or "").strip()

    if str(source) in seen:
        raise SystemExit(f"duplicate source: {source}")
    seen.add(str(source))

    if not source.is_file():
        raise SystemExit(f"missing source: {source}")

    actual = hashlib.sha256(source.read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f"hash drift: {source}")

    if (r.get("stage37_status") or "") != "PASS":
        raise SystemExit(f"source was not Stage37 PASS: {source}")

    if (r.get("disposition") or "") != "VALIDATED_PENDING_CANONICAL_INGEST":
        raise SystemExit(f"unexpected Stage44 disposition: {source}")

    print(f"PASS\t{actual}\t{source}")

print("VERIFIED=5")
print("SOURCE_HASHES_PRE=PASS")
PY
then
  echo "BLOCKER: pending-five source hash precheck failed"
  cat "$OUT/02_SOURCE_HASHES_PRE.txt" || true
  exit 26
fi

# -------------------------------------------------------------------
# Live canonical ingest. Idempotent: if a source is already canonical,
# verify the existing package instead of creating a duplicate.
# -------------------------------------------------------------------
LEDGER="$OUT/03_CANONICAL_INGEST_LEDGER.tsv"
PROGRESS="$OUT/03_CANONICAL_INGEST_PROGRESS.txt"

export PAN45_PENDING_LEDGER="$PENDING_LEDGER"
export PAN45_RECEIPTS="$RECEIPTS"
export PAN45_OUTPUT="$OUTPUT"
export PAN45_LEDGER="$LEDGER"

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

from workspace.operational.ingestion.service.batch import ingest_sources

pending_ledger = Path(os.environ["PAN45_PENDING_LEDGER"])
receipt_root = Path(os.environ["PAN45_RECEIPTS"]).resolve()
output_root = Path(os.environ["PAN45_OUTPUT"]).resolve()
ledger_path = Path(os.environ["PAN45_LEDGER"])

with pending_ledger.open("r", encoding="utf-8", newline="") as h:
    pending = list(csv.DictReader(h, delimiter="\t"))

if len(pending) != 5:
    raise SystemExit(f"expected 5 pending rows, got {len(pending)}")

def source_from_package(pkg: Path):
    receipt = pkg / "metadata/receipt.json"
    provenance = pkg / "provenance/provenance.json"

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
            data = json.loads(provenance.read_text(encoding="utf-8"))
        except Exception:
            data = {}
        value = data.get("source_path") or data.get("source")
        if value:
            return Path(value).resolve()

    return None

def inspect_package(pkg: Path, source: Path):
    manifest_path = pkg / "reports/manifest.json"
    validation_path = pkg / "reports/validation.json"

    if not manifest_path.is_file() or not validation_path.is_file():
        return None

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        validation = json.loads(validation_path.read_text(encoding="utf-8"))
    except Exception:
        return None

    if validation.get("passed") is not True:
        return None

    observed = source_from_package(pkg)
    if observed != source:
        return None

    return {
        "package": pkg.resolve(),
        "manifest": manifest,
        "validation": validation,
    }

def find_existing(source: Path):
    if not output_root.exists():
        return None

    for pkg in sorted(output_root.iterdir()):
        if not pkg.is_dir():
            continue
        hit = inspect_package(pkg, source)
        if hit is not None:
            return hit

    return None

new_count = 0
existing_count = 0
fail_count = 0
failed_source = ""

with ledger_path.open("w", encoding="utf-8", newline="") as h:
    fields = [
        "index",
        "status",
        "sha256",
        "bytes",
        "expected_manifest_kind",
        "actual_manifest_kind",
        "validation_passed",
        "source",
        "output",
        "exception",
    ]
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()

    for i, row in enumerate(pending, start=1):
        source = Path(row["source"]).resolve()
        expected_hash = row["sha256"].strip()
        expected_kind = (row.get("current_manifest_kind") or "").strip()

        actual_hash = hashlib.sha256(source.read_bytes()).hexdigest()
        if actual_hash != expected_hash:
            raise SystemExit(f"source hash drift during ingest: {source}")

        status = "FAIL"
        output = ""
        actual_kind = ""
        validation_passed = False
        exc = ""

        try:
            existing = find_existing(source)

            if existing is not None:
                status = "ALREADY_CANONICAL"
                output = str(existing["package"])
                actual_kind = str(existing["manifest"].get("kind", ""))
                validation_passed = True
                existing_count += 1
            else:
                outputs = ingest_sources(
                    sources=(source,),
                    receipt_root=receipt_root,
                    output_root=output_root,
                    source_class="manual_batch",
                )

                if len(outputs) != 1:
                    # If the batch service suppresses a duplicate, allow it only
                    # when a verified canonical package becomes visible.
                    existing = find_existing(source)
                    if len(outputs) == 0 and existing is not None:
                        status = "ALREADY_CANONICAL"
                        output = str(existing["package"])
                        actual_kind = str(existing["manifest"].get("kind", ""))
                        validation_passed = True
                        existing_count += 1
                    else:
                        raise RuntimeError(
                            f"expected one canonical output, got {len(outputs)}"
                        )
                else:
                    pkg = Path(outputs[0]).resolve()
                    inspected = inspect_package(pkg, source)
                    if inspected is None:
                        raise RuntimeError(
                            "new canonical package failed validation/source binding"
                        )

                    status = "NEW_CANONICAL"
                    output = str(pkg)
                    actual_kind = str(inspected["manifest"].get("kind", ""))
                    validation_passed = True
                    new_count += 1

            if expected_kind and actual_kind != expected_kind:
                raise RuntimeError(
                    f"manifest kind drift expected={expected_kind!r} "
                    f"actual={actual_kind!r}"
                )

        except Exception as e:
            fail_count += 1
            failed_source = str(source)
            exc = f"{type(e).__name__}: {e}"
            status = "FAIL"

        w.writerow({
            "index": i,
            "status": status,
            "sha256": actual_hash,
            "bytes": source.stat().st_size,
            "expected_manifest_kind": expected_kind,
            "actual_manifest_kind": actual_kind,
            "validation_passed": validation_passed,
            "source": str(source),
            "output": output,
            "exception": exc,
        })

        print(f"[{i}/5] {status} {source.name}", flush=True)

        if status == "FAIL":
            break

print(f"TOTAL_TARGET=5")
print(f"NEW_CANONICAL={new_count}")
print(f"ALREADY_CANONICAL={existing_count}")
print(f"FAIL={fail_count}")
print(f"FAILED_SOURCE={failed_source}")

if fail_count:
    raise SystemExit(1)
if new_count + existing_count != 5:
    raise SystemExit(
        f"completion count mismatch new={new_count} existing={existing_count}"
    )
PY
) | tee "$PROGRESS"
INGEST_RC=${PIPESTATUS[0]}
set -e

if [ "$INGEST_RC" -ne 0 ]; then
  echo "BLOCKER: canonical ingest failed"
  tail -40 "$LEDGER" 2>/dev/null || true
  exit 27
fi

# -------------------------------------------------------------------
# Gate 3: reverify all source hashes after live ingest.
# -------------------------------------------------------------------
if ! "$PYTHON" - "$PENDING_LEDGER" > "$OUT/04_SOURCE_HASHES_POST.txt" <<'PY'
from pathlib import Path
import csv
import hashlib
import sys

ledger = Path(sys.argv[1])

with ledger.open("r", encoding="utf-8", newline="") as h:
    rows = list(csv.DictReader(h, delimiter="\t"))

for r in rows:
    source = Path(r["source"]).resolve()
    expected = r["sha256"].strip()
    actual = hashlib.sha256(source.read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f"source hash drift: {source}")

print(f"VERIFIED={len(rows)}")
print("SOURCE_HASHES_POST=PASS")
PY
then
  echo "BLOCKER: post-ingest source hash verification failed"
  cat "$OUT/04_SOURCE_HASHES_POST.txt" || true
  exit 28
fi

# -------------------------------------------------------------------
# Gate 4: all five live packages must be present, source-bound, and valid.
# -------------------------------------------------------------------
if ! "$PYTHON" - "$LEDGER" > "$OUT/05_LIVE_PACKAGE_VERIFICATION.txt" <<'PY'
from pathlib import Path
import csv
import json
import sys

ledger = Path(sys.argv[1])

with ledger.open("r", encoding="utf-8", newline="") as h:
    rows = list(csv.DictReader(h, delimiter="\t"))

if len(rows) != 5:
    raise SystemExit(f"expected 5 canonical ledger rows, got {len(rows)}")

for r in rows:
    if r["status"] not in {"NEW_CANONICAL", "ALREADY_CANONICAL"}:
        raise SystemExit(f"noncanonical status: {r['status']}")

    source = Path(r["source"]).resolve()
    pkg = Path(r["output"]).resolve()

    if not pkg.is_dir():
        raise SystemExit(f"package missing: {pkg}")

    manifest = json.loads(
        (pkg / "reports/manifest.json").read_text(encoding="utf-8")
    )
    validation = json.loads(
        (pkg / "reports/validation.json").read_text(encoding="utf-8")
    )

    if validation.get("passed") is not True:
        raise SystemExit(f"validation did not pass: {pkg}")

    expected_kind = r["expected_manifest_kind"].strip()
    actual_kind = str(manifest.get("kind", ""))
    if expected_kind and actual_kind != expected_kind:
        raise SystemExit(
            f"manifest drift: {source} expected={expected_kind} actual={actual_kind}"
        )

    print(
        f"PASS\t{source}\t{pkg}\tkind={actual_kind}"
    )

print("LIVE_PACKAGES_VERIFIED=5")
print("LIVE_CANONICAL_VALIDATION=PASS")
PY
then
  echo "BLOCKER: live package verification failed"
  cat "$OUT/05_LIVE_PACKAGE_VERIFICATION.txt" || true
  exit 29
fi

# -------------------------------------------------------------------
# Gate 5: regression again after live output writes.
# -------------------------------------------------------------------
if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" "$RUN_ALL"
) > "$OUT/06_POST_INGEST_REGRESSION.txt" 2>&1
then
  echo "BLOCKER: post-ingest regression failed"
  tail -80 "$OUT/06_POST_INGEST_REGRESSION.txt" || true
  exit 30
fi

# -------------------------------------------------------------------
# Post-state and counts.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/07_GIT_STATUS_POST.z" 2>/dev/null || true
git -C "$CURRENT" status --short --branch > "$OUT/07_GIT_POST.txt" 2>&1 || true

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/07_OUTPUT_COUNT_POST.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/07_RECEIPT_COUNT_POST.txt"

NEW_CANONICAL="$(sed -n 's/^NEW_CANONICAL=//p' "$PROGRESS" | tail -1)"
ALREADY_CANONICAL="$(sed -n 's/^ALREADY_CANONICAL=//p' "$PROGRESS" | tail -1)"
FAIL_COUNT="$(sed -n 's/^FAIL=//p' "$PROGRESS" | tail -1)"

NEW_CANONICAL="${NEW_CANONICAL:-0}"
ALREADY_CANONICAL="${ALREADY_CANONICAL:-0}"
FAIL_COUNT="${FAIL_COUNT:-1}"

PRE_OUTPUT="$(cat "$OUT/00_OUTPUT_COUNT_PRE.txt")"
POST_OUTPUT="$(cat "$OUT/07_OUTPUT_COUNT_POST.txt")"
PRE_RECEIPTS="$(cat "$OUT/00_RECEIPT_COUNT_PRE.txt")"
POST_RECEIPTS="$(cat "$OUT/07_RECEIPT_COUNT_POST.txt")"

if [ "$FAIL_COUNT" -ne 0 ] || [ "$((NEW_CANONICAL + ALREADY_CANONICAL))" -ne 5 ]; then
  STATUS="FAIL"
  NEXT="PRESERVE_STAGE45_FAILURE_EVIDENCE"
else
  STATUS="PASS"
  NEXT="VERIFY_FIRST_CORPUS_TEXTLIKE_CLOSURE_777_EQUALS_676_CANONICAL_PLUS_101_HELD_BACK"
fi

cat > "$OUT/CHANGELOG_EVENT.txt" <<EOF
UTC=$TS
EVENT=STAGE44_VALIDATED_PENDING5_CANONICALLY_INGESTED
CLASSIFICATION=LIVE_CANONICAL_COMPLETION
STAGE44=$LATEST44
TARGET=5
NEW_CANONICAL=$NEW_CANONICAL
ALREADY_CANONICAL=$ALREADY_CANONICAL
FAIL_COUNT=$FAIL_COUNT
SOURCE_HASHES_PRE=PASS
SOURCE_HASHES_POST=PASS
LIVE_PACKAGE_VALIDATION=PASS
PRE_INGEST_REGRESSION=PASS
POST_INGEST_REGRESSION=PASS
COMMIT_CREATED=NO
EOF

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_CANONICAL_INGEST_STAGE44_PENDING5_STAGE45
UTC=$TS
STATUS=$STATUS
STAGE44=$LATEST44
TARGET=5
NEW_CANONICAL=$NEW_CANONICAL
ALREADY_CANONICAL=$ALREADY_CANONICAL
FAIL_COUNT=$FAIL_COUNT
SOURCE_HASHES_PRE=PASS
SOURCE_HASHES_POST=PASS
LIVE_PACKAGES_VERIFIED=5
LIVE_CANONICAL_VALIDATION=PASS
PRE_INGEST_REGRESSION=PASS
POST_INGEST_REGRESSION=PASS
PRE_OUTPUT_PACKAGES=$PRE_OUTPUT
POST_OUTPUT_PACKAGES=$POST_OUTPUT
PRE_RECEIPTS=$PRE_RECEIPTS
POST_RECEIPTS=$POST_RECEIPTS
SOURCE_MUTATION=NONE
LIVE_INGESTION_EXECUTED=YES
COMMIT_CREATED=NO
ORIGINAL_HELD_BACK_VALIDATED_PENDING_CANONICAL_INGEST=0
EVIDENCE=$OUT
LEDGER=$LEDGER
CHANGELOG_EVENT=$OUT/CHANGELOG_EVENT.txt
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- canonical ledger ---"
cat "$LEDGER"
echo
echo "--- post-ingest regression tail ---"
tail -40 "$OUT/06_POST_INGEST_REGRESSION.txt"
echo

if [ "$STATUS" = "PASS" ]; then
  echo "STAGE45_COMPLETE=YES"
  exit 0
fi

echo "STAGE45_COMPLETE=NO"
exit 1
