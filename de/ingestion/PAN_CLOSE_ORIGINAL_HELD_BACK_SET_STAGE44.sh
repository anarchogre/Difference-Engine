#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_CLOSE_ORIGINAL_HELD_BACK_SET_$TS-STAGE44"

mkdir -p "$OUT"

echo "=== PAN — CLOSE ORIGINAL HELD-BACK SET / STAGE 44 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

# -------------------------------------------------------------------
# Recover latest successful evidence for each disposition family.
# -------------------------------------------------------------------
find_stage() {
  local marker="$1"
  local required="$2"
  "$PYTHON" - "$TREE_HOME" "$marker" "$required" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
marker = sys.argv[2]
required = sys.argv[3]
hits = []

for d in root.iterdir():
    if not d.is_dir():
        continue
    s = d / "SUMMARY.txt"
    if not s.is_file():
        continue
    t = s.read_text(encoding="utf-8", errors="replace")
    if marker not in t:
        continue
    if "STATUS=PASS" not in t:
        continue
    if required and required not in t:
        continue
    hits.append((d.stat().st_mtime_ns, d))

if hits:
    print(max(hits)[1])
PY
}

STAGE43="$(find_stage \
  "PAN_CLASSIFY_TXT35_SOURCE_DEFICIENT_STAGE43" \
  "TXT_CLASSIFIED=35")"

STAGE41="$(find_stage \
  "PAN_CLASSIFY_MARKDOWN_SOURCE_DEFICIENT_STAGE41" \
  "MARKDOWN_CLASSIFIED=62")"

STAGE37="$(find_stage \
  "PAN_REQUALIFY_STAGE28_FAILURE_SET_STAGE37" \
  "ORIGINAL_FAILURE_SET=106")"

STAGE32="$(find_stage \
  "PAN_BOUND_JSON_EXCEPTION_TAIL_STAGE32" \
  "JSON_TAIL_COUNT=4")"

for x in "$STAGE43" "$STAGE41" "$STAGE37" "$STAGE32"; do
  [ -n "$x" ] && [ -d "$x" ] || {
    echo "BLOCKER: required prior stage evidence missing"
    exit 22
  }
done

TXT_LEDGER="$STAGE43/01_TXT35_DISPOSITION_LEDGER.tsv"
MD_LEDGER="$STAGE41/01_MARKDOWN_DISPOSITION_LEDGER.tsv"
REQUAL_LEDGER="$STAGE37/02_REQUALIFICATION_LEDGER.tsv"
JSON_DETAIL="$STAGE32/02_JSON_TAIL_DETAIL.tsv"

for x in "$TXT_LEDGER" "$MD_LEDGER" "$REQUAL_LEDGER" "$JSON_DETAIL"; do
  [ -f "$x" ] || { echo "BLOCKER: missing required ledger $x"; exit 23; }
done

echo "STAGE43=$STAGE43"
echo "STAGE41=$STAGE41"
echo "STAGE37=$STAGE37"
echo "STAGE32=$STAGE32"
echo

# -------------------------------------------------------------------
# Pre-state. Stage44 is accounting/disposition only.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/00_OUTPUT_COUNT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/00_RECEIPT_COUNT_PRE.txt"

export PAN44_TXT_LEDGER="$TXT_LEDGER"
export PAN44_MD_LEDGER="$MD_LEDGER"
export PAN44_REQUAL_LEDGER="$REQUAL_LEDGER"
export PAN44_JSON_DETAIL="$JSON_DETAIL"
export PAN44_OUT="$OUT"

"$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter
import csv
import hashlib
import json
import os

txt_path = Path(os.environ["PAN44_TXT_LEDGER"])
md_path = Path(os.environ["PAN44_MD_LEDGER"])
requal_path = Path(os.environ["PAN44_REQUAL_LEDGER"])
json_path = Path(os.environ["PAN44_JSON_DETAIL"])
out = Path(os.environ["PAN44_OUT"])

def read_tsv(path):
    with path.open("r", encoding="utf-8", newline="") as h:
        return list(csv.DictReader(h, delimiter="\t"))

txt = read_tsv(txt_path)
md = read_tsv(md_path)
requal = read_tsv(requal_path)
json_rows = read_tsv(json_path)

if len(txt) != 35:
    raise SystemExit(f"BLOCKER: expected 35 TXT dispositions, got {len(txt)}")
if len(md) != 62:
    raise SystemExit(f"BLOCKER: expected 62 Markdown dispositions, got {len(md)}")
if len(requal) != 106:
    raise SystemExit(f"BLOCKER: expected 106 Stage37 requalification rows, got {len(requal)}")
if len(json_rows) != 4:
    raise SystemExit(f"BLOCKER: expected 4 JSON rows, got {len(json_rows)}")

