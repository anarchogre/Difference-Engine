#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_GENERIC_VALIDATION_CONTRACT_$TS-STAGE20"

SERVICE="$CURRENT/workspace/operational/ingestion/service"
VALIDATION="$SERVICE/validation.py"
PIPELINE="$SERVICE/pipeline.py"
TESTS="$SERVICE/tests"

mkdir -p "$OUT/git-variants"

echo "=== PAN — GENERIC VALIDATION CONTRACT RECOVERY STAGE 20 ==="
echo "CURRENT=$CURRENT"
echo "VALIDATION=$VALIDATION"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$SERVICE" "$VALIDATION" "$PIPELINE" "$TESTS"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST19="$(
  find "$TREE_HOME" -maxdepth 1 -type d \
    -name 'PAN_HISTORICAL_GENERIC_VALIDATOR_*-STAGE19' \
    -printf '%T@ %p\n' 2>/dev/null \
  | sort -nr | head -1 | cut -d' ' -f2-
)"
[ -n "$LATEST19" ] && [ -d "$LATEST19" ] || {
  echo "BLOCKER: Stage 19 evidence not found"
  exit 22
}

# -------------------------------------------------------------------
# 1. Preserve active state and exact call contract.
# -------------------------------------------------------------------
sha256sum "$VALIDATION" "$PIPELINE" > "$OUT/00_ACTIVE_HASHES.sha256"

{
  echo "===== ACTIVE validation.py ====="
  sed -n '1,420p' "$VALIDATION"
  echo
  echo "===== ACTIVE pipeline.py validation call context ====="
  grep -n -C 20 -E 'validate|validation' "$PIPELINE" || true
} > "$OUT/01_ACTIVE_CONTRACT.txt"

# -------------------------------------------------------------------
# 2. Recover validation.py from Git history if available.
#    This is the highest-value recovery path because filesystem copies may
#    all reflect the same current/recovered state.
# -------------------------------------------------------------------
REL="${VALIDATION#"$CURRENT"/}"

if git -C "$CURRENT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  {
    echo "=== LOG --follow ==="
    git -C "$CURRENT" log --all --follow \
      --date=iso-strict \
      --format='%H%x09%ad%x09%an%x09%s' \
      -- "$REL" || true

    echo
    echo "=== PICKAXE manual_batch ==="
    git -C "$CURRENT" log --all -S'manual_batch' \
      --date=iso-strict \
      --format='%H%x09%ad%x09%an%x09%s' \
      -- "$REL" || true

    echo
    echo "=== PICKAXE source_class ==="
    git -C "$CURRENT" log --all -S'source_class' \
      --date=iso-strict \
      --format='%H%x09%ad%x09%an%x09%s' \
      -- "$REL" || true

    echo
    echo "=== PICKAXE invalid conversation kind ==="
    git -C "$CURRENT" log --all -S'invalid conversation kind' \
      --date=iso-strict \
      --format='%H%x09%ad%x09%an%x09%s' \
      -- "$REL" || true
  } > "$OUT/02_GIT_HISTORY.txt"

  git -C "$CURRENT" log --all --follow --format='%H' -- "$REL" \
    | awk 'NF && !seen[$0]++' > "$OUT/03_VALIDATION_COMMITS.txt"

  "$PYTHON" - "$CURRENT" "$REL" "$OUT/03_VALIDATION_COMMITS.txt" "$OUT/git-variants" \
    > "$OUT/04_GIT_VARIANTS.tsv" <<'PY'
from pathlib import Path
import hashlib, subprocess, sys

repo = Path(sys.argv[1])
rel = sys.argv[2]
commits = Path(sys.argv[3])
dest = Path(sys.argv[4])

seen = {}
print("commit\tsha256\tbytes\tfile")

