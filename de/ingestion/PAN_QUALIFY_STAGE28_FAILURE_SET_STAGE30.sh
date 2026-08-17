#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_QUALIFY_STAGE28_FAILURE_SET_$TS-STAGE30"

mkdir -p "$OUT"

echo "=== PAN — QUALIFY STAGE28 FAILURE SET / STAGE 30 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

# -------------------------------------------------------------------
# Recover latest successful Stage29. Do not infer from directory name alone.
# -------------------------------------------------------------------
LATEST29="$(
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
    if "PAN_CANONICAL_INGEST_STAGE28_PASS_SET_STAGE29" not in text:
        continue
    if "STATUS=PASS" not in text:
        continue
    if "FAIL_COUNT=0" not in text:
        continue
    if "NEXT=QUALIFY_STAGE28_FAILURE_SET" not in text:
        continue
    hits.append((d.stat().st_mtime_ns, d))

if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST29" ] && [ -d "$LATEST29" ] || {
  echo "BLOCKER: passing Stage29 evidence not found"
  exit 22
}

STAGE28="$(sed -n 's/^STAGE28=//p' "$LATEST29/SUMMARY.txt" | head -1)"
EXPECTED_FAIL="$(sed -n 's/^HELD_BACK_STAGE28_FAILURES=//p' "$LATEST29/SUMMARY.txt" | head -1)"
TARGET_PASS="$(sed -n 's/^TARGET_PASS_SET=//p' "$LATEST29/SUMMARY.txt" | head -1)"
STAGE29_LEDGER="$(sed -n 's/^LEDGER=//p' "$LATEST29/SUMMARY.txt" | head -1)"

[ -n "$STAGE28" ] && [ -d "$STAGE28" ] || {
  echo "BLOCKER: Stage28 directory missing: $STAGE28"
  exit 23
}

FAIL_SET="$(sed -n 's/^FAIL_SET=//p' "$STAGE28/SUMMARY.txt" | head -1)"
PASS_SET="$(sed -n 's/^PASS_SET=//p' "$STAGE28/SUMMARY.txt" | head -1)"
STAGE28_LEDGER="$STAGE28/08_DRYRUN_LEDGER.tsv"
HASH_LEDGER="$STAGE28/07_SOURCE_HASHES_BEFORE.tsv"

for x in "$FAIL_SET" "$PASS_SET" "$STAGE28_LEDGER" "$HASH_LEDGER" "$STAGE29_LEDGER"; do
  [ -f "$x" ] || { echo "BLOCKER: missing required artifact $x"; exit 24; }
done

ACTUAL_FAIL="$(grep -c . "$FAIL_SET" 2>/dev/null || true)"
ACTUAL_PASS="$(grep -c . "$PASS_SET" 2>/dev/null || true)"

[ "$ACTUAL_FAIL" = "$EXPECTED_FAIL" ] || {
  echo "BLOCKER: failure-set count drift expected=$EXPECTED_FAIL actual=$ACTUAL_FAIL"
  exit 25
}

[ "$ACTUAL_PASS" = "$TARGET_PASS" ] || {
  echo "BLOCKER: pass-set count drift expected=$TARGET_PASS actual=$ACTUAL_PASS"
  exit 26
}

echo "STAGE29=$LATEST29"
echo "STAGE28=$STAGE28"
echo "FAIL_SET=$FAIL_SET"
echo "FAIL_COUNT=$ACTUAL_FAIL"
echo

# -------------------------------------------------------------------
# Pre-state: Stage30 is qualification only and must be read-only to repo/source.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true
sha256sum "$OUT/00_GIT_STATUS_PRE.z" > "$OUT/00_GIT_STATUS_PRE.sha256"

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/00_OUTPUT_PACKAGE_COUNT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/00_RECEIPT_COUNT_PRE.txt"

export PAN30_STAGE28="$STAGE28"
export PAN30_FAIL_SET="$FAIL_SET"
export PAN30_PASS_SET="$PASS_SET"
export PAN30_STAGE28_LEDGER="$STAGE28_LEDGER"
export PAN30_HASH_LEDGER="$HASH_LEDGER"
export PAN30_STAGE29_LEDGER="$STAGE29_LEDGER"
export PAN30_OUT="$OUT"

# -------------------------------------------------------------------
# Qualification. No ingest call. No source writes. No repository writes.
# -------------------------------------------------------------------
"$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter
import csv
import hashlib
import json
import os
import re