# -------------------------------------------------------------------
# Stage37 authoritative partition: 5 now passing, 101 still held back.
# -------------------------------------------------------------------
now_passing = [
    r for r in requal
    if (r.get("current_status") or "") == "PASS"
]
still_not_passing = [
    r for r in requal
    if (r.get("current_status") or "") != "PASS"
]

if len(now_passing) != 5:
    raise SystemExit(f"BLOCKER: expected 5 newly passing rows, got {len(now_passing)}")
if len(still_not_passing) != 101:
    raise SystemExit(f"BLOCKER: expected 101 residual rows, got {len(still_not_passing)}")

# -------------------------------------------------------------------
# Verify Markdown/TXT disposition sets correspond exactly to Stage37 residual.
# -------------------------------------------------------------------
requal_by_source = {
    str(Path(r["source"]).resolve()): r
    for r in requal
}
residual_sources = {
    str(Path(r["source"]).resolve())
    for r in still_not_passing
}

md_sources = {
    str(Path(r["source"]).resolve())
    for r in md
}
txt_sources = {
    str(Path(r["source"]).resolve())
    for r in txt
}

# -------------------------------------------------------------------
# Formal JSON disposition: preserve distinction between source-invalid and
# encoding-unresolved. Do not collapse unresolved into invalid.
# -------------------------------------------------------------------
json_dispositions = []
json_sources = set()
hash_failures = []
json_class_counts = Counter()
json_disposition_counts = Counter()

for r in json_rows:
    source = Path(r["source"]).resolve()
    source_str = str(source)
    json_sources.add(source_str)

    if not source.is_file():
        raise SystemExit(f"BLOCKER: JSON source missing: {source}")

    expected = (
        r.get("sha256_now")
        or r.get("sha256_stage30")
        or ""
    ).strip()

    actual = hashlib.sha256(source.read_bytes()).hexdigest()
    if not expected or actual != expected:
        hash_failures.append(source_str)

    classification = (r.get("classification") or "").strip()

    if classification == "SOURCE_EMPTY":
        disposition = "HELD_BACK_SOURCE_EMPTY"
        reason = (
            "Zero-byte source contains no semantic JSON content; parser repair "
            "cannot recover absent source data."
        )
        repair = "NO"
        source_state = "SOURCE_INVALID_EMPTY"
    elif classification == "NON_UTF8_UNRESOLVED":
        disposition = "HELD_BACK_ENCODING_UNRESOLVED"
        reason = (
            "Source is not valid UTF-8 and no deterministic tested alternate "
            "encoding yielded valid JSON; representation remains unresolved."
        )
        repair = "NO_CURRENTLY_SUPPORTED_REPAIR"
        source_state = "REPRESENTATION_UNRESOLVED"
    else:
        raise SystemExit(
            f"BLOCKER: unexpected Stage32 JSON classification "
            f"{classification!r} for {source}"
        )

    json_class_counts[classification] += 1
    json_disposition_counts[disposition] += 1

    json_dispositions.append({
        "source": source_str,
        "sha256": actual,
        "bytes": r.get("bytes", ""),
        "stage32_classification": classification,
        "disposition": disposition,
        "source_state": source_state,
        "repair_indicated": repair,
        "source_rewrite_authorized": "NO",
        "parser_broadening_authorized": "NO",
        "reason": reason,
    })

if hash_failures:
    (out / "HASH_FAILURES.txt").write_text(
        "\n".join(hash_failures) + "\n",
        encoding="utf-8",
    )
    raise SystemExit(f"BLOCKER: {len(hash_failures)} JSON source hash failures")

if json_class_counts.get("SOURCE_EMPTY", 0) != 2:
    raise SystemExit("BLOCKER: expected exactly 2 SOURCE_EMPTY JSON files")
if json_class_counts.get("NON_UTF8_UNRESOLVED", 0) != 2:
    raise SystemExit("BLOCKER: expected exactly 2 NON_UTF8_UNRESOLVED JSON files")

