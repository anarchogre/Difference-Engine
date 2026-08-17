#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$HOME/Forge-File-Tree-Directories/DECO_DESKTOP_ACCESSIBILITY_ENABLE_${TS}-DCO1R5"
BIN="$HOME/.local/bin"
APPS="$HOME/.local/share/applications"
WRAPPER="$BIN/chatgpt-deco"
OVERRIDE="$APPS/chatgpt-desktop-linux_chatgpt-desktop-linux.desktop"
ORIGINAL="/var/lib/snapd/desktop/applications/chatgpt-desktop-linux_chatgpt-desktop-linux.desktop"

mkdir -p "$OUT" "$BIN" "$APPS"

echo "=== DCO1R5 DESKTOP ACCESSIBILITY ENABLE ==="

MAIN_PID="$(
  pgrep -f '/snap/chatgpt-desktop-linux/.*/chatgpt-desktop-linux' 2>/dev/null \
    | while read -r pid; do
        [ -r "/proc/$pid/cmdline" ] || continue
        cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
        case "$cmd" in
          *" --type="*) ;;
          *) echo "$pid"; break ;;
        esac
      done
)"

if [ -z "${MAIN_PID:-}" ]; then
  echo "DECO_SUMMARY_BEGIN"
  echo "STAGE=DCO1R5"
  echo "STATUS=BLOCKED"
  echo "BLOCKER=CHATGPT_MAIN_PROCESS_NOT_FOUND"
  echo "EVIDENCE=$OUT"
  echo "DECO_SUMMARY_END"
  exit 20
fi

MAIN_CMD="$(tr '\0' ' ' < "/proc/$MAIN_PID/cmdline" 2>/dev/null || true)"
FRAME_TITLE="$(
python3 - <<'PY' 2>/dev/null || true
import gi
gi.require_version("Atspi","2.0")
from gi.repository import Atspi
d=Atspi.get_desktop(0)
for i in range(d.get_child_count()):
    app=d.get_child_at_index(i)
    try: name=app.get_name() or ""
    except: name=""
    if name=="chatgpt-desktop-linux":
        try:
            if app.get_child_count():
                print(app.get_child_at_index(0).get_name() or "")
        except: pass
        break
PY
)"

{
  echo "UTC=$TS"
  echo "MAIN_PID=$MAIN_PID"
  echo "MAIN_CMD=$MAIN_CMD"
  echo "FRAME_TITLE=$FRAME_TITLE"
  if [ -f "$ORIGINAL" ]; then
    echo "ORIGINAL_DESKTOP_SHA256=$(sha256sum "$ORIGINAL" | awk '{print $1}')"
  fi
} > "$OUT/00_PRE_STATE.txt"

cat > "$WRAPPER" <<'EOF'
#!/usr/bin/env bash
exec /snap/bin/chatgpt-desktop-linux \
  --no-sandbox \
  --force-renderer-accessibility \
  "$@"
EOF
chmod 0755 "$WRAPPER"

# Restart only the main app. Child processes should exit with it.
kill -TERM "$MAIN_PID" 2>/dev/null || true

for _ in $(seq 1 80); do
  if ! kill -0 "$MAIN_PID" 2>/dev/null; then
    break
  fi
  sleep 0.125
done

if kill -0 "$MAIN_PID" 2>/dev/null; then
  kill -KILL "$MAIN_PID" 2>/dev/null || true
  sleep 0.5
fi

nohup "$WRAPPER" >"$OUT/01_RELAUNCH_STDOUT.txt" 2>"$OUT/01_RELAUNCH_STDERR.txt" &
LAUNCH_PID=$!

# Wait for the Electron app to return.
APP_FOUND=NO
for _ in $(seq 1 120); do
  if pgrep -f '/snap/chatgpt-desktop-linux/.*/chatgpt-desktop-linux' >/dev/null 2>&1; then
    sleep 0.15
    APP_FOUND=YES
    break
  fi
  sleep 0.15
done

# Give renderer time to load and publish accessibility tree.
sleep 4

python3 - "$OUT" <<'PY'
from pathlib import Path
import sys, gi
gi.require_version("Atspi","2.0")
from gi.repository import Atspi

out=Path(sys.argv[1])
d=Atspi.get_desktop(0)

def name(o):
    try: return o.get_name() or ""
    except: return ""

def role(o):
    try: return (o.get_role_name() or "").lower()
    except: return ""

def children(o):
    xs=[]
    try:
        for i in range(o.get_child_count()):
            c=o.get_child_at_index(i)
            if c is not None: xs.append(c)
    except: pass
    return xs

def walk(root, limit=50000):
    stack=[(root,0)]
    n=0
    while stack and n<limit:
        o,depth=stack.pop()
        n+=1
        yield o,depth
        cs=children(o)
        for c in reversed(cs):
            stack.append((c,depth+1))

