#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_BOUND_JSON_EXCEPTION_TAIL_$TS-STAGE32"

mkdir -p "$OUT"

echo "=== PAN — BOUND JSON EXCEPTION TAIL / STAGE 32 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME" "$SERVICE"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST31="$(
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
    if "PAN_INTERPRET_STAGE30_FAILURE_CLASSES_STAGE31" not in text:
        continue
    if "STATUS=PASS" not in text:
        continue
    if "QUALIFIED=106" not in text:
        continue
    if "NEXT=BOUND_SMALLEST_HIGH_CONFIDENCE_REPAIR_EDGE_FROM_STAGE31" not in text:
        continue
    hits.append((d.stat().st_mtime_ns, d))

if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST31" ] && [ -d "$LATEST31" ] || {
  echo "BLOCKER: passing Stage31 evidence not found"
  exit 22
}

STAGE30="$(sed -n 's/^STAGE30=//p' "$LATEST31/SUMMARY.txt" | head -1)"
LEDGER="$STAGE30/01_QUALIFICATION_LEDGER.tsv"

[ -f "$LEDGER" ] || {
  echo "BLOCKER: Stage30 qualification ledger missing: $LEDGER"
  exit 23
}

echo "STAGE31=$LATEST31"
echo "STAGE30=$STAGE30"
echo "LEDGER=$LEDGER"
echo

# Read-only pre-state.
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/00_OUTPUT_PACKAGE_COUNT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/00_RECEIPT_COUNT_PRE.txt"

# Capture parser/adapter code references involving JSON reads/parsing.
{
  echo "=== json.loads / json.load / read_text / open references ==="
  grep -R -n -E \
    'json\.loads|json\.load|read_text\(|open\(' \
    "$SERVICE" \
    --include='*.py' \
    --exclude-dir='__pycache__' \
    2>/dev/null || true
} > "$OUT/01_JSON_CODE_REFERENCES.txt"

export PAN32_LEDGER="$LEDGER"
export PAN32_OUT="$OUT"

"$PYTHON" - <<'PY'
from pathlib import Path
import csv
import hashlib
import json
import os
import string

ledger = Path(os.environ["PAN32_LEDGER"])
out = Path(os.environ["PAN32_OUT"])

with ledger.open("r", encoding="utf-8", newline="") as h:
    rows = list(csv.DictReader(h, delimiter="\t"))

json_rows = [
    r for r in rows
    if (r.get("extension") or "").strip().lower() == ".json"
]

if len(json_rows) != 4:
    raise SystemExit(
        f"BLOCKER: expected 4 Stage30 JSON failures, found {len(json_rows)}"
    )

def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def prefix_hex(data: bytes, n=64) -> str:
    return data[:n].hex()

def prefix_ascii(data: bytes, n=64) -> str:
    chars = []
    for b in data[:n]:
        c = chr(b)
        chars.append(c if c in string.printable and c not in "\r\n\t" else ".")
    return "".join(chars)

def bom(data: bytes) -> str:
    if data.startswith(b"\xef\xbb\xbf"):
        return "UTF-8-BOM"
    if data.startswith(b"\xff\xfe\x00\x00"):
        return "UTF-32-LE-BOM"
    if data.startswith(b"\x00\x00\xfe\xff"):
        return "UTF-32-BE-BOM"
    if data.startswith(b"\xff\xfe"):
        return "UTF-16-LE-BOM"
    if data.startswith(b"\xfe\xff"):
        return "UTF-16-BE-BOM"
    return "NONE"

def try_json_with_encoding(data: bytes, encoding: str):
    try:
        text = data.decode(encoding)
    except Exception as e:
        return {
            "encoding": encoding,
            "decode": "FAIL",
            "json": "",
            "top_type": "",
            "error": f"{type(e).__name__}: {e}",
        }

    try:
        obj = json.loads(text)
        return {
            "encoding": encoding,
            "decode": "PASS",
            "json": "PASS",
            "top_type": type(obj).__name__,
            "error": "",
        }
    except Exception as e:
        return {
            "encoding": encoding,
            "decode": "PASS",
            "json": "FAIL",
            "top_type": "",
            "error": f"{type(e).__name__}: {e}",
        }

