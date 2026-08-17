#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_TEST_LEVEL_GENERIC_VALIDATION_$TS-STAGE21"

SERVICE="$CURRENT/workspace/operational/ingestion/service"
TESTS="$SERVICE/tests"
VALIDATION="$SERVICE/validation.py"
PIPELINE="$SERVICE/pipeline.py"

mkdir -p "$OUT/git-tests"

echo "=== PAN — TEST-LEVEL GENERIC VALIDATION RECOVERY STAGE 21 ==="
echo "CURRENT=$CURRENT"
echo "SERVICE=$SERVICE"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$SERVICE" "$TESTS" "$VALIDATION" "$PIPELINE"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST20="$(
  find "$TREE_HOME" -maxdepth 1 -type d \
    -name 'PAN_GENERIC_VALIDATION_CONTRACT_*-STAGE20' \
    -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | head -1 | cut -d' ' -f2-
)"
[ -n "$LATEST20" ] && [ -d "$LATEST20" ] || {
  echo "BLOCKER: Stage 20 evidence not found"
  exit 22
}

# Require the exact Stage 20 decision before proceeding.
DECISION20="$(sed -n 's/^DECISION=//p' "$LATEST20/SUMMARY.txt" | head -1)"
if [ "$DECISION20" != "PASSING_OUTPUT_CONTRACT_RECOVERED_ONLY" ]; then
  echo "BLOCKER: Stage 20 decision drift: $DECISION20"
  exit 23
fi

sha256sum "$VALIDATION" "$PIPELINE" > "$OUT/00_ACTIVE_HASHES.sha256"

# -------------------------------------------------------------------
# 1. Current validation call contract.
# -------------------------------------------------------------------
{
  echo "===== ACTIVE validation.py ====="
  sed -n '1,420p' "$VALIDATION"
  echo
  echo "===== ACTIVE pipeline.py validation context ====="
  grep -n -C 30 -E 'validate|validation' "$PIPELINE" || true
} > "$OUT/01_ACTIVE_VALIDATION_CONTRACT.txt"

# -------------------------------------------------------------------
# 2. Active tests: exact assertions around validation and generic classes.
# -------------------------------------------------------------------
{
  echo "=== ACTIVE TEST ASSERTIONS ==="
  grep -RInE \
    'assert .*passed|assert .*errors|validation|validate\(|source_class|manual_batch|manual|file_library_upload|kind.*markdown|kind.*conversation|assets|turns' \
    "$TESTS" \
    --include='*.py' \
    2>/dev/null | head -6000 || true
} > "$OUT/02_ACTIVE_TEST_ASSERTIONS.txt"

# Preserve all active tests for provenance.
find "$TESTS" -maxdepth 2 -type f -name '*.py' -print 2>/dev/null | sort \
  > "$OUT/03_ACTIVE_TEST_FILES.txt"

# -------------------------------------------------------------------
# 3. Retired/recovery tests: look only for concrete validation expectations.
# -------------------------------------------------------------------
{
  echo "=== RETIRED/RECOVERY TEST ASSERTIONS ==="
  grep -RInE \
    'assert .*passed|assert .*errors|validation|validate\(|source_class|manual_batch|manual|file_library_upload|kind.*markdown|kind.*conversation|assets|turns' \
    "$CURRENT/workspace/operational/ingestion/recovery" \
    --include='test_*.py' --include='*_test.py' --include='*.md' --include='*.txt' \
    2>/dev/null | head -10000 || true
} > "$OUT/04_RETIRED_TEST_ASSERTIONS.txt"

# -------------------------------------------------------------------
# 4. Recover test files from Git history.
#    We search the current test paths and any historical test path under the service.
# -------------------------------------------------------------------
if git -C "$CURRENT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$CURRENT" log --all --name-only --pretty=format: -- \
    'workspace/operational/ingestion/service/tests/*.py' \
    'workspace/operational/ingestion/**/test_*.py' \
    2>/dev/null \
    | sed '/^$/d' | sort -u > "$OUT/05_HISTORICAL_TEST_PATHS.txt"

  "$PYTHON" - "$CURRENT" "$OUT/05_HISTORICAL_TEST_PATHS.txt" "$OUT/git-tests" \
    > "$OUT/06_GIT_TEST_VARIANTS.tsv" <<'PY'
from pathlib import Path
import hashlib, subprocess, sys

