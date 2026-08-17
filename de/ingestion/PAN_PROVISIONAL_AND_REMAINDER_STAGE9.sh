#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
FIRST_CORPUS="$HOME/Difference-Engine-LEGACY-STALE-DECOMPOSED"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"

OUT="$TREE_HOME/PAN_PROVISIONAL_AND_REMAINDER_$TS"
SANDBOX="$OUT/sandbox"
RECEIPTS="$SANDBOX/receipts"
OUTPUT="$SANDBOX/output"
LOGS="$OUT/logs"

mkdir -p "$OUT" "$RECEIPTS" "$OUTPUT" "$LOGS"

LATEST_DELTA="$(find "$TREE_HOME" -maxdepth 1 -type d -name 'PAN_FIRST_CORPUS_DELTA_*' \
  -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"

LATEST_STAGE7="$(find "$TREE_HOME" -maxdepth 1 -type d -name 'PAN_FIRST_REAL_INGEST_*' \
  -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"

LATEST_STAGE8="$(find "$TREE_HOME" -maxdepth 1 -type d -name 'PAN_BULK_INGEST_STRONG_*' \
  -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"

for x in "$CURRENT" "$FIRST_CORPUS" "$LATEST_DELTA" "$LATEST_STAGE7" "$LATEST_STAGE8"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

CENSUS_MD="$LATEST_DELTA/delta/legacy_stale_decomposed/DELTA_CENSUS.md"
STRONG_LIST="$LATEST_STAGE7/01_STRONG_CANDIDATES.txt"

[ -f "$CENSUS_MD" ] || { echo "BLOCKER: missing $CENSUS_MD"; exit 22; }
[ -f "$STRONG_LIST" ] || { echo "BLOCKER: missing $STRONG_LIST"; exit 23; }

PROVISIONAL_LIST="$OUT/01_PROVISIONAL_SUPPORTED.txt"
UNSUPPORTED_PROVISIONAL="$OUT/02_PROVISIONAL_UNSUPPORTED.txt"
REMAINDER_TSV="$OUT/03_REMAINDER_BY_EXTENSION.tsv"
REMAINDER_LIST="$OUT/04_NONCONVERSATION_REMAINDER.txt"

echo "=== PAN — PROVISIONAL + REMAINDER STAGE 9 ==="
echo "FIRST_CORPUS=$FIRST_CORPUS"
echo "EVIDENCE=$OUT"
echo

# Recover provisional conversation-bearing candidates and inventory everything not
# represented by strong/provisional conversation classification.
"$PYTHON" - "$CENSUS_MD" "$STRONG_LIST" "$FIRST_CORPUS" \
  "$PROVISIONAL_LIST" "$UNSUPPORTED_PROVISIONAL" "$REMAINDER_TSV" "$REMAINDER_LIST" <<'PY'
from pathlib import Path
import collections, re, sys

census = Path(sys.argv[1])
strong_list = Path(sys.argv[2])
root = Path(sys.argv[3])
prov_supported_out = Path(sys.argv[4])
prov_unsupported_out = Path(sys.argv[5])
remainder_tsv = Path(sys.argv[6])
remainder_list = Path(sys.argv[7])

supported = {".txt", ".md", ".json"}

def extract(label):
    found = []
    for line in census.read_text(encoding="utf-8", errors="replace").splitlines():
        if f"**{label}**" not in line.lower():
            continue
        m = re.search(r"`(/[^`]+)`", line)
        if not m:
            m = re.search(r"(/home/[^\s].*?)(?:\s+[—-]\s+|$)", line)
        if not m:
            continue
        p = Path(m.group(1).strip())
        if p.is_file():
            found.append(str(p))
    # stable exact-path dedup
    seen, out = set(), []
    for x in found:
        if x not in seen:
            seen.add(x)
            out.append(x)
    return out

strong = set(x.strip() for x in strong_list.read_text(encoding="utf-8").splitlines() if x.strip())
provisional = extract("provisional")

prov_supported = [x for x in provisional if Path(x).suffix.lower() in supported]
prov_unsupported = [x for x in provisional if Path(x).suffix.lower() not in supported]

prov_supported_out.write_text("\n".join(prov_supported) + ("\n" if prov_supported else ""), encoding="utf-8")
prov_unsupported_out.write_text("\n".join(prov_unsupported) + ("\n" if prov_unsupported else ""), encoding="utf-8")

conversation_paths = strong | set(provisional)

all_files = [str(p) for p in root.rglob("*") if p.is_file()]
remainder = [x for x in all_files if x not in conversation_paths]
remainder_list.write_text("\n".join(sorted(remainder)) + ("\n" if remainder else ""), encoding="utf-8")

counts = collections.Counter()
for x in remainder:
    p = Path(x)
    suffix = p.suffix.lower() if p.suffix else "[no_ext]"
    counts[suffix] += 1

with remainder_tsv.open("w", encoding="utf-8") as f:
    f.write("extension\tcount\n")
    for ext, count in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        f.write(f"{ext}\t{count}\n")

print(f"STRONG_CLASSIFIED={len(strong)}")
print(f"PROVISIONAL_CLASSIFIED={len(provisional)}")
print(f"PROVISIONAL_SUPPORTED={len(prov_supported)}")
print(f"PROVISIONAL_UNSUPPORTED={len(prov_unsupported)}")
print(f"TOTAL_FILES={len(all_files)}")
print(f"NONCONVERSATION_REMAINDER={len(remainder)}")
PY

