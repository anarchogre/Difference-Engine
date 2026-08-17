#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_BOUND_MARKDOWN_VALIDATOR_TITLE_POLICY_$TS-STAGE40"

mkdir -p "$OUT"

echo "=== PAN — BOUND MARKDOWN VALIDATOR TITLE POLICY / STAGE 40 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME" "$SERVICE"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST39="$(
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
        "PAN_INTERPRET_MARKDOWN_TITLE_ASSET_CONTRACT_STAGE39" in t
        and "STATUS=PASS" in t
        and "RESIDUAL_MARKDOWN=62" in t
        and "NEXT=BOUND_MARKDOWN_VALIDATOR_TITLE_POLICY_BEFORE_REPAIR" in t
    ):
        hits.append((d.stat().st_mtime_ns, d))
if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST39" ] && [ -d "$LATEST39" ] || {
  echo "BLOCKER: passing Stage39 evidence not found"
  exit 22
}

RESIDUAL="$LATEST39/03_RESIDUAL_CONTRACT_DETAIL.tsv"
PASSING_CONTRACT="$LATEST39/06_PASSING_PACKAGE_CONTRACT.tsv"
PASSING_SOURCE="$(
  sed -n 's/^PASSING_COMPARISON=//p' \
  "$(sed -n 's/^STAGE38=//p' "$LATEST39/SUMMARY.txt" | head -1)/SUMMARY.txt" \
  | head -1
)"

for x in "$RESIDUAL" "$PASSING_CONTRACT"; do
  [ -f "$x" ] || { echo "BLOCKER: missing Stage39 artifact $x"; exit 23; }
done

if [ -z "$PASSING_SOURCE" ] || [ ! -f "$PASSING_SOURCE" ]; then
  STAGE38="$(sed -n 's/^STAGE38=//p' "$LATEST39/SUMMARY.txt" | head -1)"
  PASSING_SOURCE="$STAGE38/03_PASSING_MARKDOWN_COMPARISON.tsv"
fi

[ -f "$PASSING_SOURCE" ] || {
  echo "BLOCKER: passing Markdown source comparison missing: $PASSING_SOURCE"
  exit 24
}

echo "STAGE39=$LATEST39"
echo "RESIDUAL=$RESIDUAL"
echo "PASSING_CONTRACT=$PASSING_CONTRACT"
echo "PASSING_SOURCE=$PASSING_SOURCE"
echo

# -------------------------------------------------------------------
# Pre-state: read-only policy analysis.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/00_OUTPUT_COUNT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/00_RECEIPT_COUNT_PRE.txt"

# -------------------------------------------------------------------
# Recover exact current validator/pipeline contract and history.
# -------------------------------------------------------------------
for f in \
  "$SERVICE/validation.py" \
  "$SERVICE/parsers/markdown.py" \
  "$SERVICE/manifest.py" \
  "$SERVICE/pipeline.py"
do
  if [ -f "$f" ]; then
    b="$(basename "$f")"
    nl -ba "$f" > "$OUT/01_NUMBERED_$b.txt"
  fi
done

{
  echo "===== CURRENT TITLE / ASSET VALIDATION REFERENCES ====="
  grep -R -n -E \
    'missing_title|no_assets|title|assets|MarkdownDocument|validate|markdown' \
    "$SERVICE" \
    --include='*.py' \
    --exclude-dir='__pycache__' \
    2>/dev/null || true

  echo
  echo "===== GIT HISTORY FOR VALIDATION / MARKDOWN PARSER ====="
  git -C "$CURRENT" log \
    --oneline --decorate --follow -- \
    "workspace/operational/ingestion/service/validation.py" \
    2>/dev/null || true

  echo
  git -C "$CURRENT" log \
    --oneline --decorate --follow -- \
    "workspace/operational/ingestion/service/parsers/markdown.py" \
    2>/dev/null || true
} > "$OUT/02_POLICY_CODE_AND_HISTORY.txt"

