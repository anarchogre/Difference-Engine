#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
FIRST_CORPUS="$HOME/Difference-Engine-LEGACY-STALE-DECOMPOSED"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
DATE="$(date -u +%Y-%m-%d)"
OUT="$TREE_HOME/PAN_PRESERVE_CLOSURE_AND_RECOVER_NEXT_FRONTIER_$TS-STAGE47"

EVIDENCE_ROOT="$CURRENT/workspace/operational/ingestion/evidence"
CHANGELOG="$CURRENT/CHANGELOG/CHANGELOG.md"
RUN_ALL="$SERVICE/tests/run_all.py"

mkdir -p "$OUT"

echo "=== PAN — PRESERVE CLOSURE + RECOVER NEXT FRONTIER / STAGE 47 ==="
echo "CURRENT=$CURRENT"
echo "FIRST_CORPUS=$FIRST_CORPUS"
echo "EVIDENCE=$OUT"
echo

for x in \
  "$CURRENT" \
  "$FIRST_CORPUS" \
  "$TREE_HOME" \
  "$SERVICE" \
  "$RUN_ALL" \
  "$EVIDENCE_ROOT" \
  "$CHANGELOG"
do
  [ -e "$x" ] || {
    echo "BLOCKER: required recovered path missing: $x"
    exit 20
  }
done
[ -x "$PYTHON" ] || {
  echo "BLOCKER: missing $PYTHON"
  exit 21
}

# -------------------------------------------------------------------
# Recover latest successful Stage46.
# -------------------------------------------------------------------
STAGE46="$(
  "$PYTHON" - "$TREE_HOME" <<'PY'
from pathlib import Path

root = Path(__import__("sys").argv[1])
hits = []
for d in root.iterdir():
    if not d.is_dir():
        continue
    s = d / "SUMMARY.txt"
    if not s.is_file():
        continue
    t = s.read_text(encoding="utf-8", errors="replace")
    if (
        "PAN_VERIFY_FIRST_CORPUS_TEXTLIKE_CLOSURE_STAGE46" in t
        and "STATUS=PASS" in t
        and "FIRST_CORPUS_TEXTLIKE_CLOSURE=PASS" in t
        and "SOURCE_HASHES=PASS_777_OF_777" in t
        and "NEXT=PRESERVE_FIRST_CORPUS_TEXTLIKE_CLOSURE_AND_ADVANCE_TO_NEXT_AUTHORITATIVE_CORPUS_FRONTIER" in t
    ):
        hits.append((d.stat().st_mtime_ns, d))
if hits:
    print(max(hits)[1])
PY
)"

[ -n "$STAGE46" ] && [ -d "$STAGE46" ] || {
  echo "BLOCKER: passing Stage46 evidence not found"
  exit 22
}

CLOSURE_LEDGER="$STAGE46/01_FIRST_CORPUS_777_CLOSURE_LEDGER.tsv"
CLOSURE_COUNTS="$STAGE46/02_CLOSURE_COUNTS.tsv"
CLOSURE_INVARIANTS="$STAGE46/03_CLOSURE_INVARIANTS.txt"
CLOSURE_SUMMARY="$STAGE46/SUMMARY.txt"
CLOSURE_EVENT="$STAGE46/CHANGELOG_EVENT.txt"

for x in \
  "$CLOSURE_LEDGER" \
  "$CLOSURE_COUNTS" \
  "$CLOSURE_INVARIANTS" \
  "$CLOSURE_SUMMARY" \
  "$CLOSURE_EVENT"
do
  [ -f "$x" ] || {
    echo "BLOCKER: incomplete Stage46 closure package: $x"
    exit 23
  }
done

# Explicit invariant gate.
for required in \
  "FIRST_CORPUS_TOTAL=777" \
  "LIVE_CANONICAL=676" \
  "HELD_BACK_TOTAL=101" \
  "CANONICAL_HELD_OVERLAP=0" \
  "UNACCOUNTED=0" \
  "SOURCE_HASHES=PASS_777_OF_777" \
  "FIRST_CORPUS_TEXTLIKE_CLOSURE=PASS"