def classify(data: bytes, trials):
    if len(data) == 0:
        return "SOURCE_EMPTY"

    by = {x["encoding"]: x for x in trials}

    # Existing parser expectation: ordinary UTF-8 JSON.
    if by["utf-8"]["json"] == "PASS":
        return "VALID_UTF8_JSON"

    # UTF-8 BOM is a narrow recoverable representation variant.
    if by["utf-8-sig"]["json"] == "PASS":
        return "VALID_JSON_UTF8_BOM"

    # BOM-marked UTF-16/32 can be identified without guessing.
    marker = bom(data)
    if marker.startswith("UTF-16") and by["utf-16"]["json"] == "PASS":
        return "VALID_JSON_UTF16_BOM"
    if marker.startswith("UTF-32") and by["utf-32"]["json"] == "PASS":
        return "VALID_JSON_UTF32_BOM"

    # No BOM: deterministic alternate-decode successes are evidence only.
    alt_success = [
        x["encoding"] for x in trials
        if x["encoding"] not in {"utf-8", "utf-8-sig"}
        and x["json"] == "PASS"
    ]
    if alt_success:
        return "JSON_VALID_UNDER_ALTERNATE_DECODING"

    if by["utf-8"]["decode"] == "PASS" and by["utf-8"]["json"] == "FAIL":
        return "UTF8_TEXT_NOT_VALID_JSON"

    if by["utf-8"]["decode"] == "FAIL":
        return "NON_UTF8_UNRESOLVED"

    return "UNCLASSIFIED"

detail_fields = [
    "source",
    "bytes",
    "sha256_stage30",
    "sha256_now",
    "hash_match",
    "bom",
    "nul_count",
    "nul_ratio",
    "prefix_hex_64",
    "prefix_ascii_64",
    "stage30_failure_signature",
    "classification",
    "successful_json_encodings",
    "utf8_decode",
    "utf8_json",
    "utf8_error",
    "utf8_sig_json",
    "utf16_json",
    "utf32_json",
    "cp1252_json",
    "latin1_json",
]

details = []
trial_rows = []

for r in json_rows:
    source = Path(r["source"]).resolve()
    if not source.is_file():
        raise SystemExit(f"BLOCKER: missing source {source}")

    data = source.read_bytes()
    digest = sha256(data)
    expected = (r.get("sha256_now") or r.get("sha256_stage28") or "").strip()
    match = "PASS" if digest == expected else "FAIL"

    if match != "PASS":
        raise SystemExit(f"BLOCKER: source hash drift {source}")

    encodings = [
        "utf-8",
        "utf-8-sig",
        "utf-16",
        "utf-16-le",
        "utf-16-be",
        "utf-32",
        "utf-32-le",
        "utf-32-be",
        "cp1252",
        "latin-1",
    ]
    trials = [try_json_with_encoding(data, enc) for enc in encodings]
    cls = classify(data, trials)

    for t in trials:
        trial_rows.append({
            "source": str(source),
            **t,
        })

    by = {x["encoding"]: x for x in trials}
    successful = [x["encoding"] for x in trials if x["json"] == "PASS"]

    details.append({
        "source": str(source),
        "bytes": len(data),
        "sha256_stage30": expected,
        "sha256_now": digest,
        "hash_match": match,
        "bom": bom(data),
        "nul_count": data.count(b"\x00"),
        "nul_ratio": round(data.count(b"\x00") / len(data), 6) if data else 0.0,
        "prefix_hex_64": prefix_hex(data),
        "prefix_ascii_64": prefix_ascii(data),
        "stage30_failure_signature": r.get("failure_signature", ""),
        "classification": cls,
        "successful_json_encodings": ",".join(successful),
        "utf8_decode": by["utf-8"]["decode"],
        "utf8_json": by["utf-8"]["json"],
        "utf8_error": by["utf-8"]["error"],
        "utf8_sig_json": by["utf-8-sig"]["json"],
        "utf16_json": by["utf-16"]["json"],
        "utf32_json": by["utf-32"]["json"],
        "cp1252_json": by["cp1252"]["json"],
        "latin1_json": by["latin-1"]["json"],
    })

