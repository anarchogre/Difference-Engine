#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_CLASSIFY_TXT35_SOURCE_DEFICIENT_$TS-STAGE43"

mkdir -p "$OUT"

echo "=== PAN — CLASSIFY TXT35 SOURCE-DEFICIENT / STAGE 43 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST42="$(
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
        "PAN_BOUND_REMAINING_TXT_RESIDUAL_STAGE42" in t
        and "STATUS=PASS" in t
        and "TXT_RESIDUAL=35" in t
        and "NEXT=CLASSIFY_TXT35_AS_SOURCE_DEFICIENT_WITHOUT_FURTHER_CODE_REPAIR" in t
    ):
        hits.append((d.stat().st_mtime_ns, d))

if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST42" ] && [ -d "$LATEST42" ] || {
  echo "BLOCKER: passing Stage42 evidence not found"
  exit 22
}

DETAIL="$LATEST42/02_TXT35_DETAIL.tsv"
MARKDOWN_SET="$LATEST42/06_MARKDOWN_FALLBACK_SOURCE_DEFICIENT.tsv"
CONVERSATION_SET="$LATEST42/07_CONVERSATION_MISSING_USER.tsv"

for x in "$DETAIL" "$MARKDOWN_SET" "$CONVERSATION_SET"; do
  [ -f "$x" ] || { echo "BLOCKER: missing Stage42 artifact $x"; exit 23; }
done

echo "STAGE42=$LATEST42"
echo

# -------------------------------------------------------------------
# Pre-state. Stage43 is disposition only.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/00_OUTPUT_COUNT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/00_RECEIPT_COUNT_PRE.txt"

export PAN43_DETAIL="$DETAIL"
export PAN43_MARKDOWN_SET="$MARKDOWN_SET"
export PAN43_CONVERSATION_SET="$CONVERSATION_SET"
export PAN43_OUT="$OUT"

"$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter
import csv
import hashlib
import json
import os

detail_path = Path(os.environ["PAN43_DETAIL"])
markdown_path = Path(os.environ["PAN43_MARKDOWN_SET"])
conversation_path = Path(os.environ["PAN43_CONVERSATION_SET"])
out = Path(os.environ["PAN43_OUT"])

def read_tsv(path):
    with path.open("r", encoding="utf-8", newline="") as h:
        return list(csv.DictReader(h, delimiter="\t"))

detail = read_tsv(detail_path)
markdown_rows = read_tsv(markdown_path)
conversation_rows = read_tsv(conversation_path)

if len(detail) != 35:
    raise SystemExit(f"BLOCKER: expected 35 TXT residual rows, got {len(detail)}")
if len(markdown_rows) != 34:
    raise SystemExit(f"BLOCKER: expected 34 Markdown-fallback rows, got {len(markdown_rows)}")
if len(conversation_rows) != 1:
    raise SystemExit(f"BLOCKER: expected 1 conversation row, got {len(conversation_rows)}")

by_source = {str(Path(r["source"]).resolve()): r for r in detail}
md_sources = {str(Path(r["source"]).resolve()) for r in markdown_rows}
conv_sources = {str(Path(r["source"]).resolve()) for r in conversation_rows}

if md_sources & conv_sources:
    raise SystemExit("BLOCKER: TXT source appears in both Markdown and conversation sets")
if md_sources | conv_sources != set(by_source):
    raise SystemExit("BLOCKER: Stage42 split does not cover exact TXT35 set")

rows = []
hash_failures = []
disposition_counts = Counter()
primary_counts = Counter()
secondary_counts = Counter()

