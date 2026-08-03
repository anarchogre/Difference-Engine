#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT=/storage/emulated/0
OUT=$ROOT/DifferenceEngine/inventory/reconciliation

mkdir -p "$OUT"

find "$ROOT/DifferenceEngine" -type f | sort > "$OUT/DifferenceEngine.files"
find "$ROOT/FILE_LIBRARY_UPLOADS" -type f | sort > "$OUT/FILE_LIBRARY_UPLOADS.files"

comm -23 "$OUT/DifferenceEngine.files" "$OUT/FILE_LIBRARY_UPLOADS.files" > "$OUT/DE_only.files"
comm -13 "$OUT/DifferenceEngine.files" "$OUT/FILE_LIBRARY_UPLOADS.files" > "$OUT/FLU_only.files"
comm -12 "$OUT/DifferenceEngine.files" "$OUT/FILE_LIBRARY_UPLOADS.files" > "$OUT/common.files"

find "$ROOT/DifferenceEngine" -type f -exec sha256sum {} + | sort > "$OUT/DE.sha256"
find "$ROOT/FILE_LIBRARY_UPLOADS" -type f -exec sha256sum {} + | sort > "$OUT/FLU.sha256"

cut -d' ' -f1 "$OUT/DE.sha256" | sort > "$OUT/DE.hashes"
cut -d' ' -f1 "$OUT/FLU.sha256" | sort > "$OUT/FLU.hashes"

comm -12 "$OUT/DE.hashes" "$OUT/FLU.hashes" > "$OUT/COMMON.hashes"
comm -23 "$OUT/DE.hashes" "$OUT/FLU.hashes" > "$OUT/DE_ONLY.hashes"
comm -13 "$OUT/DE.hashes" "$OUT/FLU.hashes" > "$OUT/FLU_ONLY.hashes"

echo
echo "===== RECONCILIATION SUMMARY ====="

wc -l \
"$OUT/DifferenceEngine.files" \
"$OUT/FILE_LIBRARY_UPLOADS.files" \
"$OUT/common.files" \
"$OUT/DE_only.files" \
"$OUT/FLU_only.files" \
"$OUT/COMMON.hashes" \
"$OUT/DE_ONLY.hashes" \
"$OUT/FLU_ONLY.hashes"

find "$ROOT/DifferenceEngine" -type d | sort > "$OUT/directories.lst"
find "$ROOT/DifferenceEngine" -type f | sort > "$OUT/files.lst"

tree "$ROOT/DifferenceEngine" > "$OUT/TREE_SNAPSHOT.txt"

sha256sum "$OUT/TREE_SNAPSHOT.txt" > "$OUT/TREE_HASH.sha256"

{
echo "# Repository Snapshot"
date
echo
echo "Directories:"
wc -l "$OUT/directories.lst"
echo "Files:"
wc -l "$OUT/files.lst"
echo
cat "$OUT/TREE_HASH.sha256"
} > "$OUT/REPOSITORY_SNAPSHOT.md"

cp "$OUT/TREE_HASH.sha256" \
"$ROOT/DifferenceEngine/inventory/history/TREE_HASH_$(date +%Y%m%d_%H%M%S).sha256"

find "$ROOT/DifferenceEngine/inventory/history" \
-name 'TREE_HASH_*.sha256' \
| sort \
> "$OUT/TREE_HISTORY.lst"

echo
echo "Repository tree history:"
tail -5 "$OUT/TREE_HISTORY.lst"

find "$ROOT/DifferenceEngine" \
-type f \
-printf '%TY-%Tm-%Td %TH:%TM:%TS %s %p\n' \
| sort \
> "$OUT/FILE_MANIFEST.tsv"

find "$ROOT/DifferenceEngine" \
-type d \
| sort \
> "$OUT/DIRECTORY_MANIFEST.lst"

{
echo "# Reconciliation Timestamp"
date -Iseconds
echo
echo "Repository:"
realpath "$ROOT/DifferenceEngine"
} > "$OUT/RUN_METADATA.md"

{
echo "# Repository Statistics"
echo
echo "Generated: $(date -Iseconds)"
echo
echo "Directories: $(find "$ROOT/DifferenceEngine" -type d | wc -l)"
echo "Files: $(find "$ROOT/DifferenceEngine" -type f | wc -l)"
echo "Markdown: $(find "$ROOT/DifferenceEngine" -name '*.md' | wc -l)"
echo "Python: $(find "$ROOT/DifferenceEngine" -name '*.py' | wc -l)"
echo "Shell: $(find "$ROOT/DifferenceEngine" \( -name '*.sh' -o -name '*.bash' \) | wc -l)"
} > "$OUT/REPOSITORY_STATISTICS.md"

find "$ROOT/DifferenceEngine" \
-type f \
-exec sha256sum {} + \
| sort > "$OUT/FULL_HASH_MANIFEST.sha256"

find "$ROOT/DifferenceEngine" \
-empty \
> "$OUT/EMPTY_OBJECTS.lst"

LOGROOT="$ROOT/DifferenceEngine/logs/reconciliation"
mkdir -p "$LOGROOT"

LOGFILE="$LOGROOT/reconcile_$(date +%Y%m%d_%H%M%S).log"

exec > >(tee "$LOGFILE") 2>&1

echo
echo "Run ID : $(date +%Y%m%d_%H%M%S)"
echo "Host   : $(hostname)"
echo "User   : $(whoami)"
echo
