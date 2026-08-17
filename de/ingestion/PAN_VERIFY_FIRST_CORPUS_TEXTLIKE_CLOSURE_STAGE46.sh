#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_VERIFY_FIRST_CORPUS_TEXTLIKE_CLOSURE_$TS-STAGE46"

mkdir -p "$OUT"

echo "=== PAN — VERIFY FIRST CORPUS TEXTLIKE CLOSURE / STAGE 46 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

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
    text = s.read_text(encoding="utf-8", errors="replace")
    if marker not in text:
        continue
    if "STATUS=PASS" not in text:
        continue
    if required and required not in text:
        continue
    hits.append((d.stat().st_mtime_ns, d))

if hits:
    print(max(hits)[1])
PY
}

STAGE45="$(find_stage \
  "PAN_CANONICAL_INGEST_STAGE44_PENDING5_STAGE45" \
  "TARGET=5")"

STAGE44="$(find_stage \
  "PAN_CLOSE_ORIGINAL_HELD_BACK_SET_STAGE44" \
  "ACCOUNTED=106")"

STAGE43="$(find_stage \
  "PAN_CLASSIFY_TXT35_SOURCE_DEFICIENT_STAGE43" \
  "TXT_CLASSIFIED=35")"

STAGE41="$(find_stage \
  "PAN_CLASSIFY_MARKDOWN_SOURCE_DEFICIENT_STAGE41" \
  "MARKDOWN_CLASSIFIED=62")"

STAGE29="$(find_stage \
  "PAN_CANONICAL_INGEST_STAGE28_PASS_SET_STAGE29" \
  "TARGET_PASS_SET=671")"

STAGE28="$(find_stage \
  "PAN_FIRST_CORPUS_TEXTLIKE_DRYRUN_STAGE28" \
  "TOTAL_CANDIDATES=777")"

for x in "$STAGE45" "$STAGE44" "$STAGE43" "$STAGE41" "$STAGE29" "$STAGE28"; do
  [ -n "$x" ] && [ -d "$x" ] || {
    echo "BLOCKER: required prior stage evidence missing"
    exit 22
  }
done

STAGE29_LEDGER="$(sed -n 's/^LEDGER=//p' "$STAGE29/SUMMARY.txt" | head -1)"
STAGE45_LEDGER="$(sed -n 's/^LEDGER=//p' "$STAGE45/SUMMARY.txt" | head -1)"
MD_LEDGER="$STAGE41/01_MARKDOWN_DISPOSITION_LEDGER.tsv"
TXT_LEDGER="$STAGE43/01_TXT35_DISPOSITION_LEDGER.tsv"
JSON_LEDGER="$STAGE44/01_JSON4_DISPOSITION_LEDGER.tsv"
HASH_LEDGER="$STAGE28/07_SOURCE_HASHES_BEFORE.tsv"
PASS_SET="$(sed -n 's/^PASS_SET=//p' "$STAGE28/SUMMARY.txt" | head -1)"
FAIL_SET="$(sed -n 's/^FAIL_SET=//p' "$STAGE28/SUMMARY.txt" | head -1)"

for x in \
  "$STAGE29_LEDGER" \
  "$STAGE45_LEDGER" \
  "$MD_LEDGER" \
  "$TXT_LEDGER" \
  "$JSON_LEDGER" \
  "$HASH_LEDGER" \
  "$PASS_SET" \
  "$FAIL_SET"
do
  [ -f "$x" ] || {
    echo "BLOCKER: missing required artifact $x"
    exit 23
  }
done

echo "STAGE45=$STAGE45"
echo "STAGE44=$STAGE44"
echo "STAGE29=$STAGE29"
echo "STAGE28=$STAGE28"
echo

# -------------------------------------------------------------------
# Pre-state. Stage46 must be fully read-only.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/00_OUTPUT_COUNT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/00_RECEIPT_COUNT_PRE.txt"

