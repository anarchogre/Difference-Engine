#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
FIRST_CORPUS="$HOME/Difference-Engine-LEGACY-STALE-DECOMPOSED"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
PYTHON="/usr/bin/python3"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_FIRST_CORPUS_TEXTLIKE_DRYRUN_$TS-STAGE28"

mkdir -p "$OUT"

echo "=== PAN — FIRST CORPUS TEXTLIKE DRY RUN STAGE 28 ==="
echo "CURRENT=$CURRENT"
echo "FIRST_CORPUS=$FIRST_CORPUS"
echo "EVIDENCE=$OUT"
echo

for x in "$CURRENT" "$FIRST_CORPUS" "$TREE_HOME" "$SERVICE"; do
  [ -e "$x" ] || { echo "BLOCKER: missing $x"; exit 20; }
done
[ -x "$PYTHON" ] || { echo "BLOCKER: missing $PYTHON"; exit 21; }

# -------------------------------------------------------------------
# Gate on the promoted JSON capability.
# -------------------------------------------------------------------
LATEST27B="$(
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
    if "PAN_JSON_CAPABILITY_PROMOTION_STAGE27B" not in text:
        continue
    if "STATUS=PASS" not in text:
        continue
    if "JSON_CAPABILITY=PROMOTED" not in text:
        continue
    hits.append((d.stat().st_mtime_ns, d))

if hits:
    print(max(hits)[1])
PY
)"

[ -n "$LATEST27B" ] && [ -d "$LATEST27B" ] || {
  echo "BLOCKER: promoted Stage27B evidence not found"
  exit 22
}

PROMOTED_COMMIT="$(
  sed -n 's/^COMMIT=//p' "$LATEST27B/SUMMARY.txt" | head -1
)"

[ -n "$PROMOTED_COMMIT" ] || {
  echo "BLOCKER: Stage27B commit missing"
  exit 23
}

git -C "$CURRENT" cat-file -e "$PROMOTED_COMMIT^{commit}" 2>/dev/null || {
  echo "BLOCKER: promoted commit not present in repository: $PROMOTED_COMMIT"
  exit 24
}

git -C "$CURRENT" merge-base --is-ancestor "$PROMOTED_COMMIT" HEAD || {
  echo "BLOCKER: promoted JSON commit is not an ancestor of current HEAD"
  exit 25
}

echo "STAGE27B=$LATEST27B"
echo "PROMOTED_COMMIT=$PROMOTED_COMMIT"

# -------------------------------------------------------------------
# Recover the authoritative Stage9 nonconversation remainder list.
# Do not reconstruct it from today's tree.
# -------------------------------------------------------------------
"$PYTHON" - "$TREE_HOME" "$FIRST_CORPUS" "$OUT" <<'PY'
from pathlib import Path
import json
import re
import sys

tree_home = Path(sys.argv[1])
first = Path(sys.argv[2]).resolve()
out = Path(sys.argv[3])

stage9 = []
for d in tree_home.iterdir():
    if not d.is_dir():
        continue
    for s in (d / "SUMMARY.txt",):
        if not s.is_file():
            continue
        text = s.read_text(encoding="utf-8", errors="replace")
        if "NONCONVERSATION_REMAINDER=" not in text:
            continue
        m = re.search(r"^NONCONVERSATION_REMAINDER=(\d+)\s*$", text, re.M)
        if not m:
            continue
        stage9.append((d.stat().st_mtime_ns, d, int(m.group(1))))

if not stage9:
    raise SystemExit("BLOCKER: Stage9 remainder evidence not found")

_, stage9_dir, expected = max(stage9)
(out / "00_STAGE9.txt").write_text(
    f"STAGE9={stage9_dir}\nEXPECTED_REMAINDER={expected}\n",
    encoding="utf-8",
)

root_text = str(first)
candidate_sets = []

def extract_paths(text):
    found = set()

    # Quoted/unquoted absolute-path occurrences.
    pattern = re.compile(re.escape(root_text) + r'[^"\r\n\t|]*')
    for match in pattern.finditer(text):
        raw = match.group(0).strip()
        raw = raw.rstrip(" ,;)]}")
        p = Path(raw)
        if p.is_file():
            try:
                p.resolve().relative_to(first)
            except Exception:
                continue
            found.add(str(p.resolve()))

    # TSV/line-oriented fields, including paths with spaces.
    for line in text.splitlines():
        for field in re.split(r"[\t|]", line):
            field = field.strip().strip('"').strip("'")
            idx = field.find(root_text)
            if idx < 0:
                continue
            raw = field[idx:].rstrip(" ,;)]}")
            p = Path(raw)
            if p.is_file():
                try:
                    p.resolve().relative_to(first)
                except Exception:
                    continue
                found.add(str(p.resolve()))

    return found

