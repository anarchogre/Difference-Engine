#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
FIRST_CORPUS="$HOME/Difference-Engine-LEGACY-STALE-DECOMPOSED"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_FIRST_CORPUS_DELTA_$TS"

DELTA="$CURRENT/workspace/operational/ingestion/discover_conversation_delta.py"
DOMAINS="$CURRENT/workspace/operational/ingestion/evidence/CONVERSATION_SOURCE_DOMAINS.tsv"

DOMAIN="legacy_stale_decomposed"
ROLE="first_corpus_source"

mkdir -p "$OUT"

echo "=== PAN — FIRST CORPUS DELTA STAGE 6 ==="
echo "CURRENT=$CURRENT"
echo "FIRST_CORPUS=$FIRST_CORPUS"
echo "DOMAIN=$DOMAIN"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$FIRST_CORPUS"; do
  [ -d "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }
[ -f "$DELTA" ] || { echo "BLOCKER: missing $DELTA"; exit 22; }
[ -f "$DOMAINS" ] || { echo "BLOCKER: missing $DOMAINS"; exit 23; }

# Preserve source identities.
sha256sum "$DELTA" "$DOMAINS" > "$OUT/00_SOURCE_HASHES.sha256"

# Build a CANDIDATE domain registry in evidence only.
# Do not modify the live repository registry yet.
CANDIDATE_DOMAINS="$OUT/CONVERSATION_SOURCE_DOMAINS.CANDIDATE.tsv"

"$PYTHON" - "$DOMAINS" "$CANDIDATE_DOMAINS" "$DOMAIN" "$FIRST_CORPUS" "$ROLE" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
domain = sys.argv[3]
path = sys.argv[4]
role = sys.argv[5]

lines = src.read_text(encoding="utf-8").splitlines()

if not lines:
    raise SystemExit("empty domain registry")

header = lines[0].split("\t")
if len(header) != 3:
    raise SystemExit(f"unexpected header: {lines[0]!r}")

records = []
for line in lines[1:]:
    if not line.strip():
        continue
    parts = line.split("\t", 2)
    if len(parts) != 3:
        raise SystemExit(f"malformed registry line: {line!r}")
    records.append(parts)

# Replace only the candidate copy if this domain name already exists.
records = [r for r in records if r[0] != domain]
records.append([domain, path, role])

payload = ["\t".join(header)]
payload.extend("\t".join(r) for r in records)
dst.write_text("\n".join(payload) + "\n", encoding="utf-8")

print(f"CANDIDATE_DOMAIN={domain}")
print(f"CANDIDATE_PATH={path}")
print(f"CANDIDATE_ROLE={role}")
print(f"CANDIDATE_REGISTRY={dst}")
PY

# Run the EXISTING delta implementation unchanged, but inject:
# - candidate domain registry
# - sandboxed output root
# This avoids patching live source code or the live registry.
set +e
"$PYTHON" - "$DELTA" "$CANDIDATE_DOMAINS" "$OUT" "$DOMAIN" \
  > "$OUT/01_DELTA_RUN.txt" 2> "$OUT/01_DELTA_RUN.stderr.txt" <<'PY'
from pathlib import Path
import importlib.util
import sys

delta_path = Path(sys.argv[1])
candidate_domains = Path(sys.argv[2])
outroot = Path(sys.argv[3]) / "delta"
domain = sys.argv[4]

spec = importlib.util.spec_from_file_location("pan_recovered_delta", delta_path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

mod.DOMAINS = candidate_domains
mod.OUTROOT = outroot

old_argv = sys.argv[:]
try:
    sys.argv = [str(delta_path), domain]
    mod.main()
finally:
    sys.argv = old_argv
PY
RC=$?
set -e

LATEST="$OUT/delta/$DOMAIN/LATEST"
JSON_PATH=""
MD_PATH=""

if [ -f "$LATEST" ]; then
  JSON_NAME="$(tr -d '\r\n' < "$LATEST")"
  JSON_PATH="$OUT/delta/$DOMAIN/$JSON_NAME"
  MD_PATH="${JSON_PATH%.json}.md"
fi

if [ "$RC" -eq 0 ] && [ -f "$JSON_PATH" ]; then
  "$PYTHON" - "$JSON_PATH" > "$OUT/02_SUMMARY_EXTRACT.txt" <<'PY'
import json, sys
from pathlib import Path

p = Path(sys.argv[1])
data = json.loads(p.read_text(encoding="utf-8"))
s = data["summary"]

keys = [
    "domain",
    "source",
    "role",
    "files",
    "containers",
    "extraction",
    "conversation_candidates",
    "strong_candidates",
    "provisional_candidates",
    "known_recovery_candidates",
    "known_verified",
    "new_candidates",
    "duplicate_families",
    "duplicate_paths",
]

for k in keys:
    print(f"{k}={s.get(k)}")
PY

  STATUS="PASS"
  NEXT="QUALIFY_NEW_CONVERSATION_CANDIDATES_THROUGH_RECOVERED_INGESTION_PIPELINE"
else
  STATUS="FAIL_EXIT_$RC"
  NEXT="PRESERVE_FAILURE_AND_REPAIR_ONLY_FIRST_CORPUS_DELTA_EDGE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_FIRST_CORPUS_DELTA_STAGE6
UTC=$TS
STATUS=$STATUS
EXIT_CODE=$RC
DOMAIN=$DOMAIN
SOURCE=$FIRST_CORPUS
LIVE_DELTA_SOURCE_MODIFIED=NO
LIVE_DOMAIN_REGISTRY_MODIFIED=NO
CANDIDATE_REGISTRY=$CANDIDATE_DOMAINS
JSON=$JSON_PATH
MARKDOWN=$MD_PATH
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"

if [ -f "$OUT/02_SUMMARY_EXTRACT.txt" ]; then
  echo
  echo "--- first corpus delta summary ---"
  cat "$OUT/02_SUMMARY_EXTRACT.txt"
fi

if [ "$RC" -ne 0 ]; then
  echo
  echo "--- stderr tail ---"
  tail -80 "$OUT/01_DELTA_RUN.stderr.txt" 2>/dev/null || true
fi

echo
echo "STAGE6_COMPLETE=YES"

exit "$RC"
