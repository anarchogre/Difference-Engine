#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date -u +%Y%m%dT%H%M%SZ)"
ROOT="$HOME/Forge-File-Tree-Directories"
OUT="$ROOT/PAN_DE_COPYOUT_RECOVERY_CENSUS_${TS}-DCO0"
REPORT="$OUT/DE_COPYOUT_RECOVERY_REPORT.txt"
BUNDLE="$OUT/DE_COPYOUT_RECOVERY_BUNDLE.tar.gz"

mkdir -p "$OUT"

exec > >(tee "$REPORT") 2>&1

echo "=== DE-COPYOUT RECOVERY CENSUS / DCO0 ==="
echo "UTC=$TS"
echo "HOST=$(hostname)"
echo "USER=$(id -un)"
echo "HOME=$HOME"
echo "OUT=$OUT"
echo

echo "=== 1. SESSION / DISPLAY REALITY ==="
printf 'XDG_SESSION_TYPE=%s\n' "${XDG_SESSION_TYPE:-}"
printf 'XDG_CURRENT_DESKTOP=%s\n' "${XDG_CURRENT_DESKTOP:-}"
printf 'DESKTOP_SESSION=%s\n' "${DESKTOP_SESSION:-}"
printf 'DISPLAY=%s\n' "${DISPLAY:-}"
printf 'WAYLAND_DISPLAY=%s\n' "${WAYLAND_DISPLAY:-}"
printf 'DBUS_SESSION_BUS_ADDRESS=%s\n' "${DBUS_SESSION_BUS_ADDRESS:+SET}"
printf 'XAUTHORITY=%s\n' "${XAUTHORITY:-}"
echo

echo "=== 2. NETWORK REALITY ==="
ip -brief link 2>/dev/null || true
echo
nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null || true
echo

echo "=== 3. BROWSER / GUI PROCESSES ==="
ps -eo pid,ppid,comm,args --sort=comm \
  | grep -Ei 'firefox|chromium|chrome|gnome-shell|xfce|at-spi|ydotool|xclip|xsel|wl-copy|wl-paste' \
  | grep -v grep || true
echo

echo "=== 4. BRIDGE-RELEVANT BINARIES ==="
for c in \
  python3 bash sha256sum stat inotifywait \
  ydotool ydotoold xdotool wtype \
  wl-copy wl-paste xclip xsel \
  gdbus dbus-send busctl \
  gio zenity notify-send \
  wmctrl xprop xwininfo \
  systemctl journalctl
do
  if command -v "$c" >/dev/null 2>&1; then
    printf '%-14s PRESENT %s\n' "$c" "$(command -v "$c")"
  else
    printf '%-14s MISSING\n' "$c"
  fi
done
echo

echo "=== 5. PYTHON GUI / AT-SPI CAPABILITY ==="
python3 - <<'PY' || true
mods = ["gi", "pyatspi"]
for m in mods:
    try:
        mod = __import__(m)
        print(f"{m}=PRESENT origin={getattr(mod, '__file__', '')}")
    except Exception as e:
        print(f"{m}=MISSING {type(e).__name__}: {e}")
try:
    import gi
    gi.require_version("Atspi", "2.0")
    from gi.repository import Atspi
    print("GI_ATSPI=PRESENT")
except Exception as e:
    print(f"GI_ATSPI=MISSING {type(e).__name__}: {e}")
PY
echo

echo "=== 6. USER SERVICES / UNITS WITH DE-BRIDGE SIGNAL ==="
systemctl --user list-unit-files --no-pager 2>/dev/null \
  | grep -Ei 'de-|bridge|copyout|chatgpt|ydotool' || true
echo
systemctl --user list-units --all --no-pager 2>/dev/null \
  | grep -Ei 'de-|bridge|copyout|chatgpt|ydotool' || true
echo

echo "=== 7. PRIOR IMPLEMENTATION PATH RECOVERY ==="
FIND_OUT="$OUT/01_PRIOR_PATHS.txt"
: > "$FIND_OUT"

# Exact/specific recovery only; do not crawl unrelated personal data contents.
for base in \
  "$HOME" \
  "$HOME/Difference-Engine" \
  "$HOME/DifferenceEngine"
