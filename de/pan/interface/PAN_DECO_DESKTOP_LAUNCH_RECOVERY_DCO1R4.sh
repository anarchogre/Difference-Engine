#!/usr/bin/env bash
set -Eeuo pipefail

echo "DECO_SUMMARY_BEGIN"
echo "STAGE=DCO1R4_DESKTOP_LAUNCH_RECOVERY"

echo "PROCESSES_BEGIN"
pgrep -f '/snap/chatgpt-desktop-linux/.*/chatgpt-desktop-linux' 2>/dev/null \
  | sort -n \
  | while read -r pid; do
      [ -r "/proc/$pid/cmdline" ] || continue
      cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
      ppid="$(awk '/^PPid:/{print $2}' "/proc/$pid/status" 2>/dev/null || true)"
      echo "PID=$pid PPID=${ppid:-?} CMD=$cmd"
    done
echo "PROCESSES_END"

echo "DESKTOP_FILES_BEGIN"
for root in \
  "$HOME/.local/share/applications" \
  /usr/share/applications \
  /var/lib/snapd/desktop/applications
do
  [ -d "$root" ] || continue
  find "$root" -maxdepth 1 -type f \
    \( -iname '*chatgpt*.desktop' -o -iname '*openai*.desktop' \) \
    -print 2>/dev/null \
    | while read -r f; do
        echo "FILE=$f"
        grep -E '^(Name|Exec|TryExec|Icon|StartupWMClass)=' "$f" 2>/dev/null || true
      done
done
echo "DESKTOP_FILES_END"

echo "SNAP_INFO_BEGIN"
snap info chatgpt-desktop-linux 2>/dev/null \
  | sed -n '1,80p' || true
echo "SNAP_INFO_END"

echo "SNAP_COMMANDS_BEGIN"
snap run --shell chatgpt-desktop-linux -c '
  echo SNAP="$SNAP"
  echo SNAP_USER_DATA="$SNAP_USER_DATA"
  echo SNAP_USER_COMMON="$SNAP_USER_COMMON"
  command -v chatgpt-desktop-linux 2>/dev/null || true
' 2>/dev/null || true
echo "SNAP_COMMANDS_END"

MAIN_PID="$(
  pgrep -f '/snap/chatgpt-desktop-linux/.*/chatgpt-desktop-linux' 2>/dev/null \
    | while read -r pid; do
        cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
        case "$cmd" in
          *" --type="*) ;;
          *) echo "$pid"; break ;;
        esac
      done
)"

if [ -n "${MAIN_PID:-}" ]; then
  echo "MAIN_PID=$MAIN_PID"
  echo "MAIN_CMD=$(tr '\0' ' ' < "/proc/$MAIN_PID/cmdline" 2>/dev/null || true)"
  echo "MAIN_PROCESS_FOUND=YES"
else
  echo "MAIN_PROCESS_FOUND=NO"
fi

if grep -Rqs -- '--force-renderer-accessibility' \
  /var/lib/snapd/desktop/applications "$HOME/.local/share/applications" 2>/dev/null; then
  echo "ACCESSIBILITY_FLAG_ALREADY_PRESENT=YES"
else
  echo "ACCESSIBILITY_FLAG_ALREADY_PRESENT=NO"
fi

echo "STATUS=PASS"
echo "NEXT=RELAUNCH_CHATGPT_DESKTOP_WITH_FORCE_RENDERER_ACCESSIBILITY"
echo "DECO_SUMMARY_END"
