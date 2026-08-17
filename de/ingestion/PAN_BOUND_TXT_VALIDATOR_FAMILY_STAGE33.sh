#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_BOUND_TXT_VALIDATOR_FAMILY_$TS-STAGE33"

mkdir -p "$OUT"

echo "=== PAN — BOUND TXT VALIDATOR FAMILY / STAGE 33 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME" "$SERVICE"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

# -------------------------------------------------------------------
# Recover latest successful Stage32 from evidence, not directory naming.
# -------------------------------------------------------------------
LATEST32="$(
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
    text = s.read_text(encoding="utf-8", errors="replace")
    if "PAN_BOUND_JSON_EXCEPTION_TAIL_STAGE32" not in text:
        continue
    if "STATUS=PASS" not in text:
        continue
    if "JSON_TAIL_COUNT=4" not in text:
        continue
    if "STAGE32_COMPLETE=YES" in text:
        # SUMMARY may not contain this terminal line; harmless if absent.
        pass
    hits.append((d.stat().st_mtime_ns, d))

if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST32" ] && [ -d "$LATEST32" ] || {
  echo "BLOCKER: passing Stage32 evidence not found"
  exit 22
}

STAGE30="$(sed -n 's/^STAGE30=//p' "$LATEST32/SUMMARY.txt" | head -1)"
[ -n "$STAGE30" ] && [ -d "$STAGE30" ] || {
  echo "BLOCKER: Stage30 path not recoverable from Stage32"
  exit 23
}

LEDGER="$STAGE30/01_QUALIFICATION_LEDGER.tsv"
[ -f "$LEDGER" ] || {
  echo "BLOCKER: Stage30 qualification ledger missing: $LEDGER"
  exit 24
}

echo "STAGE32=$LATEST32"
echo "STAGE30=$STAGE30"
echo "LEDGER=$LEDGER"
echo

# -------------------------------------------------------------------
# Pre-state. Stage33 must be read-only to repository and live ingestion state.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/00_OUTPUT_PACKAGE_COUNT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/00_RECEIPT_COUNT_PRE.txt"

# -------------------------------------------------------------------
# Recover the exact live code surfaces relevant to TXT routing/parsing/validation.
# This is evidence only. No edits.
# -------------------------------------------------------------------
{
  echo "===== TXT / SUFFIX / ROUTING REFERENCES ====="
  grep -R -n -E \
    '\.txt|suffix|extension|source_class|kind|conversation|turns|missing_user_turn|invalid_conversation_kind|no_conversation_turns' \
    "$SERVICE" \
    --include='*.py' \
    --exclude-dir='__pycache__' \
    2>/dev/null || true
} > "$OUT/01_TXT_ROUTING_CODE_REFERENCES.txt"

find "$SERVICE" -type f -name '*.py' -print | sort \
  > "$OUT/01_SERVICE_PYTHON_FILES.txt"

export PAN33_LEDGER="$LEDGER"
export PAN33_OUT="$OUT"

"$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter, defaultdict
import csv
import hashlib
import json
import os
import re

ledger = Path(os.environ["PAN33_LEDGER"])
out = Path(os.environ["PAN33_OUT"])

with ledger.open("r", encoding="utf-8", newline="") as h:
    rows = list(csv.DictReader(h, delimiter="\t"))

txt_rows = [
    r for r in rows
    if (r.get("extension") or "").strip().lower() == ".txt"
]

if len(txt_rows) != 40:
    raise SystemExit(
        f"BLOCKER: expected 40 Stage30 TXT failures, found {len(txt_rows)}"
    )

def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def load_json(path: Path):
    if not path.is_file():
        return None, "MISSING"
    try:
        return json.loads(path.read_text(encoding="utf-8")), "PASS"
    except Exception as e:
        return None, f"{type(e).__name__}: {e}"

def pick(d, *keys, default=None):
    if not isinstance(d, dict):
        return default
    for k in keys:
        if k in d:
            return d[k]
    return default

def count_turns(obj):
    if not isinstance(obj, dict):
        return None
    for key in ("turns", "messages", "conversation_turns"):
        v = obj.get(key)
        if isinstance(v, list):
            return len(v)
    return None