for source_str in sorted(by_source):
    r = by_source[source_str]
    source = Path(source_str)

    if not source.is_file():
        raise SystemExit(f"BLOCKER: source missing: {source}")

    expected = (r.get("sha256") or "").strip()
    actual = hashlib.sha256(source.read_bytes()).hexdigest()
    if not expected or actual != expected:
        hash_failures.append(source_str)

    try:
        errors = json.loads(r.get("validation_errors") or "[]")
    except Exception:
        errors = []

    classification = r.get("classification", "")
    manifest_kind = r.get("manifest_kind", "")

    if source_str in md_sources:
        if classification != "MARKDOWN_FALLBACK_SOURCE_TITLE_DEFICIENT":
            raise SystemExit(f"BLOCKER: unexpected Markdown classification: {source}")
        if manifest_kind != "markdown":
            raise SystemExit(f"BLOCKER: Markdown-fallback manifest drift: {source}")
        if "missing_title" not in errors:
            raise SystemExit(f"BLOCKER: Markdown TXT lacks missing_title: {source}")
        if int(r.get("h1_count") or 0) != 0:
            raise SystemExit(f"BLOCKER: Markdown TXT has H1 title signal: {source}")
        if (r.get("yaml_title") or "").strip():
            raise SystemExit(f"BLOCKER: Markdown TXT has YAML title signal: {source}")
        if (r.get("parsed_title") or "").strip():
            raise SystemExit(f"BLOCKER: Markdown TXT has parsed title: {source}")

        primary = "missing_title"
        disposition = "HELD_BACK_SOURCE_DEFICIENT"
        reason = (
            "Correctly routed to Markdown after Stage36; required title signal absent "
            "from source and parsed representation."
        )

        if "no_assets" in errors:
            secondary_counts["no_assets"] += 1

    elif source_str in conv_sources:
        if classification != "CONVERSATION_SOURCE_MISSING_USER_TURN":
            raise SystemExit(f"BLOCKER: unexpected conversation classification: {source}")
        if manifest_kind != "conversation":
            raise SystemExit(f"BLOCKER: conversation manifest drift: {source}")
        if "missing_user_turn" not in errors:
            raise SystemExit(f"BLOCKER: conversation TXT lacks missing_user_turn: {source}")

        roles = []
        try:
            roles = json.loads(r.get("parsed_roles") or "[]")
        except Exception:
            pass

        user_roles = [x for x in roles if str(x).lower() in {"user", "human"}]
        if user_roles:
            raise SystemExit(
                f"BLOCKER: user/human role exists despite source-deficient classification: {source}"
            )

        primary = "missing_user_turn"
        disposition = "HELD_BACK_SOURCE_DEFICIENT"
        reason = (
            "Conversation-shaped source contains no parsed user/human turn; "
            "conversation integrity gate remains valid."
        )

    else:
        raise SystemExit(f"BLOCKER: unpartitioned TXT source: {source}")

    disposition_counts[disposition] += 1
    primary_counts[primary] += 1

    rows.append({
        "source": source_str,
        "sha256": actual,
        "extension": ".txt",
        "manifest_kind": manifest_kind,
        "primary_blocker": primary,
        "validation_errors": json.dumps(errors, ensure_ascii=False, sort_keys=True),
        "disposition": disposition,
        "disposition_reason": reason,
        "parser_repair_indicated": "NO",
        "validator_weakening_indicated": "NO",
        "source_rewrite_authorized": "NO",
        "synthetic_content_authorized": "NO",
    })

if hash_failures:
    (out / "HASH_FAILURES.txt").write_text(
        "\n".join(hash_failures) + "\n",
        encoding="utf-8",
    )
    raise SystemExit(f"BLOCKER: {len(hash_failures)} TXT source hash failures")