repo = Path(sys.argv[1])
paths_file = Path(sys.argv[2])
dest = Path(sys.argv[3])

seen = set()
print("commit\tsha256\tpath\tcopy")

paths = [x.strip() for x in paths_file.read_text(encoding="utf-8", errors="replace").splitlines() if x.strip()]

for rel in paths:
    cp = subprocess.run(
        ["git", "-C", str(repo), "log", "--all", "--format=%H", "--", rel],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    commits = []
    for c in cp.stdout.splitlines():
        c = c.strip()
        if c and c not in commits:
            commits.append(c)

    for commit in commits:
        show = subprocess.run(
            ["git", "-C", str(repo), "show", f"{commit}:{rel}"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        if show.returncode != 0:
            continue
        data = show.stdout
        h = hashlib.sha256(data).hexdigest()
        key = (h, rel)
        name = ""
        if key not in seen:
            safe = rel.replace("/", "__")
            name = f"{h[:16]}__{safe}"
            (dest / name).write_bytes(data)
            seen.add(key)
        print(f"{commit}\t{h}\t{rel}\t{name}")
PY
else
  : > "$OUT/05_HISTORICAL_TEST_PATHS.txt"
  printf 'commit\tsha256\tpath\tcopy\n' > "$OUT/06_GIT_TEST_VARIANTS.tsv"
fi

# -------------------------------------------------------------------
# 5. Classify historical test variants for concrete generic-validation rules.
# -------------------------------------------------------------------
"$PYTHON" - "$OUT/git-tests" > "$OUT/07_GIT_TEST_RULES.tsv" <<'PY'
from pathlib import Path
import ast, hashlib, sys

root = Path(sys.argv[1])
print("sha256\tfile\tmanual_batch\tmanual\tfile_library_upload\tvalidation_assert\tmarkdown_assert\tconversation_assert\trules")

for p in sorted(root.iterdir()):
    if not p.is_file():
        continue
    text = p.read_text(encoding="utf-8", errors="replace")
    low = text.lower()
    h = hashlib.sha256(p.read_bytes()).hexdigest()

    rules = []
    try:
        tree = ast.parse(text, filename=str(p))
        for node in ast.walk(tree):
            if isinstance(node, ast.Assert):
                try:
                    s = ast.unparse(node.test)
                except Exception:
                    continue
                slow = s.lower()
                if any(k in slow for k in ("passed", "errors", "validation", "kind", "source_class", "assets", "turns")):
                    rules.append(s)
    except Exception:
        pass

    print(
        f"{h}\t{p.name}\t"
        f"{'manual_batch' in low}\t"
        f"{'manual' in low}\t"
        f"{'file_library_upload' in low}\t"
        f"{any('passed' in r.lower() or 'errors' in r.lower() for r in rules)}\t"
        f"{any('markdown' in r.lower() for r in rules)}\t"
        f"{any('conversation' in r.lower() for r in rules)}\t"
        + " || ".join(rules[:40])
    )
PY

# -------------------------------------------------------------------
# 6. Recover exact passing package invariants from Stage 20 samples.
# -------------------------------------------------------------------
cp -a "$LATEST20/08_SAMPLE_CONTRACT_SUMMARY.txt" "$OUT/08_PASSING_PACKAGE_CONTRACT.txt"

"$PYTHON" - "$LATEST20" > "$OUT/09_PASSING_PACKAGE_INVARIANTS.txt" <<'PY'
from pathlib import Path
import json, sys

root = Path(sys.argv[1])

for d in sorted(root.glob("07_SAMPLE_*")):
    print(f"===== {d.name} =====")
    docs = {}
    for p in d.glob("*.json"):
        try:
            docs[p.name] = json.loads(p.read_text(encoding="utf-8"))
        except Exception:
            continue

    receipt = next((v for k,v in docs.items() if "receipt" in k.lower()), {})
    parsed = next((v for k,v in docs.items() if "parsed" in k.lower()), {})
    assets = next((v for k,v in docs.items() if "assets" in k.lower()), {})
    refs = next((v for k,v in docs.items() if "references" in k.lower()), {})
    manifest = next((v for k,v in docs.items() if "manifest" in k.lower()), {})
    validation = next((v for k,v in docs.items() if "validation" in k.lower()), {})

    print("source_class=" + repr(receipt.get("source_class")))
    print("parsed.kind=" + repr(parsed.get("kind")))
    print("manifest.kind=" + repr(manifest.get("kind")))
    print("validation.passed=" + repr(validation.get("passed")))
    print("validation.errors=" + repr(validation.get("errors")))

    if isinstance(assets, dict):
        print("assets.keys=" + repr(sorted(assets.keys())))
    if isinstance(refs, dict):
        print("references.keys=" + repr(sorted(refs.keys())))
    print()
PY

# -------------------------------------------------------------------
# 7. Decision: only promote a rule if an explicit historical/current test asserts it.
# -------------------------------------------------------------------
DECISION="$(
"$PYTHON" - \
  "$OUT/02_ACTIVE_TEST_ASSERTIONS.txt" \
  "$OUT/04_RETIRED_TEST_ASSERTIONS.txt" \
  "$OUT/07_GIT_TEST_RULES.tsv" \
  "$OUT/09_PASSING_PACKAGE_INVARIANTS.txt" <<'PY'
from pathlib import Path
import re, sys

active = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace").lower()
retired = Path(sys.argv[2]).read_text(encoding="utf-8", errors="replace").lower()
git_rules = Path(sys.argv[3]).read_text(encoding="utf-8", errors="replace").lower()
inv = Path(sys.argv[4]).read_text(encoding="utf-8", errors="replace").lower()

tests_blob = active + "\n" + retired + "\n" + git_rules

generic_class_test = any(x in tests_blob for x in (
    "manual_batch",
    "file_library_upload",
    "source_class",
))
validation_test = any(x in tests_blob for x in (
    "passed",
    "errors",
    "validation",
))
markdown_test = "markdown" in tests_blob

manual_batch_contract = (
    "source_class='manual_batch'" in inv
    and "manifest.kind='markdown'" in inv
    and "validation.passed=true" in inv
)

print(f"GENERIC_CLASS_TEST_EVIDENCE={generic_class_test}", file=sys.stderr)
print(f"VALIDATION_TEST_EVIDENCE={validation_test}", file=sys.stderr)
print(f"MARKDOWN_TEST_EVIDENCE={markdown_test}", file=sys.stderr)
print(f"MANUAL_BATCH_PASS_CONTRACT={manual_batch_contract}", file=sys.stderr)

if generic_class_test and validation_test and markdown_test and manual_batch_contract:
    print("TEST_LEVEL_GENERIC_VALIDATION_RULES_RECOVERED")
elif manual_batch_contract and validation_test:
    print("PARTIAL_TEST_RULES_PLUS_PASSING_OUTPUT_CONTRACT")
elif manual_batch_contract:
    print("PASSING_OUTPUT_CONTRACT_ONLY_NO_TEST_RULES")
else:
    print("GENERIC_VALIDATION_RULES_NOT_RECOVERED")
PY
  2> "$OUT/10_DECISION_EVIDENCE.txt"
)"

case "$DECISION" in
  TEST_LEVEL_GENERIC_VALIDATION_RULES_RECOVERED)
    NEXT="IMPLEMENT_MINIMAL_SOURCE_CLASS_AWARE_GENERIC_VALIDATION_WITH_ROLLBACK_AND_REPLAY_MANUAL_BATCH_MARKDOWN_BEFORE_JSON"
    ;;
  PARTIAL_TEST_RULES_PLUS_PASSING_OUTPUT_CONTRACT)
    NEXT="EXTRACT_EXACT_TEST_ASSERTIONS_AND_DEFINE_ONLY_SHARED_INVARIANTS_BEFORE_IMPLEMENTATION"
    ;;
  PASSING_OUTPUT_CONTRACT_ONLY_NO_TEST_RULES)
    NEXT="STOP_NO_TEST_LEVEL_AUTHORITY_FOR_VALIDATOR_RECONSTRUCTION"
    ;;
  *)
    NEXT="STOP_GENERIC_VALIDATION_CONTRACT_NOT_RECOVERED"
    ;;
esac

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_TEST_LEVEL_GENERIC_VALIDATION_STAGE21
UTC=$TS
DECISION=$DECISION
SOURCE_MUTATION=NONE
INGESTION_EXECUTED=NO
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- decision evidence ---"
cat "$OUT/10_DECISION_EVIDENCE.txt"
echo
echo "--- passing package invariants ---"
cat "$OUT/09_PASSING_PACKAGE_INVARIANTS.txt"
echo
echo "STAGE21_COMPLETE=YES"