def roles(obj):
    found = []
    if not isinstance(obj, dict):
        return found
    for key in ("turns", "messages", "conversation_turns"):
        v = obj.get(key)
        if not isinstance(v, list):
            continue
        for item in v:
            if not isinstance(item, dict):
                continue
            role = (
                item.get("role")
                or item.get("author")
                or item.get("speaker")
                or item.get("type")
            )
            if isinstance(role, dict):
                role = role.get("role") or role.get("name")
            if role is not None:
                found.append(str(role).lower())
    return found

def asset_count(obj):
    if not isinstance(obj, dict):
        return None
    for key in ("assets", "attachments", "files"):
        v = obj.get(key)
        if isinstance(v, list):
            return len(v)
        if isinstance(v, dict):
            return len(v)
    return None

def text_features(text: str):
    lines = text.splitlines()
    nonblank = [x.strip() for x in lines if x.strip()]
    low = text.lower()

    role_line_re = re.compile(
        r'^\s*(user|assistant|system|human|chatgpt)\s*[:>\-]\s*',
        re.IGNORECASE
    )
    role_lines = [x for x in lines if role_line_re.match(x)]

    # Structural markers only; these do not assert conversation semantics.
    markers = {
        "role_label_lines": len(role_lines),
        "contains_user_token": int("user" in low),
        "contains_assistant_token": int("assistant" in low),
        "contains_chatgpt_token": int("chatgpt" in low),
        "contains_json_brace": int("{" in text or "[" in text),
        "contains_markdown_heading": int(any(
            x.lstrip().startswith("#") for x in lines
        )),
        "contains_tab": int("\t" in text),
    }

    return {
        "line_count": len(lines),
        "nonblank_line_count": len(nonblank),
        "char_count": len(text),
        "first_nonblank": nonblank[0][:240] if nonblank else "",
        **markers,
    }

detail_fields = [
    "source",
    "bytes",
    "sha256_stage30",
    "sha256_now",
    "hash_match",
    "failure_signature",
    "mechanical_bucket",
    "stage28_manifest_kind",
    "stage28_parsed_kind",
    "stage28_output_exists",
    "manifest_read",
    "parsed_read",
    "validation_read",
    "manifest_kind_live",
    "parsed_kind_live",
    "turn_count",
    "roles",
    "user_role_count",
    "assistant_role_count",
    "asset_count",
    "validation_errors_live",
    "line_count",
    "nonblank_line_count",
    "char_count",
    "first_nonblank",
    "role_label_lines",
    "contains_user_token",
    "contains_assistant_token",
    "contains_chatgpt_token",
    "contains_json_brace",
    "contains_markdown_heading",
    "contains_tab",
    "classification",
]

details = []
hash_failures = []