for commit in commits.read_text(encoding="utf-8", errors="replace").splitlines():
    commit = commit.strip()
    if not commit:
        continue
    cp = subprocess.run(
        ["git", "-C", str(repo), "show", f"{commit}:{rel}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if cp.returncode != 0:
        continue
    data = cp.stdout
    h = hashlib.sha256(data).hexdigest()
    name = ""
    if h not in seen:
        name = f"validation-{h[:16]}.py"
        (dest / name).write_bytes(data)
        seen[h] = commit
    else:
        name = f"[same-as-{seen[h][:12]}]"
    print(f"{commit}\t{h}\t{len(data)}\t{name}")
PY
else
  echo "GIT_HISTORY=UNAVAILABLE" > "$OUT/02_GIT_HISTORY.txt"
  : > "$OUT/03_VALIDATION_COMMITS.txt"
  printf 'commit\tsha256\tbytes\tfile\n' > "$OUT/04_GIT_VARIANTS.tsv"
fi

# -------------------------------------------------------------------
# 3. Classify every recovered Git validator variant.
# -------------------------------------------------------------------
"$PYTHON" - "$OUT/git-variants" > "$OUT/05_GIT_VARIANT_CLASSIFICATION.tsv" <<'PY'
from pathlib import Path
import ast, hashlib, sys

root = Path(sys.argv[1])

print("sha256\tfile\tconversation_hardcoded\tsource_class_aware\tmanual_batch_aware\tmarkdown_aware\tgeneric_branch\tfunctions")

for p in sorted(root.glob("validation-*.py")):
    text = p.read_text(encoding="utf-8", errors="replace")
    low = text.lower()
    h = hashlib.sha256(p.read_bytes()).hexdigest()

    try:
        tree = ast.parse(text, filename=str(p))
        funcs = sorted({
            n.name for n in ast.walk(tree)
            if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))
        })
    except Exception:
        funcs = []

    conversation = (
        "invalid conversation kind" in low
        or "no conversation turns" in low
    )
    source_class = "source_class" in low
    manual_batch = "manual_batch" in low
    markdown = "markdown" in low
    generic = (
        ("source_class" in low and ("manual" in low or "file_library_upload" in low))
        or ("kind" in low and "markdown" in low and not conversation)
    )

    print(
        f"{h}\t{p.name}\t{conversation}\t{source_class}\t"
        f"{manual_batch}\t{markdown}\t{generic}\t{','.join(funcs)}"
    )
PY

# -------------------------------------------------------------------
# 4. Recover exact active tests/spec references. No broad architecture search.
# -------------------------------------------------------------------
{
  echo "=== ACTIVE VALIDATION TESTS / EXPECTATIONS ==="
  grep -RInE \
    'validate|validation|passed|errors|manual_batch|manual|file_library_upload|source_class|markdown|conversation|kind|assets|turns' \
    "$TESTS" \
    --include='*.py' \
    2>/dev/null | head -5000 || true

  echo
  echo "=== NEARBY INGESTION CONTRACT REFERENCES ==="
  grep -RInE \
    'manual_batch|file_library_upload|source_class|validation|markdown|artifact|kind' \
    "$CURRENT/workspace/operational/ingestion" \
    --include='*.md' --include='*.txt' --include='*.py' \
    2>/dev/null \
    | grep -v '/recovery/retired_packages/' \
    | head -5000 || true
} > "$OUT/06_TEST_AND_SPEC_REFERENCES.txt"

# -------------------------------------------------------------------
# 5. Recover one historical PASS package for manual_batch and one
#    conversation PASS package. These are surviving behavioral contracts.
# -------------------------------------------------------------------
"$PYTHON" - "$CURRENT/workspace/operational/ingestion" "$OUT" <<'PY'
from pathlib import Path
import json, shutil, sys

root = Path(sys.argv[1])
out = Path(sys.argv[2])

targets = {
    "manual_batch": None,
    "conversation": None,
}

for receipt in sorted(root.rglob("metadata/receipt.json")):
    if "/recovery/retired_packages/" in str(receipt):
        continue
    pkg = receipt.parent.parent
    validation = pkg / "reports/validation.json"
    manifest = pkg / "reports/manifest.json"
    parsed = pkg / "structure/parsed.json"

    if not (validation.is_file() and manifest.is_file() and parsed.is_file()):
        continue

    try:
        r = json.loads(receipt.read_text(encoding="utf-8"))
        v = json.loads(validation.read_text(encoding="utf-8"))
    except Exception:
        continue

    cls = r.get("source_class")
    if cls not in targets or targets[cls] is not None:
        continue
    if v.get("passed") is not True:
        continue

    targets[cls] = pkg