# Show blame only for actual policy files; provenance, not authority by itself.
if [ -f "$SERVICE/validation.py" ]; then
  git -C "$CURRENT" blame --date=iso -- \
    "workspace/operational/ingestion/service/validation.py" \
    > "$OUT/03_VALIDATION_BLAME.txt" 2>/dev/null || true
fi

export PAN40_RESIDUAL="$RESIDUAL"
export PAN40_PASSING_CONTRACT="$PASSING_CONTRACT"
export PAN40_PASSING_SOURCE="$PASSING_SOURCE"
export PAN40_OUT="$OUT"

"$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter
import csv
import json
import os
import re

residual_path = Path(os.environ["PAN40_RESIDUAL"])
passing_contract_path = Path(os.environ["PAN40_PASSING_CONTRACT"])
passing_source_path = Path(os.environ["PAN40_PASSING_SOURCE"])
out = Path(os.environ["PAN40_OUT"])

with residual_path.open("r", encoding="utf-8", newline="") as h:
    residual = list(csv.DictReader(h, delimiter="\t"))

with passing_contract_path.open("r", encoding="utf-8", newline="") as h:
    passing_contract = list(csv.DictReader(h, delimiter="\t"))

with passing_source_path.open("r", encoding="utf-8", newline="") as h:
    passing_source = list(csv.DictReader(h, delimiter="\t"))

if len(residual) != 62:
    raise SystemExit(f"BLOCKER: expected 62 residual Markdown rows, got {len(residual)}")

if len(passing_contract) != len(passing_source):
    # Do not fail merely because rows with missing output/source were skipped,
    # but record that comparison is not one-to-one.
    comparison_alignment = "NON_1_TO_1"
else:
    comparison_alignment = "COUNT_ALIGNED"

def as_bool(v):
    return str(v).strip().lower() in {"true", "1", "yes"}

def as_int(v, default=0):
    try:
        return int(v)
    except Exception:
        return default

# ---------------------------------------------------------------
# Key policy question:
# Do passing Markdown sources themselves lack H1/YAML title signals?
# If yes, title cannot be a universal source-shape requirement.
# ---------------------------------------------------------------
passing_source_title_signal = Counter()
for r in passing_source:
    has_h1 = as_int(r.get("h1_count")) > 0
    has_yaml = bool((r.get("yaml_title") or "").strip())
    starts_h1 = as_bool(r.get("starts_h1"))
    if has_h1 or has_yaml:
        cls = "PASSING_SOURCE_HAS_TITLE_SIGNAL"
    else:
        cls = "PASSING_SOURCE_HAS_NO_TESTED_TITLE_SIGNAL"
    passing_source_title_signal[cls] += 1

residual_title_signal = Counter()
for r in residual:
    has_h1 = as_bool(r.get("has_source_h1"))
    has_yaml = as_bool(r.get("has_yaml_title"))
    if has_h1 or has_yaml:
        cls = "RESIDUAL_SOURCE_HAS_TITLE_SIGNAL"
    else:
        cls = "RESIDUAL_SOURCE_HAS_NO_TESTED_TITLE_SIGNAL"
    residual_title_signal[cls] += 1

# ---------------------------------------------------------------
# Passing package contract: actual parsed title/assets state.
# ---------------------------------------------------------------
passing_pkg_matrix = Counter()
for r in passing_contract:
    title_present = as_bool(r.get("parsed_title_present"))
    assets_present = as_bool(r.get("parsed_assets_present"))
    passing_pkg_matrix[(title_present, assets_present)] += 1

# ---------------------------------------------------------------
# Filename/title relation diagnostics. This is evidence only:
# compare whether passing no-title-signal sources still carry meaningful
# filenames that could have been accepted without parser title.
# ---------------------------------------------------------------
def filename_features(path_str):
    p = Path(path_str)
    stem = p.stem.strip()
    normalized = re.sub(r"[_\-]+", " ", stem).strip()
    normalized = re.sub(r"\s+", " ", normalized)
    generic = normalized.lower() in {
        "", "readme", "notes", "note", "document", "untitled",
        "temp", "tmp", "index", "file",
    }
    return {
        "stem": stem,
        "normalized_stem": normalized,
        "generic_filename": generic,
        "filename_has_letters": bool(re.search(r"[A-Za-z]", normalized)),
    }