for f in stage9_dir.rglob("*"):
    if not f.is_file():
        continue
    try:
        if f.stat().st_size > 25 * 1024 * 1024:
            continue
        text = f.read_text(encoding="utf-8", errors="replace")
    except Exception:
        continue
    paths = extract_paths(text)
    if paths:
        candidate_sets.append((f, paths))

with (out / "01_STAGE9_PATHSET_CANDIDATES.tsv").open("w", encoding="utf-8") as h:
    h.write("count\tfile\n")
    for f, paths in sorted(candidate_sets, key=lambda x: (-len(x[1]), str(x[0]))):
        h.write(f"{len(paths)}\t{f}\n")

exact = [(f, paths) for f, paths in candidate_sets if len(paths) == expected]
if not exact:
    raise SystemExit(
        f"BLOCKER: no Stage9 artifact reproduces exact remainder count {expected}"
    )

reference = exact[0][1]
nonidentical = [(f, p) for f, p in exact[1:] if p != reference]
if nonidentical:
    raise SystemExit(
        "BLOCKER: multiple Stage9 artifacts have expected count but different path sets"
    )

chosen = sorted((f for f, _ in exact), key=str)[0]
(out / "02_REMAINDER_SOURCE.txt").write_text(
    f"REMAINDER_ARTIFACT={chosen}\n"
    f"REMAINDER_COUNT={len(reference)}\n",
    encoding="utf-8",
)

ordered = sorted(reference)
(out / "03_NONCONVERSATION_REMAINDER_ALL.txt").write_text(
    "\n".join(ordered) + "\n",
    encoding="utf-8",
)

eligible = [
    p for p in ordered
    if Path(p).suffix.lower() in {".json", ".md", ".txt"}
]
(out / "04_ELIGIBLE_JSON_MD_TXT.txt").write_text(
    "\n".join(eligible) + ("\n" if eligible else ""),
    encoding="utf-8",
)

counts = {}
bytes_by_ext = {}
for s in eligible:
    p = Path(s)
    ext = p.suffix.lower()
    counts[ext] = counts.get(ext, 0) + 1
    bytes_by_ext[ext] = bytes_by_ext.get(ext, 0) + p.stat().st_size

with (out / "05_ELIGIBLE_COUNTS.tsv").open("w", encoding="utf-8") as h:
    h.write("extension\tcount\tbytes\n")
    for ext in sorted(counts):
        h.write(f"{ext}\t{counts[ext]}\t{bytes_by_ext[ext]}\n")

print(f"STAGE9={stage9_dir}")
print(f"REMAINDER_ARTIFACT={chosen}")
print(f"REMAINDER_COUNT={len(reference)}")
print(f"ELIGIBLE_JSON_MD_TXT={len(eligible)}")
for ext in sorted(counts):
    print(f"{ext}={counts[ext]}")
PY

ELIGIBLE="$OUT/04_ELIGIBLE_JSON_MD_TXT.txt"
[ -s "$ELIGIBLE" ] || {
  echo "BLOCKER: no eligible .json/.md/.txt remainder files"
  exit 26
}

# -------------------------------------------------------------------
# Prove runtime parser mapping before the bulk dry run.
# -------------------------------------------------------------------
(
  cd "$CURRENT"
  PYTHONPATH="$CURRENT${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - <<'PY'
from pathlib import Path
from workspace.operational.ingestion.service.registry import parser_for

for name in ("probe.json", "probe.md", "probe.txt"):
    fn = parser_for(Path(name))
    print(f"{name}\t{fn.__module__}.{fn.__name__}")
PY
) > "$OUT/06_RUNTIME_PARSER_MAP.tsv"

# -------------------------------------------------------------------
# Hash every source before execution.
# -------------------------------------------------------------------
"$PYTHON" - "$ELIGIBLE" > "$OUT/07_SOURCE_HASHES_BEFORE.tsv" <<'PY'
from pathlib import Path
import hashlib
import sys

for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    if not line:
        continue
    p = Path(line)
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    print(f"{h.hexdigest()}\t{p.stat().st_size}\t{p}")
PY

