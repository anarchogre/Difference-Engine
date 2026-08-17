#!/usr/bin/env bash
set -Eeuo pipefail

BASE="$HOME/Forge-File-Tree-Directories"
DATE="$(date +%-m-%-d-%Y)"
UTC="$(date -u +%Y%m%dT%H%M%SZ)"

CURRENT="$HOME/Difference-Engine"
LEGACY="$HOME/Difference-Engine-LEGACY-STALE-DECOMPOSED"

mkdir -p \
  "$BASE/Difference-Engine" \
  "$BASE/Difference-Engine-LEGACY-STALE-DECOMPOSED" \
  "$BASE/Forge-Top-Level" \
  "$BASE/Pan"

emit_tree() {
  local root="$1"
  local out="$2"

  {
    echo "FILE_TREE_SNAPSHOT"
    echo "UTC=$UTC"
    echo "ROOT=$root"
    echo

    if command -v tree >/dev/null 2>&1; then
      # Hidden entries, human-readable sizes, directory-first, full metadata-ish listing.
      tree -a -h --du --dirsfirst "$root"
    else
      # Deterministic fallback if tree is unavailable.
      find "$root" -xdev \
        -printf '%y %m %u %g %s %TY-%Tm-%TdT%TH:%TM:%TS %p -> %l\n' \
        2>/dev/null | sort
    fi
  } > "$out"
}

# Current Difference Engine.
emit_tree \
  "$CURRENT" \
  "$BASE/Difference-Engine/Difference-Engine-${DATE}-File-Tree.txt"

# Legacy / stale / decomposed source estate.
emit_tree \
  "$LEGACY" \
  "$BASE/Difference-Engine-LEGACY-STALE-DECOMPOSED/Difference-Engine-LEGACY-STALE-DECOMPOSED-${DATE}-File-Tree.txt"

# Forge home top level: intentionally shallow so this remains usable.
{
  echo "FORGE_TOP_LEVEL_SNAPSHOT"
  echo "UTC=$UTC"
  echo "ROOT=$HOME"
  echo
  find "$HOME" -mindepth 1 -maxdepth 2 \
    -printf '%y %m %u %g %s %TY-%Tm-%TdT%TH:%TM:%TS %p -> %l\n' \
    2>/dev/null | sort
} > "$BASE/Forge-Top-Level/Forge-Top-Level-${DATE}-File-Tree.txt"

# Pan runtime surface. Preserve the old Pan-Qwen directory; new snapshots use Pan.
{
  echo "PAN_RUNTIME_SNAPSHOT"
  echo "UTC=$UTC"
  echo
  for root in \
    "$HOME/.local/share/Difference-Engine" \
    "$HOME/.local/state/Difference-Engine" \
    "$HOME/.local/libexec/Difference-Engine"
  do
    [ -e "$root" ] || continue
    echo "===== $root ====="
    if command -v tree >/dev/null 2>&1; then
      tree -a -h --du --dirsfirst "$root" || true
    else
      find "$root" -xdev \
        -printf '%y %m %u %g %s %TY-%Tm-%TdT%TH:%TM:%TS %p -> %l\n' \
        2>/dev/null | sort
    fi
    echo
  done
} > "$BASE/Pan/Pan-${DATE}-File-Tree.txt"

# Refresh the index of the file-tree directory itself LAST so it includes the new snapshots.
emit_tree \
  "$BASE" \
  "$BASE/Forge-File-Tree-Directories-File-Tree.txt"

# Hash manifest for the newly created/updated snapshot files.
{
  find "$BASE" -maxdepth 2 -type f \
    \( -name "*-${DATE}-File-Tree.txt" -o -name "Forge-File-Tree-Directories-File-Tree.txt" \) \
    -print0 \
    | sort -z \
    | xargs -0 sha256sum
} > "$BASE/FILE_TREE_SNAPSHOT_${UTC}.sha256"

echo "FILE_TREE_REFRESH=PASS"
echo "UTC=$UTC"
echo "BASE=$BASE"
echo
echo "NEW SNAPSHOTS:"
find "$BASE" -maxdepth 2 -type f \
  \( -name "*-${DATE}-File-Tree.txt" -o -name "Forge-File-Tree-Directories-File-Tree.txt" \) \
  -print | sort
