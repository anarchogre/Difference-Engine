#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
LEGACY="$HOME/Difference-Engine-LEGACY-STALE-DECOMPOSED"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_UNIVERSAL_PIPELINE_RECOVERY_$TS-STAGE10"

mkdir -p "$OUT"

echo "=== PAN — UNIVERSAL PIPELINE RECOVERY STAGE 10 ==="
echo "CURRENT=$CURRENT"
echo "LEGACY=$LEGACY"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$LEGACY"; do
  [ -d "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST_STAGE9="$(find "$TREE_HOME" -maxdepth 1 -type d -name 'PAN_PROVISIONAL_AND_REMAINDER_*' \
  -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"

[ -n "$LATEST_STAGE9" ] && [ -d "$LATEST_STAGE9" ] || {
  echo "BLOCKER: no Stage 9 evidence found"
  exit 22
}

REMAINDER="$LATEST_STAGE9/04_NONCONVERSATION_REMAINDER.txt"
REMAINDER_EXT="$LATEST_STAGE9/03_REMAINDER_BY_EXTENSION.tsv"

[ -f "$REMAINDER" ] || { echo "BLOCKER: missing $REMAINDER"; exit 23; }
[ -f "$REMAINDER_EXT" ] || { echo "BLOCKER: missing $REMAINDER_EXT"; exit 24; }

# 1. Recover active implementation candidates separately from retired/history.
{
  echo "=== ACTIVE CURRENT IMPLEMENTATION CANDIDATES ==="
  find "$CURRENT" -xdev -type f \
    \( -path '*/workspace/operational/ingestion/*' \
       -o -path '*/ade/services/ingestion/*' \) \
    \( -iname '*formatter*' \
       -o -iname '*artifact*intake*' \
       -o -iname '*repository*object*' \
       -o -iname '*structural*parser*' \
       -o -iname '*normaliz*' \
       -o -iname '*universal*header*' \
       -o -iname '*schema*' \
       -o -iname '*metadata*' \
       -o -iname '*provenance*' \
       -o -iname '*validator*' \
       -o -iname '*pipeline*' \
       -o -iname '*batch*' \) \
    ! -path '*/recovery/retired_packages/*' \
    -print 2>/dev/null | sort
} > "$OUT/01_ACTIVE_CANDIDATES.txt"

{
  echo "=== RETIRED / HISTORICAL IMPLEMENTATION CANDIDATES ==="
  find "$CURRENT" "$LEGACY" -xdev -type f \
    \( -path '*/recovery/retired_packages/*' \
       -o -path '*/LEGACY-*/*' \
       -o -path '*/archive/*' \
       -o -path '*/Archive/*' \) \
    \( -iname '*formatter*' \
       -o -iname '*artifact*intake*' \
       -o -iname '*repository*object*' \
       -o -iname '*structural*parser*' \
       -o -iname '*normaliz*' \
       -o -iname '*universal*header*' \
       -o -iname '*schema*' \
       -o -iname '*pipeline*' \
       -o -iname '*batch*' \) \
    -print 2>/dev/null | sort
} > "$OUT/02_RETIRED_CANDIDATES.txt"

# 2. Recover textual contracts/specifications.
{
  echo "=== CONTRACT / SPEC REFERENCES ==="
  grep -RInE \
    'Universal Formatter|Artifact Intake|Repository Object|RepositoryObject|Structural Parser|Normalization Contract|normalization contract|Universal Header|artifact_type|artifact_id|schema_version|source_class|content hash|provenance' \
    "$CURRENT" "$LEGACY" \
    --include='*.md' --include='*.txt' --include='*.json' --include='*.py' \
    2>/dev/null | head -5000 || true
} > "$OUT/03_CONTRACT_REFERENCES.txt"

# 3. Static-inspect all active Python candidates.
"$PYTHON" - "$OUT/01_ACTIVE_CANDIDATES.txt" > "$OUT/04_ACTIVE_PYTHON_INTERFACE.json" <<'PY'
import ast, json, sys
from pathlib import Path

paths = []
for line in Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace").splitlines():
    p = Path(line.strip())
    if p.suffix == ".py" and p.is_file():
        paths.append(p)

def inspect(p):
    text = p.read_text(encoding="utf-8", errors="replace")
    try:
        tree = ast.parse(text, filename=str(p))
    except Exception as e:
        return {"path": str(p), "parse_error": repr(e)}

    out = {
        "path": str(p),
        "classes": [],
        "functions": [],
        "imports": [],
        "constants": {},
        "main_guard": False,
    }

    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef):
            out["classes"].append(node.name)
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            out["functions"].append(node.name)
        elif isinstance(node, ast.Import):
            out["imports"].extend(a.name for a in node.names)
        elif isinstance(node, ast.ImportFrom):
            out["imports"].append((node.module or "") + ":" + ",".join(a.name for a in node.names))
        elif isinstance(node, ast.If):
            try:
                t = ast.unparse(node.test)
            except Exception:
                t = ""
            if "__name__" in t and "__main__" in t:
                out["main_guard"] = True

    # top-level simple constants only
    for node in tree.body:
        if isinstance(node, ast.Assign):
            try:
                names = [ast.unparse(x) for x in node.targets]
                value = ast.literal_eval(node.value)
            except Exception:
                continue
            for name in names:
                if isinstance(value, (str, int, float, bool, type(None), list, tuple, dict)):
                    out["constants"][name] = value

    out["classes"] = sorted(set(out["classes"]))
    out["functions"] = sorted(set(out["functions"]))
    out["imports"] = sorted(set(out["imports"]))
    return out

print(json.dumps([inspect(p) for p in paths], indent=2))
PY

# 4. Identify likely active generic ingest entrypoints from symbols and references.
"$PYTHON" - "$OUT/04_ACTIVE_PYTHON_INTERFACE.json" > "$OUT/05_GENERIC_ENTRYPOINT_CANDIDATES.txt" <<'PY'
import json, sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
needles = (
    "ingest", "format", "normalize", "artifact", "repository",
    "build", "parse", "validate", "intake", "source"
)

for rec in data:
    path = rec.get("path","")
    symbols = rec.get("functions",[]) + rec.get("classes",[])
    hits = [s for s in symbols if any(n in s.lower() for n in needles)]
    if hits:
        print(path)
        for h in hits:
            print(f"  {h}")
PY

# 5. Preserve remainder inventory and select one low-risk non-conversation source
#    for the next qualification proof. Do NOT ingest it yet.
cp -a "$REMAINDER_EXT" "$OUT/06_REMAINDER_BY_EXTENSION.tsv"
cp -a "$REMAINDER" "$OUT/07_REMAINDER_FILES.txt"

"$PYTHON" - "$REMAINDER" > "$OUT/08_SAFE_SOURCE_CANDIDATES.txt" <<'PY'
from pathlib import Path
import sys

# Start with deterministic text-like formats already common in the corpus.
priority = [".json", ".md", ".txt", ".xml", ".properties", ".py"]

items = []
for line in Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace").splitlines():
    p = Path(line.strip())
    if p.is_file():
        items.append(p)

for ext in priority:
    for p in items:
        if p.suffix.lower() == ext:
            print(p)
PY

ACTIVE_COUNT="$(grep -c '^/' "$OUT/01_ACTIVE_CANDIDATES.txt" 2>/dev/null || true)"
ENTRY_COUNT="$(grep -c '^/' "$OUT/05_GENERIC_ENTRYPOINT_CANDIDATES.txt" 2>/dev/null || true)"
SAFE_COUNT="$(grep -c '^/' "$OUT/08_SAFE_SOURCE_CANDIDATES.txt" 2>/dev/null || true)"

if [ "$ENTRY_COUNT" -gt 0 ] && [ "$SAFE_COUNT" -gt 0 ]; then
  NEXT="INSPECT_TOP_GENERIC_ENTRYPOINT_AND_RUN_ONE_SANDBOXED_NONCONVERSATION_QUALIFICATION"
else
  NEXT="RECOVER_GENERIC_ENTRYPOINT_CONTRACT_FROM_SPEC_AND_RETIRED_LINEAGE_BEFORE_NEW_CODE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_UNIVERSAL_PIPELINE_RECOVERY_STAGE10
UTC=$TS
ACTIVE_IMPLEMENTATION_CANDIDATES=$ACTIVE_COUNT
GENERIC_ENTRYPOINT_CANDIDATES=$ENTRY_COUNT
SAFE_REMAINDER_SOURCE_CANDIDATES=$SAFE_COUNT
SOURCE_MUTATION=NONE
INGESTION_EXECUTED=NO
EVIDENCE=$OUT
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- active candidates ---"
head -80 "$OUT/01_ACTIVE_CANDIDATES.txt" || true
echo
echo "--- generic entrypoint candidates ---"
head -120 "$OUT/05_GENERIC_ENTRYPOINT_CANDIDATES.txt" || true
echo
echo "--- first safe remainder sources ---"
head -20 "$OUT/08_SAFE_SOURCE_CANDIDATES.txt" || true
echo
echo "STAGE10_COMPLETE=YES"
