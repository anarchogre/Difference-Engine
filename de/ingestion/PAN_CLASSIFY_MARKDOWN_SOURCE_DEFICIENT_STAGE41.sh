#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_CLASSIFY_MARKDOWN_SOURCE_DEFICIENT_$TS-STAGE41"

mkdir -p "$OUT"

echo "=== PAN — CLASSIFY MARKDOWN SOURCE-DEFICIENT FAMILY / STAGE 41 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST40="$(
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
        "PAN_BOUND_MARKDOWN_VALIDATOR_TITLE_POLICY_STAGE40" in t
        and "STATUS=PASS" in t
        and "RESIDUAL_MARKDOWN=62" in t
        and "NEXT=KEEP_TITLE_REJECTION_AND_CLASSIFY_RESIDUAL_SOURCES_AS_SOURCE_DEFICIENT" in t
    ):
        hits.append((d.stat().st_mtime_ns, d))

if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST40" ] && [ -d "$LATEST40" ] || {
  echo "BLOCKER: passing Stage40 evidence not found"
  exit 22
}

STAGE39="$(sed -n 's/^STAGE39=//p' "$LATEST40/SUMMARY.txt" | head -1)"
STAGE38="$(sed -n 's/^STAGE38=//p' "$STAGE39/SUMMARY.txt" | head -1)"

RESIDUAL38="$STAGE38/02_RESIDUAL_MARKDOWN_DETAIL.tsv"
RESIDUAL39="$STAGE39/03_RESIDUAL_CONTRACT_DETAIL.tsv"
OBS40="$LATEST40/10_OBSERVATIONS.tsv"
INT40="$LATEST40/11_INTERPRETATIONS.tsv"

for x in "$RESIDUAL38" "$RESIDUAL39" "$OBS40" "$INT40"; do
  [ -f "$x" ] || { echo "BLOCKER: missing required evidence $x"; exit 23; }
done

echo "STAGE40=$LATEST40"
echo "STAGE39=$STAGE39"
echo "STAGE38=$STAGE38"
echo

# Read-only pre-state.
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/00_OUTPUT_COUNT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/00_RECEIPT_COUNT_PRE.txt"

export PAN41_RESIDUAL38="$RESIDUAL38"
export PAN41_RESIDUAL39="$RESIDUAL39"
export PAN41_OBS40="$OBS40"
export PAN41_OUT="$OUT"

"$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter
import csv
import hashlib
import json
import os

r38_path = Path(os.environ["PAN41_RESIDUAL38"])
r39_path = Path(os.environ["PAN41_RESIDUAL39"])
obs40_path = Path(os.environ["PAN41_OBS40"])
out = Path(os.environ["PAN41_OUT"])

with r38_path.open("r", encoding="utf-8", newline="") as h:
    r38 = list(csv.DictReader(h, delimiter="\t"))

with r39_path.open("r", encoding="utf-8", newline="") as h:
    r39 = list(csv.DictReader(h, delimiter="\t"))

if len(r38) != 62 or len(r39) != 62:
    raise SystemExit(
        f"BLOCKER: expected 62 rows in both Stage38/39 ledgers; "
        f"got {len(r38)} and {len(r39)}"
    )

# Require the Stage40 corpus-policy findings explicitly.
obs40 = obs40_path.read_text(encoding="utf-8")

required_observations = [
    "OBSERVATION\tRESIDUAL_MARKDOWN\t62",
    "OBSERVATION\tPASSING_SOURCE_NO_TESTED_TITLE_SIGNAL\t0",
    "OBSERVATION\tPASSING_PACKAGE_WITHOUT_PARSED_TITLE\t0",
    "OBSERVATION\tPASSING_PACKAGE_WITHOUT_PARSED_ASSETS\t192",
]

for required in required_observations:
    if required not in obs40:
        raise SystemExit(f"BLOCKER: missing Stage40 observation: {required}")

by_source38 = {str(Path(r["source"]).resolve()): r for r in r38}
by_source39 = {str(Path(r["source"]).resolve()): r for r in r39}

if set(by_source38) != set(by_source39):
    raise SystemExit("BLOCKER: Stage38/39 residual source sets differ")

rows = []
hash_failures = []
secondary_counts = Counter()

for source_str in sorted(by_source38):
    a = by_source38[source_str]
    b = by_source39[source_str]
    source = Path(source_str)

    if not source.is_file():
        raise SystemExit(f"BLOCKER: source missing: {source}")

    expected = (a.get("sha256") or "").strip()
    actual = hashlib.sha256(source.read_bytes()).hexdigest()

    if not expected or actual != expected:
        hash_failures.append(source_str)

    try:
        errors = json.loads(a.get("current_validation_errors") or "[]")
    except Exception:
        errors = []

    if "missing_title" not in errors:
        raise SystemExit(f"BLOCKER: residual Markdown lacks missing_title: {source}")

    has_h1 = str(b.get("has_source_h1", "")).strip().lower() in {
        "true", "1", "yes"
    }
    has_yaml = str(b.get("has_yaml_title", "")).strip().lower() in {
        "true", "1", "yes"
    }
    parsed_title = (b.get("parsed_title") or "").strip()

    if has_h1 or has_yaml or parsed_title:
        raise SystemExit(
            f"BLOCKER: title evidence contradicts source-deficient classification: {source}"
        )

    secondary = []
    if "no_assets" in errors:
        secondary.append("no_assets")
        secondary_counts["no_assets"] += 1

    rows.append({
        "source": source_str,
        "sha256": actual,
        "extension": ".md",
        "primary_blocker": "missing_title",
        "source_title_signal": "NONE",
        "parsed_title": "",
        "secondary_diagnostics": json.dumps(
            secondary, ensure_ascii=False, sort_keys=True
        ),
        "disposition": "HELD_BACK_SOURCE_DEFICIENT",
        "disposition_reason": (
            "Required Markdown title signal absent from source; "
            "accepted corpus establishes title as required for this canonical contract."
        ),
        "repair_authorized": "NO",
        "source_mutation_authorized": "NO",
    })

