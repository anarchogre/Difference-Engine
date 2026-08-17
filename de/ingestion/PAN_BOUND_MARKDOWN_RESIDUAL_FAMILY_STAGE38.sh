#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_BOUND_MARKDOWN_RESIDUAL_FAMILY_$TS-STAGE38"

mkdir -p "$OUT"

echo "=== PAN — BOUND MARKDOWN RESIDUAL FAMILY / STAGE 38 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME" "$SERVICE"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST37="$(
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
        "PAN_REQUALIFY_STAGE28_FAILURE_SET_STAGE37" in t
        and "STATUS=PASS" in t
        and "ORIGINAL_FAILURE_SET=106" in t
        and "NOW_PASSING=5" in t
        and "STILL_NOT_PASSING=101" in t
        and "NEXT=BOUND_LARGEST_RESIDUAL_FAMILY_MD_62_BEFORE_ANY_REPAIR" in t
    ):
        hits.append((d.stat().st_mtime_ns, d))
if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST37" ] && [ -d "$LATEST37" ] || {
  echo "BLOCKER: passing Stage37 evidence not found"
  exit 22
}

REQUAL_LEDGER="$LATEST37/02_REQUALIFICATION_LEDGER.tsv"
[ -f "$REQUAL_LEDGER" ] || {
  echo "BLOCKER: Stage37 ledger missing: $REQUAL_LEDGER"
  exit 23
}

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

echo "STAGE37=$LATEST37"
echo "STAGE29=$LATEST29"
echo

# Read-only pre-state.
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/00_OUTPUT_COUNT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/00_RECEIPT_COUNT_PRE.txt"

# Exact current code surfaces.
{
  echo "===== MARKDOWN / TITLE / ASSET / VALIDATION REFERENCES ====="
  grep -R -n -E \
    'parse_markdown|MarkdownDocument|missing_title|no_assets|title|assets|heading|front.?matter|validate' \
    "$SERVICE" \
    --include='*.py' \
    --exclude-dir='__pycache__' \
    2>/dev/null || true
} > "$OUT/01_MARKDOWN_CODE_REFERENCES.txt"

for f in \
  "$SERVICE/parsers/markdown.py" \
  "$SERVICE/validation.py" \
  "$SERVICE/manifest.py"
do
  if [ -f "$f" ]; then
    b="$(basename "$f")"
    nl -ba "$f" > "$OUT/01_NUMBERED_$b.txt"
  fi
done

export PAN38_REQUAL_LEDGER="$REQUAL_LEDGER"
export PAN38_STAGE29_LEDGER="$STAGE29_LEDGER"
export PAN38_OUT="$OUT"

"$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter
import csv
import hashlib
import json
import os
import re

requal = Path(os.environ["PAN38_REQUAL_LEDGER"])
stage29 = Path(os.environ["PAN38_STAGE29_LEDGER"])
out = Path(os.environ["PAN38_OUT"])

with requal.open("r", encoding="utf-8", newline="") as h:
    rq = list(csv.DictReader(h, delimiter="\t"))

residual = [
    r for r in rq
    if (r.get("extension") or "").lower() == ".md"
    and (r.get("current_status") or "") != "PASS"
]

if len(residual) != 62:
    raise SystemExit(f"BLOCKER: expected 62 residual Markdown rows, got {len(residual)}")

with stage29.open("r", encoding="utf-8", newline="") as h:
    canon = list(csv.DictReader(h, delimiter="\t"))

passing_md = [
    r for r in canon
    if Path(r.get("source", "")).suffix.lower() == ".md"
    and (r.get("status") or "") in {"NEW_CANONICAL", "ALREADY_CANONICAL"}
]

if not passing_md:
    raise SystemExit("BLOCKER: no passing Markdown comparison set recovered")

def source_features(path: Path):
    raw = path.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    text = raw.decode("utf-8", errors="replace")
    lines = text.splitlines()
    nonblank = [x.strip() for x in lines if x.strip()]

    h1s = []
    headings = []
    image_lines = 0
    link_lines = 0

    for line in lines:
        s = line.strip()
        m = re.match(r"^(#{1,6})\s+(.+?)\s*$", s)
        if m:
            headings.append((len(m.group(1)), m.group(2)))
            if len(m.group(1)) == 1:
                h1s.append(m.group(2))
        if re.search(r"!\[[^\]]*\]\([^)]+\)", line):
            image_lines += 1
        if re.search(r"(?<!!)\[[^\]]+\]\([^)]+\)", line):
            link_lines += 1

    yaml_title = ""
    if lines and lines[0].strip() == "---":
        for line in lines[1:80]:
            if line.strip() == "---":
                break
            m = re.match(r"^\s*title\s*:\s*(.+?)\s*$", line, re.I)
            if m:
                yaml_title = m.group(1).strip().strip("'\"")
                break

    first_nonblank = nonblank[0] if nonblank else ""
    starts_h1 = bool(re.match(r"^#\s+\S", first_nonblank))

    return {
        "sha256": digest,
        "bytes": len(raw),
        "line_count": len(lines),
        "nonblank_count": len(nonblank),
        "first_nonblank": first_nonblank[:240],
        "starts_h1": starts_h1,
        "h1_count": len(h1s),
        "first_h1": h1s[0][:240] if h1s else "",
        "heading_count": len(headings),
        "yaml_title": yaml_title[:240],
        "image_lines": image_lines,
        "link_lines": link_lines,
    }

