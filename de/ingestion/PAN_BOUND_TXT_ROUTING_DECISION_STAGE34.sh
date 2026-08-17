#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_BOUND_TXT_ROUTING_DECISION_$TS-STAGE34"

mkdir -p "$OUT"

echo "=== PAN — BOUND TXT ROUTING DECISION / STAGE 34 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME" "$SERVICE"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST33="$(
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
    if "PAN_BOUND_TXT_VALIDATOR_FAMILY_STAGE33" not in t:
        continue
    if "STATUS=PASS" not in t:
        continue
    if "TXT_TOTAL=40" not in t:
        continue
    if "NEXT=READ_STAGE33_ROUTING_EVIDENCE_AND_BOUND_ONLY_CONFIRMED_TXT_CODE_EDGE" not in t:
        continue
    hits.append((d.stat().st_mtime_ns, d))
if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST33" ] && [ -d "$LATEST33" ] || {
  echo "BLOCKER: passing Stage33 evidence not found"
  exit 22
}

DETAIL="$LATEST33/02_TXT_DETAIL.tsv"
[ -f "$DETAIL" ] || { echo "BLOCKER: missing Stage33 detail ledger"; exit 23; }

echo "STAGE33=$LATEST33"
echo "DETAIL=$DETAIL"
echo

git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"
find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c > "$OUT/00_OUTPUT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c > "$OUT/00_RECEIPTS_PRE.txt"

# Preserve immutable code fingerprints before inspection.
find "$SERVICE" -type f -name '*.py' -print0 \
  | sort -z \
  | xargs -0 sha256sum \
  > "$OUT/01_SERVICE_CODE_SHA256_PRE.txt"

# Full numbered validation source and likely callers.
if [ -f "$SERVICE/validation.py" ]; then
  nl -ba "$SERVICE/validation.py" > "$OUT/02_VALIDATION_NUMBERED.txt"
else
  echo "MISSING: $SERVICE/validation.py" > "$OUT/02_VALIDATION_NUMBERED.txt"
fi

{
  echo "===== VALIDATION DEFINITIONS / CALLS / ERROR TOKENS ====="
  grep -R -n -E \
    'def .*valid|validate[_a-zA-Z0-9]*\(|validation|invalid_conversation_kind|no_conversation_turns|missing_user_turn|no_assets|manifest.*kind|parsed.*kind' \
    "$SERVICE" \
    --include='*.py' \
    --exclude-dir='__pycache__' \
    2>/dev/null || true
} > "$OUT/03_VALIDATION_CALL_REFERENCES.txt"

# Extract focused context around every relevant token/call.
"$PYTHON" - "$SERVICE" "$OUT/04_FOCUSED_CODE_CONTEXT.txt" <<'PY'
from pathlib import Path
import re, sys

root = Path(sys.argv[1])
dest = Path(sys.argv[2])
patterns = [
    "invalid_conversation_kind",
    "no_conversation_turns",
    "missing_user_turn",
    "no_assets",
    "validate",
    "validation",
]

blocks = []
seen = set()

for p in sorted(root.rglob("*.py")):
    if "__pycache__" in p.parts:
        continue
    try:
        lines = p.read_text(encoding="utf-8").splitlines()
    except Exception:
        continue

    hits = []
    for i, line in enumerate(lines, start=1):
        if any(token in line for token in patterns):
            hits.append(i)

    # Merge nearby windows.
    windows = []
    for i in hits:
        a, b = max(1, i - 8), min(len(lines), i + 10)
        if windows and a <= windows[-1][1] + 1:
            windows[-1] = (windows[-1][0], max(windows[-1][1], b))
        else:
            windows.append((a, b))

    for a, b in windows:
        key = (str(p), a, b)
        if key in seen:
            continue
        seen.add(key)
        blocks.append(f"===== {p}:{a}-{b} =====")
        for n in range(a, b + 1):
            blocks.append(f"{n:5d}  {lines[n-1]}")
        blocks.append("")

dest.write_text("\n".join(blocks) + "\n", encoding="utf-8")
PY

# Mechanically inspect the 39 markdown-manifest TXT cases and the 1 conversation case.
export PAN34_DETAIL="$DETAIL"
export PAN34_OUT="$OUT"
"$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter
import csv, json, os

detail = Path(os.environ["PAN34_DETAIL"])
out = Path(os.environ["PAN34_OUT"])

with detail.open("r", encoding="utf-8", newline="") as h:
    rows = list(csv.DictReader(h, delimiter="\t"))

if len(rows) != 40:
    raise SystemExit(f"BLOCKER: expected 40 TXT rows, got {len(rows)}")

kinds = Counter((r.get("manifest_kind_live") or "") for r in rows)
classes = Counter((r.get("classification") or "") for r in rows)
pairs = Counter(
    (
        r.get("manifest_kind_live") or "",
        r.get("failure_signature") or "",
    )
    for r in rows
)

with (out / "05_MANIFEST_X_FAILURE.tsv").open("w", encoding="utf-8") as h:
    h.write("count\tmanifest_kind\tfailure_signature\n")
    for (kind, sig), n in sorted(pairs.items(), key=lambda kv: (-kv[1], kv[0])):
        h.write(f"{n}\t{kind}\t{sig}\n")