passing_no_signal_rows = []
for r in passing_source:
    has_h1 = as_int(r.get("h1_count")) > 0
    has_yaml = bool((r.get("yaml_title") or "").strip())
    if has_h1 or has_yaml:
        continue
    ff = filename_features(r["source"])
    passing_no_signal_rows.append({
        "source": r["source"],
        "first_nonblank": r.get("first_nonblank", ""),
        **ff,
    })

residual_no_signal_rows = []
for r in residual:
    ff = filename_features(r["source"])
    residual_no_signal_rows.append({
        "source": r["source"],
        "errors": r.get("errors", ""),
        **ff,
    })

for rows, filename in [
    (passing_no_signal_rows, "04_PASSING_NO_TITLE_SIGNAL_FILES.tsv"),
    (residual_no_signal_rows, "05_RESIDUAL_NO_TITLE_SIGNAL_FILES.tsv"),
]:
    fields = sorted({k for row in rows for k in row.keys()}) if rows else ["source"]
    with (out / filename).open("w", encoding="utf-8", newline="") as h:
        w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
        w.writeheader()
        w.writerows(rows)

# ---------------------------------------------------------------
# Compare errors and source states directly.
# ---------------------------------------------------------------
residual_errors = Counter()
for r in residual:
    try:
        errs = json.loads(r.get("errors") or "[]")
    except Exception:
        errs = []
    for e in errs:
        residual_errors[str(e)] += 1

def write_counter(path, header, counter):
    with path.open("w", encoding="utf-8") as h:
        h.write("\t".join(header) + "\n")
        for key, n in sorted(counter.items(), key=lambda kv: (-kv[1], str(kv[0]))):
            if not isinstance(key, tuple):
                key = (key,)
            h.write(str(n) + "\t" + "\t".join(map(str, key)) + "\n")

write_counter(
    out / "06_PASSING_SOURCE_TITLE_SIGNAL_COUNTS.tsv",
    ["count", "class"],
    passing_source_title_signal,
)
write_counter(
    out / "07_RESIDUAL_SOURCE_TITLE_SIGNAL_COUNTS.tsv",
    ["count", "class"],
    residual_title_signal,
)
write_counter(
    out / "08_PASSING_PACKAGE_TITLE_ASSET_MATRIX.tsv",
    ["count", "parsed_title_present", "parsed_assets_present"],
    passing_pkg_matrix,
)
write_counter(
    out / "09_RESIDUAL_ERROR_COUNTS.tsv",
    ["count", "error"],
    residual_errors,
)

# ---------------------------------------------------------------
# Mechanical conclusion categories.
# ---------------------------------------------------------------
passing_no_signal = passing_source_title_signal.get(
    "PASSING_SOURCE_HAS_NO_TESTED_TITLE_SIGNAL", 0
)
passing_without_parsed_title = sum(
    n for (title_present, assets_present), n in passing_pkg_matrix.items()
    if not title_present
)
passing_without_assets = sum(
    n for (title_present, assets_present), n in passing_pkg_matrix.items()
    if not assets_present
)

observations = [
    f"OBSERVATION\tRESIDUAL_MARKDOWN\t{len(residual)}",
    f"OBSERVATION\tPASSING_MARKDOWN_SOURCE_ROWS\t{len(passing_source)}",
    f"OBSERVATION\tPASSING_MARKDOWN_PACKAGE_ROWS\t{len(passing_contract)}",
    f"OBSERVATION\tPASSING_SOURCE_NO_TESTED_TITLE_SIGNAL\t{passing_no_signal}",
    f"OBSERVATION\tPASSING_PACKAGE_WITHOUT_PARSED_TITLE\t{passing_without_parsed_title}",
    f"OBSERVATION\tPASSING_PACKAGE_WITHOUT_PARSED_ASSETS\t{passing_without_assets}",
    f"OBSERVATION\tCOMPARISON_ALIGNMENT\t{comparison_alignment}",
]

