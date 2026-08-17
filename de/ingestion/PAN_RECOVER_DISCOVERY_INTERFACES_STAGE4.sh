#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
FIRST_CORPUS="$HOME/Difference-Engine-LEGACY-STALE-DECOMPOSED"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_INGESTION_RECOVERY_$TS-STAGE4"

PYTHON="/usr/bin/python3"

mkdir -p "$OUT"

echo "=== PAN — DISCOVERY / DELTA INTERFACE RECOVERY STAGE 4 ==="
echo "CURRENT=$CURRENT"
echo "FIRST_CORPUS=$FIRST_CORPUS"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$FIRST_CORPUS"; do
  [ -d "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: python3 missing: $PYTHON"; exit 21; }

DISCOVER="$(find "$CURRENT" -xdev -type f -name 'discover_conversations.py' -print -quit 2>/dev/null || true)"
DELTA="$(find "$CURRENT" -xdev -type f -name 'discover_conversation_delta.py' -print -quit 2>/dev/null || true)"

if [ -z "$DISCOVER" ] || [ ! -f "$DISCOVER" ]; then
  echo "BLOCKER: discover_conversations.py not found"
  exit 22
fi

if [ -z "$DELTA" ] || [ ! -f "$DELTA" ]; then
  echo "BLOCKER: discover_conversation_delta.py not found"
  exit 23
fi

# 1. Identity / provenance of the live scripts.
{
  echo "=== DISCOVER ==="
  sha256sum "$DISCOVER"
  stat "$DISCOVER" || true
  echo
  echo "=== DELTA ==="
  sha256sum "$DELTA"
  stat "$DELTA" || true
} > "$OUT/01_SCRIPT_IDENTITY.txt" 2>&1

# 2. Preserve source for inspection.
cp -a "$DISCOVER" "$OUT/discover_conversations.py"
cp -a "$DELTA" "$OUT/discover_conversation_delta.py"

# 3. Recover CLI/interface contract WITHOUT executing either script.
"$PYTHON" - "$DISCOVER" "$DELTA" > "$OUT/02_STATIC_INTERFACE.json" <<'PY'
import ast, json, sys
from pathlib import Path

def inspect(path):
    src = Path(path).read_text(encoding="utf-8", errors="replace")
    tree = ast.parse(src, filename=path)
    out = {
        "path": path,
        "functions": [],
        "classes": [],
        "imports": [],
        "argparse_add_argument_calls": [],
        "main_guard": False,
        "subprocess_calls": [],
        "write_like_calls": [],
    }

    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            out["functions"].append(node.name)
        elif isinstance(node, ast.ClassDef):
            out["classes"].append(node.name)
        elif isinstance(node, ast.Import):
            out["imports"] += [a.name for a in node.names]
        elif isinstance(node, ast.ImportFrom):
            out["imports"].append(
                (node.module or "") + ":" + ",".join(a.name for a in node.names)
            )
        elif isinstance(node, ast.If):
            try:
                txt = ast.unparse(node.test)
            except Exception:
                txt = ""
            if "__name__" in txt and "__main__" in txt:
                out["main_guard"] = True
        elif isinstance(node, ast.Call):
            func = ""
            try:
                func = ast.unparse(node.func)
            except Exception:
                pass

            if func.endswith(".add_argument"):
                args = []
                for a in node.args:
                    try:
                        args.append(ast.literal_eval(a))
                    except Exception:
                        try:
                            args.append(ast.unparse(a))
                        except Exception:
                            args.append("?")
                kwargs = {}
                for kw in node.keywords:
                    if kw.arg is None:
                        continue
                    try:
                        kwargs[kw.arg] = ast.literal_eval(kw.value)
                    except Exception:
                        try:
                            kwargs[kw.arg] = ast.unparse(kw.value)
                        except Exception:
                            kwargs[kw.arg] = "?"
                out["argparse_add_argument_calls"].append(
                    {"args": args, "kwargs": kwargs}
                )

            if func.startswith("subprocess."):
                out["subprocess_calls"].append(func)

            low = func.lower()
            if any(k in low for k in [
                "write_text", "write_bytes", "mkdir", "rename", "replace",
                "unlink", "remove", "rmtree", "copy", "copy2", "move",
                "open", "json.dump"
            ]):
                out["write_like_calls"].append(func)

    out["functions"] = sorted(set(out["functions"]))
    out["classes"] = sorted(set(out["classes"]))
    out["imports"] = sorted(set(out["imports"]))
    out["subprocess_calls"] = sorted(set(out["subprocess_calls"]))
    out["write_like_calls"] = sorted(set(out["write_like_calls"]))
    return out