# -------------------------------------------------------------------
# Dry-run every eligible Stage9 nonconversation remainder source.
# Each source gets an independent sandbox batch call so one failure cannot
# destroy evidence for the rest.
# -------------------------------------------------------------------
SANDBOX="$OUT/sandbox"
mkdir -p "$SANDBOX/receipts" "$SANDBOX/output" "$SANDBOX/runroot"

export PAN28_CURRENT="$CURRENT"
export PAN28_SERVICE="$SERVICE"
export PAN28_ELIGIBLE="$ELIGIBLE"
export PAN28_SANDBOX="$SANDBOX"
export PAN28_LEDGER="$OUT/08_DRYRUN_LEDGER.tsv"
export PAN28_PASS_SET="$OUT/09_PASS_SET.txt"
export PAN28_FAIL_SET="$OUT/10_FAIL_SET.txt"

(
  cd "$SANDBOX/runroot"
  PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" \
  "$PYTHON" - <<'PY'
from pathlib import Path
import csv
import hashlib
import json
import os
import traceback

from workspace.operational.ingestion.service.batch import ingest_sources

eligible = Path(os.environ["PAN28_ELIGIBLE"])
sandbox = Path(os.environ["PAN28_SANDBOX"])
ledger_path = Path(os.environ["PAN28_LEDGER"])
pass_path = Path(os.environ["PAN28_PASS_SET"])
fail_path = Path(os.environ["PAN28_FAIL_SET"])

sources = [
    Path(x).resolve()
    for x in eligible.read_text(encoding="utf-8").splitlines()
    if x.strip()
]

passes = []
fails = []

with ledger_path.open("w", encoding="utf-8", newline="") as h:
    w = csv.writer(h, delimiter="\t")
    w.writerow([
        "index",
        "extension",
        "status",
        "manifest_kind",
        "validation_passed",
        "errors",
        "sha256",
        "bytes",
        "source",
        "output",
        "exception",
    ])

    for i, source in enumerate(sources, start=1):
        ext = source.suffix.lower()
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        status = "FAIL"
        kind = ""
        validation_passed = ""
        errors = ""
        output = ""
        exc = ""

        try:
            outputs = ingest_sources(
                sources=(source,),
                receipt_root=sandbox / "receipts",
                output_root=sandbox / "output",
                source_class="manual_batch",
            )

            if len(outputs) != 1:
                raise RuntimeError(
                    f"expected one output, got {len(outputs)}"
                )

            out = Path(outputs[0]).resolve()
            output = str(out)

            manifest = json.loads(
                (out / "reports/manifest.json").read_text(
                    encoding="utf-8"
                )
            )
            validation = json.loads(
                (out / "reports/validation.json").read_text(
                    encoding="utf-8"
                )
            )

            kind = manifest.get("kind")
            validation_passed = validation.get("passed")
            errors = json.dumps(
                validation.get("errors", []),
                ensure_ascii=False,
                sort_keys=True,
            )

            if validation_passed is True:
                status = "PASS"
                passes.append(str(source))
            else:
                status = "FAIL"
                fails.append(str(source))

        except Exception as e:
            exc = f"{type(e).__name__}: {e}"
            fails.append(str(source))

        w.writerow([
            i,
            ext,
            status,
            kind,
            validation_passed,
            errors,
            digest,
            source.stat().st_size,
            source,
            output,
            exc,
        ])

        print(
            f"[{i}/{len(sources)}] {ext} {status} {source.name}",
            flush=True,
        )

pass_path.write_text(
    "\n".join(passes) + ("\n" if passes else ""),
    encoding="utf-8",
)
fail_path.write_text(
    "\n".join(fails) + ("\n" if fails else ""),
    encoding="utf-8",
)

print(f"TOTAL={len(sources)}")
print(f"PASS={len(passes)}")
print(f"FAIL={len(fails)}")
PY
) | tee "$OUT/08_DRYRUN_PROGRESS.txt"

# -------------------------------------------------------------------
# Verify source immutability.
# -------------------------------------------------------------------
"$PYTHON" - "$ELIGIBLE" > "$OUT/11_SOURCE_HASHES_AFTER.tsv" <<'PY'
from pathlib import Path
import hashlib
import sys

for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    if not line:
        continue
    p = Path(line)
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    print(f"{h.hexdigest()}\t{p.stat().st_size}\t{p}")
PY