export PAN46_STAGE29_LEDGER="$STAGE29_LEDGER"
export PAN46_STAGE45_LEDGER="$STAGE45_LEDGER"
export PAN46_MD_LEDGER="$MD_LEDGER"
export PAN46_TXT_LEDGER="$TXT_LEDGER"
export PAN46_JSON_LEDGER="$JSON_LEDGER"
export PAN46_HASH_LEDGER="$HASH_LEDGER"
export PAN46_PASS_SET="$PASS_SET"
export PAN46_FAIL_SET="$FAIL_SET"
export PAN46_OUT="$OUT"

"$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter
import csv
import hashlib
import json
import os

stage29_path = Path(os.environ["PAN46_STAGE29_LEDGER"])
stage45_path = Path(os.environ["PAN46_STAGE45_LEDGER"])
md_path = Path(os.environ["PAN46_MD_LEDGER"])
txt_path = Path(os.environ["PAN46_TXT_LEDGER"])
json_path = Path(os.environ["PAN46_JSON_LEDGER"])
hash_path = Path(os.environ["PAN46_HASH_LEDGER"])
pass_set_path = Path(os.environ["PAN46_PASS_SET"])
fail_set_path = Path(os.environ["PAN46_FAIL_SET"])
out = Path(os.environ["PAN46_OUT"])

def read_tsv(path):
    with path.open("r", encoding="utf-8", newline="") as h:
        return list(csv.DictReader(h, delimiter="\t"))

stage29 = read_tsv(stage29_path)
stage45 = read_tsv(stage45_path)
md = read_tsv(md_path)
txt = read_tsv(txt_path)
json_rows = read_tsv(json_path)

if len(stage29) != 671:
    raise SystemExit(f"BLOCKER: expected 671 Stage29 rows, got {len(stage29)}")
if len(stage45) != 5:
    raise SystemExit(f"BLOCKER: expected 5 Stage45 rows, got {len(stage45)}")
if len(md) != 62:
    raise SystemExit(f"BLOCKER: expected 62 Markdown held-back rows, got {len(md)}")
if len(txt) != 35:
    raise SystemExit(f"BLOCKER: expected 35 TXT held-back rows, got {len(txt)}")
if len(json_rows) != 4:
    raise SystemExit(f"BLOCKER: expected 4 JSON held-back rows, got {len(json_rows)}")

# -------------------------------------------------------------------
# Authoritative Stage28 set and hash ledger.
# -------------------------------------------------------------------
pass_set = [
    str(Path(x).resolve())
    for x in pass_set_path.read_text(encoding="utf-8").splitlines()
    if x.strip()
]
fail_set = [
    str(Path(x).resolve())
    for x in fail_set_path.read_text(encoding="utf-8").splitlines()
    if x.strip()
]

if len(pass_set) != 671:
    raise SystemExit(f"BLOCKER: Stage28 pass-set count drift: {len(pass_set)}")
if len(fail_set) != 106:
    raise SystemExit(f"BLOCKER: Stage28 fail-set count drift: {len(fail_set)}")

if set(pass_set) & set(fail_set):
    raise SystemExit("BLOCKER: Stage28 pass/fail sets overlap")

stage28_all = set(pass_set) | set(fail_set)

if len(stage28_all) != 777:
    raise SystemExit(f"BLOCKER: Stage28 authoritative union is {len(stage28_all)}, expected 777")

expected_hash = {}
for line in hash_path.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    parts = line.split("\t", 2)
    if len(parts) != 3:
        raise SystemExit("BLOCKER: malformed Stage28 hash ledger")
    digest, size, path = parts
    key = str(Path(path).resolve())
    expected_hash[key] = (digest, int(size))

if set(expected_hash) != stage28_all:
    missing = sorted(stage28_all - set(expected_hash))
    extra = sorted(set(expected_hash) - stage28_all)
    raise SystemExit(
        f"BLOCKER: Stage28 hash ledger set mismatch missing={len(missing)} extra={len(extra)}"
    )