for cls, pkg in targets.items():
    if pkg is None:
        continue
    dest = out / f"07_SAMPLE_{cls.upper()}"
    dest.mkdir(parents=True, exist_ok=True)

    for rel in (
        "metadata/receipt.json",
        "structure/parsed.json",
        "structure/assets.json",
        "structure/references.json",
        "reports/manifest.json",
        "reports/validation.json",
        "provenance/provenance.json",
    ):
        src = pkg / rel
        if src.is_file():
            d = dest / rel.replace("/", "__")
            shutil.copy2(src, d)

    (dest / "PACKAGE_PATH.txt").write_text(str(pkg) + "\n", encoding="utf-8")
PY

# Summarize the two package contracts compactly.
"$PYTHON" - "$OUT" > "$OUT/08_SAMPLE_CONTRACT_SUMMARY.txt" <<'PY'
from pathlib import Path
import json, sys

root = Path(sys.argv[1])

for d in sorted(root.glob("07_SAMPLE_*")):
    print(f"===== {d.name} =====")
    for p in sorted(d.glob("*.json")):
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
        except Exception:
            continue
        print(p.name)
        if isinstance(data, dict):
            for k in (
                "source_class", "kind", "passed", "errors", "turns",
                "assets", "references", "artifact_type"
            ):
                if k in data:
                    v = data[k]
                    if isinstance(v, list):
                        print(f"  {k}: list[{len(v)}]")
                    else:
                        print(f"  {k}: {v!r}")
        print()
PY

# -------------------------------------------------------------------
# 6. Decision.
# -------------------------------------------------------------------
DECISION="$(
"$PYTHON" - \
  "$OUT/05_GIT_VARIANT_CLASSIFICATION.tsv" \
  "$OUT/06_TEST_AND_SPEC_REFERENCES.txt" \
  "$OUT/08_SAMPLE_CONTRACT_SUMMARY.txt" <<'PY'
from pathlib import Path
import re, sys

variants = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
refs = Path(sys.argv[2]).read_text(encoding="utf-8", errors="replace").lower()
samples = Path(sys.argv[3]).read_text(encoding="utf-8", errors="replace").lower()

recoverable = False
for line in variants.splitlines()[1:]:
    parts = line.split("\t")
    if len(parts) >= 7 and parts[6] == "True":
        recoverable = True
        break

manual_batch_pass_contract = (
    "sample_manual_batch" in samples
    and "passed: true" in samples
)

explicit_refs = (
    "manual_batch" in refs
    and "validation" in refs
)

if recoverable:
    print("GIT_HISTORICAL_GENERIC_VALIDATOR_RECOVERED")
elif manual_batch_pass_contract and explicit_refs:
    print("BEHAVIORAL_CONTRACT_RECOVERED_NO_CODE_VARIANT")
elif manual_batch_pass_contract:
    print("PASSING_OUTPUT_CONTRACT_RECOVERED_ONLY")
else:
    print("GENERIC_VALIDATION_CONTRACT_STILL_INCOMPLETE")
PY
)"

case "$DECISION" in
  GIT_HISTORICAL_GENERIC_VALIDATOR_RECOVERED)
    NEXT="SELECT_AND_REPLAY_EXACT_GIT_VALIDATOR_VARIANT_IN_SANDBOX_BEFORE_PROMOTION"
    ;;
  BEHAVIORAL_CONTRACT_RECOVERED_NO_CODE_VARIANT)
    NEXT="IMPLEMENT_MINIMAL_SOURCE_CLASS_AWARE_VALIDATOR_FROM_PROVEN_MANUAL_BATCH_OUTPUT_CONTRACT_WITH_ROLLBACK"
    ;;
  PASSING_OUTPUT_CONTRACT_RECOVERED_ONLY)
    NEXT="RECOVER_TEST_LEVEL_GENERIC_VALIDATION_RULES_BEFORE_IMPLEMENTATION"
    ;;
  *)
    NEXT="STOP_AND_REVIEW_EVIDENCE_NO_IMPLEMENTATION"
    ;;
esac

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_GENERIC_VALIDATION_CONTRACT_STAGE20
UTC=$TS
DECISION=$DECISION
SOURCE_MUTATION=NONE
INGESTION_EXECUTED=NO
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- git validator variants ---"
cat "$OUT/05_GIT_VARIANT_CLASSIFICATION.tsv"
echo
echo "--- behavioral contract summary ---"
cat "$OUT/08_SAMPLE_CONTRACT_SUMMARY.txt"
echo
echo "STAGE20_COMPLETE=YES"