for r in txt_rows:
    source = Path(r["source"]).resolve()
    if not source.is_file():
        raise SystemExit(f"BLOCKER: missing TXT source {source}")

    data = source.read_bytes()
    digest = sha256(data)
    expected = (r.get("sha256_now") or r.get("sha256_stage28") or "").strip()
    hash_ok = digest == expected

    if not hash_ok:
        hash_failures.append(str(source))

    try:
        text = data.decode("utf-8")
        utf8_ok = True
    except UnicodeDecodeError:
        text = ""
        utf8_ok = False

    package = Path((r.get("stage28_output") or "").strip())
    package_exists = package.is_dir()

    manifest, manifest_state = load_json(package / "reports/manifest.json") \
        if package_exists else (None, "NO_PACKAGE")
    parsed, parsed_state = load_json(package / "structure/parsed.json") \
        if package_exists else (None, "NO_PACKAGE")
    validation, validation_state = load_json(package / "reports/validation.json") \
        if package_exists else (None, "NO_PACKAGE")

    manifest_kind_live = str(
        pick(manifest, "kind", "document_kind", default="") or ""
    )
    parsed_kind_live = str(
        pick(parsed, "kind", "document_kind", default="") or ""
    )

    turns = count_turns(parsed)
    rs = roles(parsed)
    assets = asset_count(parsed)

    validation_errors = []
    if isinstance(validation, dict):
        v = validation.get("errors")
        if isinstance(v, list):
            validation_errors = [str(x) for x in v]

    tf = text_features(text) if utf8_ok else {
        "line_count": 0,
        "nonblank_line_count": 0,
        "char_count": 0,
        "first_nonblank": "",
        "role_label_lines": 0,
        "contains_user_token": 0,
        "contains_assistant_token": 0,
        "contains_chatgpt_token": 0,
        "contains_json_brace": 0,
        "contains_markdown_heading": 0,
        "contains_tab": 0,
    }

    sig = (r.get("failure_signature") or "").strip()

    # Mechanical classification only. It describes observed package state.
    if not utf8_ok:
        cls = "TXT_NON_UTF8"
    elif not package_exists:
        cls = "TXT_NO_STAGE28_PACKAGE"
    elif "invalid_conversation_kind" in sig and (turns in (0, None)):
        cls = "TXT_VALIDATED_AS_CONVERSATION_WITHOUT_TURNS"
    elif "missing_user_turn" in sig:
        cls = "TXT_CONVERSATION_SHAPE_WITHOUT_USER_TURN"
    else:
        cls = "TXT_OTHER_VALIDATION_STATE"

    details.append({
        "source": str(source),
        "bytes": len(data),
        "sha256_stage30": expected,
        "sha256_now": digest,
        "hash_match": "PASS" if hash_ok else "FAIL",
        "failure_signature": sig,
        "mechanical_bucket": r.get("mechanical_bucket", ""),
        "stage28_manifest_kind": r.get("stage28_manifest_kind", ""),
        "stage28_parsed_kind": r.get("parsed_kind", ""),
        "stage28_output_exists": "YES" if package_exists else "NO",
        "manifest_read": manifest_state,
        "parsed_read": parsed_state,
        "validation_read": validation_state,
        "manifest_kind_live": manifest_kind_live,
        "parsed_kind_live": parsed_kind_live,
        "turn_count": "" if turns is None else turns,
        "roles": json.dumps(rs, ensure_ascii=False),
        "user_role_count": sum(x in {"user", "human"} for x in rs),
        "assistant_role_count": sum(x in {"assistant", "chatgpt"} for x in rs),
        "asset_count": "" if assets is None else assets,
        "validation_errors_live": json.dumps(
            validation_errors, ensure_ascii=False, sort_keys=True
        ),
        **tf,
        "classification": cls,
    })

if hash_failures:
    (out / "HASH_FAILURES.txt").write_text(
        "\n".join(hash_failures) + "\n", encoding="utf-8"
    )
    raise SystemExit(
        f"BLOCKER: {len(hash_failures)} TXT source hashes drifted"
    )