with (out / "02_JSON_TAIL_DETAIL.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    w = csv.DictWriter(h, fieldnames=detail_fields, delimiter="\t")
    w.writeheader()
    w.writerows(details)

with (out / "03_ENCODING_TRIALS.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    fields = ["source", "encoding", "decode", "json", "top_type", "error"]
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(trial_rows)

# Classification counts.
from collections import Counter
counts = Counter(d["classification"] for d in details)

with (out / "04_CLASSIFICATION_COUNTS.tsv").open("w", encoding="utf-8") as h:
    h.write("count\tclassification\n")
    for cls, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        h.write(f"{n}\t{cls}\n")

# Evidence/interpretation/promotion remain separated.
observations = []
for d in details:
    observations.append(
        "\t".join([
            "OBSERVATION",
            d["classification"],
            d["source"],
            f"bytes={d['bytes']}",
            f"bom={d['bom']}",
            f"successful_json_encodings={d['successful_json_encodings'] or 'NONE'}",
        ])
    )

(out / "05_OBSERVATIONS.tsv").write_text(
    "\n".join(observations) + "\n",
    encoding="utf-8",
)

interpretations = []
for cls, n in sorted(counts.items()):
    if cls == "SOURCE_EMPTY":
        interpretations.append(
            f"INTERPRETATION\tSOURCE_EMPTY\tcount={n}\t"
            "No parser repair can recover semantic JSON content from a zero-byte source."
        )
    elif cls in {
        "VALID_JSON_UTF8_BOM",
        "VALID_JSON_UTF16_BOM",
        "VALID_JSON_UTF32_BOM",
        "JSON_VALID_UNDER_ALTERNATE_DECODING",
    }:
        interpretations.append(
            f"INTERPRETATION\tREPRESENTATION_EDGE\tcount={n}\t"
            "At least one source contains parseable JSON under a representation "
            "different from the current failing path. This is a candidate adapter edge, "
            "not yet a promoted repair."
        )
    elif cls == "UTF8_TEXT_NOT_VALID_JSON":
        interpretations.append(
            f"INTERPRETATION\tMALFORMED_OR_MISLABELED_JSON\tcount={n}\t"
            "The bytes decode as UTF-8 but do not form valid JSON. Parser broadening "
            "would risk accepting malformed source."
        )
    elif cls == "NON_UTF8_UNRESOLVED":
        interpretations.append(
            f"INTERPRETATION\tNON_UTF8_UNRESOLVED\tcount={n}\t"
            "The source is not valid UTF-8 and no deterministic tested encoding yielded JSON."
        )
    elif cls == "VALID_UTF8_JSON":
        interpretations.append(
            f"INTERPRETATION\tCURRENT_PATH_DISCREPANCY\tcount={n}\t"
            "Source currently parses as UTF-8 JSON despite Stage28 failure; code-path "
            "or source-state discrepancy must be bounded before repair."
        )

(out / "06_INTERPRETATIONS.tsv").write_text(
    "\n".join(interpretations) + ("\n" if interpretations else ""),
    encoding="utf-8",
)

# Candidate next edge: computed from evidence, not promoted.
repairable_classes = {
    "VALID_JSON_UTF8_BOM",
    "VALID_JSON_UTF16_BOM",
    "VALID_JSON_UTF32_BOM",
    "JSON_VALID_UNDER_ALTERNATE_DECODING",
    "VALID_UTF8_JSON",
}
repairable = sum(
    n for cls, n in counts.items() if cls in repairable_classes
)
nonrepairable = len(details) - repairable

with (out / "07_CANDIDATE_NEXT.txt").open("w", encoding="utf-8") as h:
    h.write(f"JSON_TAIL_COUNT={len(details)}\n")
    h.write(f"CANDIDATE_REPRESENTATION_OR_CODEPATH_CASES={repairable}\n")
    h.write(f"SOURCE_INVALID_OR_UNRESOLVED_CASES={nonrepairable}\n")
    if repairable:
        h.write(
            "CANDIDATE_NEXT=BOUND_JSON_REPRESENTATION_OR_CODEPATH_REPAIR_WITH_TESTS\n"
        )
    else:
        h.write(
            "CANDIDATE_NEXT=DO_NOT_BROADEN_JSON_PARSER;MOVE_TO_NEXT_VALIDATOR_FAMILY\n"
        )

print(f"JSON_TAIL={len(details)}")
print("--- classifications ---")
for cls, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
    print(f"{n}\t{cls}")
print("--- files ---")
for d in details:
    print(
        f"{d['classification']}\tbytes={d['bytes']}\t"
        f"bom={d['bom']}\t{d['source']}"
    )
print("--- candidate next ---")
print((out / "07_CANDIDATE_NEXT.txt").read_text(encoding="utf-8"), end="")
PY

# Post-state.
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/08_GIT_STATUS_POST.z" 2>/dev/null || true

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/08_OUTPUT_PACKAGE_COUNT_POST.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/08_RECEIPT_COUNT_POST.txt"

if cmp -s "$OUT/00_GIT_STATUS_PRE.z" "$OUT/08_GIT_STATUS_POST.z"; then
  GIT_MUTATION="NONE"
else
  GIT_MUTATION="DETECTED"
fi

PRE_PACKAGES="$(cat "$OUT/00_OUTPUT_PACKAGE_COUNT_PRE.txt")"
POST_PACKAGES="$(cat "$OUT/08_OUTPUT_PACKAGE_COUNT_POST.txt")"
PRE_RECEIPTS="$(cat "$OUT/00_RECEIPT_COUNT_PRE.txt")"
POST_RECEIPTS="$(cat "$OUT/08_RECEIPT_COUNT_POST.txt")"

if [ "$PRE_PACKAGES" = "$POST_PACKAGES" ] && [ "$PRE_RECEIPTS" = "$POST_RECEIPTS" ]; then
  LIVE_OUTPUT_MUTATION="NONE"
else
  LIVE_OUTPUT_MUTATION="DETECTED"
fi

if [ "$GIT_MUTATION" = "NONE" ] && [ "$LIVE_OUTPUT_MUTATION" = "NONE" ]; then
  STATUS="PASS"
  NEXT="READ_STAGE32_CANDIDATE_NEXT_AND_ADVANCE_ONLY_SUPPORTED_EDGE"
else
  STATUS="FAIL"
  NEXT="PRESERVE_STAGE32_MUTATION_EVIDENCE_AND_REPAIR_ONLY_BOUNDING_EDGE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_BOUND_JSON_EXCEPTION_TAIL_STAGE32
UTC=$TS
STATUS=$STATUS
STAGE31=$LATEST31
STAGE30=$STAGE30
JSON_TAIL_COUNT=4
REPOSITORY_STATUS_MUTATION=$GIT_MUTATION
LIVE_OUTPUT_MUTATION=$LIVE_OUTPUT_MUTATION
PRE_OUTPUT_PACKAGES=$PRE_PACKAGES
POST_OUTPUT_PACKAGES=$POST_PACKAGES
PRE_RECEIPTS=$PRE_RECEIPTS
POST_RECEIPTS=$POST_RECEIPTS
SOURCE_MUTATION=NONE
CANONICAL_INGEST_EXECUTED=NO
PARSER_CODE_MODIFIED=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
CODE_REFERENCES=$OUT/01_JSON_CODE_REFERENCES.txt
DETAIL=$OUT/02_JSON_TAIL_DETAIL.tsv
ENCODING_TRIALS=$OUT/03_ENCODING_TRIALS.tsv
CLASSIFICATIONS=$OUT/04_CLASSIFICATION_COUNTS.tsv
OBSERVATIONS=$OUT/05_OBSERVATIONS.tsv
INTERPRETATIONS=$OUT/06_INTERPRETATIONS.tsv
CANDIDATE_NEXT=$OUT/07_CANDIDATE_NEXT.txt
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
cat "$OUT/04_CLASSIFICATION_COUNTS.tsv"
echo
cat "$OUT/07_CANDIDATE_NEXT.txt"
echo

if [ "$STATUS" = "PASS" ]; then
  echo "STAGE32_COMPLETE=YES"
  exit 0
fi

echo "STAGE32_COMPLETE=NO"
exit 1