# -------------------------------------------------------------------
# Verify all 777 source bytes still match Stage28.
# -------------------------------------------------------------------
hash_failures = []

for source_str in sorted(stage28_all):
    source = Path(source_str)
    if not source.is_file():
        hash_failures.append((source_str, "MISSING"))
        continue

    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    expected_digest, expected_size = expected_hash[source_str]

    if digest != expected_digest or source.stat().st_size != expected_size:
        hash_failures.append((source_str, "HASH_OR_SIZE_DRIFT"))

if hash_failures:
    with (out / "HASH_FAILURES.tsv").open("w", encoding="utf-8") as h:
        h.write("source\tfailure\n")
        for source, failure in hash_failures:
            h.write(f"{source}\t{failure}\n")
    raise SystemExit(f"BLOCKER: {len(hash_failures)} source hash/size failures")

# -------------------------------------------------------------------
# Canonical source set = Stage29 671 + Stage45 5.
# Every package must exist and validate.
# -------------------------------------------------------------------
canonical_rows = []

def verify_canonical_row(row, origin_stage):
    source = Path(row["source"]).resolve()
    source_str = str(source)
    status = (row.get("status") or "").strip()

    if status not in {"NEW_CANONICAL", "ALREADY_CANONICAL"}:
        raise SystemExit(
            f"BLOCKER: noncanonical status in {origin_stage}: {status!r} {source}"
        )

    pkg = Path((row.get("output") or "").strip()).resolve()
    if not pkg.is_dir():
        raise SystemExit(f"BLOCKER: canonical package missing: {pkg}")

    manifest_path = pkg / "reports/manifest.json"
    validation_path = pkg / "reports/validation.json"

    if not manifest_path.is_file() or not validation_path.is_file():
        raise SystemExit(f"BLOCKER: canonical package reports missing: {pkg}")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    validation = json.loads(validation_path.read_text(encoding="utf-8"))

    if validation.get("passed") is not True:
        raise SystemExit(f"BLOCKER: canonical package validation false: {pkg}")

    actual_kind = str(manifest.get("kind", ""))
    expected_kind = (
        row.get("actual_manifest_kind")
        or row.get("manifest_kind")
        or ""
    ).strip()

    if expected_kind and actual_kind != expected_kind:
        raise SystemExit(
            f"BLOCKER: manifest kind drift: {source} "
            f"expected={expected_kind!r} actual={actual_kind!r}"
        )

    canonical_rows.append({
        "source": source_str,
        "disposition": "LIVE_CANONICAL",
        "origin_stage": origin_stage,
        "package": str(pkg),
        "manifest_kind": actual_kind,
        "validation_passed": "True",
    })

for row in stage29:
    verify_canonical_row(row, "STAGE29")

for row in stage45:
    verify_canonical_row(row, "STAGE45")

canonical_sources = {r["source"] for r in canonical_rows}

if len(canonical_sources) != 676:
    raise SystemExit(
        f"BLOCKER: canonical source set is {len(canonical_sources)}, expected 676"
    )

if len(canonical_rows) != 676:
    raise SystemExit(
        f"BLOCKER: canonical row count is {len(canonical_rows)}, expected 676"
    )

# -------------------------------------------------------------------
# Held-back source set = Markdown 62 + TXT 35 + JSON 4.
# Preserve exact disposition semantics.
# -------------------------------------------------------------------
held_rows = []

for row in md:
    source = str(Path(row["source"]).resolve())
    if row.get("disposition") != "HELD_BACK_SOURCE_DEFICIENT":
        raise SystemExit(f"BLOCKER: unexpected Markdown disposition: {source}")

    held_rows.append({
        "source": source,
        "disposition": "HELD_BACK_MARKDOWN_SOURCE_DEFICIENT",
        "primary_blocker": row.get("primary_blocker", ""),
        "origin_stage": "STAGE41",
    })

