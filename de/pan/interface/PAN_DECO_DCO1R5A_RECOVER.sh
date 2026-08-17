#!/usr/bin/env bash
set -Eeuo pipefail

LATEST="$(find "$HOME/Forge-File-Tree-Directories" -maxdepth 1 -type d \
  -name 'DECO_DESKTOP_ACCESSIBILITY_ENABLE_*-DCO1R5' -print 2>/dev/null \
  | sort | tail -1)"

echo "DECO_SUMMARY_BEGIN"
echo "STAGE=DCO1R5A_RECOVER_ABORTED_POSTPROBE"

if [ -z "${LATEST:-}" ] || [ ! -f "$LATEST/04_DISCOVERY.txt" ]; then
  echo "STATUS=BLOCKED"
  echo "BLOCKER=DCO1R5_DISCOVERY_EVIDENCE_NOT_FOUND"
  echo "DECO_SUMMARY_END"
  exit 20
fi

getv() {
  awk -F= -v k="$1" '$1==k {sub(/^[^=]*=/,""); print; exit}' "$LATEST/04_DISCOVERY.txt"
}

APP_FOUND="$(getv APP_FOUND)"
TOTAL_NODES="$(getv TOTAL_NODES)"
ROLE_TYPES="$(getv ROLE_TYPES)"
EDITABLE_CANDIDATES="$(getv EDITABLE_CANDIDATES)"
COPY_CODE_BUTTONS="$(getv COPY_CODE_BUTTONS)"
SEND_BUTTONS="$(getv SEND_BUTTONS)"

echo "EVIDENCE=$LATEST"
echo "APP_FOUND=${APP_FOUND:-UNKNOWN}"
echo "TOTAL_ATSPI_NODES=${TOTAL_NODES:-0}"
echo "AT_SPI_ROLE_TYPES=${ROLE_TYPES:-0}"
echo "EDITABLE_CANDIDATES=${EDITABLE_CANDIDATES:-0}"
echo "COPY_CODE_BUTTONS=${COPY_CODE_BUTTONS:-0}"
echo "SEND_BUTTONS=${SEND_BUTTONS:-0}"

ACCESS=NO
if [ "${TOTAL_NODES:-0}" -gt 2 ] 2>/dev/null && [ "${ROLE_TYPES:-0}" -gt 2 ] 2>/dev/null; then
  ACCESS=YES
fi

echo "RENDERER_ACCESSIBILITY=$ACCESS"

BIN="$HOME/.local/bin"
APPS="$HOME/.local/share/applications"
WRAPPER="$BIN/chatgpt-deco"
OVERRIDE="$APPS/chatgpt-desktop-linux_chatgpt-desktop-linux.desktop"
mkdir -p "$BIN" "$APPS"

if [ "$ACCESS" = YES ]; then
  cat > "$WRAPPER" <<'EOF'
#!/usr/bin/env bash
exec /snap/bin/chatgpt-desktop-linux \
  --no-sandbox \
  --force-renderer-accessibility \
  "$@"
EOF
  chmod 0755 "$WRAPPER"

  cat > "$OVERRIDE" <<EOF
[Desktop Entry]
Name=ChatGPT Desktop
Comment=ChatGPT Desktop with DECO accessibility support
Exec=$WRAPPER
Icon=/snap/chatgpt-desktop-linux/current/meta/gui/icon.png
Terminal=false
Type=Application
Categories=Network;Utility;
StartupWMClass=chatgpt-desktop-linux
EOF
  chmod 0644 "$OVERRIDE"
  update-desktop-database "$APPS" >/dev/null 2>&1 || true

  echo "DESKTOP_LAUNCHER_OVERRIDE=INSTALLED"
  echo "STATUS=PASS"
  echo "NEXT=PATCH_DECO_COMPOSER_DISCOVERY_AND_ARM"
else
  echo "DESKTOP_LAUNCHER_OVERRIDE=NOT_INSTALLED"
  echo "STATUS=BLOCKED"
  echo "BLOCKER=RENDERER_ACCESSIBILITY_NOT_EXPOSED"
  echo "NEXT=FALL_BACK_TO_FIREFOX_OR_PATCH_ELECTRON_MAIN"
fi

echo "DECO_SUMMARY_END"