fields = list(rows[0].keys())
with (out / "01_TXT35_DISPOSITION_LEDGER.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(rows)

with (out / "02_DISPOSITION_COUNTS.tsv").open("w", encoding="utf-8") as h:
    h.write("count\tdisposition\n")
    for k, n in sorted(disposition_counts.items()):
        h.write(f"{n}\t{k}\n")

with (out / "03_PRIMARY_BLOCKER_COUNTS.tsv").open("w", encoding="utf-8") as h:
    h.write("count\tprimary_blocker\n")
    for k, n in sorted(primary_counts.items(), key=lambda kv: (-kv[1], kv[0])):
        h.write(f"{n}\t{k}\n")

with (out / "04_SECONDARY_DIAGNOSTICS.tsv").open("w", encoding="utf-8") as h:
    h.write("count\tdiagnostic\n")
    for k, n in sorted(secondary_counts.items(), key=lambda kv: (-kv[1], kv[0])):
        h.write(f"{n}\t{k}\n")

(out / "05_POLICY_DISPOSITION.txt").write_text(
    "CLASSIFICATION=CANONICAL_HELD_BACK_SOURCE_DEFICIENT\n"
    "COUNT=35\n"
    "MARKDOWN_FALLBACK_COUNT=34\n"
    "MARKDOWN_PRIMARY_BLOCKER=missing_title\n"
    "CONVERSATION_COUNT=1\n"
    "CONVERSATION_PRIMARY_BLOCKER=missing_user_turn\n"
    "PARSER_REPAIR_INDICATED=NO\n"
    "VALIDATOR_WEAKENING_INDICATED=NO\n"
    "SOURCE_REWRITE_AUTHORIZED=NO\n"
    "SYNTHETIC_CONTENT_AUTHORIZED=NO\n",
    encoding="utf-8",
)

print("CLASSIFIED=35")
print("MARKDOWN_SOURCE_DEFICIENT=34")
print("CONVERSATION_SOURCE_DEFICIENT=1")
print("PRIMARY_missing_title=34")
print("PRIMARY_missing_user_turn=1")
print(f"SECONDARY_no_assets={secondary_counts.get('no_assets', 0)}")
print("SOURCE_HASHES=PASS")
PY

# -------------------------------------------------------------------
# Post-state proof.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/06_GIT_STATUS_POST.z" 2>/dev/null || true

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/06_OUTPUT_COUNT_POST.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/06_RECEIPT_COUNT_POST.txt"

GIT_MUTATION="NONE"
cmp -s "$OUT/00_GIT_STATUS_PRE.z" "$OUT/06_GIT_STATUS_POST.z" || GIT_MUTATION="DETECTED"

PRE_OUTPUT="$(cat "$OUT/00_OUTPUT_COUNT_PRE.txt")"
POST_OUTPUT="$(cat "$OUT/06_OUTPUT_COUNT_POST.txt")"
PRE_RECEIPTS="$(cat "$OUT/00_RECEIPT_COUNT_PRE.txt")"
POST_RECEIPTS="$(cat "$OUT/06_RECEIPT_COUNT_POST.txt")"

LIVE_MUTATION="NONE"
if [ "$PRE_OUTPUT" != "$POST_OUTPUT" ] || [ "$PRE_RECEIPTS" != "$POST_RECEIPTS" ]; then
  LIVE_MUTATION="DETECTED"
fi

if [ "$GIT_MUTATION" = "NONE" ] && [ "$LIVE_MUTATION" = "NONE" ]; then
  STATUS="PASS"
  NEXT="CLASSIFY_JSON4_SOURCE_INVALID_OR_UNRESOLVED_AND_CLOSE_ORIGINAL_HELD_BACK_SET"
else
  STATUS="FAIL"
  NEXT="PRESERVE_STAGE43_MUTATION_EVIDENCE"
fi

cat > "$OUT/CHANGELOG_EVENT.txt" <<EOF
UTC=$TS
EVENT=TXT35_RESIDUAL_FAMILY_CLASSIFIED_SOURCE_DEFICIENT
CLASSIFICATION=OBSERVED_AND_VALIDATED_DISPOSITION
COUNT=35
MARKDOWN_FALLBACK_SOURCE_DEFICIENT=34
CONVERSATION_SOURCE_DEFICIENT=1
PRIMARY_MISSING_TITLE=34
PRIMARY_MISSING_USER_TURN=1
PARSER_REPAIR_INDICATED=NO
VALIDATOR_WEAKENING_INDICATED=NO
SOURCE_REWRITE_AUTHORIZED=NO
SOURCE_HASHES=PASS
EOF

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_CLASSIFY_TXT35_SOURCE_DEFICIENT_STAGE43
UTC=$TS
STATUS=$STATUS
STAGE42=$LATEST42
TXT_CLASSIFIED=35
DISPOSITION=HELD_BACK_SOURCE_DEFICIENT
MARKDOWN_FALLBACK_SOURCE_DEFICIENT=34
CONVERSATION_SOURCE_DEFICIENT=1
PRIMARY_MISSING_TITLE=34
PRIMARY_MISSING_USER_TURN=1
PARSER_REPAIR_INDICATED=NO
VALIDATOR_WEAKENING_INDICATED=NO
SOURCE_REWRITE_AUTHORIZED=NO
SYNTHETIC_CONTENT_AUTHORIZED=NO
SOURCE_HASHES=PASS
REPOSITORY_STATUS_MUTATION=$GIT_MUTATION
LIVE_OUTPUT_MUTATION=$LIVE_MUTATION
SOURCE_MUTATION=NONE
LIVE_INGESTION_EXECUTED=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
DISPOSITION_LEDGER=$OUT/01_TXT35_DISPOSITION_LEDGER.tsv
DISPOSITION_COUNTS=$OUT/02_DISPOSITION_COUNTS.tsv
PRIMARY_BLOCKERS=$OUT/03_PRIMARY_BLOCKER_COUNTS.tsv
SECONDARY_DIAGNOSTICS=$OUT/04_SECONDARY_DIAGNOSTICS.tsv
POLICY_DISPOSITION=$OUT/05_POLICY_DISPOSITION.txt
CHANGELOG_EVENT=$OUT/CHANGELOG_EVENT.txt
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
cat "$OUT/02_DISPOSITION_COUNTS.tsv"
echo
cat "$OUT/03_PRIMARY_BLOCKER_COUNTS.tsv"
echo

if [ "$STATUS" = "PASS" ]; then
  echo "STAGE43_COMPLETE=YES"
  exit 0
fi

echo "STAGE43_COMPLETE=NO"
exit 1