for row in txt:
    source = str(Path(row["source"]).resolve())
    if row.get("disposition") != "HELD_BACK_SOURCE_DEFICIENT":
        raise SystemExit(f"BLOCKER: unexpected TXT disposition: {source}")

    held_rows.append({
        "source": source,
        "disposition": "HELD_BACK_TXT_SOURCE_DEFICIENT",
        "primary_blocker": row.get("primary_blocker", ""),
        "origin_stage": "STAGE43",
    })

for row in json_rows:
    source = str(Path(row["source"]).resolve())
    disp = row.get("disposition", "")

    if disp == "HELD_BACK_SOURCE_EMPTY":
        normalized = "HELD_BACK_JSON_SOURCE_EMPTY"
    elif disp == "HELD_BACK_ENCODING_UNRESOLVED":
        normalized = "HELD_BACK_JSON_ENCODING_UNRESOLVED"
    else:
        raise SystemExit(f"BLOCKER: unexpected JSON disposition {disp!r}: {source}")

    held_rows.append({
        "source": source,
        "disposition": normalized,
        "primary_blocker": row.get("source_state", ""),
        "origin_stage": "STAGE44",
    })

held_sources = {r["source"] for r in held_rows}

if len(held_sources) != 101:
    raise SystemExit(
        f"BLOCKER: held-back source set is {len(held_sources)}, expected 101"
    )

if len(held_rows) != 101:
    raise SystemExit(
        f"BLOCKER: held-back row count is {len(held_rows)}, expected 101"
    )

# -------------------------------------------------------------------
# Closure invariants.
# -------------------------------------------------------------------
overlap = canonical_sources & held_sources
if overlap:
    (out / "OVERLAP.txt").write_text(
        "\n".join(sorted(overlap)) + "\n",
        encoding="utf-8",
    )
    raise SystemExit(
        f"BLOCKER: {len(overlap)} sources appear in both canonical and held-back sets"
    )

accounted = canonical_sources | held_sources

missing = stage28_all - accounted
extra = accounted - stage28_all

if missing or extra:
    with (out / "ACCOUNTING_MISMATCH.txt").open("w", encoding="utf-8") as h:
        h.write("MISSING_FROM_ACCOUNTING=\n")
        for x in sorted(missing):
            h.write(x + "\n")
        h.write("EXTRA_IN_ACCOUNTING=\n")
        for x in sorted(extra):
            h.write(x + "\n")

    raise SystemExit(
        f"BLOCKER: closure mismatch missing={len(missing)} extra={len(extra)}"
    )

if len(accounted) != 777:
    raise SystemExit(
        f"BLOCKER: accounted union is {len(accounted)}, expected 777"
    )

# Stage28 original pass-set must be entirely canonical.
if set(pass_set) - canonical_sources:
    raise SystemExit(
        "BLOCKER: at least one original Stage28 pass source is not live canonical"
    )

# Original Stage28 fail-set must now split as exactly 5 canonical + 101 held.
fail_now_canonical = set(fail_set) & canonical_sources
fail_now_held = set(fail_set) & held_sources

if len(fail_now_canonical) != 5:
    raise SystemExit(
        f"BLOCKER: expected 5 Stage28-fail sources now canonical, got {len(fail_now_canonical)}"
    )

if len(fail_now_held) != 101:
    raise SystemExit(
        f"BLOCKER: expected 101 Stage28-fail sources held, got {len(fail_now_held)}"
    )

if fail_now_canonical | fail_now_held != set(fail_set):
    raise SystemExit(
        "BLOCKER: Stage28 fail-set does not partition cleanly into 5 canonical + 101 held"
    )

# -------------------------------------------------------------------
# Preserve full closure ledger.
# -------------------------------------------------------------------
closure_rows = []

for row in canonical_rows:
    closure_rows.append({
        "source": row["source"],
        "sha256": expected_hash[row["source"]][0],
        "bytes": expected_hash[row["source"]][1],
        "final_disposition": "LIVE_CANONICAL",
        "origin_stage": row["origin_stage"],
        "detail": row["package"],
    })

