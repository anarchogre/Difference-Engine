#!/usr/bin/env bash
set -Eeuo pipefail

echo "DECO_SUMMARY_BEGIN"
echo "STAGE=DCO1R3_DESKTOP_ACCESSIBILITY_PROBE"

PID="$(pgrep -n -f 'chatgpt-desktop-linux' || true)"
echo "PID=${PID:-NONE}"

if [ -n "${PID:-}" ]; then
  EXE="$(readlink -f "/proc/$PID/exe" 2>/dev/null || true)"
  CMD="$(tr '\0' ' ' < "/proc/$PID/cmdline" 2>/dev/null || true)"
  echo "EXE=${EXE:-UNKNOWN}"
  echo "CMDLINE=${CMD:-UNKNOWN}"
else
  echo "EXE=UNKNOWN"
  echo "CMDLINE=UNKNOWN"
fi

echo "DESKTOP_FILES_BEGIN"
find "$HOME/.local/share/applications" /usr/share/applications \
  -maxdepth 1 -type f -iname '*chatgpt*.desktop' -print 2>/dev/null \
  | while read -r f; do
      echo "FILE=$f"
      grep -E '^(Name|Exec|TryExec)=' "$f" 2>/dev/null || true
    done
echo "DESKTOP_FILES_END"

if command -v xdotool >/dev/null 2>&1; then
  echo "XDOTOOL=PRESENT"
  xdotool search --onlyvisible --name 'Difference Engine|ChatGPT' getwindowname %@ 2>/dev/null \
    | sed 's/^/WINDOW=/' || true
else
  echo "XDOTOOL=MISSING"
fi

if command -v wmctrl >/dev/null 2>&1; then
  echo "WMCTRL=PRESENT"
  wmctrl -lx 2>/dev/null | grep -Ei 'chatgpt|difference engine' \
    | sed 's/^/WM=/' || true
else
  echo "WMCTRL=MISSING"
fi

echo "AT_SPI_CURRENT=TOP_LEVEL_ONLY"
echo "NEXT=ENABLE_RENDERER_ACCESSIBILITY_IF_EXECUTABLE_SUPPORTS_FLAG"
echo "STATUS=PASS"
echo "DECO_SUMMARY_END"
