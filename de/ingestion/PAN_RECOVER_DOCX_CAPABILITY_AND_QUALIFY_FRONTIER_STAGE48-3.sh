#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
FIRST_CORPUS="$HOME/Difference-Engine-LEGACY-STALE-DECOMPOSED"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_RECOVER_DOCX_CAPABILITY_AND_QUALIFY_FRONTIER_$TS-STAGE48"

mkdir -p "$OUT"

echo "=== PAN — RECOVER DOCX CAPABILITY + QUALIFY FRONTIER / STAGE 48 ==="
echo "CURRENT=$CURRENT"
echo "FIRST_CORPUS=$FIRST_CORPUS"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$FIRST_CORPUS" "$TREE_HOME" "$SERVICE"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

# -------------------------------------------------------------------
# Recover latest successful Stage47.
# -------------------------------------------------------------------
STAGE47="$(
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
        "PAN_PRESERVE_CLOSURE_AND_RECOVER_NEXT_FRONTIER_STAGE47" in t
        and "STATUS=PASS" in t
        and "PROVISIONAL_UNSUPPORTED=11" in t
        and "NEXT_EXTENSION=.docx" in t
        and "NEXT_EXTENSION_COUNT=11" in t
        and "NEXT=RECOVER_EXISTING_DOCX_INGESTION_CAPABILITY_AND_QUALIFY_EXACT_UNSUPPORTED_FRONTIER_BEFORE_IMPLEMENTATION" in t
    ):
        hits.append((d.stat().st_mtime_ns, d))

if hits:
    print(max(hits)[1])
PY
)"

[ -n "$STAGE47" ] && [ -d "$STAGE47" ] || {
  echo "BLOCKER: passing Stage47 evidence not found"
  exit 22
}

DOCX_LEDGER="$STAGE47/02_PROVISIONAL_UNSUPPORTED_LEDGER.tsv"
CAPABILITY_CLUES="$STAGE47/07_EXISTING_UNSUPPORTED_CAPABILITY_CLUES.txt"

for x in "$DOCX_LEDGER" "$CAPABILITY_CLUES"; do
  [ -f "$x" ] || { echo "BLOCKER: missing Stage47 artifact $x"; exit 23; }
done

echo "STAGE47=$STAGE47"
echo "DOCX_LEDGER=$DOCX_LEDGER"
echo

# -------------------------------------------------------------------
# Pre-state. Stage48 is read-only.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/00_OUTPUT_COUNT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/00_RECEIPT_COUNT_PRE.txt"

# -------------------------------------------------------------------
# Repository-first capability recovery.
# Search current tree + git history for surviving DOCX / OOXML primitives.
# -------------------------------------------------------------------
{
  echo "===== CURRENT REPOSITORY DOCX / OOXML / OFFICE PATHS ====="
  find "$CURRENT" -xdev \
    \( -type f -o -type d \) \
    \( -iname '*docx*' \
       -o -iname '*ooxml*' \
       -o -iname '*office*' \
       -o -iname '*wordprocessing*' \
       -o -iname '*document_xml*' \
       -o -iname '*zipfile*' \) \
    -print 2>/dev/null | sort

  echo
  echo "===== CURRENT REPOSITORY CODE / DOC REFERENCES ====="
  grep -R -n -E \
    '\.docx|docx|OOXML|WordprocessingML|word/document\.xml|python-docx|zipfile|application/vnd\.openxmlformats-officedocument' \
    "$CURRENT" \
    --include='*.py' \
    --include='*.md' \
    --include='*.json' \
    --include='*.txt' \
    --exclude-dir='.git' \
    --exclude-dir='output' \
    --exclude-dir='test_output' \
    2>/dev/null | head -5000 || true

  echo
  echo "===== GIT HISTORY DOCX / OOXML HITS ====="
  git -C "$CURRENT" log --all --oneline --decorate -- \
    ':(glob)**/*docx*' \
    ':(glob)**/*office*' \
    ':(glob)**/*ooxml*' \
    2>/dev/null || true

  echo
  echo "===== TRACKED FILE NAMES WITH DOCX/OFFICE/OOXML ====="
  git -C "$CURRENT" ls-files \
    | grep -Ei 'docx|office|ooxml|wordprocessing|document_xml' \
    || true
} > "$OUT/01_REPOSITORY_DOCX_CAPABILITY_RECOVERY.txt"