if ! cmp -s "$OUT/07_SOURCE_HASHES_BEFORE.tsv" "$OUT/11_SOURCE_HASHES_AFTER.tsv"; then
  echo "BLOCKER: source hash drift during dry run"
  diff -u "$OUT/07_SOURCE_HASHES_BEFORE.tsv" "$OUT/11_SOURCE_HASHES_AFTER.tsv" \
    > "$OUT/11_SOURCE_HASH_DRIFT.diff" || true
  exit 27
fi

# -------------------------------------------------------------------
# Summarize exact outcomes by extension and manifest kind.
# -------------------------------------------------------------------
"$PYTHON" - "$OUT/08_DRYRUN_LEDGER.tsv" "$OUT" <<'PY'
from pathlib import Path
import csv
import collections
import sys

ledger = Path(sys.argv[1])
out = Path(sys.argv[2])

rows = list(csv.DictReader(
    ledger.open(encoding="utf-8"),
    delimiter="\t",
))

ext = collections.Counter()
ext_pass = collections.Counter()
kind = collections.Counter()
failure = collections.Counter()

for r in rows:
    e = r["extension"]
    ext[e] += 1
    if r["status"] == "PASS":
        ext_pass[e] += 1
        kind[r["manifest_kind"] or "<blank>"] += 1
    else:
        key = r["exception"] or r["errors"] or "<unknown>"
        failure[key] += 1

with (out / "12_DRYRUN_SUMMARY.tsv").open("w", encoding="utf-8") as h:
    h.write("extension\ttotal\tpass\tfail\n")
    for e in sorted(ext):
        h.write(
            f"{e}\t{ext[e]}\t{ext_pass[e]}\t"
            f"{ext[e] - ext_pass[e]}\n"
        )

with (out / "13_PASS_KINDS.tsv").open("w", encoding="utf-8") as h:
    h.write("manifest_kind\tcount\n")
    for k, n in sorted(kind.items()):
        h.write(f"{k}\t{n}\n")

with (out / "14_FAILURE_CLASSES.tsv").open("w", encoding="utf-8") as h:
    h.write("count\tfailure\n")
    for msg, n in failure.most_common():
        h.write(f"{n}\t{msg}\n")

total = len(rows)
passed = sum(1 for r in rows if r["status"] == "PASS")
failed = total - passed

print(f"TOTAL={total}")
print(f"PASS={passed}")
print(f"FAIL={failed}")
for e in sorted(ext):
    print(
        f"{e}: total={ext[e]} "
        f"pass={ext_pass[e]} "
        f"fail={ext[e] - ext_pass[e]}"
    )
PY

TOTAL="$(($(wc -l < "$OUT/08_DRYRUN_LEDGER.tsv") - 1))"
PASS_COUNT="$(wc -l < "$OUT/09_PASS_SET.txt" 2>/dev/null || true)"
FAIL_COUNT="$(wc -l < "$OUT/10_FAIL_SET.txt" 2>/dev/null || true)"

if [ "$PASS_COUNT" -gt 0 ]; then
  NEXT="CANONICAL_INGEST_ONLY_STAGE28_PASS_SET_THEN_QUALIFY_STAGE28_FAILURES"
else
  NEXT="STOP_NO_REMAINDER_SOURCE_PASSED_DRYRUN"
fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_FIRST_CORPUS_TEXTLIKE_DRYRUN_STAGE28
UTC=$TS
STATUS=PASS
STAGE27B=$LATEST27B
PROMOTED_COMMIT=$PROMOTED_COMMIT
FIRST_CORPUS=$FIRST_CORPUS
TOTAL_CANDIDATES=$TOTAL
PASS_COUNT=$PASS_COUNT
FAIL_COUNT=$FAIL_COUNT
SOURCE_HASHES=PASS
SOURCE_MUTATION=NONE
LIVE_REPOSITORY_OUTPUT_MODIFIED=NO
EVIDENCE=$OUT
PASS_SET=$OUT/09_PASS_SET.txt
FAIL_SET=$OUT/10_FAIL_SET.txt
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
echo "--- eligible counts ---"
cat "$OUT/05_ELIGIBLE_COUNTS.tsv"
echo
echo "--- dry-run summary ---"
cat "$OUT/12_DRYRUN_SUMMARY.tsv"
echo
echo "--- failure classes ---"
head -40 "$OUT/14_FAILURE_CLASSES.tsv"
echo
echo "STAGE28_COMPLETE=YES"