target=None
for app in children(d):
    if name(app)=="chatgpt-desktop-linux":
        target=app
        break

rows=[]
roles={}
editable=[]
copy_buttons=[]
send_buttons=[]

if target is not None:
    for o,depth in walk(target):
        r=role(o)
        n=name(o)
        roles[r]=roles.get(r,0)+1

        try:
            st=o.get_state_set()
            is_editable=st.contains(Atspi.StateType.EDITABLE)
        except:
            is_editable=False

        if is_editable or r in {"entry","text","paragraph"}:
            editable.append((depth,r,n))

        if r in {"button","push button"}:
            low=n.lower()
            if "copy code" in low:
                copy_buttons.append((depth,r,n))
            if "send" in low:
                send_buttons.append((depth,r,n))

        if depth <= 4 or is_editable or "chatgpt" in n.lower() or "send" in n.lower():
            rows.append(f"depth={depth}\trole={r!r}\tname={n!r}\teditable={is_editable}")

(out/"02_ATSPI_AFTER.txt").write_text("\n".join(rows)+"\n",encoding="utf-8")
(out/"03_ROLE_COUNTS.tsv").write_text(
    "role\tcount\n" + "".join(f"{r}\t{c}\n" for r,c in sorted(roles.items())),
    encoding="utf-8"
)

with (out/"04_DISCOVERY.txt").open("w",encoding="utf-8") as f:
    f.write(f"APP_FOUND={'YES' if target is not None else 'NO'}\n")
    f.write(f"TOTAL_NODES={sum(roles.values())}\n")
    f.write(f"ROLE_TYPES={len(roles)}\n")
    f.write(f"EDITABLE_CANDIDATES={len(editable)}\n")
    f.write(f"COPY_CODE_BUTTONS={len(copy_buttons)}\n")
    f.write(f"SEND_BUTTONS={len(send_buttons)}\n")
    for depth,r,n in editable[:20]:
        f.write(f"EDITABLE depth={depth} role={r!r} name={n!r}\n")
PY

source "$OUT/04_DISCOVERY.txt"

# Persist the launcher only if renderer accessibility materially appeared.
ACCESS=NO
if [ "${TOTAL_NODES:-0}" -gt 2 ] && [ "${ROLE_TYPES:-0}" -gt 2 ]; then
  ACCESS=YES
fi

if [ "$ACCESS" = YES ]; then
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
fi

NEW_MAIN_PID="$(
  pgrep -f '/snap/chatgpt-desktop-linux/.*/chatgpt-desktop-linux' 2>/dev/null \
    | while read -r pid; do
        [ -r "/proc/$pid/cmdline" ] || continue
        cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
        case "$cmd" in
          *" --type="*) ;;
          *) echo "$pid"; break ;;
        esac
      done
)"
NEW_CMD=""
[ -n "${NEW_MAIN_PID:-}" ] && NEW_CMD="$(tr '\0' ' ' < "/proc/$NEW_MAIN_PID/cmdline" 2>/dev/null || true)"

{
  echo "DECO_SUMMARY_BEGIN"
  echo "STAGE=DCO1R5_DESKTOP_ACCESSIBILITY_ENABLE"
  echo "APP_RELAUNCHED=$APP_FOUND"
  echo "OLD_FRAME_TITLE=$FRAME_TITLE"
  echo "NEW_MAIN_PID=${NEW_MAIN_PID:-NONE}"
  echo "NEW_CMD=${NEW_CMD:-UNKNOWN}"
  echo "TOTAL_ATSPI_NODES=${TOTAL_NODES:-0}"
  echo "AT_SPI_ROLE_TYPES=${ROLE_TYPES:-0}"
  echo "EDITABLE_CANDIDATES=${EDITABLE_CANDIDATES:-0}"
  echo "COPY_CODE_BUTTONS=${COPY_CODE_BUTTONS:-0}"
  echo "SEND_BUTTONS=${SEND_BUTTONS:-0}"
  echo "RENDERER_ACCESSIBILITY=$ACCESS"
  if [ "$ACCESS" = YES ]; then
    echo "DESKTOP_LAUNCHER_OVERRIDE=INSTALLED"
    echo "STATUS=PASS"
    echo "NEXT=REPAIR_DECO_COMPOSER_DISCOVERY_AGAINST_ENABLED_TREE"
  else
    echo "DESKTOP_LAUNCHER_OVERRIDE=NOT_INSTALLED"
    echo "STATUS=BLOCKED"
    echo "BLOCKER=FORCE_RENDERER_ACCESSIBILITY_DID_NOT_EXPOSE_WEB_TREE"
    echo "NEXT=FALL_BACK_TO_FIREFOX_ACCESSIBILITY_OR_PATCH_ELECTRON_MAIN"
  fi
  echo "EVIDENCE=$OUT"
  echo "DECO_SUMMARY_END"
} | tee "$OUT/SUMMARY.txt"