for row in held_rows:
    closure_rows.append({
        "source": row["source"],
        "sha256": expected_hash[row["source"]][0],
        "bytes": expected_hash[row["source"]][1],
        "final_disposition": row["disposition"],
        "origin_stage": row["origin_stage"],
        "detail": row["primary_blocker"],
    })

closure_rows.sort(key=lambda r: r["source"])

with (out / "01_FIRST_CORPUS_777_CLOSURE_LEDGER.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    fields = [
        "source",
        "sha256",
        "bytes",
        "final_disposition",
        "origin_stage",
        "detail",
    ]
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(closure_rows)

counts = Counter(r["final_disposition"] for r in closure_rows)

with (out / "02_CLOSURE_COUNTS.tsv").open("w", encoding="utf-8") as h:
    h.write("count\tfinal_disposition\n")
    for disp, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        h.write(f"{n}\t{disp}\n")
    h.write("777\tTOTAL_FIRST_CORPUS_TEXTLIKE\n")

(out / "03_CLOSURE_INVARIANTS.txt").write_text(
    "FIRST_CORPUS_TOTAL=777\n"
    "LIVE_CANONICAL=676\n"
    "HELD_BACK_TOTAL=101\n"
    "HELD_BACK_MARKDOWN_SOURCE_DEFICIENT=62\n"
    "HELD_BACK_TXT_SOURCE_DEFICIENT=35\n"
    "HELD_BACK_JSON_SOURCE_EMPTY=2\n"
    "HELD_BACK_JSON_ENCODING_UNRESOLVED=2\n"
    "CANONICAL_HELD_OVERLAP=0\n"
    "UNACCOUNTED=0\n"
    "EXTRA=0\n"
    "SOURCE_HASHES=PASS_777_OF_777\n"
    "STAGE28_PASS_SET_CANONICAL=671_OF_671\n"
    "STAGE28_FAIL_SET_NOW_CANONICAL=5_OF_106\n"
    "STAGE28_FAIL_SET_HELD_BACK=101_OF_106\n"
    "FIRST_CORPUS_TEXTLIKE_CLOSURE=PASS\n",
    encoding="utf-8",
)

print("FIRST_CORPUS_TOTAL=777")
print("LIVE_CANONICAL=676")
print("HELD_BACK_TOTAL=101")
print("HELD_BACK_MARKDOWN_SOURCE_DEFICIENT=62")
print("HELD_BACK_TXT_SOURCE_DEFICIENT=35")
print("HELD_BACK_JSON_SOURCE_EMPTY=2")
print("HELD_BACK_JSON_ENCODING_UNRESOLVED=2")
print("CANONICAL_HELD_OVERLAP=0")
print("UNACCOUNTED=0")
print("EXTRA=0")
print("SOURCE_HASHES=PASS_777_OF_777")
print("STAGE28_PASS_SET_CANONICAL=671_OF_671")
print("STAGE28_FAIL_SET_NOW_CANONICAL=5_OF_106")
print("STAGE28_FAIL_SET_HELD_BACK=101_OF_106")
print("FIRST_CORPUS_TEXTLIKE_CLOSURE=PASS")
PY

# -------------------------------------------------------------------
# Post-state verification.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/04_GIT_STATUS_POST.z" 2>/dev/null || true

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/04_OUTPUT_COUNT_POST.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/04_RECEIPT_COUNT_POST.txt"

GIT_MUTATION="NONE"
cmp -s "$OUT/00_GIT_STATUS_PRE.z" "$OUT/04_GIT_STATUS_POST.z" || GIT_MUTATION="DETECTED"

PRE_OUTPUT="$(cat "$OUT/00_OUTPUT_COUNT_PRE.txt")"
POST_OUTPUT="$(cat "$OUT/04_OUTPUT_COUNT_POST.txt")"
PRE_RECEIPTS="$(cat "$OUT/00_RECEIPT_COUNT_PRE.txt")"
POST_RECEIPTS="$(cat "$OUT/04_RECEIPT_COUNT_POST.txt")"

