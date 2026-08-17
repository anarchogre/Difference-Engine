#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_REQUALIFY_STAGE28_FAILURE_SET_$TS-STAGE37"
SANDBOX="$OUT/sandbox"

mkdir -p "$OUT" "$SANDBOX"

echo "=== PAN — REQUALIFY STAGE28 FAILURE SET / STAGE 37 ==="
echo "CURRENT=$CURRENT"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$TREE_HOME" "$SERVICE"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

LATEST36="$(
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
    if "PAN_PROMOTE_TXT_MARKDOWN_FALLBACK_STAGE36" not in t:
        continue
    if "STATUS=PASS" not in t:
        continue
    if "COMMIT_CREATED=YES" not in t:
        continue
    if "POSTCOMMIT_FULL_REGRESSION=PASS" not in t:
        continue
    if "NEXT=REQUALIFY_REMAINING_STAGE28_FAILURE_SET_AGAINST_PROMOTED_STAGE36_BEFORE_ANY_MARKDOWN_REPAIR" not in t:
        continue
    hits.append((d.stat().st_mtime_ns, d))
if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST36" ] && [ -d "$LATEST36" ] || {
  echo "BLOCKER: passing Stage36 evidence not found"
  exit 22
}

PROMOTED_COMMIT="$(sed -n 's/^COMMIT=//p' "$LATEST36/SUMMARY.txt" | head -1)"
[ -n "$PROMOTED_COMMIT" ] || {
  echo "BLOCKER: Stage36 commit missing"
  exit 23
}

git -C "$CURRENT" cat-file -e "$PROMOTED_COMMIT^{commit}" 2>/dev/null || {
  echo "BLOCKER: promoted commit unavailable: $PROMOTED_COMMIT"
  exit 24
}
git -C "$CURRENT" merge-base --is-ancestor "$PROMOTED_COMMIT" HEAD || {
  echo "BLOCKER: Stage36 commit is not ancestor of HEAD"
  exit 25
}

STAGE35="$(sed -n 's/^STAGE35=//p' "$LATEST36/SUMMARY.txt" | head -1)"
STAGE33="$(sed -n 's/^STAGE33=//p' "$STAGE35/SUMMARY.txt" | head -1)"
STAGE32="$(sed -n 's/^STAGE32=//p' "$STAGE33/SUMMARY.txt" | head -1)"
STAGE30="$(sed -n 's/^STAGE30=//p' "$STAGE32/SUMMARY.txt" | head -1)"
LEDGER="$STAGE30/01_QUALIFICATION_LEDGER.tsv"

[ -f "$LEDGER" ] || {
  echo "BLOCKER: Stage30 qualification ledger missing: $LEDGER"
  exit 26
}

echo "STAGE36=$LATEST36"
echo "PROMOTED_COMMIT=$PROMOTED_COMMIT"
echo "STAGE30=$STAGE30"
echo

git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_STATUS_PRE.z" 2>/dev/null || true

RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"
find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c > "$OUT/00_OUTPUT_COUNT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c > "$OUT/00_RECEIPT_COUNT_PRE.txt"

RUN_ALL="$SERVICE/tests/run_all.py"
if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" "$RUN_ALL"
) > "$OUT/01_PRE_REQUALIFICATION_REGRESSION.txt" 2>&1
then
  echo "BLOCKER: current regression failed"
  tail -80 "$OUT/01_PRE_REQUALIFICATION_REGRESSION.txt" || true
  exit 27
fi

export PAN37_LEDGER="$LEDGER"
export PAN37_SANDBOX="$SANDBOX"
export PAN37_OUT="$OUT"

