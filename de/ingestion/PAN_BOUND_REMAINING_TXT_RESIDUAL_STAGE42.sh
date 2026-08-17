#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_BOUND_REMAINING_TXT_RESIDUAL_$TS-STAGE42"

mkdir -p "$OUT"

echo "=== PAN — BOUND REMAINING TXT RESIDUAL / STAGE 42 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME" "$SERVICE"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST41="$(
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
        "PAN_CLASSIFY_MARKDOWN_SOURCE_DEFICIENT_STAGE41" in t
        and "STATUS=PASS" in t
        and "MARKDOWN_CLASSIFIED=62" in t
        and "NEXT=BOUND_REMAINING_TXT_RESIDUAL_35_AGAINST_PROMOTED_STAGE36" in t
    ):
        hits.append((d.stat().st_mtime_ns, d))
if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST41" ] && [ -d "$LATEST41" ] || {
  echo "BLOCKER: passing Stage41 evidence not found"
  exit 22
}

LATEST37="$(
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
        "PAN_REQUALIFY_STAGE28_FAILURE_SET_STAGE37" in t
        and "STATUS=PASS" in t
        and "ORIGINAL_FAILURE_SET=106" in t
        and "NOW_PASSING=5" in t
        and "STILL_NOT_PASSING=101" in t
    ):
        hits.append((d.stat().st_mtime_ns, d))
if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST37" ] && [ -d "$LATEST37" ] || {
  echo "BLOCKER: passing Stage37 evidence not found"
  exit 23
}

LEDGER="$LATEST37/02_REQUALIFICATION_LEDGER.tsv"
[ -f "$LEDGER" ] || {
  echo "BLOCKER: Stage37 requalification ledger missing: $LEDGER"
  exit 24
}

echo "STAGE41=$LATEST41"
echo "STAGE37=$LATEST37"
echo "LEDGER=$LEDGER"
echo

# -------------------------------------------------------------------
# Read-only pre-state.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/00_OUTPUT_COUNT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/00_RECEIPT_COUNT_PRE.txt"

# Exact live routing / parser / validation references.
{
  echo "===== TXT / CHATGPT / MARKDOWN / USER TURN REFERENCES ====="
  grep -R -n -E \
    '\.txt|parse_chatgpt|parse_markdown|missing_title|no_assets|missing_user_turn|conversation|turns|role' \
    "$SERVICE" \
    --include='*.py' \
    --exclude-dir='__pycache__' \
    2>/dev/null || true
} > "$OUT/01_TXT_CODE_REFERENCES.txt"

for f in \
  "$SERVICE/parsers/chatgpt.py" \
  "$SERVICE/parsers/markdown.py" \
  "$SERVICE/validation.py"
do
  if [ -f "$f" ]; then
    b="$(basename "$f")"
    nl -ba "$f" > "$OUT/01_NUMBERED_$b.txt"
  fi
done

export PAN42_LEDGER="$LEDGER"
export PAN42_OUT="$OUT"

"$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter
import csv
import hashlib
import json
import os
import re

ledger = Path(os.environ["PAN42_LEDGER"])
out = Path(os.environ["PAN42_OUT"])

with ledger.open("r", encoding="utf-8", newline="") as h:
    rows = list(csv.DictReader(h, delimiter="\t"))

txt = [
    r for r in rows
    if (r.get("extension") or "").lower() == ".txt"
    and (r.get("current_status") or "") != "PASS"
]

if len(txt) != 35:
    raise SystemExit(f"BLOCKER: expected 35 residual TXT rows, got {len(txt)}")

def jload(v, default):
    try:
        return json.loads(v)
    except Exception:
        return default

def source_features(source: Path):
    raw = source.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    text = raw.decode("utf-8", errors="replace")
    lines = text.splitlines()
    nonblank = [x.strip() for x in lines if x.strip()]

    h1s = []
    yaml_title = ""
    role_lines = []

    for line in lines:
        s = line.strip()
        m = re.match(r"^#\s+(.+?)\s*$", s)
        if m:
            h1s.append(m.group(1))

        if re.match(
            r"^\s*(User|Assistant|Human|ChatGPT|System)\s*:\s*",
            line,
            re.I,
        ):
            role_lines.append(line.strip())

    if lines and lines[0].strip() == "---":
        for line in lines[1:80]:
            if line.strip() == "---":
                break
            m = re.match(r"^\s*title\s*:\s*(.+?)\s*$", line, re.I)
            if m:
                yaml_title = m.group(1).strip().strip("'\"")
                break

    return {
        "sha256": digest,
        "bytes": len(raw),
        "line_count": len(lines),
        "nonblank_count": len(nonblank),
        "first_nonblank": nonblank[0][:240] if nonblank else "",
        "h1_count": len(h1s),
        "first_h1": h1s[0][:240] if h1s else "",
        "yaml_title": yaml_title[:240],
        "role_label_line_count": len(role_lines),
        "first_role_line": role_lines[0][:240] if role_lines else "",
    }