# Preserve Stage47 clue file beside deeper recovery evidence.
cp -a "$CAPABILITY_CLUES" "$OUT/01_STAGE47_CAPABILITY_CLUES.txt"

# Installed runtime capability is observation, not repository authority.
"$PYTHON" - <<'PY' > "$OUT/02_RUNTIME_DOCX_CAPABILITIES.txt"
import importlib.util
import sys
import zipfile
import xml.etree.ElementTree as ET

print(f"PYTHON={sys.version.split()[0]}")
print("STDLIB_ZIPFILE=YES")
print("STDLIB_XML_ETREE=YES")
for name in ("docx", "lxml", "mammoth"):
    spec = importlib.util.find_spec(name)
    print(f"MODULE_{name.upper()}={'YES' if spec else 'NO'}")
    if spec:
        print(f"MODULE_{name.upper()}_ORIGIN={spec.origin}")
PY

# -------------------------------------------------------------------
# Qualify exact 11 DOCX sources structurally with stdlib only.
# No extraction into corpus, no mutation, no parser claims.
# -------------------------------------------------------------------
export PAN48_DOCX_LEDGER="$DOCX_LEDGER"
export PAN48_OUT="$OUT"

"$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter
import csv
import hashlib
import html
import json
import os
import re
import zipfile
import xml.etree.ElementTree as ET

ledger = Path(os.environ["PAN48_DOCX_LEDGER"])
out = Path(os.environ["PAN48_OUT"])

with ledger.open("r", encoding="utf-8", newline="") as h:
    rows = list(csv.DictReader(h, delimiter="\t"))

if len(rows) != 11:
    raise SystemExit(f"BLOCKER: expected 11 DOCX frontier rows, got {len(rows)}")

for r in rows:
    if (r.get("extension") or "").lower() != ".docx":
        raise SystemExit(
            f"BLOCKER: provisional unsupported frontier contains non-DOCX: {r.get('source')}"
        )

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
R = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
PKG_REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"

speaker_re = re.compile(
    r"^\s*(User|Assistant|Human|ChatGPT|System|You|AI)\s*[:>\-]\s*(.*)$",
    re.I,
)

def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def xml_text_paragraphs(xml_bytes):
    root = ET.fromstring(xml_bytes)
    paragraphs = []
    for p in root.iter(W + "p"):
        parts = []
        for node in p.iter():
            if node.tag == W + "t" and node.text:
                parts.append(node.text)
            elif node.tag == W + "tab":
                parts.append("\t")
            elif node.tag == W + "br":
                parts.append("\n")
        text = "".join(parts).strip()
        if text:
            paragraphs.append(text)
    return paragraphs

def content_type(zipf):
    try:
        data = zipf.read("[Content_Types].xml")
        root = ET.fromstring(data)
        vals = []
        for node in root:
            ct = node.attrib.get("ContentType", "")
            pn = node.attrib.get("PartName", "")
            if ct:
                vals.append((pn, ct))
        return vals
    except Exception:
        return []

def relationships(zipf):
    rels = []
    name = "word/_rels/document.xml.rels"
    if name not in zipf.namelist():
        return rels
    try:
        root = ET.fromstring(zipf.read(name))
        for node in root:
            rels.append({
                "Id": node.attrib.get("Id", ""),
                "Type": node.attrib.get("Type", ""),
                "Target": node.attrib.get("Target", ""),
                "TargetMode": node.attrib.get("TargetMode", ""),
            })
    except Exception:
        pass
    return rels