with (out / "02_TXT_DETAIL.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    w = csv.DictWriter(h, fieldnames=detail_fields, delimiter="\t")
    w.writeheader()
    w.writerows(details)

# Cross-tabs.
classification_counts = Counter(d["classification"] for d in details)
failure_counts = Counter(d["failure_signature"] for d in details)
manifest_counts = Counter(d["manifest_kind_live"] for d in details)
parsed_counts = Counter(d["parsed_kind_live"] for d in details)
class_x_sig = Counter(
    (d["classification"], d["failure_signature"]) for d in details
)
manifest_x_sig = Counter(
    (d["manifest_kind_live"], d["failure_signature"]) for d in details
)
marker_profiles = Counter(
    (
        d["classification"],
        d["role_label_lines"] > 0,
        d["contains_user_token"],
        d["contains_assistant_token"],
    )
    for d in details
)

def write_counter(path, header, counter):
    with path.open("w", encoding="utf-8") as h:
        h.write("\t".join(header) + "\n")
        for key, n in sorted(counter.items(), key=lambda kv: (-kv[1], str(kv[0]))):
            if not isinstance(key, tuple):
                key = (key,)
            h.write(str(n) + "\t" + "\t".join(map(str, key)) + "\n")

write_counter(
    out / "03_CLASSIFICATION_COUNTS.tsv",
    ["count", "classification"],
    classification_counts,
)
write_counter(
    out / "04_FAILURE_COUNTS.tsv",
    ["count", "failure_signature"],
    failure_counts,
)
write_counter(
    out / "05_MANIFEST_KIND_COUNTS.tsv",
    ["count", "manifest_kind_live"],
    manifest_counts,
)
write_counter(
    out / "06_PARSED_KIND_COUNTS.tsv",
    ["count", "parsed_kind_live"],
    parsed_counts,
)
write_counter(
    out / "07_CLASSIFICATION_X_FAILURE.tsv",
    ["count", "classification", "failure_signature"],
    class_x_sig,
)
write_counter(
    out / "08_MANIFEST_X_FAILURE.tsv",
    ["count", "manifest_kind_live", "failure_signature"],
    manifest_x_sig,
)
write_counter(
    out / "09_MARKER_PROFILES.tsv",
    [
        "count",
        "classification",
        "has_role_label_lines",
        "contains_user_token",
        "contains_assistant_token",
    ],
    marker_profiles,
)

# Evidence / interpretation separation.
observations = [
    f"OBSERVATION\tTXT_TOTAL\t{len(details)}",
    f"OBSERVATION\tSOURCE_HASHES\tPASS",
]

for cls, n in sorted(classification_counts.items()):
    observations.append(f"OBSERVATION\tCLASSIFICATION\t{n}\t{cls}")

for kind, n in sorted(manifest_counts.items()):
    observations.append(
        f"OBSERVATION\tMANIFEST_KIND\t{n}\t{kind or '<EMPTY>'}"
    )

role_label_count = sum(d["role_label_lines"] > 0 for d in details)
turns_present_count = sum(
    isinstance(d["turn_count"], int) and d["turn_count"] > 0
    for d in details
)

observations.append(
    f"OBSERVATION\tFILES_WITH_ROLE_LABEL_LINES\t{role_label_count}"
)
observations.append(
    f"OBSERVATION\tFILES_WITH_PARSED_TURNS_GT_0\t{turns_present_count}"
)

(out / "10_OBSERVATIONS.tsv").write_text(
    "\n".join(observations) + "\n",
    encoding="utf-8",
)

interpretations = []

no_turn_family = classification_counts.get(
    "TXT_VALIDATED_AS_CONVERSATION_WITHOUT_TURNS", 0
)
missing_user_family = classification_counts.get(
    "TXT_CONVERSATION_SHAPE_WITHOUT_USER_TURN", 0
)

if no_turn_family:
    interpretations.append(
        "INTERPRETATION\tTXT_ROUTING_BOUNDARY\t"
        f"count={no_turn_family}\t"
        "These sources reached conversation-oriented validation with no parsed turns. "
        "The next repair investigation should determine why TXT inputs are routed into "
        "that contract before changing validation policy."
    )

if missing_user_family:
    interpretations.append(
        "INTERPRETATION\tTXT_USER_TURN_EDGE\t"
        f"count={missing_user_family}\t"
        "At least one TXT source produced a conversation-shaped package lacking a user "
        "turn. This case should remain separate from the no-turn family."
    )

(out / "11_INTERPRETATIONS.tsv").write_text(
    "\n".join(interpretations) + ("\n" if interpretations else ""),
    encoding="utf-8",
)

# Candidate next operation derived from observed state, not promoted doctrine.
with (out / "12_CANDIDATE_NEXT.txt").open("w", encoding="utf-8") as h:
    h.write(f"TXT_TOTAL={len(details)}\n")
    h.write(f"TXT_NO_TURN_FAMILY={no_turn_family}\n")
    h.write(f"TXT_MISSING_USER_FAMILY={missing_user_family}\n")
    h.write(
        "CANDIDATE_NEXT=BOUND_TXT_ROUTING_DECISION_AND_CREATE_MINIMAL_REGRESSION_FIX_ONLY_IF_CODE_EVIDENCE_CONFIRMS_MISROUTING\n"
    )

print(f"TXT_TOTAL={len(details)}")
print("--- classification counts ---")
for cls, n in sorted(
    classification_counts.items(), key=lambda kv: (-kv[1], kv[0])
):
    print(f"{n}\t{cls}")

print("--- manifest kinds ---")
for kind, n in sorted(
    manifest_counts.items(), key=lambda kv: (-kv[1], kv[0])
):
    print(f"{n}\t{kind or '<EMPTY>'}")

print("--- parsed kinds ---")
for kind, n in sorted(
    parsed_counts.items(), key=lambda kv: (-kv[1], kv[0])
):
    print(f"{n}\t{kind or '<EMPTY>'}")

print(f"FILES_WITH_ROLE_LABEL_LINES={role_label_count}")
print(f"FILES_WITH_PARSED_TURNS_GT_0={turns_present_count}")
print("--- candidate next ---")
print((out / "12_CANDIDATE_NEXT.txt").read_text(encoding="utf-8"), end="")
PY

# -------------------------------------------------------------------
# Post-state proof: Stage33 itself made no live modifications.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/13_GIT_STATUS_POST.z" 2>/dev/null || true

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/13_OUTPUT_PACKAGE_COUNT_POST.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/13_RECEIPT_COUNT_POST.txt"

if cmp -s "$OUT/00_GIT_STATUS_PRE.z" "$OUT/13_GIT_STATUS_POST.z"; then
  GIT_MUTATION="NONE"
else
  GIT_MUTATION="DETECTED"
fi

PRE_PACKAGES="$(cat "$OUT/00_OUTPUT_PACKAGE_COUNT_PRE.txt")"
POST_PACKAGES="$(cat "$OUT/13_OUTPUT_PACKAGE_COUNT_POST.txt")"
PRE_RECEIPTS="$(cat "$OUT/00_RECEIPT_COUNT_PRE.txt")"
POST_RECEIPTS="$(cat "$OUT/13_RECEIPT_COUNT_POST.txt")"

if [ "$PRE_PACKAGES" = "$POST_PACKAGES" ] && [ "$PRE_RECEIPTS" = "$POST_RECEIPTS" ]; then
  LIVE_OUTPUT_MUTATION="NONE"
else
  LIVE_OUTPUT_MUTATION="DETECTED"
fi

if [ "$GIT_MUTATION" = "NONE" ] && [ "$LIVE_OUTPUT_MUTATION" = "NONE" ]; then
  STATUS="PASS"
  NEXT="READ_STAGE33_ROUTING_EVIDENCE_AND_BOUND_ONLY_CONFIRMED_TXT_CODE_EDGE"
else
  STATUS="FAIL"
  NEXT="PRESERVE_STAGE33_MUTATION_EVIDENCE_AND_REPAIR_ONLY_BOUNDING_EDGE"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_BOUND_TXT_VALIDATOR_FAMILY_STAGE33
UTC=$TS
STATUS=$STATUS
STAGE32=$LATEST32
STAGE30=$STAGE30
TXT_TOTAL=40
SOURCE_HASHES=PASS
REPOSITORY_STATUS_MUTATION=$GIT_MUTATION
LIVE_OUTPUT_MUTATION=$LIVE_OUTPUT_MUTATION
PRE_OUTPUT_PACKAGES=$PRE_PACKAGES
POST_OUTPUT_PACKAGES=$POST_PACKAGES
PRE_RECEIPTS=$PRE_RECEIPTS
POST_RECEIPTS=$POST_RECEIPTS
SOURCE_MUTATION=NONE
CANONICAL_INGEST_EXECUTED=NO
PARSER_CODE_MODIFIED=NO
VALIDATOR_CODE_MODIFIED=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
CODE_REFERENCES=$OUT/01_TXT_ROUTING_CODE_REFERENCES.txt
DETAIL=$OUT/02_TXT_DETAIL.tsv
CLASSIFICATIONS=$OUT/03_CLASSIFICATION_COUNTS.tsv
MANIFEST_KINDS=$OUT/05_MANIFEST_KIND_COUNTS.tsv
PARSED_KINDS=$OUT/06_PARSED_KIND_COUNTS.tsv
OBSERVATIONS=$OUT/10_OBSERVATIONS.tsv
INTERPRETATIONS=$OUT/11_INTERPRETATIONS.tsv
CANDIDATE_NEXT=$OUT/12_CANDIDATE_NEXT.txt
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- classifications ---"
cat "$OUT/03_CLASSIFICATION_COUNTS.tsv"
echo
echo "--- manifest kinds ---"
cat "$OUT/05_MANIFEST_KIND_COUNTS.tsv"
echo
echo "--- candidate next ---"
cat "$OUT/12_CANDIDATE_NEXT.txt"
echo

if [ "$STATUS" = "PASS" ]; then
  echo "STAGE33_COMPLETE=YES"
  exit 0
fi

echo "STAGE33_COMPLETE=NO"
exit 1