stage28 = Path(os.environ["PAN30_STAGE28"])
fail_set = Path(os.environ["PAN30_FAIL_SET"])
pass_set = Path(os.environ["PAN30_PASS_SET"])
stage28_ledger = Path(os.environ["PAN30_STAGE28_LEDGER"])
hash_ledger = Path(os.environ["PAN30_HASH_LEDGER"])
stage29_ledger = Path(os.environ["PAN30_STAGE29_LEDGER"])
out = Path(os.environ["PAN30_OUT"])

fail_sources = [
    Path(x).resolve()
    for x in fail_set.read_text(encoding="utf-8").splitlines()
    if x.strip()
]
pass_sources = {
    str(Path(x).resolve())
    for x in pass_set.read_text(encoding="utf-8").splitlines()
    if x.strip()
}

if len(fail_sources) != len(set(map(str, fail_sources))):
    raise SystemExit("BLOCKER: duplicate path in Stage28 failure set")

# Stage28 source hash ledger.
expected_hash = {}
for line in hash_ledger.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    parts = line.split("\t", 2)
    if len(parts) != 3:
        raise SystemExit("BLOCKER: malformed Stage28 source hash ledger")
    digest, size, path = parts
    expected_hash[str(Path(path).resolve())] = (digest, int(size))

# Stage28 dry-run rows keyed by source.
stage28_rows = {}
with stage28_ledger.open("r", encoding="utf-8", newline="") as h:
    reader = csv.DictReader(h, delimiter="\t")
    for row in reader:
        source = str(Path(row["source"]).resolve())
        stage28_rows[source] = row

# Stage29 live canonical ledger: prove no Stage28 failure-set overlap.
stage29_sources = set()
with stage29_ledger.open("r", encoding="utf-8", newline="") as h:
    reader = csv.DictReader(h, delimiter="\t")
    for row in reader:
        source = row.get("source", "").strip()
        if source:
            stage29_sources.add(str(Path(source).resolve()))

overlap = sorted(set(map(str, fail_sources)) & stage29_sources)
(out / "00_STAGE29_FAILURE_SET_OVERLAP.txt").write_text(
    "\n".join(overlap) + ("\n" if overlap else ""),
    encoding="utf-8",
)
if overlap:
    raise SystemExit(
        f"BLOCKER: {len(overlap)} Stage28 failure sources appear in Stage29 canonical ledger"
    )

def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def clean_sig(row):
    exc = (row.get("exception") or "").strip()
    errors = (row.get("errors") or "").strip()
    if exc:
        return "EXCEPTION", exc
    if errors:
        try:
            parsed = json.loads(errors)
            if isinstance(parsed, list):
                return "VALIDATION", json.dumps(
                    sorted(str(x) for x in parsed),
                    ensure_ascii=False,
                    separators=(",", ":"),
                )
        except Exception:
            pass
        return "VALIDATION", errors
    return "UNKNOWN", ""

def utf8_state(data: bytes):
    try:
        text = data.decode("utf-8")
        return True, text
    except UnicodeDecodeError:
        return False, None

def bom_name(data: bytes):
    if data.startswith(b"\xef\xbb\xbf"):
        return "UTF-8-BOM"
    if data.startswith(b"\xff\xfe\x00\x00"):
        return "UTF-32-LE"
    if data.startswith(b"\x00\x00\xfe\xff"):
        return "UTF-32-BE"
    if data.startswith(b"\xff\xfe"):
        return "UTF-16-LE"
    if data.startswith(b"\xfe\xff"):
        return "UTF-16-BE"
    return ""

def json_diag(data: bytes):
    result = {
        "json_utf8_parse": "",
        "json_alt_decode_candidate": "",
        "json_top_type": "",
        "json_top_keys": "",
        "json_error": "",
    }

    if len(data) == 0:
        result["json_utf8_parse"] = "EMPTY"
        result["json_error"] = "zero_bytes"
        return result

    try:
        text = data.decode("utf-8-sig")
    except UnicodeDecodeError as e:
        result["json_utf8_parse"] = "UTF8_DECODE_FAIL"
        result["json_error"] = f"{type(e).__name__}: {e}"

        # Diagnostic only: test common deterministic encodings. Do not transform source.
        candidates = []
        for enc in ("utf-16", "utf-16-le", "utf-16-be", "cp1252", "latin-1"):
            try:
                t = data.decode(enc)
                json.loads(t)
                candidates.append(enc)
            except Exception:
                pass
        result["json_alt_decode_candidate"] = ",".join(candidates)
        return result

    try:
        obj = json.loads(text)
        result["json_utf8_parse"] = "PASS"
        result["json_top_type"] = type(obj).__name__
        if isinstance(obj, dict):
            keys = [str(k) for k in list(obj.keys())[:40]]
            result["json_top_keys"] = json.dumps(keys, ensure_ascii=False)
    except Exception as e:
        result["json_utf8_parse"] = "JSON_PARSE_FAIL"
        result["json_error"] = f"{type(e).__name__}: {e}"

    return result