if hash_failures:
    (out / "HASH_FAILURES.txt").write_text(
        "\n".join(hash_failures) + "\n",
        encoding="utf-8",
    )
    raise SystemExit(
        f"BLOCKER: {len(hash_failures)} Markdown source hash failures"
    )

fields = list(rows[0].keys())
with (out / "01_MARKDOWN_DISPOSITION_LEDGER.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(rows)

with (out / "02_DISPOSITION_COUNTS.tsv").open("w", encoding="utf-8") as h:
    h.write("count\tdisposition\tprimary_blocker\n")
    h.write(f"{len(rows)}\tHELD_BACK_SOURCE_DEFICIENT\tmissing_title\n")

with (out / "03_SECONDARY_DIAGNOSTIC_COUNTS.tsv").open(
    "w", encoding="utf-8"
) as h:
    h.write("count\tdiagnostic\n")
    for k, n in sorted(
        secondary_counts.items(), key=lambda kv: (-kv[1], kv[0])
    ):
        h.write(f"{n}\t{k}\n")

(out / "04_POLICY_DISPOSITION.txt").write_text(
    "CLASSIFICATION=CANONICAL_HELD_BACK_SOURCE_DEFICIENT\n"
    "PRIMARY_BLOCKER=missing_title\n"
    "COUNT=62\n"
    "TITLE_REJECTION=KEEP\n"
    "TITLE_SYNTHESIS=NOT_AUTHORIZED\n"
    "SOURCE_REWRITE=NOT_AUTHORIZED\n"
    "PARSER_REPAIR=NOT_INDICATED\n"
    "VALIDATOR_WEAKENING=NOT_INDICATED\n"
    "NO_ASSETS=SECONDARY_NONUNIVERSAL_DIAGNOSTIC\n",
    encoding="utf-8",
)

print(f"CLASSIFIED={len(rows)}")
print("PRIMARY_BLOCKER=missing_title")
print("DISPOSITION=HELD_BACK_SOURCE_DEFICIENT")
print(f"SECONDARY_NO_ASSETS={secondary_counts.get('no_assets', 0)}")
print("SOURCE_HASHES=PASS")
PY

# Post-state verification.
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
  NEXT="BOUND_REMAINING_TXT_RESIDUAL_35_AGAINST_PROMOTED_STAGE36"
else
  STATUS="FAIL"
  NEXT="PRESERVE_STAGE41_MUTATION_EVIDENCE"
fi

cat > "$OUT/CHANGELOG_EVENT.txt" <<EOF
UTC=$TS
EVENT=MARKDOWN_RESIDUAL_FAMILY_CLASSIFIED_SOURCE_DEFICIENT
CLASSIFICATION=OBSERVED_AND_VALIDATED_DISPOSITION
COUNT=62
PRIMARY_BLOCKER=missing_title
TITLE_REJECTION=KEEP
SOURCE_REWRITE=NOT_AUTHORIZED
PARSER_REPAIR=NOT_INDICATED
VALIDATOR_WEAKENING=NOT_INDICATED
NO_ASSETS=SECONDARY_NONUNIVERSAL_DIAGNOSTIC
SOURCE_HASHES=PASS
EOF

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_CLASSIFY_MARKDOWN_SOURCE_DEFICIENT_STAGE41
UTC=$TS
STATUS=$STATUS
STAGE40=$LATEST40
MARKDOWN_CLASSIFIED=62
DISPOSITION=HELD_BACK_SOURCE_DEFICIENT
PRIMARY_BLOCKER=missing_title
TITLE_REJECTION=KEEP
TITLE_SYNTHESIS_AUTHORIZED=NO
SOURCE_REWRITE_AUTHORIZED=NO
PARSER_REPAIR_INDICATED=NO
VALIDATOR_WEAKENING_INDICATED=NO
SOURCE_HASHES=PASS
REPOSITORY_STATUS_MUTATION=$GIT_MUTATION
LIVE_OUTPUT_MUTATION=$LIVE_MUTATION
SOURCE_MUTATION=NONE
LIVE_INGESTION_EXECUTED=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
DISPOSITION_LEDGER=$OUT/01_MARKDOWN_DISPOSITION_LEDGER.tsv
DISPOSITION_COUNTS=$OUT/02_DISPOSITION_COUNTS.tsv
SECONDARY_DIAGNOSTICS=$OUT/03_SECONDARY_DIAGNOSTIC_COUNTS.tsv
POLICY_DISPOSITION=$OUT/04_POLICY_DISPOSITION.txt
CHANGELOG_EVENT=$OUT/CHANGELOG_EVENT.txt
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
cat "$OUT/02_DISPOSITION_COUNTS.tsv"
echo
cat "$OUT/03_SECONDARY_DIAGNOSTIC_COUNTS.tsv"
echo

if [ "$STATUS" = "PASS" ]; then
  echo "STAGE41_COMPLETE=YES"
  exit 0
fi

echo "STAGE41_COMPLETE=NO"
exit 1