json_fields = list(json_dispositions[0].keys())
with (out / "01_JSON4_DISPOSITION_LEDGER.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    w = csv.DictWriter(h, fieldnames=json_fields, delimiter="\t")
    w.writeheader()
    w.writerows(json_dispositions)

# JSON sources must be exactly the residual JSON subset.
residual_json_sources = {
    str(Path(r["source"]).resolve())
    for r in still_not_passing
    if (r.get("extension") or "").lower() == ".json"
}

if json_sources != residual_json_sources:
    raise SystemExit(
        "BLOCKER: Stage32 JSON set does not match Stage37 residual JSON set"
    )

# Final residual coverage must be exact: 62 MD + 35 TXT + 4 JSON = 101.
accounted_residual = md_sources | txt_sources | json_sources

if md_sources & txt_sources or md_sources & json_sources or txt_sources & json_sources:
    raise SystemExit("BLOCKER: disposition families overlap")

if accounted_residual != residual_sources:
    missing = sorted(residual_sources - accounted_residual)
    extra = sorted(accounted_residual - residual_sources)
    (out / "ACCOUNTING_MISMATCH.txt").write_text(
        "MISSING=\n" + "\n".join(missing) +
        "\nEXTRA=\n" + "\n".join(extra) + "\n",
        encoding="utf-8",
    )
    raise SystemExit(
        f"BLOCKER: residual accounting mismatch missing={len(missing)} extra={len(extra)}"
    )

# -------------------------------------------------------------------
# Preserve the exact five newly passing sources for Stage45 canonical ingest.
# They remain source-hash verified but are not claimed live-canonical here.
# -------------------------------------------------------------------
passing_rows = []
passing_hash_failures = []

for r in now_passing:
    source = Path(r["source"]).resolve()
    if not source.is_file():
        raise SystemExit(f"BLOCKER: newly passing source missing: {source}")

    expected = (r.get("sha256") or "").strip()
    actual = hashlib.sha256(source.read_bytes()).hexdigest()

    if not expected or actual != expected:
        passing_hash_failures.append(str(source))

    passing_rows.append({
        "source": str(source),
        "sha256": actual,
        "extension": source.suffix.lower(),
        "current_manifest_kind": r.get("current_manifest_kind", ""),
        "stage37_status": r.get("current_status", ""),
        "disposition": "VALIDATED_PENDING_CANONICAL_INGEST",
    })

if passing_hash_failures:
    (out / "PASSING_HASH_FAILURES.txt").write_text(
        "\n".join(passing_hash_failures) + "\n",
        encoding="utf-8",
    )
    raise SystemExit(
        f"BLOCKER: {len(passing_hash_failures)} newly passing source hash failures"
    )

with (out / "02_STAGE37_NOW_PASSING_5.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    fields = list(passing_rows[0].keys())
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(passing_rows)

(out / "02_STAGE37_NOW_PASSING_5.txt").write_text(
    "\n".join(r["source"] for r in passing_rows) + "\n",
    encoding="utf-8",
)

# -------------------------------------------------------------------
# Full original-set accounting.
# -------------------------------------------------------------------
summary_rows = [
    ("VALIDATED_PENDING_CANONICAL_INGEST", 5),
    ("HELD_BACK_MARKDOWN_SOURCE_DEFICIENT", 62),
    ("HELD_BACK_TXT_SOURCE_DEFICIENT", 35),
    ("HELD_BACK_JSON_SOURCE_EMPTY", 2),
    ("HELD_BACK_JSON_ENCODING_UNRESOLVED", 2),
]

with (out / "03_ORIGINAL_106_ACCOUNTING.tsv").open(
    "w", encoding="utf-8"
) as h:
    h.write("count\tdisposition\n")
    for disposition, count in summary_rows:
        h.write(f"{count}\t{disposition}\n")
    h.write("106\tTOTAL_ORIGINAL_HELD_BACK_SET\n")

accounted_total = sum(count for _, count in summary_rows)
if accounted_total != 106:
    raise SystemExit(
        f"BLOCKER: accounting total must be 106, got {accounted_total}"
    )

(out / "04_CLOSURE_STATE.txt").write_text(
    "ORIGINAL_HELD_BACK_SET=106\n"
    "ACCOUNTED=106\n"
    "UNCLASSIFIED=0\n"
    "NOW_VALIDATED_PENDING_CANONICAL_INGEST=5\n"
    "HELD_BACK_SOURCE_DEFICIENT_MARKDOWN=62\n"
    "HELD_BACK_SOURCE_DEFICIENT_TXT=35\n"
    "HELD_BACK_JSON_SOURCE_EMPTY=2\n"
    "HELD_BACK_JSON_ENCODING_UNRESOLVED=2\n"
    "JSON_PARSER_BROADENING_AUTHORIZED=NO\n"
    "SOURCE_REWRITE_AUTHORIZED=NO\n"
    "ORIGINAL_HELD_BACK_ACCOUNTING=CLOSED\n"
    "LIVE_CANONICAL_COMPLETION=NOT_YET_COMPLETE_5_VALIDATED_SOURCES_PENDING\n",
    encoding="utf-8",
)

print("ORIGINAL_HELD_BACK_SET=106")
print("ACCOUNTED=106")
print("UNCLASSIFIED=0")
print("NOW_VALIDATED_PENDING_CANONICAL_INGEST=5")
print("MARKDOWN_SOURCE_DEFICIENT=62")
print("TXT_SOURCE_DEFICIENT=35")
print("JSON_SOURCE_EMPTY=2")
print("JSON_ENCODING_UNRESOLVED=2")
print("SOURCE_HASHES=PASS")
print("ORIGINAL_HELD_BACK_ACCOUNTING=CLOSED")
print("LIVE_CANONICAL_COMPLETION=PENDING_5")
PY

# -------------------------------------------------------------------
# Post-state proof.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/05_GIT_STATUS_POST.z" 2>/dev/null || true

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/05_OUTPUT_COUNT_POST.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/05_RECEIPT_COUNT_POST.txt"

GIT_MUTATION="NONE"
cmp -s "$OUT/00_GIT_STATUS_PRE.z" "$OUT/05_GIT_STATUS_POST.z" || GIT_MUTATION="DETECTED"

PRE_OUTPUT="$(cat "$OUT/00_OUTPUT_COUNT_PRE.txt")"
POST_OUTPUT="$(cat "$OUT/05_OUTPUT_COUNT_POST.txt")"
PRE_RECEIPTS="$(cat "$OUT/00_RECEIPT_COUNT_PRE.txt")"
POST_RECEIPTS="$(cat "$OUT/05_RECEIPT_COUNT_POST.txt")"

LIVE_MUTATION="NONE"
if [ "$PRE_OUTPUT" != "$POST_OUTPUT" ] || [ "$PRE_RECEIPTS" != "$POST_RECEIPTS" ]; then
  LIVE_MUTATION="DETECTED"
fi

if [ "$GIT_MUTATION" = "NONE" ] && [ "$LIVE_MUTATION" = "NONE" ]; then
  STATUS="PASS"
  NEXT="CANONICAL_INGEST_STAGE37_NOW_PASSING_5_ONLY"
else
  STATUS="FAIL"
  NEXT="PRESERVE_STAGE44_MUTATION_EVIDENCE"
fi

cat > "$OUT/CHANGELOG_EVENT.txt" <<EOF
UTC=$TS
EVENT=ORIGINAL_STAGE28_HELD_BACK_SET_FULLY_ACCOUNTED
CLASSIFICATION=OBSERVED_AND_VALIDATED_ACCOUNTING
ORIGINAL_HELD_BACK_SET=106
ACCOUNTED=106
UNCLASSIFIED=0
VALIDATED_PENDING_CANONICAL_INGEST=5
MARKDOWN_SOURCE_DEFICIENT=62
TXT_SOURCE_DEFICIENT=35
JSON_SOURCE_EMPTY=2
JSON_ENCODING_UNRESOLVED=2
ORIGINAL_HELD_BACK_ACCOUNTING=CLOSED
LIVE_CANONICAL_COMPLETION=PENDING_5
EOF

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_CLOSE_ORIGINAL_HELD_BACK_SET_STAGE44
UTC=$TS
STATUS=$STATUS
STAGE43=$STAGE43
STAGE41=$STAGE41
STAGE37=$STAGE37
STAGE32=$STAGE32
ORIGINAL_HELD_BACK_SET=106
ACCOUNTED=106
UNCLASSIFIED=0
VALIDATED_PENDING_CANONICAL_INGEST=5
MARKDOWN_SOURCE_DEFICIENT=62
TXT_SOURCE_DEFICIENT=35
JSON_SOURCE_EMPTY=2
JSON_ENCODING_UNRESOLVED=2
SOURCE_HASHES=PASS
ORIGINAL_HELD_BACK_ACCOUNTING=CLOSED
LIVE_CANONICAL_COMPLETION=PENDING_5
REPOSITORY_STATUS_MUTATION=$GIT_MUTATION
LIVE_OUTPUT_MUTATION=$LIVE_MUTATION
SOURCE_MUTATION=NONE
LIVE_INGESTION_EXECUTED=NO
PARSER_CODE_MODIFIED=NO
VALIDATOR_CODE_MODIFIED=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
JSON_DISPOSITION_LEDGER=$OUT/01_JSON4_DISPOSITION_LEDGER.tsv
NOW_PASSING_5_LEDGER=$OUT/02_STAGE37_NOW_PASSING_5.tsv
NOW_PASSING_5_SET=$OUT/02_STAGE37_NOW_PASSING_5.txt
ACCOUNTING=$OUT/03_ORIGINAL_106_ACCOUNTING.tsv
CLOSURE_STATE=$OUT/04_CLOSURE_STATE.txt
CHANGELOG_EVENT=$OUT/CHANGELOG_EVENT.txt
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- original 106 accounting ---"
cat "$OUT/03_ORIGINAL_106_ACCOUNTING.tsv"
echo
echo "--- closure state ---"
cat "$OUT/04_CLOSURE_STATE.txt"
echo

if [ "$STATUS" = "PASS" ]; then
  echo "STAGE44_COMPLETE=YES"
  exit 0
fi

echo "STAGE44_COMPLETE=NO"
exit 1