def read_pkg(path_str):
    pkg = Path(path_str)
    result = {
        "manifest_kind": "",
        "validation_errors": [],
        "validation_passed": "",
        "parsed_type": "",
        "parsed_kind": "",
        "parsed_title": "",
        "parsed_turn_count": "",
        "parsed_roles": [],
    }
    if not pkg.is_dir():
        return result

    try:
        manifest = json.loads(
            (pkg / "reports/manifest.json").read_text(encoding="utf-8")
        )
        validation = json.loads(
            (pkg / "reports/validation.json").read_text(encoding="utf-8")
        )
        parsed = json.loads(
            (pkg / "structure/parsed.json").read_text(encoding="utf-8")
        )
    except Exception:
        return result

    result["manifest_kind"] = str(manifest.get("kind", ""))
    result["validation_errors"] = [
        str(x) for x in (validation.get("errors") or [])
    ]
    result["validation_passed"] = validation.get("passed")
    result["parsed_type"] = type(parsed).__name__

    if isinstance(parsed, dict):
        result["parsed_kind"] = str(parsed.get("kind", ""))
        if parsed.get("title") is not None:
            result["parsed_title"] = str(parsed.get("title"))

        turns = parsed.get("turns")
        if isinstance(turns, list):
            result["parsed_turn_count"] = len(turns)
            roles = []
            for t in turns:
                if not isinstance(t, dict):
                    continue
                role = t.get("role") or t.get("speaker") or t.get("author")
                if isinstance(role, dict):
                    role = role.get("role") or role.get("name")
                if role is not None:
                    roles.append(str(role).lower())
            result["parsed_roles"] = roles

    return result

details = []
hash_failures = []

for r in txt:
    source = Path(r["source"]).resolve()
    if not source.is_file():
        raise SystemExit(f"BLOCKER: source missing: {source}")

    sf = source_features(source)
    expected = (r.get("sha256") or "").strip()
    if expected and sf["sha256"] != expected:
        hash_failures.append(str(source))

    pkg = read_pkg(r.get("output") or "")
    errors = jload(r.get("current_validation_errors") or "[]", [])

    if pkg["manifest_kind"] == "markdown":
        has_title_signal = bool(sf["h1_count"] or sf["yaml_title"])
        if "missing_title" not in errors:
            cls = "MARKDOWN_FALLBACK_OTHER"
        elif has_title_signal:
            cls = "MARKDOWN_FALLBACK_TITLE_SIGNAL_PRESENT"
        else:
            cls = "MARKDOWN_FALLBACK_SOURCE_TITLE_DEFICIENT"
    elif pkg["manifest_kind"] == "conversation":
        roles = pkg["parsed_roles"]
        user_roles = [
            x for x in roles
            if x in {"user", "human"}
        ]
        if "missing_user_turn" in errors and not user_roles:
            cls = "CONVERSATION_SOURCE_MISSING_USER_TURN"
        elif "missing_user_turn" in errors:
            cls = "CONVERSATION_VALIDATOR_DISCREPANCY"
        else:
            cls = "CONVERSATION_OTHER"
    else:
        cls = "UNKNOWN_MANIFEST_KIND"

    details.append({
        "source": str(source),
        "sha256": sf["sha256"],
        "bytes": sf["bytes"],
        "line_count": sf["line_count"],
        "nonblank_count": sf["nonblank_count"],
        "first_nonblank": sf["first_nonblank"],
        "h1_count": sf["h1_count"],
        "first_h1": sf["first_h1"],
        "yaml_title": sf["yaml_title"],
        "role_label_line_count": sf["role_label_line_count"],
        "first_role_line": sf["first_role_line"],
        "current_status": r.get("current_status", ""),
        "manifest_kind": pkg["manifest_kind"],
        "validation_errors": json.dumps(errors, ensure_ascii=False, sort_keys=True),
        "validation_passed": pkg["validation_passed"],
        "parsed_kind": pkg["parsed_kind"],
        "parsed_title": pkg["parsed_title"],
        "parsed_turn_count": pkg["parsed_turn_count"],
        "parsed_roles": json.dumps(pkg["parsed_roles"], ensure_ascii=False),
        "classification": cls,
    })