def text_diag(data: bytes):
    result = {
        "utf8_decode": "",
        "bom": bom_name(data),
        "nul_ratio": 0.0,
        "nonblank": "",
        "first_nonblank": "",
        "markdown_h1": "",
    }
    result["nul_ratio"] = (
        round(data.count(b"\x00") / len(data), 6) if data else 0.0
    )
    ok, text = utf8_state(data)
    result["utf8_decode"] = "PASS" if ok else "FAIL"

    if ok and text is not None:
        lines = text.splitlines()
        nonblank = [x.strip() for x in lines if x.strip()]
        result["nonblank"] = "YES" if nonblank else "NO"
        if nonblank:
            result["first_nonblank"] = nonblank[0][:240]
            result["markdown_h1"] = (
                "YES" if re.match(r"^#\s+\S", nonblank[0]) else "NO"
            )
    return result

def mechanical_bucket(kind, signature):
    if kind == "VALIDATION":
        return "VALIDATION_ERRORS_ONLY"
    if kind == "EXCEPTION":
        if signature.startswith("JSONDecodeError"):
            return "EXCEPTION_JSON_DECODE"
        if signature.startswith("UnicodeDecodeError"):
            return "EXCEPTION_UNICODE_DECODE"
        return "EXCEPTION_OTHER"
    return "UNCLASSIFIED"

rows = []
class_counts = Counter()
bucket_counts = Counter()
ext_counts = Counter()
hash_failures = []

for source in fail_sources:
    s = str(source)

    if s in pass_sources:
        raise SystemExit(f"BLOCKER: source occurs in both Stage28 pass/fail sets: {source}")
    if s not in stage28_rows:
        raise SystemExit(f"BLOCKER: failure source absent from Stage28 ledger: {source}")
    if s not in expected_hash:
        raise SystemExit(f"BLOCKER: failure source absent from Stage28 hash ledger: {source}")
    if not source.is_file():
        raise SystemExit(f"BLOCKER: source missing: {source}")

    data = source.read_bytes()
    digest = sha256_bytes(data)
    exp_digest, exp_size = expected_hash[s]
    hash_ok = digest == exp_digest and len(data) == exp_size
    if not hash_ok:
        hash_failures.append(s)

    r28 = stage28_rows[s]
    failure_kind, failure_signature = clean_sig(r28)
    bucket = mechanical_bucket(failure_kind, failure_signature)

    ext = source.suffix.lower()
    ext_counts[ext] += 1
    class_counts[(failure_kind, failure_signature)] += 1
    bucket_counts[bucket] += 1

    td = text_diag(data)
    jd = json_diag(data) if ext == ".json" else {
        "json_utf8_parse": "",
        "json_alt_decode_candidate": "",
        "json_top_type": "",
        "json_top_keys": "",
        "json_error": "",
    }

    package = Path(r28.get("output") or "")
    package_exists = package.is_dir()
    manifest_kind = r28.get("manifest_kind") or ""
    validation_passed = r28.get("validation_passed") or ""

    validation_report_errors = ""
    parsed_kind = ""

    if package_exists:
        vr = package / "reports/validation.json"
        pr = package / "structure/parsed.json"

        if vr.is_file():
            try:
                v = json.loads(vr.read_text(encoding="utf-8"))
                validation_report_errors = json.dumps(
                    v.get("errors", []),
                    ensure_ascii=False,
                    sort_keys=True,
                )
            except Exception as e:
                validation_report_errors = f"READ_ERROR:{type(e).__name__}:{e}"

        if pr.is_file():
            try:
                p = json.loads(pr.read_text(encoding="utf-8"))
                if isinstance(p, dict):
                    parsed_kind = str(p.get("kind", ""))
            except Exception:
                pass

    rows.append({
        "extension": ext,
        "mechanical_bucket": bucket,
        "failure_kind": failure_kind,
        "failure_signature": failure_signature,
        "stage28_manifest_kind": manifest_kind,
        "stage28_validation_passed": validation_passed,
        "stage28_output_exists": "YES" if package_exists else "NO",
        "validation_report_errors": validation_report_errors,
        "parsed_kind": parsed_kind,
        "sha256_stage28": exp_digest,
        "sha256_now": digest,
        "source_hash_match": "PASS" if hash_ok else "FAIL",
        "bytes": len(data),
        "bom": td["bom"],
        "utf8_decode": td["utf8_decode"],
        "nul_ratio": td["nul_ratio"],
        "nonblank": td["nonblank"],
        "first_nonblank": td["first_nonblank"],
        "markdown_h1": td["markdown_h1"],
        "json_utf8_parse": jd["json_utf8_parse"],
        "json_alt_decode_candidate": jd["json_alt_decode_candidate"],
        "json_top_type": jd["json_top_type"],
        "json_top_keys": jd["json_top_keys"],
        "json_error": jd["json_error"],
        "source": s,
        "stage28_output": str(package) if r28.get("output") else "",
    })