TOTAL_PROV="$(grep -c . "$PROVISIONAL_LIST" 2>/dev/null || true)"
LEDGER="$OUT/05_PROVISIONAL_INGEST_LEDGER.tsv"
printf 'index\tstatus\tsha256\toutput_count\tsource\n' > "$LEDGER"

PASS=0
FAIL=0
INDEX=0
FAILED_SOURCE=""

# Ingest only provisional files using the already-proven conversation batch path.
while IFS= read -r SOURCE; do
  [ -n "$SOURCE" ] || continue
  INDEX=$((INDEX + 1))

  if [ ! -f "$SOURCE" ]; then
    printf '%s\tFAIL_MISSING_SOURCE\t-\t0\t%s\n' "$INDEX" "$SOURCE" >> "$LEDGER"
    FAIL=$((FAIL + 1))
    FAILED_SOURCE="$SOURCE"
    break
  fi

  HASH="$(sha256sum "$SOURCE" | awk '{print $1}')"
  RUNLOG="$LOGS/$(printf '%05d' "$INDEX").stdout.txt"
  ERRLOG="$LOGS/$(printf '%05d' "$INDEX").stderr.txt"
  RESULT="$LOGS/$(printf '%05d' "$INDEX").result.txt"

  printf '[%s/%s] %s ... ' "$INDEX" "$TOTAL_PROV" "$(basename "$SOURCE")"

  set +e
  (
    cd "$CURRENT"
    PYTHONPATH="$CURRENT${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" - "$SOURCE" "$RECEIPTS" "$OUTPUT" "$RESULT" <<'PY'
from pathlib import Path
import sys
from workspace.operational.ingestion.service.batch import ingest_sources

source = Path(sys.argv[1])
receipt_root = Path(sys.argv[2])
output_root = Path(sys.argv[3])
result_path = Path(sys.argv[4])

outputs = ingest_sources(
    sources=[source],
    receipt_root=receipt_root,
    output_root=output_root,
    source_class="conversation",
)

result_path.write_text(
    "OUTPUT_COUNT=" + str(len(outputs)) + "\n" +
    "".join(f"OUTPUT={x}\n" for x in outputs),
    encoding="utf-8",
)

print(f"SOURCE={source}")
print(f"OUTPUT_COUNT={len(outputs)}")
for out in outputs:
    print(f"OUTPUT={out}")
PY
  ) > "$RUNLOG" 2> "$ERRLOG"
  RC=$?
  set -e

  OUTPUT_COUNT="$(sed -n 's/^OUTPUT_COUNT=//p' "$RESULT" 2>/dev/null | head -1)"
  OUTPUT_COUNT="${OUTPUT_COUNT:-0}"

  if [ "$RC" -eq 0 ] && [ "$OUTPUT_COUNT" -ge 1 ]; then
    echo "PASS"
    printf '%s\tPASS\t%s\t%s\t%s\n' \
      "$INDEX" "$HASH" "$OUTPUT_COUNT" "$SOURCE" >> "$LEDGER"
    PASS=$((PASS + 1))
  else
    echo "FAIL"
    printf '%s\tFAIL_EXIT_%s\t%s\t%s\t%s\n' \
      "$INDEX" "$RC" "$HASH" "$OUTPUT_COUNT" "$SOURCE" >> "$LEDGER"
    FAIL=$((FAIL + 1))
    FAILED_SOURCE="$SOURCE"
    break
  fi
done < "$PROVISIONAL_LIST"

PACKAGE_COUNT="$(find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
RECEIPT_COUNT="$(find "$RECEIPTS" -maxdepth 1 -type f 2>/dev/null | wc -l)"
UNSUPPORTED_COUNT="$(grep -c . "$UNSUPPORTED_PROVISIONAL" 2>/dev/null || true)"
REMAINDER_COUNT="$(grep -c . "$REMAINDER_LIST" 2>/dev/null || true)"

if [ "$FAIL" -eq 0 ]; then
  STATUS="PASS"
  NEXT="RECOVER_UNIVERSAL_FORMATTER_ARTIFACT_INTAKE_AND_REPOSITORY_OBJECT_CONTRACT_FOR_NONCONVERSATION_REMAINDER"
else
  STATUS="FAIL"
  NEXT="PRESERVE_FAILURE_AND_REPAIR_ONLY_FAILED_PROVISIONAL_SOURCE_EDGE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_PROVISIONAL_AND_REMAINDER_STAGE9
UTC=$TS
STATUS=$STATUS
PROVISIONAL_SUPPORTED_TOTAL=$TOTAL_PROV
PROVISIONAL_PASS=$PASS
PROVISIONAL_FAIL=$FAIL
FAILED_SOURCE=$FAILED_SOURCE
PROVISIONAL_UNSUPPORTED=$UNSUPPORTED_COUNT
NONCONVERSATION_REMAINDER=$REMAINDER_COUNT
PACKAGE_COUNT=$PACKAGE_COUNT
RECEIPT_COUNT=$RECEIPT_COUNT
LIVE_SOURCE_MODIFIED=NO_INTENTIONAL_MUTATION
LIVE_REPOSITORY_OUTPUT_MODIFIED=NO
EVIDENCE=$OUT
NEXT=$NEXT
EOF

echo
cat "$OUT/SUMMARY.txt"
echo
echo "--- remainder by extension (top 30) ---"
head -31 "$REMAINDER_TSV" || true

if [ "$FAIL" -ne 0 ]; then
  echo
  echo "--- failed source stderr tail ---"
  tail -60 "$LOGS/$(printf '%05d' "$INDEX").stderr.txt" 2>/dev/null || true
fi

echo
echo "STAGE9_COMPLETE=YES"

[ "$FAIL" -eq 0 ]