def read_pkg(pkg: Path):
    out = {
        "manifest_kind": "",
        "validation_passed": "",
        "validation_errors": [],
        "parsed_type": "",
        "parsed_keys": [],
        "parsed_title": "",
        "parsed_assets_count": "",
    }
    try:
        m = json.loads((pkg / "reports/manifest.json").read_text(encoding="utf-8"))
        v = json.loads((pkg / "reports/validation.json").read_text(encoding="utf-8"))
        p = json.loads((pkg / "structure/parsed.json").read_text(encoding="utf-8"))
    except Exception:
        return out

    out["manifest_kind"] = str(m.get("kind", ""))
    out["validation_passed"] = v.get("passed")
    out["validation_errors"] = [str(x) for x in (v.get("errors") or [])]
    out["parsed_type"] = type(p).__name__

    if isinstance(p, dict):
        out["parsed_keys"] = sorted(str(k) for k in p.keys())
        title = p.get("title")
        if title is not None:
            out["parsed_title"] = str(title)
        assets = p.get("assets")
        if isinstance(assets, (list, dict)):
            out["parsed_assets_count"] = len(assets)
    return out

detail_fields = [
    "source",
    "sha256",
    "bytes",
    "line_count",
    "nonblank_count",
    "first_nonblank",
    "starts_h1",
    "h1_count",
    "first_h1",
    "heading_count",
    "yaml_title",
    "image_lines",
    "link_lines",
    "current_status",
    "current_manifest_kind",
    "current_validation_errors",
    "pkg_manifest_kind",
    "pkg_validation_passed",
    "pkg_validation_errors",
    "parsed_type",
    "parsed_keys",
    "parsed_title",
    "parsed_assets_count",
    "mechanical_class",
]

details = []
hash_failures = []

for r in residual:
    source = Path(r["source"]).resolve()
    if not source.is_file():
        raise SystemExit(f"BLOCKER: missing source {source}")

    f = source_features(source)
    expected = (r.get("sha256") or "").strip()
    if expected and f["sha256"] != expected:
        hash_failures.append(str(source))

    pkg = Path((r.get("output") or "").strip())
    p = read_pkg(pkg) if pkg.is_dir() else {
        "manifest_kind": "",
        "validation_passed": "",
        "validation_errors": [],
        "parsed_type": "",
        "parsed_keys": [],
        "parsed_title": "",
        "parsed_assets_count": "",
    }

    errors = json.loads(r.get("current_validation_errors") or "[]")

    if "missing_title" in errors and "no_assets" in errors:
        cls = "MISSING_TITLE_AND_NO_ASSETS"
    elif "missing_title" in errors:
        cls = "MISSING_TITLE_ONLY"
    elif "no_assets" in errors:
        cls = "NO_ASSETS_ONLY"
    elif errors:
        cls = "OTHER_VALIDATION"
    else:
        cls = r.get("current_status") or "UNKNOWN"

    details.append({
        "source": str(source),
        **f,
        "current_status": r.get("current_status", ""),
        "current_manifest_kind": r.get("current_manifest_kind", ""),
        "current_validation_errors": json.dumps(errors, ensure_ascii=False, sort_keys=True),
        "pkg_manifest_kind": p["manifest_kind"],
        "pkg_validation_passed": p["validation_passed"],
        "pkg_validation_errors": json.dumps(p["validation_errors"], ensure_ascii=False, sort_keys=True),
        "parsed_type": p["parsed_type"],
        "parsed_keys": json.dumps(p["parsed_keys"], ensure_ascii=False),
        "parsed_title": p["parsed_title"],
        "parsed_assets_count": p["parsed_assets_count"],
        "mechanical_class": cls,
    })

if hash_failures:
    (out / "HASH_FAILURES.txt").write_text(
        "\n".join(hash_failures) + "\n",
        encoding="utf-8",
    )
    raise SystemExit(f"BLOCKER: {len(hash_failures)} residual Markdown hash failures")

