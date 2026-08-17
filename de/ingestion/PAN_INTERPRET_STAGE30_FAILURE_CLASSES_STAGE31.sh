#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_INTERPRET_STAGE30_FAILURE_CLASSES_$TS-STAGE31"

mkdir -p "$OUT"

echo "=== PAN — INTERPRET STAGE30 FAILURE CLASSES / STAGE 31 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME" "$SERVICE"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST30="$(
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
    if "PAN_QUALIFY_STAGE28_FAILURE_SET_STAGE30" not in text:
        continue
    if "STATUS=PASS" not in text:
        continue
    if "QUALIFIED=106" not in text:
        continue
    if "NEXT=INTERPRET_STAGE30_FAILURE_CLASSES_BEFORE_ANY_REPAIR" not in text:
        continue
    hits.append((d.stat().st_mtime_ns, d))

if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST30" ] && [ -d "$LATEST30" ] || {
  echo "BLOCKER: passing Stage30 evidence not found"
  exit 22
}

LEDGER="$(sed -n 's/^LEDGER=//p' "$LATEST30/SUMMARY.txt" | head -1)"
EXPECTED="$(sed -n 's/^QUALIFIED=//p' "$LATEST30/SUMMARY.txt" | head -1)"
STAGE29="$(sed -n 's/^STAGE29=//p' "$LATEST30/SUMMARY.txt" | head -1)"
STAGE28="$(sed -n 's/^STAGE28=//p' "$LATEST30/SUMMARY.txt" | head -1)"

[ -f "$LEDGER" ] || { echo "BLOCKER: missing Stage30 ledger $LEDGER"; exit 23; }

echo "STAGE30=$LATEST30"
echo "LEDGER=$LEDGER"
echo "QUALIFIED=$EXPECTED"
echo

# Preserve pre-state. Stage31 is read-only.
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/00_OUTPUT_PACKAGE_COUNT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/00_RECEIPT_COUNT_PRE.txt"

# Static code references for the exact observed error tokens.
: > "$OUT/01_CODE_ERROR_REFERENCES.txt"
for token in \
  missing_title \
  no_assets \
  invalid_conversation_kind \
  no_conversation_turns \
  missing_user_turn
do
  {
    echo "===== $token ====="
    grep -R -n -F --exclude-dir='__pycache__' -- "$token" "$SERVICE" 2>/dev/null || true
    echo
  } >> "$OUT/01_CODE_ERROR_REFERENCES.txt"
done

export PAN31_LEDGER="$LEDGER"
export PAN31_OUT="$OUT"
export PAN31_EXPECTED="$EXPECTED"

"$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter, defaultdict
import csv
import json
import os

ledger = Path(os.environ["PAN31_LEDGER"])
out = Path(os.environ["PAN31_OUT"])
expected = int(os.environ["PAN31_EXPECTED"])

with ledger.open("r", encoding="utf-8", newline="") as h:
    rows = list(csv.DictReader(h, delimiter="\t"))

if len(rows) != expected:
    raise SystemExit(
        f"BLOCKER: qualification ledger row count drift expected={expected} actual={len(rows)}"
    )

def sig(row):
    return (row.get("failure_signature") or "").strip()

def ext(row):
    return (row.get("extension") or "").strip()

def bucket(row):
    return (row.get("mechanical_bucket") or "").strip()

# Core cross-tabs.
ext_sig = Counter((ext(r), sig(r)) for r in rows)
ext_bucket = Counter((ext(r), bucket(r)) for r in rows)
kind_sig = Counter(
    (
        (r.get("stage28_manifest_kind") or "").strip(),
        sig(r),
    )
    for r in rows
)
ext_manifest = Counter(
    (
        ext(r),
        (r.get("stage28_manifest_kind") or "").strip(),
    )
    for r in rows
)

def write_counter(path, header, counter):
    with path.open("w", encoding="utf-8") as h:
        h.write("\t".join(header) + "\n")
        for key, n in sorted(counter.items(), key=lambda kv: (-kv[1], kv[0])):
            if not isinstance(key, tuple):
                key = (key,)
            h.write(str(n) + "\t" + "\t".join(str(x) for x in key) + "\n")

write_counter(
    out / "02_EXTENSION_X_FAILURE.tsv",
    ["count", "extension", "failure_signature"],
    ext_sig,
)
write_counter(
    out / "03_EXTENSION_X_BUCKET.tsv",
    ["count", "extension", "mechanical_bucket"],
    ext_bucket,
)
write_counter(
    out / "04_MANIFEST_KIND_X_FAILURE.tsv",
    ["count", "stage28_manifest_kind", "failure_signature"],
    kind_sig,
)
write_counter(
    out / "05_EXTENSION_X_MANIFEST_KIND.tsv",
    ["count", "extension", "stage28_manifest_kind"],
    ext_manifest,
)

