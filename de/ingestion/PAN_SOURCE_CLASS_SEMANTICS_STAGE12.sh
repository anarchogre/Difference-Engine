#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_SOURCE_CLASS_SEMANTICS_$TS-STAGE12"

BATCH="$CURRENT/workspace/operational/ingestion/service/batch.py"
PROV="$CURRENT/workspace/operational/ingestion/service/provenance.py"

mkdir -p "$OUT"

echo "=== PAN — SOURCE CLASS SEMANTICS STAGE 12 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$BATCH" "$PROV"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

# 1. Exact implementation context around source_class.
{
  echo "=== batch.py source_class context ==="
  grep -n -C 12 'source_class' "$BATCH" || true
  echo
  echo "=== provenance.py source_class context ==="
  grep -n -C 12 'source_class' "$PROV" || true
} > "$OUT/01_IMPLEMENTATION_CONTEXT.txt"

# 2. Every active call site with surrounding context.
"$PYTHON" - "$CURRENT" > "$OUT/02_ACTIVE_CALL_SITES.txt" <<'PY'
from pathlib import Path
import re, sys

root = Path(sys.argv[1])

for p in sorted(root.rglob("*.py")):
    s = str(p)
    if "/recovery/retired_packages/" in s:
        continue
    try:
        lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
    except Exception:
        continue

    for i, line in enumerate(lines):
        if "ingest_sources" not in line and "source_class" not in line:
            continue
        lo = max(0, i - 8)
        hi = min(len(lines), i + 12)
        print(f"\n===== {p}:{i+1} =====")
        for j in range(lo, hi):
            print(f"{j+1:05d}: {lines[j]}")
PY

# 3. Recover observed source_class values from active code.
grep -RInE 'source_class[[:space:]]*=[[:space:]]*["'\''][^"'\'']+["'\'']' \
  "$CURRENT/workspace/operational/ingestion" \
  "$CURRENT/ade/services/ingestion" \
  --include='*.py' 2>/dev/null \
  | grep -v '/recovery/retired_packages/' \
  > "$OUT/03_SOURCE_CLASS_ASSIGNMENTS.txt" || true

# 4. Recover receipts/provenance records that actually contain source_class.
find "$CURRENT/workspace/operational/ingestion" \
  -type f \( -name 'receipt.json' -o -name 'provenance.json' -o -name '*.json' \) \
  ! -path '*/recovery/retired_packages/*' \
  -print0 2>/dev/null \
  | "$PYTHON" -c '
import json, sys
from pathlib import Path

raw = sys.stdin.buffer.read().split(b"\0")
for b in raw:
    if not b:
        continue
    p = Path(b.decode("utf-8", "replace"))
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        continue

    def walk(x, path=""):
        if isinstance(x, dict):
            if "source_class" in x:
                print(json.dumps({
                    "file": str(p),
                    "json_path": path or "$",
                    "source_class": x.get("source_class"),
                    "source": x.get("source") or x.get("source_path") or x.get("path"),
                    "source_type": x.get("source_type"),
                    "artifact_type": x.get("artifact_type"),
                }, ensure_ascii=False))
            for k,v in x.items():
                walk(v, f"{path}.{k}" if path else k)
        elif isinstance(x, list):
            for i,v in enumerate(x):
                walk(v, f"{path}[{i}]")
    walk(data)
' > "$OUT/04_RECEIPT_SOURCE_CLASS_RECORDS.jsonl"

# 5. Summarize source_class semantics from receipts and call sites.
"$PYTHON" - "$OUT/03_SOURCE_CLASS_ASSIGNMENTS.txt" "$OUT/04_RECEIPT_SOURCE_CLASS_RECORDS.jsonl" \
  > "$OUT/05_SEMANTIC_SUMMARY.txt" <<'PY'
from collections import Counter, defaultdict
from pathlib import Path
import json, re, sys

assign_path = Path(sys.argv[1])
receipt_path = Path(sys.argv[2])

assign_text = assign_path.read_text(encoding="utf-8", errors="replace") if assign_path.exists() else ""
vals = re.findall(r"source_class\s*=\s*[\"']([^\"']+)[\"']", assign_text)

print("CODE_SOURCE_CLASS_COUNTS=")
for k,v in Counter(vals).most_common():
    print(f"{k}\t{v}")

by_class = defaultdict(list)
if receipt_path.exists():
    for line in receipt_path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip():
            continue
        try:
            rec = json.loads(line)
        except Exception:
            continue
        by_class[str(rec.get("source_class"))].append(rec)

print()
print("RECEIPT_SOURCE_CLASS_COUNTS=")
for k,v in sorted(((k,len(v)) for k,v in by_class.items()), key=lambda kv:(-kv[1],kv[0])):
    print(f"{k}\t{v}")

print()
print("RECEIPT_SAMPLES=")
for k in sorted(by_class):
    print(f"\n[{k}]")
    for rec in by_class[k][:8]:
        print(json.dumps(rec, ensure_ascii=False))
PY

# 6. Recover any prose/spec references defining these labels.
{
  echo "=== prose/spec references ==="
  grep -RInE \
    'file_library_upload|manual_batch|source class|source_class|artifact intake|manual ingest|batch ingest' \
    "$CURRENT/workspace/operational/ingestion" "$CURRENT/docs" "$CURRENT/inventory" \
    --include='*.md' --include='*.txt' --include='*.json' --include='*.py' \
    2>/dev/null | head -3000 || true
} > "$OUT/06_SPEC_REFERENCES.txt"

# 7. Decision must be evidence-based. Do NOT guess a class.
DECISION="$("$PYTHON" - "$OUT/05_SEMANTIC_SUMMARY.txt" "$OUT/06_SPEC_REFERENCES.txt" <<'PY'
from pathlib import Path
import re, sys

summary = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
specs = Path(sys.argv[2]).read_text(encoding="utf-8", errors="replace")

# We only auto-promote a class if the evidence explicitly links a label to
# generic/manual local filesystem ingestion. Otherwise require human/contract review.
blob = (summary + "\n" + specs).lower()

if "manual_batch" in blob and re.search(r"manual_batch.{0,160}(batch|filesystem|local|manual)", blob, re.S):
    print("USE_MANUAL_BATCH")
elif re.search(r"\bmanual\b.{0,160}(filesystem|local|manual ingest|artifact intake)", blob, re.S):
    print("USE_MANUAL")
else:
    print("NOT_PROVEN")
PY
)"

case "$DECISION" in
  USE_MANUAL_BATCH)
    CLASS="manual_batch"
    NEXT="RUN_ONE_SANDBOXED_NONCONVERSATION_INGEST_WITH_MANUAL_BATCH"
    ;;
  USE_MANUAL)
    CLASS="manual"
    NEXT="RUN_ONE_SANDBOXED_NONCONVERSATION_INGEST_WITH_MANUAL"
    ;;
  *)
    CLASS=""
    NEXT="READ_SEMANTIC_SUMMARY_AND_SPEC_REFERENCES_BEFORE_EXECUTION"
    ;;
esac

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_SOURCE_CLASS_SEMANTICS_STAGE12
UTC=$TS
GENERIC_CLASS_DECISION=$DECISION
GENERIC_CLASS=$CLASS
INGESTION_EXECUTED=NO
SOURCE_MUTATION=NONE
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- semantic summary ---"
cat "$OUT/05_SEMANTIC_SUMMARY.txt"
echo
echo "STAGE12_COMPLETE=YES"