do
  grep -Fqx "$required" "$CLOSURE_INVARIANTS" || {
    echo "BLOCKER: Stage46 invariant missing: $required"
    exit 24
  }
done

echo "STAGE46=$STAGE46"
echo

# -------------------------------------------------------------------
# Recover authoritative Stage9 rather than reconstructing its classification.
# -------------------------------------------------------------------
STAGE9="$(
  "$PYTHON" - "$TREE_HOME" <<'PY'
from pathlib import Path
import re
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
    if "PAN_PROVISIONAL_AND_REMAINDER_STAGE9" not in t:
        continue
    if "STATUS=PASS" not in t:
        continue
    m = re.search(r"^NONCONVERSATION_REMAINDER=(\d+)\s*$", t, re.M)
    if not m:
        continue
    hits.append((d.stat().st_mtime_ns, d, int(m.group(1))))
if hits:
    _, d, _ = max(hits)
    print(d)
PY
)"

[ -n "$STAGE9" ] && [ -d "$STAGE9" ] || {
  echo "BLOCKER: authoritative passing Stage9 evidence not found"
  exit 25
}

PROV_UNSUPPORTED="$STAGE9/02_PROVISIONAL_UNSUPPORTED.txt"
REMAINDER_BY_EXT="$STAGE9/03_REMAINDER_BY_EXTENSION.tsv"
REMAINDER_ALL="$STAGE9/04_NONCONVERSATION_REMAINDER.txt"

for x in "$PROV_UNSUPPORTED" "$REMAINDER_BY_EXT" "$REMAINDER_ALL"; do
  [ -f "$x" ] || {
    echo "BLOCKER: Stage9 frontier artifact missing: $x"
    exit 26
  }
done

# -------------------------------------------------------------------
# Pre-state and precommit regression.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true
git -C "$CURRENT" status --short --branch > "$OUT/00_GIT_PRE.txt" 2>&1 || true
cp -a "$CHANGELOG" "$OUT/00_CHANGELOG_PRE.md"

if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" "$RUN_ALL"
) > "$OUT/01_PRE_PRESERVATION_REGRESSION.txt" 2>&1
then
  echo "BLOCKER: regression failed before closure preservation"
  tail -80 "$OUT/01_PRE_PRESERVATION_REGRESSION.txt" || true
  exit 27
fi

# -------------------------------------------------------------------
# Create exact repository evidence package. This is a recovered evidence
# namespace; no new top-level architecture is invented.
# -------------------------------------------------------------------
DEST="$EVIDENCE_ROOT/FIRST_CORPUS_TEXTLIKE_CLOSURE_STAGE46"

[ ! -e "$DEST" ] || {
  echo "BLOCKER: closure destination already exists; inspect instead of overwrite"
  echo "DEST=$DEST"
  exit 28
}

mkdir -p "$DEST"

cp -a "$CLOSURE_LEDGER" "$DEST/01_FIRST_CORPUS_777_CLOSURE_LEDGER.tsv"
cp -a "$CLOSURE_COUNTS" "$DEST/02_CLOSURE_COUNTS.tsv"
cp -a "$CLOSURE_INVARIANTS" "$DEST/03_CLOSURE_INVARIANTS.txt"
cp -a "$CLOSURE_SUMMARY" "$DEST/STAGE46_SUMMARY.txt"
cp -a "$CLOSURE_EVENT" "$DEST/STAGE46_CHANGELOG_EVENT.txt"

sha256sum \
  "$DEST/01_FIRST_CORPUS_777_CLOSURE_LEDGER.tsv" \
  "$DEST/02_CLOSURE_COUNTS.tsv" \
  "$DEST/03_CLOSURE_INVARIANTS.txt" \
  "$DEST/STAGE46_SUMMARY.txt" \
  "$DEST/STAGE46_CHANGELOG_EVENT.txt" \
  > "$DEST/SHA256SUMS"