if ! (
  cd "$CURRENT"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
    "$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter
import csv
import hashlib
import json
import os

from workspace.operational.ingestion.service.batch import ingest_sources

ledger = Path(os.environ["PAN37_LEDGER"])
sandbox = Path(os.environ["PAN37_SANDBOX"])
out = Path(os.environ["PAN37_OUT"])

with ledger.open("r", encoding="utf-8", newline="") as h:
    rows = list(csv.DictReader(h, delimiter="\t"))

if len(rows) != 106:
    raise SystemExit(f"expected 106 rows, got {len(rows)}")

results = []
hash_failures = []

for i, r in enumerate(rows, start=1):
    source = Path(r["source"]).resolve()
    if not source.is_file():
        raise SystemExit(f"source missing: {source}")

    expected = (r.get("sha256_now") or r.get("sha256_stage28") or "").strip()
    before = hashlib.sha256(source.read_bytes()).hexdigest()
    if before != expected:
        hash_failures.append(str(source))
        continue

    case = sandbox / f"{i:03d}"
    receipts = case / "receipts"
    output = case / "output"
    runroot = case / "runroot"
    receipts.mkdir(parents=True)
    output.mkdir(parents=True)
    runroot.mkdir(parents=True)

    old_cwd = Path.cwd()
    outs = []
    exc = ""
    try:
        os.chdir(runroot)
        outs = ingest_sources(
            sources=(source,),
            receipt_root=receipts,
            output_root=output,
            source_class="manual_batch",
        )
    except Exception as e:
        exc = f"{type(e).__name__}: {e}"
    finally:
        os.chdir(old_cwd)

    after = hashlib.sha256(source.read_bytes()).hexdigest()
    if after != before:
        hash_failures.append(str(source))

    manifest_kind = ""
    errors = []
    passed = False
    output_path = ""

    if exc:
        status = "EXCEPTION"
    elif len(outs) != 1:
        status = "OUTPUT_COUNT_ERROR"
        exc = f"expected one output, got {len(outs)}"
    else:
        pkg = Path(outs[0]).resolve()
        output_path = str(pkg)
        try:
            manifest = json.loads((pkg / "reports/manifest.json").read_text(encoding="utf-8"))
            validation = json.loads((pkg / "reports/validation.json").read_text(encoding="utf-8"))
            manifest_kind = str(manifest.get("kind", ""))
            passed = validation.get("passed") is True
            errors = [str(x) for x in (validation.get("errors") or [])]
            status = "PASS" if passed else "VALIDATION_FAIL"
        except Exception as e:
            status = "ARTIFACT_READ_ERROR"
            exc = f"{type(e).__name__}: {e}"

    results.append({
        "source": str(source),
        "extension": source.suffix.lower(),
        "stage30_failure_signature": r.get("failure_signature", ""),
        "current_status": status,
        "current_manifest_kind": manifest_kind,
        "current_validation_passed": passed,
        "current_validation_errors": json.dumps(errors, ensure_ascii=False, sort_keys=True),
        "exception": exc,
        "sha256": before,
        "source_hash_match": "PASS" if before == after == expected else "FAIL",
        "output": output_path,
    })

    print(f"[{i:03d}/106] {status:18s} {source.suffix.lower():5s} {source.name}", flush=True)

if hash_failures:
    (out / "SOURCE_HASH_FAILURES.txt").write_text("\n".join(hash_failures) + "\n", encoding="utf-8")
    raise SystemExit(f"{len(hash_failures)} source hash failures")

fields = list(results[0].keys())
with (out / "02_REQUALIFICATION_LEDGER.tsv").open("w", encoding="utf-8", newline="") as h:
    w = csv.DictWriter(h, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(results)

status_counts = Counter(r["current_status"] for r in results)
ext_status = Counter((r["extension"], r["current_status"]) for r in results)
error_counts = Counter()
residual_sigs = Counter()
passing_ext = Counter()

for r in results:
    if r["current_status"] == "PASS":
        passing_ext[r["extension"]] += 1
        continue
    errs = json.loads(r["current_validation_errors"])
    if errs:
        for e in errs:
            error_counts[e] += 1
        residual_sigs[json.dumps(sorted(errs), ensure_ascii=False, separators=(",", ":"))] += 1
    elif r["exception"]:
        residual_sigs[r["exception"]] += 1
    else:
        residual_sigs[r["current_status"]] += 1

def write_counter(path, header, counter):
    with path.open("w", encoding="utf-8") as h:
        h.write("\t".join(header) + "\n")
        for key, n in sorted(counter.items(), key=lambda kv: (-kv[1], str(kv[0]))):
            if not isinstance(key, tuple):
                key = (key,)
            h.write(str(n) + "\t" + "\t".join(map(str, key)) + "\n")

write_counter(out / "03_STATUS_COUNTS.tsv", ["count", "status"], status_counts)
write_counter(out / "04_EXTENSION_X_STATUS.tsv", ["count", "extension", "status"], ext_status)
write_counter(out / "05_ERROR_COUNTS.tsv", ["count", "error"], error_counts)
write_counter(out / "06_RESIDUAL_SIGNATURES.tsv", ["count", "signature"], residual_sigs)
write_counter(out / "07_NOW_PASSING_BY_EXTENSION.tsv", ["count", "extension"], passing_ext)

pass_count = status_counts.get("PASS", 0)
remaining = len(results) - pass_count

residual_by_ext = Counter()
for r in results:
    if r["current_status"] != "PASS":
        residual_by_ext[r["extension"]] += 1

with (out / "08_CANDIDATE_NEXT.txt").open("w", encoding="utf-8") as h:
    h.write(f"ORIGINAL_FAILURE_SET={len(results)}\n")
    h.write(f"NOW_PASSING={pass_count}\n")
    h.write(f"STILL_NOT_PASSING={remaining}\n")
    for ext, n in sorted(residual_by_ext.items(), key=lambda kv: (-kv[1], kv[0])):
        h.write(f"RESIDUAL_{ext.lstrip('.').upper()}={n}\n")
    if residual_by_ext:
        ext, n = sorted(residual_by_ext.items(), key=lambda kv: (-kv[1], kv[0]))[0]
        h.write(
            f"CANDIDATE_NEXT=BOUND_LARGEST_RESIDUAL_FAMILY_{ext.lstrip('.').upper()}_{n}_BEFORE_ANY_REPAIR\n"
        )
    else:
        h.write("CANDIDATE_NEXT=NO_RESIDUAL_FAILURES\n")

print()
print(f"ORIGINAL_FAILURE_SET={len(results)}")
print(f"NOW_PASSING={pass_count}")
print(f"STILL_NOT_PASSING={remaining}")
print("--- extension x status ---")
print((out / "04_EXTENSION_X_STATUS.tsv").read_text(encoding="utf-8"), end="")
print("--- error counts ---")
print((out / "05_ERROR_COUNTS.tsv").read_text(encoding="utf-8"), end="")
print("--- candidate next ---")
print((out / "08_CANDIDATE_NEXT.txt").read_text(encoding="utf-8"), end="")
PY
) > "$OUT/02_REQUALIFICATION_RUN.txt" 2>&1
then
  echo "BLOCKER: requalification failed"
  tail -100 "$OUT/02_REQUALIFICATION_RUN.txt" || true
  exit 28
fi

cat "$OUT/02_REQUALIFICATION_RUN.txt"

git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/09_GIT_STATUS_POST.z" 2>/dev/null || true
find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c > "$OUT/09_OUTPUT_COUNT_POST.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c > "$OUT/09_RECEIPT_COUNT_POST.txt"

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

NOW_PASSING="$(sed -n 's/^NOW_PASSING=//p' "$OUT/08_CANDIDATE_NEXT.txt" | head -1)"
STILL_NOT_PASSING="$(sed -n 's/^STILL_NOT_PASSING=//p' "$OUT/08_CANDIDATE_NEXT.txt" | head -1)"
NEXT="$(sed -n 's/^CANDIDATE_NEXT=//p' "$OUT/08_CANDIDATE_NEXT.txt" | head -1)"

if [ "$GIT_MUTATION" = "NONE" ] && [ "$LIVE_MUTATION" = "NONE" ]; then
  STATUS="PASS"
else
  STATUS="FAIL"
  NEXT="PRESERVE_STAGE37_MUTATION_EVIDENCE"
fi

cat > "$OUT/CHANGELOG_EVENT.txt" <<EOF
UTC=$TS
EVENT=STAGE28_FAILURE_SET_REQUALIFIED_AFTER_STAGE36_PROMOTION
CLASSIFICATION=OBSERVED_STATE
STAGE36_COMMIT=$PROMOTED_COMMIT
ORIGINAL_FAILURE_SET=106
NOW_PASSING=$NOW_PASSING
STILL_NOT_PASSING=$STILL_NOT_PASSING
SOURCE_HASHES=PASS
LIVE_INGESTION_EXECUTED=NO
REPOSITORY_MUTATION_BY_STAGE37=$GIT_MUTATION
LIVE_OUTPUT_MUTATION_BY_STAGE37=$LIVE_MUTATION
EOF

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_REQUALIFY_STAGE28_FAILURE_SET_STAGE37
UTC=$TS
STATUS=$STATUS
STAGE36=$LATEST36
PROMOTED_COMMIT=$PROMOTED_COMMIT
ORIGINAL_FAILURE_SET=106
NOW_PASSING=$NOW_PASSING
STILL_NOT_PASSING=$STILL_NOT_PASSING
SOURCE_HASHES=PASS
PRE_REQUALIFICATION_REGRESSION=PASS
REPOSITORY_STATUS_MUTATION=$GIT_MUTATION
LIVE_OUTPUT_MUTATION=$LIVE_MUTATION
SOURCE_MUTATION=NONE
LIVE_INGESTION_EXECUTED=NO
PARSER_CODE_MODIFIED=NO
VALIDATOR_CODE_MODIFIED=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
LEDGER=$OUT/02_REQUALIFICATION_LEDGER.tsv
STATUS_COUNTS=$OUT/03_STATUS_COUNTS.tsv
EXTENSION_X_STATUS=$OUT/04_EXTENSION_X_STATUS.tsv
ERROR_COUNTS=$OUT/05_ERROR_COUNTS.tsv
RESIDUAL_SIGNATURES=$OUT/06_RESIDUAL_SIGNATURES.tsv
CANDIDATE_NEXT=$OUT/08_CANDIDATE_NEXT.txt
CHANGELOG_EVENT=$OUT/CHANGELOG_EVENT.txt
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- candidate next ---"
cat "$OUT/08_CANDIDATE_NEXT.txt"
echo

if [ "$STATUS" = "PASS" ]; then
  echo "STAGE37_COMPLETE=YES"
  exit 0
fi

echo "STAGE37_COMPLETE=NO"
exit 1
