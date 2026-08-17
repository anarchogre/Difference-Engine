#!/data/data/com.termux/files/usr/bin/bash

set -u

ROOT="$(pwd)"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$ROOT/inventory/initialization/$STAMP"

mkdir -p \
  "$OUT/manifests" \
  "$OUT/reports" \
  "$OUT/git"

REPORT="$OUT/INITIALIZATION_REPORT.txt"

{
  echo "DIFFERENCE ENGINE INITIALIZATION EVIDENCE"
  echo "Generated: $(date -Iseconds)"
  echo "Repository candidate: $ROOT"
  echo

  echo "=== REPOSITORY IDENTITY ==="
  printf "Directory: "
  basename "$ROOT"
  printf "Absolute path: "
  pwd
  printf "Readable: "
  test -r "$ROOT" && echo yes || echo no
  printf "Writable: "
  test -w "$ROOT" && echo yes || echo no
  echo

  echo "=== TOP-LEVEL STATE ==="
  find . \
    -mindepth 1 \
    -maxdepth 1 \
    -printf '%y %f\n' \
    2>/dev/null \
    | sort
  echo

  echo "=== FILESYSTEM COUNTS ==="
  printf "Files: "
  find . -path './.git' -prune -o -type f -print \
    | wc -l
  printf "Directories: "
  find . -path './.git' -prune -o -type d -print \
    | wc -l
  printf "Repository size: "
  du -sh . 2>/dev/null | cut -f1
  echo

  echo "=== REQUIRED TOP-LEVEL CANDIDATES ==="
  for path in \
    Repository \
    ade \
    scripts \
    docs \
    inventory \
    BOOTSTRAP \
    DOCTRINE \
    QUEUES \
    SESSION \
    SUMMITS \
    MISSIONS \
    Phylactery \
    MemoryPalace
  do
    if test -e "$path"; then
      printf "PRESENT  %s\n" "$path"
    else
      printf "MISSING  %s\n" "$path"
    fi
  done
  echo

  echo "=== GIT ==="
  if git rev-parse --is-inside-work-tree \
    >/dev/null 2>&1
  then
    echo "Git repository: yes"
    printf "Root: "
    git rev-parse --show-toplevel
    printf "Branch: "
    git branch --show-current
    printf "HEAD: "
    git rev-parse --short HEAD 2>/dev/null \
      || echo "unborn"
    printf "Remote origin: "
    git remote get-url origin 2>/dev/null \
      || echo "none"
    printf "Changed paths: "
    git status --porcelain | wc -l
  else
    echo "Git repository: no"
  fi
  echo

  echo "=== INGESTION CORPUS ==="
  printf "Matching files: "
  find . \
    -path './.git' -prune -o \
    -type f \
    \( \
      -iname '*ingest*' -o \
      -iname '*parser*' -o \
      -iname '*format*' -o \
      -iname '*artifact*' -o \
      -iname '*conversation*' -o \
      -iname '*provenance*' -o \
      -iname '*repository*object*' \
    \) \
    -print \
    | wc -l
  echo

  echo "=== IMPLEMENTATION CANDIDATES ==="
  printf "Python files under ade/: "
  if test -d ade; then
    find ade -type f -name '*.py' | wc -l
  else
    echo 0
  fi

  printf "Shell files under scripts/: "
  if test -d scripts; then
    find scripts -type f \
      \( -name '*.sh' -o -perm -u+x \) \
      | wc -l
  else
    echo 0
  fi
  echo

  echo "=== OPERATIONAL STATE ARTIFACTS ==="
  printf "Queue/state/bootstrap matches: "
  find . \
    -path './.git' -prune -o \
    -type f \
    \( \
      -iname '*queue*' -o \
      -iname '*flag*' -o \
      -iname '*mission*' -o \
      -iname '*session*' -o \
      -iname '*bootstrap*' -o \
      -iname '*blocker*' -o \
      -iname '*roadmap*' \
    \) \
    -print \
    | wc -l
  echo

  echo "=== FILE_LIBRARY_UPLOADS ==="
  for candidate in \
    "../FILE_LIBRARY_UPLOADS" \
    "$HOME/storage/shared/FILE_LIBRARY_UPLOADS" \
    "/storage/emulated/0/FILE_LIBRARY_UPLOADS"
  do
    if test -d "$candidate"; then
      resolved="$(cd "$candidate" && pwd)"
      echo "PRESENT  $resolved"
      printf "Files: "
      find "$resolved" -type f | wc -l
      printf "Size: "
      du -sh "$resolved" 2>/dev/null | cut -f1
      break
    fi
  done
  echo

  echo "=== INITIALIZATION RESULT ==="
  echo "Constitutional state: loaded in session"
  echo "Repository state: evidence captured"
  echo "Git state: see report"
  echo "Ingester state: requires classification"
  echo "File Library overlap: requires comparison"
  echo "Readiness: not yet claimed"
  echo
  echo "Next operation:"
  echo "Classify recovered ingestion specifications and code,"
  echo "then identify the smallest missing dependency."
} > "$REPORT"

find . \
  -path './.git' -prune -o \
  -type f \
  -printf '%P\n' \
  | sort \
  > "$OUT/manifests/REPOSITORY_FILES.txt"

find . \
  -path './.git' -prune -o \
  -type d \
  -printf '%P\n' \
  | sort \
  > "$OUT/manifests/REPOSITORY_DIRECTORIES.txt"

find . \
  -path './.git' -prune -o \
  -type f \
  \( \
    -iname '*ingest*' -o \
    -iname '*parser*' -o \
    -iname '*format*' -o \
    -iname '*artifact*' -o \
    -iname '*conversation*' -o \
    -iname '*provenance*' -o \
    -iname '*repository*object*' \
  \) \
  -printf '%P\n' \
  | sort \
  > "$OUT/reports/INGESTION_CANDIDATES.txt"

find . \
  -path './.git' -prune -o \
  -type f \
  \( \
    -iname '*queue*' -o \
    -iname '*flag*' -o \
    -iname '*mission*' -o \
    -iname '*session*' -o \
    -iname '*bootstrap*' -o \
    -iname '*blocker*' -o \
    -iname '*roadmap*' \
  \) \
  -printf '%P\n' \
  | sort \
  > "$OUT/reports/OPERATIONAL_STATE_FILES.txt"

if test -d ade; then
  find ade \
    -type f \
    \( \
      -name '*.py' -o \
      -name '*.sh' -o \
      -name '*.json' -o \
      -name '*.yaml' -o \
      -name '*.yml' -o \
      -name '*.toml' \
    \) \
    -printf '%P\n' \
    | sort \
    > "$OUT/reports/ADE_IMPLEMENTATION_FILES.txt"
else
  : > "$OUT/reports/ADE_IMPLEMENTATION_FILES.txt"
fi

if git rev-parse --is-inside-work-tree \
  >/dev/null 2>&1
then
  git status --short \
    > "$OUT/git/STATUS.txt"

  git log \
    --oneline \
    --decorate \
    -25 \
    > "$OUT/git/RECENT_HISTORY.txt"

  git remote -v \
    > "$OUT/git/REMOTES.txt"

  git branch -avv \
    > "$OUT/git/BRANCHES.txt"
fi

printf '\nEvidence directory:\n%s\n\n' "$OUT"
cat "$REPORT"