do
  [ -d "$base" ] || continue
  find "$base" -xdev \
    \( -path "$HOME/.cache" -o -path "$HOME/.local/share/Trash" -o -path "$HOME/Downloads" \) -prune -o \
    \( -type f -o -type l -o -type d \) \
    \( -iname 'de-bridge-watch*' \
       -o -iname 'de-bridge-onclip*' \
       -o -iname 'de-chatgpt-return-text*' \
       -o -iname 'de-copyout*' \
       -o -iname '*copyout*bridge*' \
       -o -iname '*chatgpt*return*' \
       -o -iname '*focus*edge*' \
       -o -iname 'Hearth' \
       -o -iname '*DE-COPYOUT*' \
    \) -print 2>/dev/null
done | awk '!seen[$0]++' | sort > "$FIND_OUT"

cat "$FIND_OUT"
echo

echo "=== 8. PRIOR FILE METADATA + HASHES ==="
META="$OUT/02_PRIOR_FILE_METADATA.tsv"
printf 'path\ttype\tmode\tbytes\tmtime\tsha256\n' > "$META"

while IFS= read -r p; do
  [ -n "$p" ] || continue
  if [ -f "$p" ]; then
    mode="$(stat -c '%a' "$p" 2>/dev/null || echo '?')"
    bytes="$(stat -c '%s' "$p" 2>/dev/null || echo '?')"
    mtime="$(stat -c '%y' "$p" 2>/dev/null || echo '?')"
    hash="$(sha256sum "$p" 2>/dev/null | awk '{print $1}')"
    printf '%s\tfile\t%s\t%s\t%s\t%s\n' "$p" "$mode" "$bytes" "$mtime" "$hash" >> "$META"
  elif [ -d "$p" ]; then
    mode="$(stat -c '%a' "$p" 2>/dev/null || echo '?')"
    mtime="$(stat -c '%y' "$p" 2>/dev/null || echo '?')"
    printf '%s\tdir\t%s\t-\t%s\t-\n' "$p" "$mode" "$mtime" >> "$META"
  elif [ -L "$p" ]; then
    printf '%s\tsymlink\t-\t-\t-\t-\n' "$p" >> "$META"
  fi
done < "$FIND_OUT"

cat "$META"
echo

echo "=== 9. SAFE SOURCE SNAPSHOTS OF RECOVERED BRIDGE FILES ==="
SRC="$OUT/recovered-sources"
mkdir -p "$SRC"

python3 - "$FIND_OUT" "$SRC" <<'PY'
from pathlib import Path
import sys, shutil, hashlib

paths = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace").splitlines()
dest = Path(sys.argv[2])

allowed_suffixes = {
    ".sh", ".py", ".service", ".timer", ".conf", ".md", ".txt", ".json"
}
allowed_names = {
    "de-bridge-watch", "de-bridge-onclip", "de-chatgpt-return-text",
    "de-copyout", "de-copyout.sh"
}

manifest = []
for raw in paths:
    p = Path(raw)
    if not p.is_file():
        continue
    if p.suffix.lower() not in allowed_suffixes and p.name not in allowed_names:
        continue
    try:
        size = p.stat().st_size
    except OSError:
        continue
    if size > 1024 * 1024:
        continue

    # Copy only bridge-targeted files already selected by the exact-name search.
    digest = hashlib.sha256(str(p).encode()).hexdigest()[:16]
    target = dest / f"{digest}__{p.name}"
    try:
        shutil.copy2(p, target)
        manifest.append(f"{p}\t{target}\n")
    except Exception:
        pass

(dest / "MANIFEST.tsv").write_text(
    "source\tcopied_to\n" + "".join(manifest),
    encoding="utf-8",
)
PY

find "$SRC" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort
echo

echo "=== 10. USER UNIT FILE CONTENTS FOR MATCHING SERVICES ==="
UNITOUT="$OUT/03_MATCHING_USER_UNITS.txt"
: > "$UNITOUT"
for dir in "$HOME/.config/systemd/user" "$HOME/.local/share/systemd/user"; do
  [ -d "$dir" ] || continue
  find "$dir" -maxdepth 1 -type f \
    \( -iname '*de-*' -o -iname '*bridge*' -o -iname '*copyout*' -o -iname '*chatgpt*' \) \
    -print0 2>/dev/null \
  | while IFS= read -r -d '' f; do
      {
        echo "===== $f ====="
        sed -n '1,260p' "$f"
        echo
      } >> "$UNITOUT"
    done