print(json.dumps([inspect(p) for p in sys.argv[1:]], indent=2))
PY

# 4. Human-readable CLI clues and historical invocations.
{
  echo "=== DISCOVER CLI CLUES ==="
  grep -nE 'argparse|add_argument|ArgumentParser|def main|__main__|SOURCE|ROOT|OUTPUT|candidate|duplicate|verified|domain' \
    "$DISCOVER" | head -500 || true
  echo
  echo "=== DELTA CLI CLUES ==="
  grep -nE 'argparse|add_argument|ArgumentParser|def main|__main__|SOURCE|ROOT|OUTPUT|candidate|duplicate|verified|domain|delta|baseline' \
    "$DELTA" | head -500 || true
} > "$OUT/03_CLI_CLUES.txt"

{
  echo "=== HISTORICAL INVOCATIONS / REFERENCES ==="
  grep -RInF "$(basename "$DISCOVER")" "$CURRENT" "$FIRST_CORPUS" 2>/dev/null | head -1000 || true
  echo
  grep -RInF "$(basename "$DELTA")" "$CURRENT" "$FIRST_CORPUS" 2>/dev/null | head -1000 || true
} > "$OUT/04_HISTORICAL_REFERENCES.txt"

# 5. Recover prior conversation-discovery evidence contracts.
{
  find "$CURRENT" "$FIRST_CORPUS" -xdev -type f \
    \( -name 'CONVERSATION_CORPUS_CANDIDATES.txt' \
       -o -name 'CONVERSATION_CORPUS_DUPLICATES.txt' \
       -o -name 'CONVERSATION_CORPUS_UNIQUE.txt' \
       -o -name 'CONVERSATION_CORPUS_VERIFIED.json' \
       -o -name 'CONVERSATION_PACKAGE_HISTORY.txt' \
       -o -name 'CONVERSATION_RECOVERY_INSPECTION.txt' \
       -o -name 'CONVERSATION_SOURCE_DOMAINS.tsv' \
       -o -iname '*conversation*delta*' \
       -o -iname '*conversation*census*' \) \
    -print 2>/dev/null | sort
} > "$OUT/05_DISCOVERY_EVIDENCE_FILES.txt"

# 6. First-corpus top-level shape.
{
  echo "=== FIRST CORPUS TOP LEVEL ==="
  find "$FIRST_CORPUS" -mindepth 1 -maxdepth 2 \
    -printf '%y\t%s\t%TY-%Tm-%TdT%TH:%TM:%TS\t%p\t%l\n' \
    2>/dev/null | sort
} > "$OUT/06_FIRST_CORPUS_TOP_LEVEL.tsv"

# 7. Determine whether static recovery found a usable argparse contract.
ARGCOUNT="$("$PYTHON" - "$OUT/02_STATIC_INTERFACE.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
print(sum(len(x.get("argparse_add_argument_calls", [])) for x in d))
PY
)"

if [ "$ARGCOUNT" -gt 0 ]; then
  NEXT="BUILD_EXACT_DRY_RUN_INVOCATION_FROM_RECOVERED_ARGUMENT_CONTRACT"
else
  NEXT="RECOVER_CALL_CONTRACT_FROM_HISTORICAL_REFERENCES_AND_SOURCE_MAIN_FUNCTION"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_DISCOVERY_INTERFACE_RECOVERY_STAGE4
UTC=$TS
DISCOVER=$DISCOVER
DELTA=$DELTA
ARGPARSE_ARGUMENT_CALLS=$ARGCOUNT
FIRST_CORPUS=$FIRST_CORPUS
EVIDENCE=$OUT
SOURCE_MUTATION=NONE
SCRIPTS_EXECUTED=NO
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- static argument contract ---"
grep -n '"args"\|"dest"\|"default"\|"required"\|"action"\|"help"' \
  "$OUT/02_STATIC_INTERFACE.json" | head -120 || true
echo
echo "STAGE4_COMPLETE=YES"
