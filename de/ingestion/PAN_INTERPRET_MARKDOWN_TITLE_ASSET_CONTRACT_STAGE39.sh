#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_INTERPRET_MARKDOWN_TITLE_ASSET_CONTRACT_$TS-STAGE39"

mkdir -p "$OUT"

echo "=== PAN — INTERPRET MARKDOWN TITLE / ASSET CONTRACT / STAGE 39 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME" "$SERVICE"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST38="$(
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
        "PAN_BOUND_MARKDOWN_RESIDUAL_FAMILY_STAGE38" in t
        and "STATUS=PASS" in t
        and "RESIDUAL_MARKDOWN=62" in t
        and "NEXT=INTERPRET_MARKDOWN_TITLE_AND_ASSET_CONTRACT_AGAINST_SOURCE_SHAPES_AND_LIVE_CODE_BEFORE_ANY_REPAIR" in t
    ):
        hits.append((d.stat().st_mtime_ns, d))

if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST38" ] && [ -d "$LATEST38" ] || {
  echo "BLOCKER: passing Stage38 evidence not found"
  exit 22
}

RESIDUAL="$LATEST38/02_RESIDUAL_MARKDOWN_DETAIL.tsv"
PASSING="$LATEST38/03_PASSING_MARKDOWN_COMPARISON.tsv"

for x in "$RESIDUAL" "$PASSING"; do
  [ -f "$x" ] || { echo "BLOCKER: missing Stage38 artifact $x"; exit 23; }
done

LATEST29="$(
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
        "PAN_CANONICAL_INGEST_STAGE28_PASS_SET_STAGE29" in t
        and "STATUS=PASS" in t
        and "TARGET_PASS_SET=671" in t
        and "FAIL_COUNT=0" in t
    ):
        hits.append((d.stat().st_mtime_ns, d))
if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST29" ] && [ -d "$LATEST29" ] || {
  echo "BLOCKER: passing Stage29 evidence not found"
  exit 24
}

STAGE29_LEDGER="$(sed -n 's/^LEDGER=//p' "$LATEST29/SUMMARY.txt" | head -1)"
[ -f "$STAGE29_LEDGER" ] || {
  echo "BLOCKER: Stage29 ledger missing: $STAGE29_LEDGER"
  exit 25
}

echo "STAGE38=$LATEST38"
echo "STAGE29=$LATEST29"
echo

# -------------------------------------------------------------------
# Pre-state: Stage39 is interpretation only.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/00_OUTPUT_COUNT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/00_RECEIPT_COUNT_PRE.txt"

# -------------------------------------------------------------------
# Recover exact live code with line numbers.
# -------------------------------------------------------------------
for f in \
  "$SERVICE/parsers/markdown.py" \
  "$SERVICE/validation.py" \
  "$SERVICE/manifest.py" \
  "$SERVICE/pipeline.py"
do
  if [ -f "$f" ]; then
    b="$(basename "$f")"
    nl -ba "$f" > "$OUT/01_NUMBERED_$b.txt"
  fi
done

{
  echo "===== TITLE / ASSET CONTRACT REFERENCES ====="
  grep -R -n -E \
    'missing_title|no_assets|title|assets|MarkdownDocument|parse_markdown|validate' \
    "$SERVICE" \
    --include='*.py' \
    --exclude-dir='__pycache__' \
    2>/dev/null || true
} > "$OUT/01_CONTRACT_REFERENCES.txt"

# AST/exact-source extraction of relevant functions.
"$PYTHON" - "$SERVICE" "$OUT/02_RELEVANT_FUNCTIONS.txt" <<'PY'
from pathlib import Path
import ast
import sys

root = Path(sys.argv[1])
dest = Path(sys.argv[2])

wanted_tokens = {
    "title",
    "asset",
    "validate",
    "markdown",
}