# Select one deterministic representative from each manifest kind.
reps = {}
for r in rows:
    kind = r.get("manifest_kind_live") or "<EMPTY>"
    reps.setdefault(kind, r)

with (out / "06_REPRESENTATIVES.txt").open("w", encoding="utf-8") as h:
    for kind in sorted(reps):
        r = reps[kind]
        h.write(f"===== manifest_kind={kind} =====\n")
        for key in [
            "source",
            "failure_signature",
            "classification",
            "stage28_output_exists",
            "manifest_kind_live",
            "parsed_kind_live",
            "turn_count",
            "roles",
            "user_role_count",
            "assistant_role_count",
            "validation_errors_live",
            "first_nonblank",
        ]:
            h.write(f"{key}={r.get(key,'')}\n")
        h.write("\n")

# Observations only; no causal promotion.
obs = [
    f"OBSERVATION\tTXT_TOTAL\t{len(rows)}",
]
for kind, n in sorted(kinds.items()):
    obs.append(f"OBSERVATION\tMANIFEST_KIND\t{n}\t{kind or '<EMPTY>'}")
for cls, n in sorted(classes.items()):
    obs.append(f"OBSERVATION\tCLASSIFICATION\t{n}\t{cls}")

(out / "07_OBSERVATIONS.tsv").write_text("\n".join(obs) + "\n", encoding="utf-8")

print("--- manifest x failure ---")
print((out / "05_MANIFEST_X_FAILURE.tsv").read_text(encoding="utf-8"), end="")
print("--- representatives ---")
print((out / "06_REPRESENTATIVES.txt").read_text(encoding="utf-8"), end="")
PY

# Print only the tightest live code evidence to terminal.
echo
echo "--- validation.py ---"
if [ -f "$SERVICE/validation.py" ]; then
  sed -n '1,140p' "$OUT/02_VALIDATION_NUMBERED.txt"
fi

echo
echo "--- validation call references ---"
cat "$OUT/03_VALIDATION_CALL_REFERENCES.txt"

# Post-state verification.
find "$SERVICE" -type f -name '*.py' -print0 \
  | sort -z \
  | xargs -0 sha256sum \
  > "$OUT/08_SERVICE_CODE_SHA256_POST.txt"

git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/08_GIT_STATUS_POST.z" 2>/dev/null || true
find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c > "$OUT/08_OUTPUT_POST.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c > "$OUT/08_RECEIPTS_POST.txt"

CODE_MUTATION="NONE"
cmp -s "$OUT/01_SERVICE_CODE_SHA256_PRE.txt" "$OUT/08_SERVICE_CODE_SHA256_POST.txt" || CODE_MUTATION="DETECTED"

GIT_MUTATION="NONE"
cmp -s "$OUT/00_GIT_STATUS_PRE.z" "$OUT/08_GIT_STATUS_POST.z" || GIT_MUTATION="DETECTED"

PRE_OUTPUT="$(cat "$OUT/00_OUTPUT_PRE.txt")"
POST_OUTPUT="$(cat "$OUT/08_OUTPUT_POST.txt")"
PRE_RECEIPTS="$(cat "$OUT/00_RECEIPTS_PRE.txt")"
POST_RECEIPTS="$(cat "$OUT/08_RECEIPTS_POST.txt")"

LIVE_MUTATION="NONE"
if [ "$PRE_OUTPUT" != "$POST_OUTPUT" ] || [ "$PRE_RECEIPTS" != "$POST_RECEIPTS" ]; then
  LIVE_MUTATION="DETECTED"
fi

if [ "$CODE_MUTATION" = "NONE" ] && [ "$GIT_MUTATION" = "NONE" ] && [ "$LIVE_MUTATION" = "NONE" ]; then
  STATUS="PASS"
  NEXT="INTERPRET_STAGE34_CODE_PATH_AND_IF_CONFIRMED_BUILD_MINIMAL_TXT_REGRESSION_FIX"
else
  STATUS="FAIL"
  NEXT="PRESERVE_STAGE34_MUTATION_EVIDENCE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_BOUND_TXT_ROUTING_DECISION_STAGE34
UTC=$TS
STATUS=$STATUS
STAGE33=$LATEST33
TXT_TOTAL=40
SERVICE_CODE_MUTATION=$CODE_MUTATION
REPOSITORY_STATUS_MUTATION=$GIT_MUTATION
LIVE_OUTPUT_MUTATION=$LIVE_MUTATION
SOURCE_MUTATION=NONE
CANONICAL_INGEST_EXECUTED=NO
PARSER_CODE_MODIFIED=NO
VALIDATOR_CODE_MODIFIED=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
VALIDATION_SOURCE=$OUT/02_VALIDATION_NUMBERED.txt
CALL_REFERENCES=$OUT/03_VALIDATION_CALL_REFERENCES.txt
FOCUSED_CONTEXT=$OUT/04_FOCUSED_CODE_CONTEXT.txt
MANIFEST_X_FAILURE=$OUT/05_MANIFEST_X_FAILURE.tsv
REPRESENTATIVES=$OUT/06_REPRESENTATIVES.txt
NEXT=$NEXT
EOF

echo
cat "$OUT/SUMMARY.txt"
echo

if [ "$STATUS" = "PASS" ]; then
  echo "STAGE34_COMPLETE=YES"
  exit 0
fi

echo "STAGE34_COMPLETE=NO"
exit 1