def core_properties(zipf):
    result = {}
    name = "docProps/core.xml"
    if name not in zipf.namelist():
        return result
    try:
        root = ET.fromstring(zipf.read(name))
        for node in root:
            tag = node.tag.rsplit("}", 1)[-1]
            if node.text:
                result[tag] = node.text.strip()
    except Exception:
        pass
    return result

detail = []
hash_failures = []
class_counts = Counter()
marker_counts = Counter()

for r in rows:
    source = Path(r["source"]).resolve()
    if not source.is_file():
        raise SystemExit(f"BLOCKER: DOCX source missing: {source}")

    actual_hash = sha256(source)
    expected_hash = (r.get("sha256") or "").strip()

    if not expected_hash or actual_hash != expected_hash:
        hash_failures.append(str(source))

    valid_zip = False
    ooxml_docx = False
    document_xml = False
    document_xml_valid = False
    paragraphs = []
    rels = []
    props = {}
    names = []
    exception = ""
    external_links = 0
    embedded_objects = 0
    images = 0

    try:
        with zipfile.ZipFile(source, "r") as z:
            bad_member = z.testzip()
            if bad_member is not None:
                raise RuntimeError(f"bad_zip_member:{bad_member}")

            valid_zip = True
            names = z.namelist()
            document_xml = "word/document.xml" in names

            cts = content_type(z)
            ooxml_docx = any(
                ct == "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"
                for _, ct in cts
            )

            if document_xml:
                try:
                    paragraphs = xml_text_paragraphs(z.read("word/document.xml"))
                    document_xml_valid = True
                except Exception as e:
                    exception = f"document_xml:{type(e).__name__}: {e}"

            rels = relationships(z)
            props = core_properties(z)

            external_links = sum(
                1 for rel in rels
                if rel.get("TargetMode", "").lower() == "external"
            )
            embedded_objects = sum(
                1 for n in names
                if n.startswith("word/embeddings/")
            )
            images = sum(
                1 for n in names
                if n.startswith("word/media/")
            )

    except Exception as e:
        exception = f"{type(e).__name__}: {e}"

    role_lines = []
    role_counts = Counter()
    for i, para in enumerate(paragraphs, start=1):
        m = speaker_re.match(para)
        if m:
            role = m.group(1).lower()
            role_counts[role] += 1
            role_lines.append((i, role, para[:300]))

    joined = "\n".join(paragraphs)
    has_user_token = bool(re.search(r"\b(user|human|you)\b", joined, re.I))
    has_assistant_token = bool(re.search(r"\b(assistant|chatgpt|ai)\b", joined, re.I))

    if not valid_zip:
        cls = "NOT_VALID_ZIP"
    elif not ooxml_docx:
        cls = "ZIP_NOT_STANDARD_DOCX_MAIN_CONTENT_TYPE"
    elif not document_xml:
        cls = "DOCX_MISSING_WORD_DOCUMENT_XML"
    elif not document_xml_valid:
        cls = "DOCX_DOCUMENT_XML_INVALID"
    elif not paragraphs:
        cls = "DOCX_NO_TEXT_PARAGRAPHS"
    elif role_lines:
        cls = "DOCX_EXPLICIT_SPEAKER_MARKERS"
    elif has_user_token and has_assistant_token:
        cls = "DOCX_CONVERSATION_TOKENS_NO_LINE_MARKERS"
    else:
        cls = "DOCX_TEXT_NO_CONFIRMED_CONVERSATION_MARKERS"

    class_counts[cls] += 1
    marker_counts["explicit_role_marker_files"] += int(bool(role_lines))
    marker_counts["files_with_user_token"] += int(has_user_token)
    marker_counts["files_with_assistant_token"] += int(has_assistant_token)
    marker_counts["files_with_external_links"] += int(external_links > 0)
    marker_counts["files_with_embedded_objects"] += int(embedded_objects > 0)
    marker_counts["files_with_images"] += int(images > 0)

    detail.append({
        "source": str(source),
        "sha256": actual_hash,
        "bytes": source.stat().st_size,
        "valid_zip": valid_zip,
        "standard_docx_main_content_type": ooxml_docx,
        "word_document_xml_present": document_xml,
        "word_document_xml_valid": document_xml_valid,
        "paragraph_count": len(paragraphs),
        "character_count": len(joined),
        "first_paragraph": paragraphs[0][:300] if paragraphs else "",
        "core_title": props.get("title", ""),
        "core_subject": props.get("subject", ""),
        "core_creator": props.get("creator", ""),
        "explicit_role_marker_count": len(role_lines),
        "role_counts": json.dumps(role_counts, sort_keys=True),
        "first_role_marker": (
            f"{role_lines[0][0]}:{role_lines[0][1]}:{role_lines[0][2]}"
            if role_lines else ""
        ),
        "has_user_or_human_token": has_user_token,
        "has_assistant_or_chatgpt_token": has_assistant_token,
        "relationship_count": len(rels),
        "external_relationship_count": external_links,
        "embedded_object_count": embedded_objects,
        "image_count": images,
        "zip_member_count": len(names),
        "qualification_class": cls,
        "exception": exception,
    })