blocks = []
for p in sorted(root.rglob("*.py")):
    if "__pycache__" in p.parts:
        continue
    try:
        text = p.read_text(encoding="utf-8")
        tree = ast.parse(text, filename=str(p))
    except Exception:
        continue

    lines = text.splitlines()

    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue

        name = node.name.lower()
        segment = ast.get_source_segment(text, node) or ""
        low = segment.lower()

        if not (
            any(tok in name for tok in wanted_tokens)
            or "missing_title" in low
            or "no_assets" in low
            or "parse_markdown" in low
        ):
            continue

        blocks.append(f"===== {p}:{node.lineno}-{node.end_lineno} {node.name} =====")
        for n in range(node.lineno, node.end_lineno + 1):
            blocks.append(f"{n:5d}  {lines[n-1]}")
        blocks.append("")

dest.write_text("\n".join(blocks) + "\n", encoding="utf-8")
PY

export PAN39_RESIDUAL="$RESIDUAL"
export PAN39_PASSING="$PASSING"
export PAN39_STAGE29_LEDGER="$STAGE29_LEDGER"
export PAN39_OUT="$OUT"

"$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter, defaultdict
import csv
import json
import os

residual_path = Path(os.environ["PAN39_RESIDUAL"])
passing_path = Path(os.environ["PAN39_PASSING"])
stage29_path = Path(os.environ["PAN39_STAGE29_LEDGER"])
out = Path(os.environ["PAN39_OUT"])

with residual_path.open("r", encoding="utf-8", newline="") as h:
    residual = list(csv.DictReader(h, delimiter="\t"))

with passing_path.open("r", encoding="utf-8", newline="") as h:
    passing_shapes = list(csv.DictReader(h, delimiter="\t"))

with stage29_path.open("r", encoding="utf-8", newline="") as h:
    stage29_rows = list(csv.DictReader(h, delimiter="\t"))

if len(residual) != 62:
    raise SystemExit(f"BLOCKER: expected 62 residual Markdown rows, got {len(residual)}")

# Convert common string fields.
def as_bool(v):
    return str(v).strip().lower() in {"true", "1", "yes"}

def as_int(v, default=0):
    try:
        return int(v)
    except Exception:
        return default

def jload(v, default):
    try:
        return json.loads(v)
    except Exception:
        return default

# ---------------------------------------------------------------
# Residual title evidence:
# source title signals vs parsed title vs validator result.
# ---------------------------------------------------------------
title_classes = Counter()
asset_classes = Counter()
residual_detail = []

for r in residual:
    errors = jload(r.get("current_validation_errors", "[]"), [])
    has_source_h1 = as_int(r.get("h1_count")) > 0
    starts_h1 = as_bool(r.get("starts_h1"))
    has_yaml_title = bool((r.get("yaml_title") or "").strip())
    parsed_title = (r.get("parsed_title") or "").strip()
    parsed_assets = r.get("parsed_assets_count", "")
    has_image_line = as_int(r.get("image_lines")) > 0

    if has_source_h1 or has_yaml_title:
        if parsed_title:
            title_class = "SOURCE_TITLE_SIGNAL_AND_PARSED_TITLE_PRESENT"
        else:
            title_class = "SOURCE_TITLE_SIGNAL_BUT_PARSED_TITLE_EMPTY"
    else:
        if parsed_title:
            title_class = "NO_SOURCE_TITLE_SIGNAL_BUT_PARSED_TITLE_PRESENT"
        else:
            title_class = "NO_SOURCE_TITLE_SIGNAL_AND_PARSED_TITLE_EMPTY"

    if "no_assets" in errors:
        if has_image_line:
            asset_class = "NO_ASSETS_ERROR_DESPITE_MARKDOWN_IMAGE_SYNTAX"
        else:
            asset_class = "NO_ASSETS_ERROR_AND_NO_MARKDOWN_IMAGE_SYNTAX"
    else:
        if has_image_line:
            asset_class = "NO_ASSETS_ERROR_ABSENT_WITH_MARKDOWN_IMAGE_SYNTAX"
        else:
            asset_class = "NO_ASSETS_ERROR_ABSENT_AND_NO_MARKDOWN_IMAGE_SYNTAX"

    title_classes[title_class] += 1
    asset_classes[asset_class] += 1

    residual_detail.append({
        "source": r["source"],
        "errors": json.dumps(errors, ensure_ascii=False, sort_keys=True),
        "starts_h1": starts_h1,
        "has_source_h1": has_source_h1,
        "first_h1": r.get("first_h1", ""),
        "has_yaml_title": has_yaml_title,
        "yaml_title": r.get("yaml_title", ""),
        "parsed_title": parsed_title,
        "title_evidence_class": title_class,
        "has_markdown_image_syntax": has_image_line,
        "image_lines": as_int(r.get("image_lines")),
        "parsed_assets_count": parsed_assets,
        "asset_evidence_class": asset_class,
        "mechanical_class": r.get("mechanical_class", ""),
    })