if hash_failures:
    (out / "HASH_FAILURES.txt").write_text(
        "\n".join(hash_failures) + "\n",
        encoding="utf-8",
    )
    raise SystemExit(
        f"BLOCKER: {len(hash_failures)} TXT source hash failures"
    )

fields = list(details[0].keys())
with (out / "02_TXT35_DETAIL.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(details)

class_counts = Counter(d["classification"] for d in details)
manifest_counts = Counter(d["manifest_kind"] for d in details)
error_counts = Counter()
for d in details:
    for e in jload(d["validation_errors"], []):
        error_counts[e] += 1

def write_counter(path, header, counter):
    with path.open("w", encoding="utf-8") as h:
        h.write("\t".join(header) + "\n")
        for key, n in sorted(
            counter.items(),
            key=lambda kv: (-kv[1], str(kv[0])),
        ):
            if not isinstance(key, tuple):
                key = (key,)
            h.write(str(n) + "\t" + "\t".join(map(str, key)) + "\n")

write_counter(
    out / "03_CLASSIFICATION_COUNTS.tsv",
    ["count", "classification"],
    class_counts,
)
write_counter(
    out / "04_MANIFEST_KIND_COUNTS.tsv",
    ["count", "manifest_kind"],
    manifest_counts,
)
write_counter(
    out / "05_ERROR_COUNTS.tsv",
    ["count", "error"],
    error_counts,
)

# Separate disposition candidates.
markdown_deficient = [
    d for d in details
    if d["classification"] == "MARKDOWN_FALLBACK_SOURCE_TITLE_DEFICIENT"
]
conversation_missing_user = [
    d for d in details
    if d["classification"] == "CONVERSATION_SOURCE_MISSING_USER_TURN"
]

with (out / "06_MARKDOWN_FALLBACK_SOURCE_DEFICIENT.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(markdown_deficient)

with (out / "07_CONVERSATION_MISSING_USER.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(conversation_missing_user)

obs = [
    f"OBSERVATION\tTXT_RESIDUAL\t{len(details)}",
    f"OBSERVATION\tMARKDOWN_FALLBACK\t{manifest_counts.get('markdown', 0)}",
    f"OBSERVATION\tCONVERSATION\t{manifest_counts.get('conversation', 0)}",
    f"OBSERVATION\tMARKDOWN_FALLBACK_SOURCE_TITLE_DEFICIENT\t{len(markdown_deficient)}",
    f"OBSERVATION\tCONVERSATION_SOURCE_MISSING_USER_TURN\t{len(conversation_missing_user)}",
    "OBSERVATION\tSOURCE_HASHES\tPASS",
]

for err, n in sorted(error_counts.items()):
    obs.append(
        f"OBSERVATION\tERROR_INCIDENCE\t{n}\t{err}"
    )

(out / "08_OBSERVATIONS.tsv").write_text(
    "\n".join(obs) + "\n",
    encoding="utf-8",
)

interpretations = []

if len(markdown_deficient) == 34:
    interpretations.append(
        "INTERPRETATION\tTXT_MARKDOWN_FALLBACK_SOURCE_DEFICIENT\tcount=34\t"
        "These sources now route correctly to the Markdown contract but expose no H1/YAML "
        "title signal and fail the same valid missing_title gate established for the native "
        "Markdown residual family. Parser/validator weakening is not indicated."
    )

if len(conversation_missing_user) == 1:
    interpretations.append(
        "INTERPRETATION\tTXT_CONVERSATION_SOURCE_DEFICIENT\tcount=1\t"
        "The remaining conversation-shaped TXT source contains no parsed user/human role "
        "and fails missing_user_turn. This is a source/content deficiency unless contrary "
        "source evidence is recovered."
    )

(out / "09_INTERPRETATIONS.tsv").write_text(
    "\n".join(interpretations) + ("\n" if interpretations else ""),
    encoding="utf-8",
)

with (out / "10_CANDIDATE_NEXT.txt").open(
    "w", encoding="utf-8"
) as h:
    h.write(f"TXT_RESIDUAL={len(details)}\n")
    h.write(f"MARKDOWN_FALLBACK_SOURCE_TITLE_DEFICIENT={len(markdown_deficient)}\n")
    h.write(f"CONVERSATION_SOURCE_MISSING_USER_TURN={len(conversation_missing_user)}\n")

    if (
        len(markdown_deficient) == 34
        and len(conversation_missing_user) == 1
        and len(details) == 35
    ):
        h.write(
            "CANDIDATE_NEXT=CLASSIFY_TXT35_AS_SOURCE_DEFICIENT_WITHOUT_FURTHER_CODE_REPAIR\n"
        )
    else:
        h.write(
            "CANDIDATE_NEXT=BOUND_ONLY_UNRESOLVED_TXT42_CLASSIFICATIONS_BEFORE_ANY_REPAIR\n"
        )

print("--- classifications ---")
print((out / "03_CLASSIFICATION_COUNTS.tsv").read_text(encoding="utf-8"), end="")
print("--- manifest kinds ---")
print((out / "04_MANIFEST_KIND_COUNTS.tsv").read_text(encoding="utf-8"), end="")
print("--- errors ---")
print((out / "05_ERROR_COUNTS.tsv").read_text(encoding="utf-8"), end="")
print("--- interpretations ---")
print((out / "09_INTERPRETATIONS.tsv").read_text(encoding="utf-8"), end="")
print("--- candidate next ---")
print((out / "10_CANDIDATE_NEXT.txt").read_text(encoding="utf-8"), end="")
PY

echo
echo "--- live TXT code references ---"
cat "$OUT/01_TXT_CODE_REFERENCES.txt"

# -------------------------------------------------------------------
# Post-state proof.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/11_GIT_STATUS_POST.z" 2>/dev/null || true

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/11_OUTPUT_COUNT_POST.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/11_RECEIPT_COUNT_POST.txt"

GIT_MUTATION="NONE"
cmp -s "$OUT/00_GIT_STATUS_PRE.z" "$OUT/11_GIT_STATUS_POST.z" || GIT_MUTATION="DETECTED"

PRE_OUTPUT="$(cat "$OUT/00_OUTPUT_COUNT_PRE.txt")"
POST_OUTPUT="$(cat "$OUT/11_OUTPUT_COUNT_POST.txt")"
PRE_RECEIPTS="$(cat "$OUT/00_RECEIPT_COUNT_PRE.txt")"
POST_RECEIPTS="$(cat "$OUT/11_RECEIPT_COUNT_POST.txt")"

LIVE_MUTATION="NONE"
if [ "$PRE_OUTPUT" != "$POST_OUTPUT" ] || [ "$PRE_RECEIPTS" != "$POST_RECEIPTS" ]; then
  LIVE_MUTATION="DETECTED"
fi

NEXT="$(sed -n 's/^CANDIDATE_NEXT=//p' "$OUT/10_CANDIDATE_NEXT.txt" | head -1)"

if [ "$GIT_MUTATION" = "NONE" ] && [ "$LIVE_MUTATION" = "NONE" ]; then
  STATUS="PASS"
else
  STATUS="FAIL"
  NEXT="PRESERVE_STAGE42_MUTATION_EVIDENCE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_BOUND_REMAINING_TXT_RESIDUAL_STAGE42
UTC=$TS
STATUS=$STATUS
STAGE41=$LATEST41
STAGE37=$LATEST37
TXT_RESIDUAL=35
SOURCE_HASHES=PASS
REPOSITORY_STATUS_MUTATION=$GIT_MUTATION
LIVE_OUTPUT_MUTATION=$LIVE_MUTATION
SOURCE_MUTATION=NONE
LIVE_INGESTION_EXECUTED=NO
PARSER_CODE_MODIFIED=NO
VALIDATOR_CODE_MODIFIED=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
CODE_REFERENCES=$OUT/01_TXT_CODE_REFERENCES.txt
DETAIL=$OUT/02_TXT35_DETAIL.tsv
CLASSIFICATIONS=$OUT/03_CLASSIFICATION_COUNTS.tsv
MANIFEST_KINDS=$OUT/04_MANIFEST_KIND_COUNTS.tsv
ERROR_COUNTS=$OUT/05_ERROR_COUNTS.tsv
MARKDOWN_SOURCE_DEFICIENT=$OUT/06_MARKDOWN_FALLBACK_SOURCE_DEFICIENT.tsv
CONVERSATION_MISSING_USER=$OUT/07_CONVERSATION_MISSING_USER.tsv
OBSERVATIONS=$OUT/08_OBSERVATIONS.tsv
INTERPRETATIONS=$OUT/09_INTERPRETATIONS.tsv
CANDIDATE_NEXT=$OUT/10_CANDIDATE_NEXT.txt
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- candidate next ---"
cat "$OUT/10_CANDIDATE_NEXT.txt"
echo

if [ "$STATUS" = "PASS" ]; then
  echo "STAGE42_COMPLETE=YES"
  exit 0
fi

echo "STAGE42_COMPLETE=NO"
exit 1