if hash_failures:
    (out / "HASH_FAILURES.txt").write_text(
        "\n".join(hash_failures) + "\n",
        encoding="utf-8",
    )
    raise SystemExit(f"BLOCKER: {len(hash_failures)} source hashes drifted since Stage28")

columns = [
    "extension",
    "mechanical_bucket",
    "failure_kind",
    "failure_signature",
    "stage28_manifest_kind",
    "stage28_validation_passed",
    "stage28_output_exists",
    "validation_report_errors",
    "parsed_kind",
    "sha256_stage28",
    "sha256_now",
    "source_hash_match",
    "bytes",
    "bom",
    "utf8_decode",
    "nul_ratio",
    "nonblank",
    "first_nonblank",
    "markdown_h1",
    "json_utf8_parse",
    "json_alt_decode_candidate",
    "json_top_type",
    "json_top_keys",
    "json_error",
    "source",
    "stage28_output",
]

with (out / "01_QUALIFICATION_LEDGER.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    w = csv.DictWriter(h, fieldnames=columns, delimiter="\t")
    w.writeheader()
    w.writerows(rows)

with (out / "02_FAILURE_CLASS_COUNTS.tsv").open("w", encoding="utf-8") as h:
    h.write("count\tfailure_kind\tfailure_signature\n")
    for (kind, sig), n in class_counts.most_common():
        h.write(f"{n}\t{kind}\t{sig}\n")

with (out / "03_MECHANICAL_BUCKET_COUNTS.tsv").open("w", encoding="utf-8") as h:
    h.write("count\tmechanical_bucket\n")
    for bucket, n in bucket_counts.most_common():
        h.write(f"{n}\t{bucket}\n")

with (out / "04_EXTENSION_COUNTS.tsv").open("w", encoding="utf-8") as h:
    h.write("extension\tcount\n")
    for ext, n in sorted(ext_counts.items()):
        h.write(f"{ext}\t{n}\n")

with (out / "05_JSON_DIAGNOSTICS.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    fields = [
        "source", "bytes", "bom", "utf8_decode", "json_utf8_parse",
        "json_alt_decode_candidate", "json_top_type", "json_top_keys",
        "json_error", "failure_signature",
    ]
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()
    for row in rows:
        if row["extension"] == ".json":
            w.writerow({k: row[k] for k in fields})

with (out / "06_TEXT_DIAGNOSTICS.tsv").open(
    "w", encoding="utf-8", newline=""
) as h:
    fields = [
        "source", "extension", "bytes", "bom", "utf8_decode", "nul_ratio",
        "nonblank", "markdown_h1", "first_nonblank", "failure_signature",
    ]
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()
    for row in rows:
        if row["extension"] in {".md", ".txt"}:
            w.writerow({k: row[k] for k in fields})

(out / "07_SOURCE_HASH_VERIFICATION.txt").write_text(
    f"VERIFIED={len(rows)}\nSOURCE_HASHES=PASS\n",
    encoding="utf-8",
)

(out / "08_STAGE29_SEPARATION.txt").write_text(
    "STAGE28_FAILURE_SET_IN_STAGE29_LEDGER=0\n"
    f"STAGE28_FAILURE_SET_COUNT={len(fail_sources)}\n"
    f"STAGE29_CANONICAL_SOURCE_COUNT={len(stage29_sources)}\n"
    "SEPARATION=PASS\n",
    encoding="utf-8",
)

# Preserve an unpromoted changelog event as evidence. Canonical changelog
# destination is intentionally not invented here.
(out / "CHANGELOG_EVENT.txt").write_text(
    "UTC_STAGE30=" + os.environ.get("PAN30_OUT", "") + "\n"
    "EVENT=STAGE29_CANONICAL_PASS_SET_INGEST_ACCEPTED_AND_STAGE30_FAILURE_QUALIFICATION\n"
    f"STAGE29={os.environ.get('PAN30_STAGE28','')}\n"
    f"FAILURE_SET_QUALIFIED={len(fail_sources)}\n"
    "SOURCE_MUTATION=NONE\n"
    "REPOSITORY_MUTATION_BY_STAGE30=NONE\n"
    "STATUS=CANDIDATE_CHANGELOG_EVENT_PENDING_CANONICAL_CHANGELOG_RECOVERY\n",
    encoding="utf-8",
)

print(f"QUALIFIED={len(rows)}")
print("SOURCE_HASHES=PASS")
print("STAGE29_FAILURE_SET_OVERLAP=0")
print("FAILURE_CLASSES=")
for (kind, sig), n in class_counts.most_common():
    print(f"  {n}\t{kind}\t{sig}")
print("MECHANICAL_BUCKETS=")
for bucket, n in bucket_counts.most_common():
    print(f"  {n}\t{bucket}")
print("EXTENSIONS=")
for ext, n in sorted(ext_counts.items()):
    print(f"  {ext}\t{n}")
PY

# -------------------------------------------------------------------
# Verify Stage30 itself did not mutate live repository/output state.
# -------------------------------------------------------------------
git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/09_GIT_STATUS_POST.z" 2>/dev/null || true
sha256sum "$OUT/09_GIT_STATUS_POST.z" > "$OUT/09_GIT_STATUS_POST.sha256"

find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c \
  > "$OUT/09_OUTPUT_PACKAGE_COUNT_POST.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c \
  > "$OUT/09_RECEIPT_COUNT_POST.txt"

if cmp -s "$OUT/00_GIT_STATUS_PRE.z" "$OUT/09_GIT_STATUS_POST.z"; then
  GIT_MUTATION="NONE"
else
  GIT_MUTATION="DETECTED"
fi

PRE_PACKAGES="$(cat "$OUT/00_OUTPUT_PACKAGE_COUNT_PRE.txt")"
POST_PACKAGES="$(cat "$OUT/09_OUTPUT_PACKAGE_COUNT_POST.txt")"
PRE_RECEIPTS="$(cat "$OUT/00_RECEIPT_COUNT_PRE.txt")"
POST_RECEIPTS="$(cat "$OUT/09_RECEIPT_COUNT_POST.txt")"

if [ "$PRE_PACKAGES" = "$POST_PACKAGES" ] && [ "$PRE_RECEIPTS" = "$POST_RECEIPTS" ]; then
  LIVE_OUTPUT_MUTATION="NONE"
else
  LIVE_OUTPUT_MUTATION="DETECTED"
fi

if [ "$GIT_MUTATION" != "NONE" ] || [ "$LIVE_OUTPUT_MUTATION" != "NONE" ]; then
  STATUS="FAIL"
  NEXT="PRESERVE_STAGE30_MUTATION_EVIDENCE_AND_REPAIR_ONLY_QUALIFICATION_EDGE"
else
  STATUS="PASS"
  NEXT="INTERPRET_STAGE30_FAILURE_CLASSES_BEFORE_ANY_REPAIR"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_QUALIFY_STAGE28_FAILURE_SET_STAGE30
UTC=$TS
STATUS=$STATUS
STAGE29=$LATEST29
STAGE28=$STAGE28
FAIL_SET=$FAIL_SET
QUALIFIED=$ACTUAL_FAIL
SOURCE_HASHES=PASS
STAGE29_FAILURE_SET_OVERLAP=0
REPOSITORY_STATUS_MUTATION=$GIT_MUTATION
LIVE_OUTPUT_MUTATION=$LIVE_OUTPUT_MUTATION
PRE_OUTPUT_PACKAGES=$PRE_PACKAGES
POST_OUTPUT_PACKAGES=$POST_PACKAGES
PRE_RECEIPTS=$PRE_RECEIPTS
POST_RECEIPTS=$POST_RECEIPTS
SOURCE_MUTATION=NONE
CANONICAL_INGEST_EXECUTED=NO
PARSER_CODE_MODIFIED=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
LEDGER=$OUT/01_QUALIFICATION_LEDGER.tsv
FAILURE_CLASSES=$OUT/02_FAILURE_CLASS_COUNTS.tsv
MECHANICAL_BUCKETS=$OUT/03_MECHANICAL_BUCKET_COUNTS.tsv
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- failure classes ---"
cat "$OUT/02_FAILURE_CLASS_COUNTS.tsv"
echo
echo "--- mechanical buckets ---"
cat "$OUT/03_MECHANICAL_BUCKET_COUNTS.tsv"
echo
echo "--- extensions ---"
cat "$OUT/04_EXTENSION_COUNTS.tsv"
echo

if [ "$STATUS" = "PASS" ]; then
  echo "STAGE30_COMPLETE=YES"
  exit 0
fi

echo "STAGE30_COMPLETE=NO"
exit 1