for err, n in sorted(residual_errors.items()):
    observations.append(f"OBSERVATION\tRESIDUAL_ERROR_INCIDENCE\t{n}\t{err}")

(out / "10_OBSERVATIONS.tsv").write_text(
    "\n".join(observations) + "\n",
    encoding="utf-8",
)

interpretations = []

if passing_no_signal > 0:
    interpretations.append(
        "INTERPRETATION\tTITLE_NOT_UNIVERSAL_SOURCE_SHAPE_REQUIREMENT\t"
        f"passing_without_tested_title_signal={passing_no_signal}\t"
        "At least one canonically passing Markdown source lacks the same tested H1/YAML "
        "title signals absent from all 62 residual sources. A universal source-level title "
        "requirement would therefore conflict with observed accepted corpus state."
    )

if passing_without_parsed_title > 0:
    interpretations.append(
        "INTERPRETATION\tPARSED_TITLE_NOT_UNIVERSAL_ACCEPTANCE_REQUIREMENT\t"
        f"passing_without_parsed_title={passing_without_parsed_title}\t"
        "Canonically passing Markdown packages exist with no parsed title, so missing_title "
        "cannot be treated as a universally necessary Markdown acceptance condition without "
        "additional context."
    )

if passing_without_assets > 0:
    interpretations.append(
        "INTERPRETATION\tPARSED_ASSETS_NOT_UNIVERSAL_ACCEPTANCE_REQUIREMENT\t"
        f"passing_without_parsed_assets={passing_without_assets}\t"
        "Canonically passing Markdown packages exist without parsed assets, so no_assets "
        "cannot be a universal Markdown rejection condition."
    )

(out / "11_INTERPRETATIONS.tsv").write_text(
    "\n".join(interpretations) + ("\n" if interpretations else ""),
    encoding="utf-8",
)

# Candidate next: only if evidence contradicts universal title requirement.
with (out / "12_CANDIDATE_NEXT.txt").open("w", encoding="utf-8") as h:
    h.write(f"RESIDUAL_MARKDOWN={len(residual)}\n")
    h.write(f"PASSING_SOURCE_NO_TESTED_TITLE_SIGNAL={passing_no_signal}\n")
    h.write(f"PASSING_PACKAGE_WITHOUT_PARSED_TITLE={passing_without_parsed_title}\n")
    h.write(f"PASSING_PACKAGE_WITHOUT_PARSED_ASSETS={passing_without_assets}\n")

    if passing_no_signal > 0 or passing_without_parsed_title > 0:
        h.write(
            "CANDIDATE_NEXT=BOUND_EXACT_VALIDATION_BRANCH_CAUSING_MISSING_TITLE_AND_NO_ASSETS_ON_RESIDUAL_MARKDOWN_THEN_BUILD_MINIMAL_REGRESSION_FIX_ONLY_IF_BRANCH_IS_INCONSISTENT_WITH_PASSING_CONTRACT\n"
        )
    else:
        h.write(
            "CANDIDATE_NEXT=KEEP_TITLE_REJECTION_AND_CLASSIFY_RESIDUAL_SOURCES_AS_SOURCE_DEFICIENT\n"
        )

print("--- passing source title signals ---")
print((out / "06_PASSING_SOURCE_TITLE_SIGNAL_COUNTS.tsv").read_text(encoding="utf-8"), end="")
print("--- passing package title/assets ---")
print((out / "08_PASSING_PACKAGE_TITLE_ASSET_MATRIX.tsv").read_text(encoding="utf-8"), end="")
print("--- residual errors ---")
print((out / "09_RESIDUAL_ERROR_COUNTS.tsv").read_text(encoding="utf-8"), end="")
print("--- interpretations ---")
print((out / "11_INTERPRETATIONS.tsv").read_text(encoding="utf-8"), end="")
print("--- candidate next ---")
print((out / "12_CANDIDATE_NEXT.txt").read_text(encoding="utf-8"), end="")
PY