with (out / "02_RESIDUAL_MARKDOWN_DETAIL.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    w = csv.DictWriter(h, fieldnames=detail_fields, delimiter="\t")
    w.writeheader()
    w.writerows(details)

# Passing Markdown comparison features. Sample all passing Markdown sources
# from Stage29, but do not mutate or re-ingest them.
passing_features = []
for r in passing_md:
    source = Path(r["source"]).resolve()
    if not source.is_file():
        continue
    f = source_features(source)
    passing_features.append({
        "source": str(source),
        **f,
    })

pass_fields = [
    "source", "sha256", "bytes", "line_count", "nonblank_count",
    "first_nonblank", "starts_h1", "h1_count", "first_h1",
    "heading_count", "yaml_title", "image_lines", "link_lines",
]

with (out / "03_PASSING_MARKDOWN_COMPARISON.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    w = csv.DictWriter(h, fieldnames=pass_fields, delimiter="\t")
    w.writeheader()
    w.writerows(passing_features)

class_counts = Counter(d["mechanical_class"] for d in details)
error_counts = Counter()
for d in details:
    for e in json.loads(d["current_validation_errors"]):
        error_counts[e] += 1

residual_shape = Counter(
    (
        d["starts_h1"],
        bool(d["yaml_title"]),
        d["h1_count"] > 0,
        d["image_lines"] > 0,
    )
    for d in details
)

passing_shape = Counter(
    (
        d["starts_h1"],
        bool(d["yaml_title"]),
        d["h1_count"] > 0,
        d["image_lines"] > 0,
    )
    for d in passing_features
)

def write_counter(path, header, counter):
    with path.open("w", encoding="utf-8") as h:
        h.write("\t".join(header) + "\n")
        for key, n in sorted(counter.items(), key=lambda kv: (-kv[1], str(kv[0]))):
            if not isinstance(key, tuple):
                key = (key,)
            h.write(str(n) + "\t" + "\t".join(map(str, key)) + "\n")

write_counter(
    out / "04_MECHANICAL_CLASS_COUNTS.tsv",
    ["count", "class"],
    class_counts,
)
write_counter(
    out / "05_ERROR_COUNTS.tsv",
    ["count", "error"],
    error_counts,
)
write_counter(
    out / "06_RESIDUAL_SOURCE_SHAPES.tsv",
    ["count", "starts_h1", "has_yaml_title", "has_any_h1", "has_image_line"],
    residual_shape,
)
write_counter(
    out / "07_PASSING_SOURCE_SHAPES.tsv",
    ["count", "starts_h1", "has_yaml_title", "has_any_h1", "has_image_line"],
    passing_shape,
)

obs = []
obs.append(f"OBSERVATION\tRESIDUAL_MARKDOWN\t{len(details)}")
obs.append(f"OBSERVATION\tPASSING_MARKDOWN_COMPARISON\t{len(passing_features)}")
obs.append("OBSERVATION\tSOURCE_HASHES\tPASS")
for cls, n in sorted(class_counts.items()):
    obs.append(f"OBSERVATION\tMECHANICAL_CLASS\t{n}\t{cls}")
for err, n in sorted(error_counts.items()):
    obs.append(f"OBSERVATION\tERROR_INCIDENCE\t{n}\t{err}")

for label, rows_ in [("RESIDUAL", details), ("PASSING", passing_features)]:
    if not rows_:
        continue
    obs.append(
        f"OBSERVATION\t{label}_STARTS_H1\t"
        f"{sum(bool(x['starts_h1']) for x in rows_)}"
    )
    obs.append(
        f"OBSERVATION\t{label}_HAS_ANY_H1\t"
        f"{sum(int(x['h1_count']) > 0 for x in rows_)}"
    )
    obs.append(
        f"OBSERVATION\t{label}_HAS_YAML_TITLE\t"
        f"{sum(bool(x['yaml_title']) for x in rows_)}"
    )
    obs.append(
        f"OBSERVATION\t{label}_HAS_IMAGE_LINE\t"
        f"{sum(int(x['image_lines']) > 0 for x in rows_)}"
    )

(out / "08_OBSERVATIONS.tsv").write_text(
    "\n".join(obs) + "\n",
    encoding="utf-8",
)

# Candidate next remains classification, not repair.
with (out / "09_CANDIDATE_NEXT.txt").open("w", encoding="utf-8") as h:
    h.write(f"RESIDUAL_MARKDOWN={len(details)}\n")
    h.write(f"PASSING_MARKDOWN_COMPARISON={len(passing_features)}\n")
    for cls, n in sorted(class_counts.items(), key=lambda kv: (-kv[1], kv[0])):
        h.write(f"CLASS_{cls}={n}\n")
    h.write(
        "CANDIDATE_NEXT=INTERPRET_MARKDOWN_TITLE_AND_ASSET_CONTRACT_AGAINST_SOURCE_SHAPES_AND_LIVE_CODE_BEFORE_ANY_REPAIR\n"
    )

print(f"RESIDUAL_MARKDOWN={len(details)}")
print(f"PASSING_MARKDOWN_COMPARISON={len(passing_features)}")
print("--- mechanical classes ---")
print((out / "04_MECHANICAL_CLASS_COUNTS.tsv").read_text(encoding="utf-8"), end="")
print("--- error counts ---")
print((out / "05_ERROR_COUNTS.tsv").read_text(encoding="utf-8"), end="")
print("--- residual source shapes ---")
print((out / "06_RESIDUAL_SOURCE_SHAPES.tsv").read_text(encoding="utf-8"), end="")
print("--- passing source shapes ---")
print((out / "07_PASSING_SOURCE_SHAPES.tsv").read_text(encoding="utf-8"), end="")
PY

# Print code references after corpus facts.
echo
echo "--- Markdown code references ---"
cat "$OUT/01_MARKDOWN_CODE_REFERENCES.txt"

# Post-state verification.
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/10_GIT_STATUS_POST.z" 2>/dev/null || true
find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/10_OUTPUT_COUNT_POST.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/10_RECEIPT_COUNT_POST.txt"

GIT_MUTATION="NONE"
cmp -s "$OUT/00_GIT_STATUS_PRE.z" "$OUT/10_GIT_STATUS_POST.z" || GIT_MUTATION="DETECTED"

PRE_OUTPUT="$(cat "$OUT/00_OUTPUT_COUNT_PRE.txt")"
POST_OUTPUT="$(cat "$OUT/10_OUTPUT_COUNT_POST.txt")"
PRE_RECEIPTS="$(cat "$OUT/00_RECEIPT_COUNT_PRE.txt")"
POST_RECEIPTS="$(cat "$OUT/10_RECEIPT_COUNT_POST.txt")"

LIVE_MUTATION="NONE"
if [ "$PRE_OUTPUT" != "$POST_OUTPUT" ] || [ "$PRE_RECEIPTS" != "$POST_RECEIPTS" ]; then
  LIVE_MUTATION="DETECTED"
fi

if [ "$GIT_MUTATION" = "NONE" ] && [ "$LIVE_MUTATION" = "NONE" ]; then
  STATUS="PASS"
  NEXT="INTERPRET_MARKDOWN_TITLE_AND_ASSET_CONTRACT_AGAINST_SOURCE_SHAPES_AND_LIVE_CODE_BEFORE_ANY_REPAIR"
else
  STATUS="FAIL"
  NEXT="PRESERVE_STAGE38_MUTATION_EVIDENCE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_BOUND_MARKDOWN_RESIDUAL_FAMILY_STAGE38
UTC=$TS
STATUS=$STATUS
STAGE37=$LATEST37
RESIDUAL_MARKDOWN=62
SOURCE_HASHES=PASS
REPOSITORY_STATUS_MUTATION=$GIT_MUTATION
LIVE_OUTPUT_MUTATION=$LIVE_MUTATION
SOURCE_MUTATION=NONE
LIVE_INGESTION_EXECUTED=NO
PARSER_CODE_MODIFIED=NO
VALIDATOR_CODE_MODIFIED=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
CODE_REFERENCES=$OUT/01_MARKDOWN_CODE_REFERENCES.txt
RESIDUAL_DETAIL=$OUT/02_RESIDUAL_MARKDOWN_DETAIL.tsv
PASSING_COMPARISON=$OUT/03_PASSING_MARKDOWN_COMPARISON.tsv
MECHANICAL_CLASSES=$OUT/04_MECHANICAL_CLASS_COUNTS.tsv
ERROR_COUNTS=$OUT/05_ERROR_COUNTS.tsv
RESIDUAL_SHAPES=$OUT/06_RESIDUAL_SOURCE_SHAPES.tsv
PASSING_SHAPES=$OUT/07_PASSING_SOURCE_SHAPES.tsv
OBSERVATIONS=$OUT/08_OBSERVATIONS.tsv
CANDIDATE_NEXT=$OUT/09_CANDIDATE_NEXT.txt
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- candidate next ---"
cat "$OUT/09_CANDIDATE_NEXT.txt"
echo

if [ "$STATUS" = "PASS" ]; then
  echo "STAGE38_COMPLETE=YES"
  exit 0
fi

echo "STAGE38_COMPLETE=NO"
exit 1