done
cat "$UNITOUT"
echo

echo "=== 11. RECENT USER JOURNAL SIGNAL ==="
journalctl --user --since '14 days ago' --no-pager 2>/dev/null \
  | grep -Ei 'de-bridge|copyout|chatgpt-return|ydotool|at-spi|clipboard' \
  | tail -1200 > "$OUT/04_RECENT_BRIDGE_JOURNAL.txt" || true
tail -160 "$OUT/04_RECENT_BRIDGE_JOURNAL.txt" 2>/dev/null || true
echo

echo "=== 12. XINPUT / TOUCH / POINTER REALITY (IF XWAYLAND/X11 AVAILABLE) ==="
if command -v xinput >/dev/null 2>&1; then
  xinput list 2>&1 || true
else
  echo "xinput=MISSING"
fi
echo

echo "=== 13. CLIPBOARD TRANSPORT SMOKE — NONMUTATING DISCOVERY ONLY ==="
if command -v wl-paste >/dev/null 2>&1; then
  echo "WAYLAND_CLIPBOARD_READER=wl-paste"
elif command -v xclip >/dev/null 2>&1; then
  echo "X_CLIPBOARD_READER=xclip"
elif command -v xsel >/dev/null 2>&1; then
  echo "X_CLIPBOARD_READER=xsel"
else
  echo "CLIPBOARD_READER=NONE"
fi
echo

echo "=== 14. CURRENT DOWNLOAD SURFACE ==="
for d in "$HOME/Downloads" "$HOME/Download"; do
  [ -d "$d" ] || continue
  echo "DOWNLOAD_DIR=$d"
  find "$d" -maxdepth 1 -type f -printf '%TY-%Tm-%TdT%TH:%TM:%TS %s %f\n' 2>/dev/null \
    | sort -r | head -30 || true
done
echo

echo "=== 15. RECOVERY CLASSIFICATION ==="
PRIOR_COUNT="$(awk 'NF{n++} END{print n+0}' "$FIND_OUT")"
echo "PRIOR_MATCHING_PATHS=$PRIOR_COUNT"

if grep -Eq 'de-bridge-watch|de-bridge-onclip|de-chatgpt-return-text|de-copyout' "$FIND_OUT"; then
  echo "PRIOR_IMPLEMENTATION_RECOVERABLE=YES"
else
  echo "PRIOR_IMPLEMENTATION_RECOVERABLE=NO_MATCH_FOUND"
fi

if command -v ydotool >/dev/null 2>&1; then
  echo "YDOTOOL_AVAILABLE=YES"
else
  echo "YDOTOOL_AVAILABLE=NO"
fi

if python3 - <<'PY' >/dev/null 2>&1
import gi
gi.require_version("Atspi", "2.0")
from gi.repository import Atspi
PY
then
  echo "ATSPI_AVAILABLE=YES"
else
  echo "ATSPI_AVAILABLE=NO"
fi

if command -v wl-paste >/dev/null 2>&1 || command -v xclip >/dev/null 2>&1 || command -v xsel >/dev/null 2>&1; then
  echo "CLIPBOARD_READ_AVAILABLE=YES"
else
  echo "CLIPBOARD_READ_AVAILABLE=NO"
fi

echo "SOURCE_MUTATION=NONE"
echo "REPOSITORY_MUTATION=NONE"
echo "LIVE_BRIDGE_MUTATION=NONE"
echo "DCO0_STATUS=PASS"
echo "NEXT=UPLOAD_DE_COPYOUT_RECOVERY_BUNDLE_FOR_EXACT_REPAIR"
echo

# Create bundle after report is complete enough to include all evidence collected so far.
tar -C "$OUT" \
  --exclude="$(basename "$BUNDLE")" \
  -czf "$BUNDLE" .

echo "=== BUNDLE ==="
echo "BUNDLE=$BUNDLE"
echo "BUNDLE_SHA256=$(sha256sum "$BUNDLE" | awk '{print $1}')"
echo "BUNDLE_BYTES=$(stat -c '%s' "$BUNDLE")"
echo
echo "DCO0_COMPLETE=YES"