# Verify copies are byte-identical to Stage46.
cmp -s "$CLOSURE_LEDGER" "$DEST/01_FIRST_CORPUS_777_CLOSURE_LEDGER.tsv" || exit 29
cmp -s "$CLOSURE_COUNTS" "$DEST/02_CLOSURE_COUNTS.tsv" || exit 29
cmp -s "$CLOSURE_INVARIANTS" "$DEST/03_CLOSURE_INVARIANTS.txt" || exit 29
cmp -s "$CLOSURE_SUMMARY" "$DEST/STAGE46_SUMMARY.txt" || exit 29
cmp -s "$CLOSURE_EVENT" "$DEST/STAGE46_CHANGELOG_EVENT.txt" || exit 29

# -------------------------------------------------------------------
# Update the recovered repository changelog without requiring the Operator.
# Append factual state only.
# -------------------------------------------------------------------
cat >> "$CHANGELOG" <<EOF

## $DATE — First Corpus Textlike Closure

- Stage 46 closure verified: 777/777 textlike sources accounted.
- Live canonical: 676.
- Explicitly held back: 101.
- Canonical/held overlap: 0.
- Unaccounted: 0.
- Source hashes preserved: 777/777.
- TXT parser representation repair promoted earlier at commit db811fb.
- Closure evidence: workspace/operational/ingestion/evidence/FIRST_CORPUS_TEXTLIKE_CLOSURE_STAGE46/
- Next operation: recover unsupported first-corpus frontier from authoritative Stage9 evidence before changing source estates.
EOF

# -------------------------------------------------------------------
# Recover exact unsupported first-corpus frontier.
# Conversation-bearing provisional unsupported has priority as evidence,
# but Stage47 does NOT select a parser implementation yet.
# -------------------------------------------------------------------
export PAN47_FIRST="$FIRST_CORPUS"
export PAN47_PROV_UNSUPPORTED="$PROV_UNSUPPORTED"
export PAN47_REMAINDER_ALL="$REMAINDER_ALL"
export PAN47_OUT="$OUT"

"$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter
import csv
import hashlib
import os

first = Path(os.environ["PAN47_FIRST"]).resolve()
prov_path = Path(os.environ["PAN47_PROV_UNSUPPORTED"])
remainder_path = Path(os.environ["PAN47_REMAINDER_ALL"])
out = Path(os.environ["PAN47_OUT"])

SUPPORTED_TEXTLIKE = {".txt", ".md", ".json"}

def read_paths(path):
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        p = Path(line).resolve()
        try:
            p.relative_to(first)
        except Exception:
            raise SystemExit(f"BLOCKER: path outside first corpus: {p}")
        if not p.is_file():
            raise SystemExit(f"BLOCKER: Stage9 source missing: {p}")
        rows.append(p)
    return rows

prov = read_paths(prov_path)
remainder = read_paths(remainder_path)

if len(prov) != len(set(map(str, prov))):
    raise SystemExit("BLOCKER: duplicate provisional-unsupported path")
if len(remainder) != len(set(map(str, remainder))):
    raise SystemExit("BLOCKER: duplicate remainder path")

prov_set = set(map(str, prov))
rem_set = set(map(str, remainder))

if prov_set & rem_set:
    raise SystemExit("BLOCKER: provisional unsupported overlaps nonconversation remainder")

unsupported_remainder = [
    p for p in remainder
    if p.suffix.lower() not in SUPPORTED_TEXTLIKE
]

def extension(p):
    return p.suffix.lower() if p.suffix else "[no_ext]"

def hashrow(p):
    return {
        "extension": extension(p),
        "bytes": p.stat().st_size,
        "sha256": hashlib.sha256(p.read_bytes()).hexdigest(),
        "source": str(p),
    }

prov_rows = [hashrow(p) for p in prov]
rem_rows = [hashrow(p) for p in unsupported_remainder]

fields = ["extension", "bytes", "sha256", "source"]