if hash_failures:
    (out / "HASH_FAILURES.txt").write_text(
        "\n".join(hash_failures) + "\n",
        encoding="utf-8",
    )
    raise SystemExit(f"BLOCKER: {len(hash_failures)} DOCX source hash failures")

fields = list(detail[0].keys())
with (out / "03_DOCX_QUALIFICATION_LEDGER.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(detail)

with (out / "04_DOCX_CLASS_COUNTS.tsv").open("w", encoding="utf-8") as h:
    h.write("count\tqualification_class\n")
    for cls, n in sorted(class_counts.items(), key=lambda kv: (-kv[1], kv[0])):
        h.write(f"{n}\t{cls}\n")

with (out / "05_DOCX_MARKER_COUNTS.tsv").open("w", encoding="utf-8") as h:
    h.write("count\tobservation\n")
    for k, n in sorted(marker_counts.items()):
        h.write(f"{n}\t{k}\n")

# Preserve short per-file text preview as evidence without dumping full source content.
with (out / "06_DOCX_TEXT_PREVIEWS.txt").open("w", encoding="utf-8") as h:
    for d in detail:
        h.write(f"===== {d['source']} =====\n")
        h.write(f"class={d['qualification_class']}\n")
        h.write(f"paragraph_count={d['paragraph_count']}\n")
        h.write(f"first_paragraph={d['first_paragraph']}\n")
        h.write(f"first_role_marker={d['first_role_marker']}\n")
        h.write("\n")

# Candidate next remains capability recovery / parser contract, not implementation.
standard_valid = sum(
    1 for d in detail
    if d["valid_zip"]
    and d["standard_docx_main_content_type"]
    and d["word_document_xml_present"]
    and d["word_document_xml_valid"]
)
explicit_conv = sum(
    1 for d in detail
    if d["qualification_class"] == "DOCX_EXPLICIT_SPEAKER_MARKERS"
)

with (out / "07_CANDIDATE_NEXT.txt").open("w", encoding="utf-8") as h:
    h.write("DOCX_FRONTIER=11\n")
    h.write(f"STANDARD_VALID_DOCX={standard_valid}\n")
    h.write(f"EXPLICIT_CONVERSATION_MARKER_FILES={explicit_conv}\n")

    if standard_valid == 11:
        h.write(
            "CANDIDATE_NEXT=RECOVER_OR_DEFINE_MINIMAL_DOCX_EXTRACTION_CONTRACT_FROM_SURVIVING_REPOSITORY_PRIMITIVES_AND_BUILD_SANDBOX_ADAPTER_ONLY\n"
        )
    else:
        h.write(
            "CANDIDATE_NEXT=CLASSIFY_NONSTANDARD_DOCX_CASES_BEFORE_ANY_ADAPTER_IMPLEMENTATION\n"
        )

print("DOCX_FRONTIER=11")
print(f"STANDARD_VALID_DOCX={standard_valid}")
print(f"EXPLICIT_CONVERSATION_MARKER_FILES={explicit_conv}")
print("--- qualification classes ---")
print((out / "04_DOCX_CLASS_COUNTS.tsv").read_text(encoding="utf-8"), end="")
print("--- marker observations ---")
print((out / "05_DOCX_MARKER_COUNTS.tsv").read_text(encoding="utf-8"), end="")
print("--- candidate next ---")
print((out / "07_CANDIDATE_NEXT.txt").read_text(encoding="utf-8"), end="")
PY

# -------------------------------------------------------------------
# Classify repository recovery evidence mechanically.
# -------------------------------------------------------------------
export PAN48_RECOVERY="$OUT/01_REPOSITORY_DOCX_CAPABILITY_RECOVERY.txt"
export PAN48_CLUES="$OUT/01_STAGE47_CAPABILITY_CLUES.txt"
export PAN48_RUNTIME="$OUT/02_RUNTIME_DOCX_CAPABILITIES.txt"
export PAN48_OUT="$OUT"

"$PYTHON" - <<'PY'
from pathlib import Path
import os
import re

recovery = Path(os.environ["PAN48_RECOVERY"]).read_text(
    encoding="utf-8", errors="replace"
)
clues = Path(os.environ["PAN48_CLUES"]).read_text(
    encoding="utf-8", errors="replace"
)
runtime = Path(os.environ["PAN48_RUNTIME"]).read_text(
    encoding="utf-8", errors="replace"
)
out = Path(os.environ["PAN48_OUT"])

combined = recovery + "\n" + clues

# Strong evidence requires an actual surviving parser/adapter/module path,
# not mere prose mention of DOCX.
strong_patterns = [
    r"service/.+docx.+\.py",
    r"parsers/.+docx.+\.py",
    r"docx.+parser.+\.py",
    r"office.+parser.+\.py",
    r"ooxml.+\.py",
]

strong_hits = []
for pattern in strong_patterns:
    strong_hits.extend(re.findall(pattern, combined, flags=re.I))

python_docx = "MODULE_DOCX=YES" in runtime

if strong_hits:
    repo_state = "SURVIVING_DOCX_IMPLEMENTATION_CANDIDATE_FOUND"
elif re.search(r"\.docx|docx|OOXML|WordprocessingML", combined, re.I):
    repo_state = "DOCX_REFERENCES_FOUND_NO_CONFIRMED_SERVICE_IMPLEMENTATION"
else:
    repo_state = "NO_DOCX_CAPABILITY_RECOVERED"

(out / "08_CAPABILITY_RECOVERY_CLASSIFICATION.txt").write_text(
    f"REPOSITORY_DOCX_STATE={repo_state}\n"
    f"RUNTIME_PYTHON_DOCX={'YES' if python_docx else 'NO'}\n"
    f"STRONG_IMPLEMENTATION_HITS={len(set(strong_hits))}\n"
    + "".join(f"STRONG_HIT={x}\n" for x in sorted(set(strong_hits))),
    encoding="utf-8",
)

print((out / "08_CAPABILITY_RECOVERY_CLASSIFICATION.txt").read_text(
    encoding="utf-8"
), end="")
PY

# -------------------------------------------------------------------
# Post-state proof.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/09_GIT_STATUS_POST.z" 2>/dev/null || true

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/09_OUTPUT_COUNT_POST.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/09_RECEIPT_COUNT_POST.txt"

GIT_MUTATION="NONE"
cmp -s "$OUT/00_GIT_STATUS_PRE.z" "$OUT/09_GIT_STATUS_POST.z" || GIT_MUTATION="DETECTED"

PRE_OUTPUT="$(cat "$OUT/00_OUTPUT_COUNT_PRE.txt")"
POST_OUTPUT="$(cat "$OUT/09_OUTPUT_COUNT_POST.txt")"
PRE_RECEIPTS="$(cat "$OUT/00_RECEIPT_COUNT_PRE.txt")"
POST_RECEIPTS="$(cat "$OUT/09_RECEIPT_COUNT_POST.txt")"

LIVE_MUTATION="NONE"
if [ "$PRE_OUTPUT" != "$POST_OUTPUT" ] || [ "$PRE_RECEIPTS" != "$POST_RECEIPTS" ]; then
  LIVE_MUTATION="DETECTED"
fi

NEXT="$(sed -n 's/^CANDIDATE_NEXT=//p' "$OUT/07_CANDIDATE_NEXT.txt" | head -1)"

if [ "$GIT_MUTATION" = "NONE" ] && [ "$LIVE_MUTATION" = "NONE" ]; then
  STATUS="PASS"
else
  STATUS="FAIL"
  NEXT="PRESERVE_STAGE48_MUTATION_EVIDENCE"
fi

cat > "$OUT/CHANGELOG_EVENT.txt" <<EOF
UTC=$TS
EVENT=DOCX_UNSUPPORTED_FRONTIER_CAPABILITY_RECOVERED_AND_QUALIFIED
CLASSIFICATION=OBSERVED_FRONTIER
STAGE47=$STAGE47
DOCX_FRONTIER=11
SOURCE_HASHES=PASS
REPOSITORY_MUTATION=$GIT_MUTATION
LIVE_OUTPUT_MUTATION=$LIVE_MUTATION
EOF

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_RECOVER_DOCX_CAPABILITY_AND_QUALIFY_FRONTIER_STAGE48
UTC=$TS
STATUS=$STATUS
STAGE47=$STAGE47
DOCX_FRONTIER=11
SOURCE_HASHES=PASS
REPOSITORY_STATUS_MUTATION=$GIT_MUTATION
LIVE_OUTPUT_MUTATION=$LIVE_MUTATION
SOURCE_MUTATION=NONE
LIVE_INGESTION_EXECUTED=NO
PARSER_CODE_MODIFIED=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
REPOSITORY_CAPABILITY_RECOVERY=$OUT/01_REPOSITORY_DOCX_CAPABILITY_RECOVERY.txt
RUNTIME_CAPABILITIES=$OUT/02_RUNTIME_DOCX_CAPABILITIES.txt
DOCX_QUALIFICATION_LEDGER=$OUT/03_DOCX_QUALIFICATION_LEDGER.tsv
DOCX_CLASS_COUNTS=$OUT/04_DOCX_CLASS_COUNTS.tsv
DOCX_MARKER_COUNTS=$OUT/05_DOCX_MARKER_COUNTS.tsv
DOCX_PREVIEWS=$OUT/06_DOCX_TEXT_PREVIEWS.txt
CANDIDATE_NEXT=$OUT/07_CANDIDATE_NEXT.txt
CAPABILITY_CLASSIFICATION=$OUT/08_CAPABILITY_RECOVERY_CLASSIFICATION.txt
CHANGELOG_EVENT=$OUT/CHANGELOG_EVENT.txt
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- qualification classes ---"
cat "$OUT/04_DOCX_CLASS_COUNTS.tsv"
echo
echo "--- capability recovery ---"
cat "$OUT/08_CAPABILITY_RECOVERY_CLASSIFICATION.txt"
echo
echo "--- candidate next ---"
cat "$OUT/07_CANDIDATE_NEXT.txt"
echo

if [ "$STATUS" = "PASS" ]; then
  echo "STAGE48_COMPLETE=YES"
  exit 0
fi

echo "STAGE48_COMPLETE=NO"
exit 1