# Extension-specific row profiles copied from the qualification ledger.
profile_fields = [
    "source",
    "extension",
    "failure_kind",
    "failure_signature",
    "mechanical_bucket",
    "stage28_manifest_kind",
    "parsed_kind",
    "stage28_output_exists",
    "validation_report_errors",
    "bytes",
    "bom",
    "utf8_decode",
    "nul_ratio",
    "nonblank",
    "markdown_h1",
    "first_nonblank",
    "json_utf8_parse",
    "json_alt_decode_candidate",
    "json_top_type",
    "json_top_keys",
    "json_error",
]

for extension, filename in [
    (".md", "06_MARKDOWN_PROFILE.tsv"),
    (".txt", "07_TEXT_PROFILE.tsv"),
    (".json", "08_JSON_PROFILE.tsv"),
]:
    with (out / filename).open("w", encoding="utf-8", newline="") as h:
        w = csv.DictWriter(h, fieldnames=profile_fields, delimiter="\t")
        w.writeheader()
        for r in rows:
            if ext(r) == extension:
                w.writerow({k: r.get(k, "") for k in profile_fields})

# Deterministic observations only.
by_ext = defaultdict(list)
for r in rows:
    by_ext[ext(r)].append(r)

def signatures(rs):
    return Counter(sig(r) for r in rs)

def all_have(rs, token):
    return bool(rs) and all(token in sig(r) for r in rs)

def any_have(rs, token):
    return any(token in sig(r) for r in rs)

def summary_line(label, value):
    return f"OBSERVATION\t{label}\t{value}"

observations = []

for extension in sorted(by_ext):
    rs = by_ext[extension]
    observations.append(summary_line(f"{extension}.count", len(rs)))
    observations.append(
        summary_line(
            f"{extension}.failure_signatures",
            json.dumps(signatures(rs), ensure_ascii=False, sort_keys=True),
        )
    )
    observations.append(
        summary_line(
            f"{extension}.mechanical_buckets",
            json.dumps(Counter(bucket(r) for r in rs), sort_keys=True),
        )
    )
    observations.append(
        summary_line(
            f"{extension}.manifest_kinds",
            json.dumps(
                Counter(
                    (r.get("stage28_manifest_kind") or "").strip()
                    for r in rs
                ),
                sort_keys=True,
            ),
        )
    )

md = by_ext.get(".md", [])
txt = by_ext.get(".txt", [])
js = by_ext.get(".json", [])

if md:
    observations.append(
        summary_line(
            "markdown.all_failures_include_missing_title",
            str(all_have(md, "missing_title")).upper(),
        )
    )
    observations.append(
        summary_line(
            "markdown.failures_include_no_assets_count",
            sum("no_assets" in sig(r) for r in md),
        )
    )
    observations.append(
        summary_line(
            "markdown.h1_yes_count",
            sum((r.get("markdown_h1") or "") == "YES" for r in md),
        )
    )
    observations.append(
        summary_line(
            "markdown.h1_no_count",
            sum((r.get("markdown_h1") or "") == "NO" for r in md),
        )
    )

if txt:
    observations.append(
        summary_line(
            "text.invalid_conversation_kind_count",
            sum("invalid_conversation_kind" in sig(r) for r in txt),
        )
    )
    observations.append(
        summary_line(
            "text.no_conversation_turns_count",
            sum("no_conversation_turns" in sig(r) for r in txt),
        )
    )
    observations.append(
        summary_line(
            "text.missing_user_turn_count",
            sum("missing_user_turn" in sig(r) for r in txt),
        )
    )

if js:
    observations.append(
        summary_line(
            "json.exception_count",
            sum((r.get("failure_kind") or "") == "EXCEPTION" for r in js),
        )
    )
    observations.append(
        summary_line(
            "json.utf8_decode_fail_count",
            sum((r.get("utf8_decode") or "") == "FAIL" for r in js),
        )
    )
    observations.append(
        summary_line(
            "json.json_parse_fail_count",
            sum((r.get("json_utf8_parse") or "") == "JSON_PARSE_FAIL" for r in js),
        )
    )
    observations.append(
        summary_line(
            "json.empty_count",
            sum((r.get("json_utf8_parse") or "") == "EMPTY" for r in js),
        )
    )

(out / "09_OBSERVATIONS.tsv").write_text(
    "\n".join(observations) + "\n",
    encoding="utf-8",
)

# Explicitly separate interpretation from evidence.
interpretations = []

if md and all_have(md, "missing_title"):
    interpretations.append(
        "INTERPRETATION\tMARKDOWN_TITLE_EDGE\t"
        "The Markdown failure family is concentrated on title validation. "
        "Whether the defect is source-content deficiency, title extraction, "
        "or validator policy is not yet promoted."
    )

if txt and (
    sum("invalid_conversation_kind" in sig(r) for r in txt)
    + sum("missing_user_turn" in sig(r) for r in txt)
    == len(txt)
):
    interpretations.append(
        "INTERPRETATION\tTEXT_CONVERSATION_EDGE\t"
        "The TXT failure family is concentrated on conversation-shape validation. "
        "This suggests an adapter/validator classification boundary, but the cause "
        "is not yet promoted."
    )