echo
echo "--- exact validator policy evidence ---"
if [ -f "$OUT/01_NUMBERED_validation.py.txt" ]; then
  cat "$OUT/01_NUMBERED_validation.py.txt"
else
  cat "$OUT/02_POLICY_CODE_AND_HISTORY.txt"
fi

# -------------------------------------------------------------------
# Post-state verification.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/13_GIT_STATUS_POST.z" 2>/dev/null || true
find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/13_OUTPUT_COUNT_POST.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/13_RECEIPT_COUNT_POST.txt"

GIT_MUTATION="NONE"
cmp -s "$OUT/00_GIT_STATUS_PRE.z" "$OUT/13_GIT_STATUS_POST.z" || GIT_MUTATION="DETECTED"

PRE_OUTPUT="$(cat "$OUT/00_OUTPUT_COUNT_PRE.txt")"
POST_OUTPUT="$(cat "$OUT/13_OUTPUT_COUNT_POST.txt")"
PRE_RECEIPTS="$(cat "$OUT/00_RECEIPT_COUNT_PRE.txt")"
POST_RECEIPTS="$(cat "$OUT/13_RECEIPT_COUNT_POST.txt")"

LIVE_MUTATION="NONE"
if [ "$PRE_OUTPUT" != "$POST_OUTPUT" ] || [ "$PRE_RECEIPTS" != "$POST_RECEIPTS" ]; then
  LIVE_MUTATION="DETECTED"
fi

NEXT="$(sed -n 's/^CANDIDATE_NEXT=//p' "$OUT/12_CANDIDATE_NEXT.txt" | head -1)"

if [ "$GIT_MUTATION" = "NONE" ] && [ "$LIVE_MUTATION" = "NONE" ]; then
  STATUS="PASS"
else
  STATUS="FAIL"
  NEXT="PRESERVE_STAGE40_MUTATION_EVIDENCE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_BOUND_MARKDOWN_VALIDATOR_TITLE_POLICY_STAGE40
UTC=$TS
STATUS=$STATUS
STAGE39=$LATEST39
RESIDUAL_MARKDOWN=62
REPOSITORY_STATUS_MUTATION=$GIT_MUTATION
LIVE_OUTPUT_MUTATION=$LIVE_MUTATION
SOURCE_MUTATION=NONE
LIVE_INGESTION_EXECUTED=NO
PARSER_CODE_MODIFIED=NO
VALIDATOR_CODE_MODIFIED=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
CURRENT_CODE=$OUT/01_NUMBERED_validation.py.txt
POLICY_HISTORY=$OUT/02_POLICY_CODE_AND_HISTORY.txt
VALIDATION_BLAME=$OUT/03_VALIDATION_BLAME.txt
PASSING_NO_TITLE_SIGNAL=$OUT/04_PASSING_NO_TITLE_SIGNAL_FILES.tsv
RESIDUAL_NO_TITLE_SIGNAL=$OUT/05_RESIDUAL_NO_TITLE_SIGNAL_FILES.tsv
PASSING_TITLE_SIGNAL_COUNTS=$OUT/06_PASSING_SOURCE_TITLE_SIGNAL_COUNTS.tsv
PASSING_TITLE_ASSET_MATRIX=$OUT/08_PASSING_PACKAGE_TITLE_ASSET_MATRIX.tsv
RESIDUAL_ERROR_COUNTS=$OUT/09_RESIDUAL_ERROR_COUNTS.tsv
OBSERVATIONS=$OUT/10_OBSERVATIONS.tsv
INTERPRETATIONS=$OUT/11_INTERPRETATIONS.tsv
CANDIDATE_NEXT=$OUT/12_CANDIDATE_NEXT.txt
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- candidate next ---"
cat "$OUT/12_CANDIDATE_NEXT.txt"
echo

if [ "$STATUS" = "PASS" ]; then
  echo "STAGE40_COMPLETE=YES"
  exit 0
fi

echo "STAGE40_COMPLETE=NO"
exit 1