with (out / "02_PROVISIONAL_UNSUPPORTED_LEDGER.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(sorted(prov_rows, key=lambda r: r["source"]))

with (out / "03_NONCONVERSATION_UNSUPPORTED_LEDGER.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(sorted(rem_rows, key=lambda r: r["source"]))

prov_counts = Counter(r["extension"] for r in prov_rows)
rem_counts = Counter(r["extension"] for r in rem_rows)

with (out / "04_UNSUPPORTED_FRONTIER_COUNTS.tsv").open("w", encoding="utf-8") as h:
    h.write("source_class\textension\tcount\tbytes\n")
    for label, rows, counts in (
        ("provisional_conversation_bearing", prov_rows, prov_counts),
        ("nonconversation_remainder", rem_rows, rem_counts),
    ):
        byte_counts = Counter()
        for r in rows:
            byte_counts[r["extension"]] += int(r["bytes"])
        for ext, count in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
            h.write(f"{label}\t{ext}\t{count}\t{byte_counts[ext]}\n")

all_unsupported = prov_rows + rem_rows
all_counts = Counter(r["extension"] for r in all_unsupported)

with (out / "05_ALL_UNSUPPORTED_EXTENSION_COUNTS.tsv").open("w", encoding="utf-8") as h:
    h.write("extension\tcount\tbytes\n")
    byte_counts = Counter()
    for r in all_unsupported:
        byte_counts[r["extension"]] += int(r["bytes"])
    for ext, count in sorted(all_counts.items(), key=lambda kv: (-kv[1], kv[0])):
        h.write(f"{ext}\t{count}\t{byte_counts[ext]}\n")

# Candidate ordering: conversation-bearing unsupported first.
if prov_rows:
    pcounts = Counter(r["extension"] for r in prov_rows)
    next_ext, next_count = sorted(
        pcounts.items(),
        key=lambda kv: (-kv[1], kv[0]),
    )[0]
    next_reason = "PROVISIONAL_CONVERSATION_BEARING_UNSUPPORTED_FIRST"
elif rem_rows:
    rcounts = Counter(r["extension"] for r in rem_rows)
    next_ext, next_count = sorted(
        rcounts.items(),
        key=lambda kv: (-kv[1], kv[0]),
    )[0]
    next_reason = "NONCONVERSATION_UNSUPPORTED_REMAINDER"
else:
    next_ext, next_count = "", 0
    next_reason = "FIRST_CORPUS_STAGE9_UNSUPPORTED_EXHAUSTED"

with (out / "06_FRONTIER_DECISION.txt").open("w", encoding="utf-8") as h:
    h.write(f"PROVISIONAL_UNSUPPORTED={len(prov_rows)}\n")
    h.write(f"NONCONVERSATION_UNSUPPORTED={len(rem_rows)}\n")
    h.write(f"TOTAL_UNSUPPORTED_FRONTIER={len(all_unsupported)}\n")
    h.write(f"NEXT_REASON={next_reason}\n")
    if next_ext:
        h.write(f"NEXT_EXTENSION={next_ext}\n")
        h.write(f"NEXT_EXTENSION_COUNT={next_count}\n")
        h.write(
            "CANDIDATE_NEXT="
            f"RECOVER_EXISTING_{next_ext.lstrip('.').upper()}_INGESTION_CAPABILITY_"
            "AND_QUALIFY_EXACT_UNSUPPORTED_FRONTIER_BEFORE_IMPLEMENTATION\n"
        )
    else:
        h.write("CANDIDATE_NEXT=ADVANCE_TO_NEXT_REGISTERED_SOURCE_ESTATE\n")

print(f"PROVISIONAL_UNSUPPORTED={len(prov_rows)}")
print(f"NONCONVERSATION_UNSUPPORTED={len(rem_rows)}")
print(f"TOTAL_UNSUPPORTED_FRONTIER={len(all_unsupported)}")
print("--- frontier counts ---")
print((out / "04_UNSUPPORTED_FRONTIER_COUNTS.tsv").read_text(encoding="utf-8"), end="")
print("--- frontier decision ---")
print((out / "06_FRONTIER_DECISION.txt").read_text(encoding="utf-8"), end="")
PY

# -------------------------------------------------------------------
# Recover existing capability clues for unsupported formats, without redesign.
# -------------------------------------------------------------------
{
  echo "===== EXISTING INGESTION / RECOVERY CAPABILITY CLUES ====="
  find "$CURRENT/workspace/operational/ingestion" -xdev \
    \( -type f -o -type d \) \
    \( -iname '*pdf*' \
       -o -iname '*docx*' \
       -o -iname '*zip*' \
       -o -iname '*office*' \
       -o -iname '*document*' \
       -o -iname '*semantic*qualification*' \) \
    -print 2>/dev/null | sort

  echo
  echo "===== SERVICE REGISTRY / PARSER REFERENCES ====="
  grep -R -n -E \
    '\.pdf|\.docx|\.zip|pdf|docx|zip|office|extract' \
    "$CURRENT/workspace/operational/ingestion" \
    --include='*.py' \
    --include='*.md' \
    --include='*.json' \
    --exclude-dir='output' \
    --exclude-dir='test_output' \
    2>/dev/null | head -3000 || true
} > "$OUT/07_EXISTING_UNSUPPORTED_CAPABILITY_CLUES.txt"

# -------------------------------------------------------------------
# Stage and commit only closure evidence + changelog.
# Frontier evidence remains operational Stage47 evidence, not canonical claim.
# -------------------------------------------------------------------
git -C "$CURRENT" reset --quiet

REL_DEST="workspace/operational/ingestion/evidence/FIRST_CORPUS_TEXTLIKE_CLOSURE_STAGE46"
REL_CHANGELOG="CHANGELOG/CHANGELOG.md"

git -C "$CURRENT" add -- "$REL_DEST" "$REL_CHANGELOG"

git -C "$CURRENT" diff --cached --name-only | sort > "$OUT/08_STAGED_PATHS.txt"
git -C "$CURRENT" diff --cached > "$OUT/08_STAGED_DIFF.patch"

# Require all staged paths to be under exact allowed surfaces.
if grep -Ev \
  "^(workspace/operational/ingestion/evidence/FIRST_CORPUS_TEXTLIKE_CLOSURE_STAGE46/|CHANGELOG/CHANGELOG\.md$)" \
  "$OUT/08_STAGED_PATHS.txt" \
  | grep -q .
then
  echo "BLOCKER: unexpected staged path"
  cat "$OUT/08_STAGED_PATHS.txt"
  git -C "$CURRENT" reset --quiet
  cp -a "$OUT/00_CHANGELOG_PRE.md" "$CHANGELOG"
  rm -rf "$DEST"
  exit 30
fi

COMMIT_MESSAGE="ingestion: preserve first textlike corpus closure"

if ! git -C "$CURRENT" commit -m "$COMMIT_MESSAGE" > "$OUT/09_COMMIT.txt" 2>&1; then
  echo "BLOCKER: closure preservation commit failed"
  cat "$OUT/09_COMMIT.txt" || true
  git -C "$CURRENT" reset --quiet
  cp -a "$OUT/00_CHANGELOG_PRE.md" "$CHANGELOG"
  rm -rf "$DEST"
  exit 31
fi

COMMIT="$(git -C "$CURRENT" rev-parse HEAD)"
git -C "$CURRENT" show --stat --oneline --decorate "$COMMIT" > "$OUT/10_COMMIT_SHOW.txt"

# -------------------------------------------------------------------
# Postcommit regression.
# -------------------------------------------------------------------
if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" "$RUN_ALL"
) > "$OUT/11_POSTCOMMIT_REGRESSION.txt" 2>&1
then
  cat > "$OUT/SUMMARY.txt" <<EOF
PAN_PRESERVE_CLOSURE_AND_RECOVER_NEXT_FRONTIER_STAGE47
UTC=$TS
STATUS=FAIL_POSTCOMMIT_REGRESSION
STAGE46=$STAGE46
STAGE9=$STAGE9
COMMIT=$COMMIT
COMMIT_CREATED=YES
POSTCOMMIT_REGRESSION=FAIL
EVIDENCE=$OUT
NEXT=REVERT_ONLY_STAGE47_COMMIT_AND_PRESERVE_FAILURE_EVIDENCE
EOF
  cat "$OUT/SUMMARY.txt"
  tail -80 "$OUT/11_POSTCOMMIT_REGRESSION.txt" || true
  exit 32
fi

NEXT="$(sed -n 's/^CANDIDATE_NEXT=//p' "$OUT/06_FRONTIER_DECISION.txt" | head -1)"
PROV_COUNT="$(sed -n 's/^PROVISIONAL_UNSUPPORTED=//p' "$OUT/06_FRONTIER_DECISION.txt" | head -1)"
REM_COUNT="$(sed -n 's/^NONCONVERSATION_UNSUPPORTED=//p' "$OUT/06_FRONTIER_DECISION.txt" | head -1)"
TOTAL_UNSUPPORTED="$(sed -n 's/^TOTAL_UNSUPPORTED_FRONTIER=//p' "$OUT/06_FRONTIER_DECISION.txt" | head -1)"
NEXT_EXT="$(sed -n 's/^NEXT_EXTENSION=//p' "$OUT/06_FRONTIER_DECISION.txt" | head -1)"
NEXT_EXT_COUNT="$(sed -n 's/^NEXT_EXTENSION_COUNT=//p' "$OUT/06_FRONTIER_DECISION.txt" | head -1)"

cat > "$OUT/CHANGELOG_EVENT.txt" <<EOF
UTC=$TS
EVENT=FIRST_CORPUS_TEXTLIKE_CLOSURE_PRESERVED_AND_UNSUPPORTED_FRONTIER_RECOVERED
CLASSIFICATION=PROMOTED_CLOSURE_EVIDENCE_PLUS_OBSERVED_FRONTIER
STAGE46=$STAGE46
CLOSURE_COMMIT=$COMMIT
FIRST_CORPUS_TEXTLIKE_TOTAL=777
LIVE_CANONICAL=676
HELD_BACK=101
PROVISIONAL_UNSUPPORTED=$PROV_COUNT
NONCONVERSATION_UNSUPPORTED=$REM_COUNT
TOTAL_UNSUPPORTED_FRONTIER=$TOTAL_UNSUPPORTED
NEXT_EXTENSION=$NEXT_EXT
NEXT_EXTENSION_COUNT=$NEXT_EXT_COUNT
EOF

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_PRESERVE_CLOSURE_AND_RECOVER_NEXT_FRONTIER_STAGE47
UTC=$TS
STATUS=PASS
STAGE46=$STAGE46
STAGE9=$STAGE9
CLOSURE_PRESERVED_IN_REPOSITORY=YES
CHANGELOG_UPDATED=YES
COMMIT=$COMMIT
COMMIT_MESSAGE=$COMMIT_MESSAGE
PRE_PRESERVATION_REGRESSION=PASS
POSTCOMMIT_REGRESSION=PASS
PROVISIONAL_UNSUPPORTED=$PROV_COUNT
NONCONVERSATION_UNSUPPORTED=$REM_COUNT
TOTAL_UNSUPPORTED_FRONTIER=$TOTAL_UNSUPPORTED
NEXT_EXTENSION=$NEXT_EXT
NEXT_EXTENSION_COUNT=$NEXT_EXT_COUNT
SOURCE_MUTATION=NONE
COMMIT_CREATED=YES
EVIDENCE=$OUT
REPOSITORY_CLOSURE_PACKAGE=$DEST
PROVISIONAL_UNSUPPORTED_LEDGER=$OUT/02_PROVISIONAL_UNSUPPORTED_LEDGER.tsv
NONCONVERSATION_UNSUPPORTED_LEDGER=$OUT/03_NONCONVERSATION_UNSUPPORTED_LEDGER.tsv
FRONTIER_COUNTS=$OUT/04_UNSUPPORTED_FRONTIER_COUNTS.tsv
CAPABILITY_CLUES=$OUT/07_EXISTING_UNSUPPORTED_CAPABILITY_CLUES.txt
CHANGELOG_EVENT=$OUT/CHANGELOG_EVENT.txt
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- commit ---"
cat "$OUT/10_COMMIT_SHOW.txt"
echo
echo "--- unsupported frontier ---"
cat "$OUT/04_UNSUPPORTED_FRONTIER_COUNTS.tsv"
echo
echo "--- decision ---"
cat "$OUT/06_FRONTIER_DECISION.txt"
echo
echo "--- postcommit regression tail ---"
tail -40 "$OUT/11_POSTCOMMIT_REGRESSION.txt"
echo
echo "STAGE47_COMPLETE=YES"