fields = list(residual_detail[0].keys())
with (out / "03_RESIDUAL_CONTRACT_DETAIL.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(residual_detail)

def write_counter(path, header, counter):
    with path.open("w", encoding="utf-8") as h:
        h.write("\t".join(header) + "\n")
        for key, n in sorted(counter.items(), key=lambda kv: (-kv[1], str(kv[0]))):
            if not isinstance(key, tuple):
                key = (key,)
            h.write(str(n) + "\t" + "\t".join(map(str, key)) + "\n")

write_counter(
    out / "04_TITLE_EVIDENCE_CLASSES.tsv",
    ["count", "title_evidence_class"],
    title_classes,
)
write_counter(
    out / "05_ASSET_EVIDENCE_CLASSES.tsv",
    ["count", "asset_evidence_class"],
    asset_classes,
)

# ---------------------------------------------------------------
# Passing canonical Markdown package contract:
# inspect output packages from Stage29, so we know what title/assets
# successful validation actually tolerated.
# ---------------------------------------------------------------
passing_pkg_rows = []

for r in stage29_rows:
    source = Path(r.get("source", "")).resolve()
    if source.suffix.lower() != ".md":
        continue
    if (r.get("status") or "") not in {"NEW_CANONICAL", "ALREADY_CANONICAL"}:
        continue

    pkg = Path((r.get("output") or "").strip())
    if not pkg.is_dir():
        continue

    try:
        manifest = json.loads((pkg / "reports/manifest.json").read_text(encoding="utf-8"))
        validation = json.loads((pkg / "reports/validation.json").read_text(encoding="utf-8"))
        parsed = json.loads((pkg / "structure/parsed.json").read_text(encoding="utf-8"))
    except Exception:
        continue

    title = ""
    assets_count = ""
    parsed_keys = []
    if isinstance(parsed, dict):
        parsed_keys = sorted(str(k) for k in parsed.keys())
        if parsed.get("title") is not None:
            title = str(parsed.get("title"))
        assets = parsed.get("assets")
        if isinstance(assets, (list, dict)):
            assets_count = len(assets)

    passing_pkg_rows.append({
        "source": str(source),
        "manifest_kind": manifest.get("kind", ""),
        "validation_passed": validation.get("passed"),
        "validation_errors": json.dumps(validation.get("errors") or [], ensure_ascii=False, sort_keys=True),
        "parsed_type": type(parsed).__name__,
        "parsed_keys": json.dumps(parsed_keys, ensure_ascii=False),
        "parsed_title": title,
        "parsed_title_present": bool(title.strip()),
        "parsed_assets_count": assets_count,
        "parsed_assets_present": isinstance(assets_count, int) and assets_count > 0,
    })

if not passing_pkg_rows:
    raise SystemExit("BLOCKER: could not inspect any passing Markdown packages")

pass_fields = list(passing_pkg_rows[0].keys())
with (out / "06_PASSING_PACKAGE_CONTRACT.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    w = csv.DictWriter(h, fieldnames=pass_fields, delimiter="\t")
    w.writeheader()
    w.writerows(passing_pkg_rows)

passing_contract = Counter(
    (
        bool(x["parsed_title_present"]),
        bool(x["parsed_assets_present"]),
    )
    for x in passing_pkg_rows
)

write_counter(
    out / "07_PASSING_TITLE_ASSET_MATRIX.tsv",
    ["count", "parsed_title_present", "parsed_assets_present"],
    passing_contract,
)

# ---------------------------------------------------------------
# Source-shape comparison: passing vs residual.
# ---------------------------------------------------------------
def shape_class(r):
    h1 = as_int(r.get("h1_count")) > 0
    yaml = bool((r.get("yaml_title") or "").strip())
    image = as_int(r.get("image_lines")) > 0
    return (
        h1,
        yaml,
        image,
    )

residual_shapes = Counter(shape_class(r) for r in residual)
passing_source_shapes = Counter(shape_class(r) for r in passing_shapes)

write_counter(
    out / "08_RESIDUAL_TITLE_ASSET_SOURCE_MATRIX.tsv",
    ["count", "has_h1", "has_yaml_title", "has_markdown_image_syntax"],
    residual_shapes,
)
write_counter(
    out / "09_PASSING_TITLE_ASSET_SOURCE_MATRIX.tsv",
    ["count", "has_h1", "has_yaml_title", "has_markdown_image_syntax"],
    passing_source_shapes,
)

# ---------------------------------------------------------------
# Evidence -> interpretation, but no promotion yet.
# ---------------------------------------------------------------
observations = [
    f"OBSERVATION\tRESIDUAL_MARKDOWN\t{len(residual)}",
    f"OBSERVATION\tPASSING_MARKDOWN_PACKAGES_INSPECTED\t{len(passing_pkg_rows)}",
]

for cls, n in sorted(title_classes.items()):
    observations.append(f"OBSERVATION\tTITLE_CLASS\t{n}\t{cls}")
for cls, n in sorted(asset_classes.items()):
    observations.append(f"OBSERVATION\tASSET_CLASS\t{n}\t{cls}")
for (title_present, assets_present), n in sorted(passing_contract.items()):
    observations.append(
        f"OBSERVATION\tPASSING_PACKAGE_CONTRACT\t{n}\t"
        f"title_present={title_present}\tassets_present={assets_present}"
    )

(out / "10_OBSERVATIONS.tsv").write_text(
    "\n".join(observations) + "\n",
    encoding="utf-8",
)

interpretations = []

source_title_but_empty = title_classes.get(
    "SOURCE_TITLE_SIGNAL_BUT_PARSED_TITLE_EMPTY", 0
)
no_source_no_parsed = title_classes.get(
    "NO_SOURCE_TITLE_SIGNAL_AND_PARSED_TITLE_EMPTY", 0
)
passing_without_assets = sum(
    n for (title_present, assets_present), n in passing_contract.items()
    if title_present and not assets_present
)
no_assets_without_image = asset_classes.get(
    "NO_ASSETS_ERROR_AND_NO_MARKDOWN_IMAGE_SYNTAX", 0
)
no_assets_with_image = asset_classes.get(
    "NO_ASSETS_ERROR_DESPITE_MARKDOWN_IMAGE_SYNTAX", 0
)

if source_title_but_empty:
    interpretations.append(
        "INTERPRETATION\tTITLE_EXTRACTION_EDGE\t"
        f"count={source_title_but_empty}\t"
        "These residual sources contain an H1 and/or YAML title signal but the parsed "
        "title field is empty. This is evidence for a parser/title-extraction edge."
    )

if no_source_no_parsed:
    interpretations.append(
        "INTERPRETATION\tSOURCE_TITLE_DEFICIENCY\t"
        f"count={no_source_no_parsed}\t"
        "These residual sources expose no tested source-level title signal and no parsed "
        "title. They should not be automatically repaired by inventing titles."
    )

if passing_without_assets:
    interpretations.append(
        "INTERPRETATION\tASSET_REQUIREMENT_QUESTION\t"
        f"passing_markdown_without_parsed_assets={passing_without_assets}\t"
        "Passing Markdown packages exist without parsed assets. If current residual "
        "validation still emits no_assets for comparable Markdown documents, the asset "
        "requirement may be context-dependent or stale and must be bounded in live code."
    )

if no_assets_with_image:
    interpretations.append(
        "INTERPRETATION\tASSET_EXTRACTION_EDGE\t"
        f"count={no_assets_with_image}\t"
        "Some residual sources contain Markdown image syntax while validation reports no_assets."
    )

if no_assets_without_image:
    interpretations.append(
        "INTERPRETATION\tNO_ASSET_SOURCE_CASES\t"
        f"count={no_assets_without_image}\t"
        "Some residual sources contain no tested Markdown image syntax and report no_assets. "
        "This alone does not justify synthesizing assets."
    )

(out / "11_INTERPRETATIONS.tsv").write_text(
    "\n".join(interpretations) + ("\n" if interpretations else ""),
    encoding="utf-8",
)

# Mechanical candidate next selection.
with (out / "12_CANDIDATE_NEXT.txt").open("w", encoding="utf-8") as h:
    h.write(f"RESIDUAL_MARKDOWN={len(residual)}\n")
    h.write(f"SOURCE_TITLE_SIGNAL_BUT_PARSED_TITLE_EMPTY={source_title_but_empty}\n")
    h.write(f"NO_SOURCE_TITLE_SIGNAL_AND_PARSED_TITLE_EMPTY={no_source_no_parsed}\n")
    h.write(f"PASSING_MARKDOWN_WITHOUT_PARSED_ASSETS={passing_without_assets}\n")
    h.write(f"NO_ASSETS_ERROR_WITH_IMAGE_SYNTAX={no_assets_with_image}\n")
    h.write(f"NO_ASSETS_ERROR_WITHOUT_IMAGE_SYNTAX={no_assets_without_image}\n")

    if source_title_but_empty:
        h.write(
            "CANDIDATE_NEXT=BOUND_MARKDOWN_TITLE_EXTRACTION_EDGE_WITH_EXACT_SOURCE_EXAMPLES_AND_TESTS_BEFORE_REPAIR\n"
        )
    else:
        h.write(
            "CANDIDATE_NEXT=BOUND_MARKDOWN_VALIDATOR_TITLE_POLICY_BEFORE_REPAIR\n"
        )

print("--- title evidence classes ---")
print((out / "04_TITLE_EVIDENCE_CLASSES.tsv").read_text(encoding="utf-8"), end="")
print("--- asset evidence classes ---")
print((out / "05_ASSET_EVIDENCE_CLASSES.tsv").read_text(encoding="utf-8"), end="")
print("--- passing title/asset matrix ---")
print((out / "07_PASSING_TITLE_ASSET_MATRIX.tsv").read_text(encoding="utf-8"), end="")
print("--- interpretations ---")
print((out / "11_INTERPRETATIONS.tsv").read_text(encoding="utf-8"), end="")
print("--- candidate next ---")
print((out / "12_CANDIDATE_NEXT.txt").read_text(encoding="utf-8"), end="")
PY

echo
echo "--- relevant live functions ---"
cat "$OUT/02_RELEVANT_FUNCTIONS.txt"

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
  NEXT="PRESERVE_STAGE39_MUTATION_EVIDENCE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_INTERPRET_MARKDOWN_TITLE_ASSET_CONTRACT_STAGE39
UTC=$TS
STATUS=$STATUS
STAGE38=$LATEST38
RESIDUAL_MARKDOWN=62
REPOSITORY_STATUS_MUTATION=$GIT_MUTATION
LIVE_OUTPUT_MUTATION=$LIVE_MUTATION
SOURCE_MUTATION=NONE
LIVE_INGESTION_EXECUTED=NO
PARSER_CODE_MODIFIED=NO
VALIDATOR_CODE_MODIFIED=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
CONTRACT_REFERENCES=$OUT/01_CONTRACT_REFERENCES.txt
RELEVANT_FUNCTIONS=$OUT/02_RELEVANT_FUNCTIONS.txt
RESIDUAL_DETAIL=$OUT/03_RESIDUAL_CONTRACT_DETAIL.tsv
TITLE_CLASSES=$OUT/04_TITLE_EVIDENCE_CLASSES.tsv
ASSET_CLASSES=$OUT/05_ASSET_EVIDENCE_CLASSES.tsv
PASSING_PACKAGE_CONTRACT=$OUT/06_PASSING_PACKAGE_CONTRACT.tsv
PASSING_TITLE_ASSET_MATRIX=$OUT/07_PASSING_TITLE_ASSET_MATRIX.tsv
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
  echo "STAGE39_COMPLETE=YES"
  exit 0
fi

echo "STAGE39_COMPLETE=NO"
exit 1