LIVE_MUTATION="NONE"
if [ "$PRE_OUTPUT" != "$POST_OUTPUT" ] || [ "$PRE_RECEIPTS" != "$POST_RECEIPTS" ]; then
  LIVE_MUTATION="DETECTED"
fi

if [ "$GIT_MUTATION" = "NONE" ] && [ "$LIVE_MUTATION" = "NONE" ]; then
  STATUS="PASS"
  NEXT="PRESERVE_FIRST_CORPUS_TEXTLIKE_CLOSURE_AND_ADVANCE_TO_NEXT_AUTHORITATIVE_CORPUS_FRONTIER"
else
  STATUS="FAIL"
  NEXT="PRESERVE_STAGE46_MUTATION_EVIDENCE"
fi

cat > "$OUT/CHANGELOG_EVENT.txt" <<EOF
UTC=$TS
EVENT=FIRST_CORPUS_TEXTLIKE_CLOSURE_VERIFIED
CLASSIFICATION=VALIDATED_CORPUS_CLOSURE
FIRST_CORPUS_TOTAL=777
LIVE_CANONICAL=676
HELD_BACK_TOTAL=101
HELD_BACK_MARKDOWN_SOURCE_DEFICIENT=62
HELD_BACK_TXT_SOURCE_DEFICIENT=35
HELD_BACK_JSON_SOURCE_EMPTY=2
HELD_BACK_JSON_ENCODING_UNRESOLVED=2
UNACCOUNTED=0
OVERLAP=0
SOURCE_HASHES=PASS_777_OF_777
EOF

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_VERIFY_FIRST_CORPUS_TEXTLIKE_CLOSURE_STAGE46
UTC=$TS
STATUS=$STATUS
STAGE45=$STAGE45
STAGE44=$STAGE44
STAGE43=$STAGE43
STAGE41=$STAGE41
STAGE29=$STAGE29
STAGE28=$STAGE28
FIRST_CORPUS_TOTAL=777
LIVE_CANONICAL=676
HELD_BACK_TOTAL=101
HELD_BACK_MARKDOWN_SOURCE_DEFICIENT=62
HELD_BACK_TXT_SOURCE_DEFICIENT=35
HELD_BACK_JSON_SOURCE_EMPTY=2
HELD_BACK_JSON_ENCODING_UNRESOLVED=2
CANONICAL_HELD_OVERLAP=0
UNACCOUNTED=0
EXTRA=0
SOURCE_HASHES=PASS_777_OF_777
STAGE28_PASS_SET_CANONICAL=671_OF_671
STAGE28_FAIL_SET_NOW_CANONICAL=5_OF_106
STAGE28_FAIL_SET_HELD_BACK=101_OF_106
FIRST_CORPUS_TEXTLIKE_CLOSURE=PASS
REPOSITORY_STATUS_MUTATION=$GIT_MUTATION
LIVE_OUTPUT_MUTATION=$LIVE_MUTATION
SOURCE_MUTATION=NONE
LIVE_INGESTION_EXECUTED=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
CLOSURE_LEDGER=$OUT/01_FIRST_CORPUS_777_CLOSURE_LEDGER.tsv
CLOSURE_COUNTS=$OUT/02_CLOSURE_COUNTS.tsv
INVARIANTS=$OUT/03_CLOSURE_INVARIANTS.txt
CHANGELOG_EVENT=$OUT/CHANGELOG_EVENT.txt
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- closure counts ---"
cat "$OUT/02_CLOSURE_COUNTS.tsv"
echo
echo "--- closure invariants ---"
cat "$OUT/03_CLOSURE_INVARIANTS.txt"
echo

if [ "$STATUS" = "PASS" ]; then
  echo "STAGE46_COMPLETE=YES"
  exit 0
fi

echo "STAGE46_COMPLETE=NO"
exit 1