if js:
    interpretations.append(
        "INTERPRETATION\tJSON_EXCEPTION_EDGE\t"
        "The JSON remainder is a small exceptional tail. It should be handled "
        "separately from the validator-dominated Markdown/TXT families."
    )

(out / "10_INTERPRETATIONS.tsv").write_text(
    "\n".join(interpretations) + ("\n" if interpretations else ""),
    encoding="utf-8",
)

# Candidate repair ordering is a hypothesis, not authority.
candidates = []
if txt:
    candidates.append(
        (
            len(txt),
            "CANDIDATE",
            "TXT_CLASSIFICATION_OR_VALIDATION_EDGE",
            "Bound the exact code path producing invalid_conversation_kind/"
            "no_conversation_turns/missing_user_turn for .txt inputs.",
        )
    )
if md:
    candidates.append(
        (
            len(md),
            "CANDIDATE",
            "MARKDOWN_TITLE_VALIDATION_EDGE",
            "Bound title extraction/validation for .md inputs and separate "
            "missing-title source cases from parser defects.",
        )
    )
if js:
    candidates.append(
        (
            len(js),
            "CANDIDATE",
            "JSON_EXCEPTION_TAIL",
            "Handle malformed/empty/non-UTF8 JSON separately after the validator "
            "families are understood.",
        )
    )

with (out / "11_CANDIDATE_REPAIR_ORDER.tsv").open("w", encoding="utf-8") as h:
    h.write("affected_count\tclassification\tedge\tdescription\n")
    for item in sorted(candidates, reverse=True):
        h.write("\t".join(map(str, item)) + "\n")

print(f"ROWS={len(rows)}")
print("--- extension x failure ---")
for (extension, failure), n in sorted(
    ext_sig.items(), key=lambda kv: (-kv[1], kv[0])
):
    print(f"{n}\t{extension}\t{failure}")
print("--- observations ---")
for line in observations:
    print(line)
print("--- interpretations ---")
for line in interpretations:
    print(line)
PY

# Print exact code references after the row mapping, but never modify code.
echo
echo "--- code references ---"
cat "$OUT/01_CODE_ERROR_REFERENCES.txt"

# Verify no live-state mutation.
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/12_GIT_STATUS_POST.z" 2>/dev/null || true

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/12_OUTPUT_PACKAGE_COUNT_POST.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/12_RECEIPT_COUNT_POST.txt"

if cmp -s "$OUT/00_GIT_STATUS_PRE.z" "$OUT/12_GIT_STATUS_POST.z"; then
  GIT_MUTATION="NONE"
else
  GIT_MUTATION="DETECTED"
fi

PRE_PACKAGES="$(cat "$OUT/00_OUTPUT_PACKAGE_COUNT_PRE.txt")"
POST_PACKAGES="$(cat "$OUT/12_OUTPUT_PACKAGE_COUNT_POST.txt")"
PRE_RECEIPTS="$(cat "$OUT/00_RECEIPT_COUNT_PRE.txt")"
POST_RECEIPTS="$(cat "$OUT/12_RECEIPT_COUNT_POST.txt")"

if [ "$PRE_PACKAGES" = "$POST_PACKAGES" ] && [ "$PRE_RECEIPTS" = "$POST_RECEIPTS" ]; then
  LIVE_OUTPUT_MUTATION="NONE"
else
  LIVE_OUTPUT_MUTATION="DETECTED"
fi

if [ "$GIT_MUTATION" = "NONE" ] && [ "$LIVE_OUTPUT_MUTATION" = "NONE" ]; then
  STATUS="PASS"
  NEXT="BOUND_SMALLEST_HIGH_CONFIDENCE_REPAIR_EDGE_FROM_STAGE31"
else
  STATUS="FAIL"
  NEXT="PRESERVE_STAGE31_MUTATION_EVIDENCE_AND_REPAIR_ONLY_INTERPRETATION_EDGE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_INTERPRET_STAGE30_FAILURE_CLASSES_STAGE31
UTC=$TS
STATUS=$STATUS
STAGE30=$LATEST30
STAGE29=$STAGE29
STAGE28=$STAGE28
QUALIFIED=$EXPECTED
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
EXTENSION_X_FAILURE=$OUT/02_EXTENSION_X_FAILURE.tsv
CODE_REFERENCES=$OUT/01_CODE_ERROR_REFERENCES.txt
OBSERVATIONS=$OUT/09_OBSERVATIONS.tsv
INTERPRETATIONS=$OUT/10_INTERPRETATIONS.tsv
CANDIDATE_REPAIR_ORDER=$OUT/11_CANDIDATE_REPAIR_ORDER.tsv
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"

echo
echo "--- extension x failure ---"
cat "$OUT/02_EXTENSION_X_FAILURE.tsv"
echo
echo "--- candidate repair order ---"
cat "$OUT/11_CANDIDATE_REPAIR_ORDER.tsv"
echo

if [ "$STATUS" = "PASS" ]; then
  echo "STAGE31_COMPLETE=YES"
  exit 0
fi

echo "STAGE31_COMPLETE=NO"
exit 1
