#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date -u +%Y%m%dT%H%M%SZ)"
EVID="$HOME/Forge-File-Tree-Directories/DECO_RECOVERY_INSTALL_${TS}-DCO1R"
BIN="$HOME/.local/bin"
UNITDIR="$HOME/.config/systemd/user"
STATE="$HOME/.local/state/deco"
RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

mkdir -p "$EVID" "$BIN" "$UNITDIR" "$STATE"

echo "=== DECO RECOVERY INSTALL / DCO1R ==="

# Preserve old service state before touching it.
{
  echo "UTC=$TS"
  echo "SESSION=${XDG_SESSION_TYPE:-}"
  echo "DESKTOP=${XDG_CURRENT_DESKTOP:-}"
  echo "DISPLAY=${DISPLAY:-}"
  echo "XAUTHORITY=${XAUTHORITY:-}"
  echo
  systemctl --user status de-bridge-watch.service --no-pager 2>&1 || true
  echo
  systemctl --user status ydotool.service --no-pager 2>&1 || true
  echo
  ls -l "$UNITDIR/de-bridge-watch.service" 2>&1 || true
  ls -l "$UNITDIR/default.target.wants/de-bridge-watch.service" 2>&1 || true
} > "$EVID/00_PRE_STATE.txt"

# Old watcher is broken/stale and must not race the recovered bridge.
systemctl --user disable --now de-bridge-watch.service >/dev/null 2>&1 || true

cat > "$BIN/deco-watch" <<'PY'
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path

import gi

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi

SESSION = os.environ.get("XDG_SESSION_TYPE", "").lower()
HOME = Path.home()
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
STATE_DIR = HOME / ".local/state/deco"
STATE_DIR.mkdir(parents=True, exist_ok=True)
SEEN_FILE = STATE_DIR / "seen.json"
RUN_DIR = RUNTIME / "deco"
RUN_DIR.mkdir(parents=True, exist_ok=True)

POLL = 2.0
COPY_WAIT = 3.0
RUN_TIMEOUT = 60 * 60
COMPOSER_WAIT = 45.0

AUTHORIZED_PREFIX = "# DE-RUN"

PLACEHOLDERS = {
    "",
    "ask chatgpt",
    "message chatgpt",
    "chat with chatgpt",
}


class DecoError(RuntimeError):
    pass


def emit(s):
    print(s, flush=True)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def role_name(obj):
    try:
        return (obj.get_role_name() or "").lower()
    except Exception:
        return ""


def obj_name(obj):
    try:
        return obj.get_name() or ""
    except Exception:
        return ""


def children(obj):
    try:
        n = obj.get_child_count()
    except Exception:
        return []
    out = []
    for i in range(n):
        try:
            c = obj.get_child_at_index(i)
            if c is not None:
                out.append(c)
        except Exception:
            pass
    return out


def walk(root, limit=20000):
    stack = [root]
    seen = 0
    while stack and seen < limit:
        obj = stack.pop()
        seen += 1
        yield obj
        cs = children(obj)
        for c in reversed(cs):
            stack.append(c)


def desktop_apps():
    desktop = Atspi.get_desktop(0)
    return children(desktop)


def focused(obj):
    try:
        return obj.get_state_set().contains(Atspi.StateType.FOCUSED)
    except Exception:
        return False


def grab_focus(obj, timeout=10.0):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            Atspi.Component.grab_focus(obj)
        except Exception:
            pass
        if focused(obj):
            return True
        time.sleep(0.1)
    return False


def text_of(obj):
    try:
        count = Atspi.Text.get_character_count(obj)
        return Atspi.Text.get_text(obj, 0, count)
    except Exception:
        return None


def reconstruct_text(obj):
    direct = text_of(obj)
    if direct not in (None, ""):
        return direct

    parts = []
    for c in children(obj):
        t = text_of(c)
        if t is not None:
            parts.append(t)
    if parts:
        return "\n".join(parts)

    return ""


def discover_terminal():
    candidates = []
    for app in desktop_apps():
        appname = obj_name(app).lower()
        for obj in walk(app):
            if role_name(obj) == "terminal":
                score = 0
                if "terminal" in appname:
                    score += 3
                if "xfce" in appname or "ptyxis" in appname:
                    score += 2
                if focused(obj):
                    score += 1
                candidates.append((score, appname, obj))
    if not candidates:
        raise DecoError("TERMINAL_DISCOVERY=FAIL")
    candidates.sort(key=lambda x: x[0], reverse=True)
    return candidates[0][2]


def composer_score(app, obj):
    role = role_name(obj)
    name = obj_name(obj).lower()
    if role not in {"entry", "text", "paragraph"}:
        return -1
    score = 0
    if "chatgpt" in name:
        score += 7
    if name in {"ask chatgpt", "message chatgpt", "chat with chatgpt"}:
        score += 10
    appname = obj_name(app).lower()
    if "chatgpt" in appname:
        score += 6
    elif "firefox" in appname:
        score += 3
    return score


def discover_chat():
    composer_candidates = []

    for app in desktop_apps():
        # Current governed target is the ChatGPT desktop wrapper only.
        # Firefox is historical substrate, not a fallback.
        if "chatgpt" not in obj_name(app).lower():
            continue

        for obj in walk(app):
            score = composer_score(app, obj)
            if score >= 7:
                composer_candidates.append((score, app, obj))

    if not composer_candidates:
        raise DecoError("COMPOSER_DISCOVERY=FAIL")

    composer_candidates.sort(key=lambda x: x[0], reverse=True)
    _, app, composer = composer_candidates[0]
    return app, composer


def actionable(obj):
    try:
        count = Atspi.Action.get_n_actions(obj)
    except Exception:
        return False
    return count > 0


def press(obj):
    try:
        count = Atspi.Action.get_n_actions(obj)
    except Exception as exc:
        raise DecoError("ACTION_QUERY=FAIL") from exc

    preferred = []
    other = []
    for i in range(count):
        try:
            name = (Atspi.Action.get_action_name(obj, i) or "").lower()
        except Exception:
            name = ""
        if name in {"press", "click", "activate"}:
            preferred.append(i)
        else:
            other.append(i)

    for i in preferred + other:
        try:
            if Atspi.Action.do_action(obj, i):
                return True
        except Exception:
            pass

    return False


def copy_code_buttons(app):
    out = []
    for obj in walk(app):
        r = role_name(obj)
        if r not in {"button", "push button"}:
            continue

        # Current ChatGPT desktop exposes the code-box control as
        # exactly "Copy".  "Copy message"/"Copy response" are excluded.
        if obj_name(obj).strip().lower() == "copy":
            out.append(obj)

    return out


def send_buttons(app):
    out = []
    for obj in walk(app):
        r = role_name(obj)
        if r not in {"button", "push button"}:
            continue
        n = obj_name(obj).strip().lower()
        if "send" in n and "prompt" in n:
            out.append(obj)
        elif n in {"send", "send message"}:
            out.append(obj)
    return out


def clipboard_x11():
    gi.require_version("Gtk", "3.0")
    gi.require_version("Gdk", "3.0")
    from gi.repository import Gtk, Gdk
    return Gtk, Gdk, Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)


def clipboard_get() -> bytes:
    if SESSION == "x11":
        Gtk, Gdk, clip = clipboard_x11()
        text = clip.wait_for_text()
        if text is None:
            return b""
        return text.encode("utf-8")

    run = subprocess.run(
        ["wl-paste", "--no-newline", "--type", "text"],
        capture_output=True,
    )
    if run.returncode != 0:
        raise DecoError(f"CLIPBOARD_READ=FAIL:{run.returncode}")
    return run.stdout


def clipboard_set(data: bytes):
    text = data.decode("utf-8", errors="replace")

    if SESSION == "x11":
        Gtk, Gdk, clip = clipboard_x11()
        clip.set_text(text, -1)
        clip.store()

        got = clip.wait_for_text()
        if got != text:
            raise DecoError("CLIPBOARD_WRITE_VERIFY=FAIL")
        return

    run = subprocess.run(["wl-copy"], input=data)
    if run.returncode != 0:
        raise DecoError(f"CLIPBOARD_WRITE=FAIL:{run.returncode}")


def clipboard_clear():
    if SESSION == "x11":
        Gtk, Gdk, _ = clipboard_x11()

        for selection in (
            Gdk.SELECTION_CLIPBOARD,
            Gdk.SELECTION_PRIMARY,
        ):
            clip = Gtk.Clipboard.get(selection)
            clip.set_text("", -1)
            clip.store()

        return

    subprocess.run(
        ["wl-copy", "--clear"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def keycode(name):
    path = "/usr/include/linux/input-event-codes.h"
    rx = re.compile(rf"^#define\s+{re.escape(name)}\s+(\d+)")
    with open(path, encoding="utf-8", errors="replace") as h:
        for line in h:
            m = rx.match(line)
            if m:
                return int(m.group(1))
    raise DecoError(f"KEYCODE_NOT_FOUND={name}")


def ydotool_key(sequence):
    env = dict(os.environ)
    socket = env.get("YDOTOOL_SOCKET")
    if not socket:
        candidates = [
            RUNTIME / "de-ydotool.sock",
            RUNTIME / ".ydotool_socket",
            RUNTIME / "ydotool.sock",
        ]
        for c in candidates:
            if c.exists():
                env["YDOTOOL_SOCKET"] = str(c)
                break
    run = subprocess.run(["ydotool", "key", *sequence], env=env)
    if run.returncode != 0:
        raise DecoError(f"YDOTOOL=FAIL:{run.returncode}")


def paste_terminal_command(command: str):
    terminal = discover_terminal()
    if not grab_focus(terminal, 10.0):
        raise DecoError("TERMINAL_FOCUS=FAIL")

    clipboard_set(command.encode())

    ctrl = keycode("KEY_LEFTCTRL")
    shift = keycode("KEY_LEFTSHIFT")
    v = keycode("KEY_V")
    enter = keycode("KEY_ENTER")

    try:
        ydotool_key([
            f"{ctrl}:1", f"{shift}:1", f"{v}:1",
            f"{v}:0", f"{shift}:0", f"{ctrl}:0",
        ])
        time.sleep(0.25)
    finally:
        # Never leave an executable command armed in either X11 selection.
        clipboard_clear()

    ydotool_key([f"{enter}:1", f"{enter}:0"])


def load_seen():
    try:
        data = json.loads(SEEN_FILE.read_text())
        if isinstance(data, list):
            return set(x for x in data if isinstance(x, str))
    except Exception:
        pass
    return set()


def save_seen(seen):
    tmp = SEEN_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(sorted(seen), indent=2) + "\n")
    tmp.chmod(0o600)
    tmp.replace(SEEN_FILE)


def authorized(payload: bytes):
    first = payload.split(b"\n", 1)[0].strip()
    return first == AUTHORIZED_PREFIX.encode()


def wait_clipboard_change(before: bytes):
    deadline = time.monotonic() + COPY_WAIT
    while time.monotonic() < deadline:
        try:
            now = clipboard_get()
        except Exception:
            now = b""
        if now and now != before:
            return now
        time.sleep(0.08)
    return clipboard_get()


def probe_copy_button(button):
    before = clipboard_get()

    if not press(button):
        raise DecoError("COPY_CODE_ACTION=FAIL")

    payload = wait_clipboard_change(before)

    if not payload:
        clipboard_clear()
        raise DecoError("COPY_CODE_CLIPBOARD=EMPTY")

    # Clipboard is transport, never durable state.
    clipboard_clear()
    return payload


def run_payload(payload: bytes, digest: str):
    taskdir = RUN_DIR / digest[:16]
    taskdir.mkdir(parents=True, exist_ok=True)

    payload_path = taskdir / "payload.sh"
    full_path = taskdir / "output.txt"
    rc_path = taskdir / "exit.txt"
    done_path = taskdir / "done"

    payload_path.write_bytes(payload)
    payload_path.chmod(0o700)

    for p in (full_path, rc_path, done_path):
        try:
            p.unlink()
        except FileNotFoundError:
            pass

    q_payload = shlex.quote(str(payload_path))
    q_full = shlex.quote(str(full_path))
    q_rc = shlex.quote(str(rc_path))
    q_done = shlex.quote(str(done_path))

    command = (
        f"bash {q_payload} 2>&1 | tee {q_full}; "
        f"rc=${{PIPESTATUS[0]}}; "
        f"printf '%s\\n' \"$rc\" > {q_rc}; "
        f"touch {q_done}; "
        f"printf '__DECO_DONE__ EXIT=%s\\n' \"$rc\""
    )

    emit(f"TASK_SHA256={digest}")
    emit(f"TASK_PATH={payload_path}")
    emit("TERMINAL_EXECUTION=START")

    paste_terminal_command(command)

    deadline = time.monotonic() + RUN_TIMEOUT
    while time.monotonic() < deadline:
        if done_path.exists() and rc_path.exists() and full_path.exists():
            break
        time.sleep(0.25)
    else:
        raise DecoError("RUN_TIMEOUT")

    try:
        rc = int(rc_path.read_text().strip())
    except Exception as exc:
        raise DecoError("EXIT_READ=FAIL") from exc

    output = full_path.read_bytes()
    emit(f"OUTPUT_BYTES={len(output)}")
    emit(f"OUTPUT_SHA256={sha256(output)}")
    emit(f"COMMAND_EXIT={rc}")

    return rc, output


def reduce_output(output: bytes, rc: int, digest: str) -> bytes:
    text = output.decode("utf-8", errors="replace")
    lines = text.splitlines()

    begin = None
    end = None
    for i, line in enumerate(lines):
        if line.strip() == "DECO_SUMMARY_BEGIN":
            begin = i + 1
        elif line.strip() == "DECO_SUMMARY_END" and begin is not None:
            end = i
    if begin is not None:
        chosen = lines[begin:end] if end is not None else lines[begin:]
    else:
        key_rx = re.compile(
            r"^(?:"
            r"STATUS|BLOCKER|NEXT|EVIDENCE|COMMIT|"
            r".*COMPLETE|.*STATUS|.*PASS|.*FAIL|.*ERROR|"
            r".*_COUNT|.*_TOTAL|.*_FRONTIER|.*_MUTATION|"
            r"SOURCE_HASHES|LIVE_.*|REPOSITORY_.*"
            r")="
        )
        keyed = [ln for ln in lines if key_rx.match(ln.strip())]
        if rc != 0:
            tail = lines[-80:]
            chosen = keyed[-80:] + ["--- ERROR TAIL ---"] + tail
        elif keyed:
            chosen = keyed[-120:]
        else:
            chosen = lines[-80:]

    body = "\n".join(chosen).strip()
    if len(body) > 14000:
        body = body[-14000:]

    envelope = (
        "DECO_RESULT\n"
        f"TASK_SHA256={digest}\n"
        f"EXIT={rc}\n"
        f"OUTPUT_BYTES={len(output)}\n"
        f"OUTPUT_SHA256={sha256(output)}\n"
        "--- CONTINUATION ---\n"
        f"{body}\n"
    )
    return envelope.encode("utf-8")


def composer_empty(composer):
    raw = reconstruct_text(composer)
    norm = (raw or "").strip().lower()
    if norm in PLACEHOLDERS:
        return True

    # Common contenteditable representation: one child holding placeholder.
    cs = children(composer)
    if len(cs) == 1:
        t = (text_of(cs[0]) or "").strip().lower()
        if t in PLACEHOLDERS:
            return True

    return False


def payload_present(composer, payload: bytes):
    want = payload.decode("utf-8", errors="replace").rstrip("\n")

    for obj in walk(composer, 5000):
        t = text_of(obj)
        if t is not None and t.rstrip("\n") == want:
            return True

    try:
        parts = []
        for c in children(composer):
            t = text_of(c)
            if t is None:
                return False
            parts.append(t)
        joined = "\n".join(parts).rstrip("\n")
        if joined == want:
            return True
    except Exception:
        pass

    return False


def return_result(payload: bytes):
    deadline = time.monotonic() + COMPOSER_WAIT

    while time.monotonic() < deadline:
        try:
            app, composer = discover_chat()
            if composer_empty(composer):
                break
        except Exception:
            pass
        time.sleep(0.25)
    else:
        raise DecoError("COMPOSER_EMPTY_GATE=TIMEOUT")

    if not grab_focus(composer, 10.0):
        raise DecoError("COMPOSER_FOCUS=FAIL")

    clipboard_set(payload)

    ctrl = keycode("KEY_LEFTCTRL")
    v = keycode("KEY_V")

    try:
        ydotool_key([
            f"{ctrl}:1", f"{v}:1", f"{v}:0", f"{ctrl}:0"
        ])
        time.sleep(0.25)
    finally:
        # Result must never remain as ambient clipboard/PRIMARY state.
        clipboard_clear()

    verify_deadline = time.monotonic() + 8.0
    while time.monotonic() < verify_deadline:
        try:
            app, composer = discover_chat()
            if payload_present(composer, payload):
                break
        except Exception:
            pass
        time.sleep(0.15)
    else:
        raise DecoError("RETURN_PAYLOAD_GATE=FAIL")

    emit("RETURN_PAYLOAD_GATE=PASS")

    send_deadline = time.monotonic() + 20.0
    while time.monotonic() < send_deadline:
        app, composer = discover_chat()
        buttons = send_buttons(app)
        for b in reversed(buttons):
            try:
                states = b.get_state_set()
                ready = (
                    states.contains(Atspi.StateType.ENABLED)
                    and states.contains(Atspi.StateType.SENSITIVE)
                )
            except Exception:
                ready = False
            if ready and press(b):
                emit("SEND_ACTION=PASS")
                return
        time.sleep(0.15)

    raise DecoError("SEND_ACTION=FAIL")


def current_copy_count():
    app, composer = discover_chat()
    return len(copy_code_buttons(app))


def doctor():
    emit(f"SESSION={SESSION or 'unknown'}")

    terminal = discover_terminal()
    emit(f"TERMINAL_NAME={obj_name(terminal)!r}")
    emit("TERMINAL_DISCOVERY=PASS")

    app, composer = discover_chat()
    emit(f"CHAT_APP={obj_name(app)!r}")
    emit(f"COMPOSER_NAME={obj_name(composer)!r}")
    emit("COMPOSER_DISCOVERY=PASS")

    buttons = copy_code_buttons(app)
    emit(f"COPY_CODE_BUTTONS={len(buttons)}")

    send = send_buttons(app)
    emit(f"SEND_BUTTONS={len(send)}")

    token = f"DECO_CLIPBOARD_PROBE_{time.time_ns()}".encode()
    clipboard_set(token)

    try:
        got = clipboard_get()
        if got != token:
            raise DecoError("CLIPBOARD_ROUNDTRIP=FAIL")
    finally:
        clipboard_clear()

    emit("CLIPBOARD_ROUNDTRIP=PASS")

    # Confirm required executable pieces.
    for cmd in ("ydotool", "bash", "tee"):
        path = shutil_which(cmd)
        if not path:
            raise DecoError(f"BINARY_MISSING={cmd}")
        emit(f"BINARY_{cmd.upper()}={path}")

    emit("DECO_DOCTOR=PASS")
    return 0


def shutil_which(cmd):
    for d in os.environ.get("PATH", "").split(os.pathsep):
        p = Path(d) / cmd
        if p.is_file() and os.access(p, os.X_OK):
            return str(p)
    return None


def watch():
    seen = load_seen()
    emit(f"SEEN_HASHES={len(seen)}")

    # Baseline the current page. Existing code boxes are never executed
    # merely because the watcher starts.
    while True:
        try:
            baseline = current_copy_count()
            break
        except DecoError as exc:
            emit(f"WAITING={exc}")
            time.sleep(1.0)

    emit(f"BASELINE_COPY_CODE_BUTTONS={baseline}")
    emit("DECO_ARMED=YES")

    previous_count = baseline
    waiting_reset = False

    while True:
        try:
            app, composer = discover_chat()
            buttons = copy_code_buttons(app)
            count = len(buttons)

            if count < previous_count:
                # DOM/navigation changed. Rebaseline fail-closed.
                previous_count = count
                emit(f"REBASELINE_COPY_CODE_BUTTONS={count}")
                time.sleep(POLL)
                continue

            if count > previous_count:
                emit(
                    f"NEW_COPY_CODE_BUTTONS={count - previous_count}"
                )

                # Only inspect newly appended buttons, newest first.
                new_buttons = buttons[previous_count:count]
                previous_count = count

                for b in reversed(new_buttons):
                    try:
                        payload = probe_copy_button(b)
                    except Exception as exc:
                        emit(
                            "COPY_PROBE_ERROR="
                            + type(exc).__name__
                            + ":"
                            + str(exc)
                        )
                        continue

                    if not authorized(payload):
                        emit("CODE_BLOCK_IGNORED=UNAUTHORIZED")
                        continue

                    digest = sha256(payload)

                    if digest in seen:
                        emit("CODE_BLOCK_IGNORED=DUPLICATE")
                        continue

                    # Persist authorization consumption BEFORE execution.
                    seen.add(digest)
                    save_seen(seen)

                    emit("AUTHORIZATION_GATE=PASS")
                    emit(f"INPUT_SHA256={digest}")

                    try:
                        rc, output = run_payload(payload, digest)
                        result = reduce_output(output, rc, digest)
                        return_result(result)
                        emit("DECO_CYCLE=PASS")
                    except Exception as exc:
                        emit(
                            "DECO_CYCLE_ERROR="
                            + type(exc).__name__
                            + ":"
                            + str(exc)
                        )

                continue

            time.sleep(POLL)

        except KeyboardInterrupt:
            emit("DECO_WATCH=INTERRUPTED")
            return 130

        except Exception as exc:
            emit(
                "WATCH_ERROR="
                + type(exc).__name__
                + ":"
                + str(exc)
            )
            time.sleep(1.0)


def main():
    p = argparse.ArgumentParser()
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--doctor", action="store_true")
    g.add_argument("--watch", action="store_true")
    args = p.parse_args()

    try:
        if args.doctor:
            return doctor()
        return watch()
    except DecoError as exc:
        emit(f"DECO_ERROR={exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
PY

chmod 0755 "$BIN/deco-watch"

# Compile before installation continues.
python3 -m py_compile "$BIN/deco-watch"

# Import current graphical environment into user systemd.
systemctl --user import-environment \
  DISPLAY XAUTHORITY XDG_SESSION_TYPE XDG_CURRENT_DESKTOP \
  DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR PATH \
  >/dev/null 2>&1 || true

# Resolve the surviving ydotool socket.
YDOTOOL_SOCKET_PATH=""
for candidate in \
  "$RUNTIME/de-ydotool.sock" \
  "$RUNTIME/.ydotool_socket" \
  "$RUNTIME/ydotool.sock"
do
  if [ -S "$candidate" ]; then
    YDOTOOL_SOCKET_PATH="$candidate"
    break
  fi
done

if [ -z "$YDOTOOL_SOCKET_PATH" ]; then
  YDOTOOL_SOCKET_PATH="$RUNTIME/de-ydotool.sock"
fi

cat > "$UNITDIR/deco-watch.service" <<EOF
[Unit]
Description=Difference Engine DECO ChatGPT desktop-or-Firefox terminal bridge
After=graphical-session.target ydotool.service

[Service]
Type=simple
Environment=YDOTOOL_SOCKET=$YDOTOOL_SOCKET_PATH
ExecStart=$BIN/deco-watch --watch
Restart=on-failure
RestartSec=2
TimeoutStopSec=5

[Install]
WantedBy=default.target
EOF

# Doctor runs in the active shell first, before daemonization.
set +e
"$BIN/deco-watch" --doctor > "$EVID/01_DOCTOR.txt" 2>&1
DOCTOR_RC=$?
set -e

cat "$EVID/01_DOCTOR.txt"

if [ "$DOCTOR_RC" -ne 0 ]; then
  cat > "$EVID/SUMMARY.txt" <<EOF
DCO1R_STATUS=BLOCKED
DOCTOR_EXIT=$DOCTOR_RC
OLD_BRIDGE_DISABLED=YES
DECO_INSTALLED=$BIN/deco-watch
SERVICE_INSTALLED=$UNITDIR/deco-watch.service
EVIDENCE=$EVID
NEXT=INSPECT_DOCTOR_FAILURE
EOF
  cat "$EVID/SUMMARY.txt"
  exit "$DOCTOR_RC"
fi

systemctl --user daemon-reload
systemctl --user enable --now deco-watch.service

sleep 2

systemctl --user status deco-watch.service --no-pager \
  > "$EVID/02_SERVICE_STATUS.txt" 2>&1 || true

journalctl --user -u deco-watch.service --since '-2 min' --no-pager \
  > "$EVID/03_SERVICE_JOURNAL.txt" 2>&1 || true

if ! grep -Fq "DECO_ARMED=YES" "$EVID/03_SERVICE_JOURNAL.txt"; then
  cat "$EVID/02_SERVICE_STATUS.txt"
  cat "$EVID/03_SERVICE_JOURNAL.txt"
  cat > "$EVID/SUMMARY.txt" <<EOF
DCO1R_STATUS=BLOCKED
DOCTOR=PASS
SERVICE_ARMED=NO
OLD_BRIDGE_DISABLED=YES
EVIDENCE=$EVID
NEXT=INSPECT_DECO_SERVICE_DISCOVERY
EOF
  cat "$EVID/SUMMARY.txt"
  exit 30
fi

cat > "$EVID/SUMMARY.txt" <<EOF
DCO1R_STATUS=PASS
DOCTOR=PASS
OLD_BRIDGE_DISABLED=YES
SESSION=${XDG_SESSION_TYPE:-unknown}
DESKTOP=${XDG_CURRENT_DESKTOP:-unknown}
YDOTOOL_SOCKET=$YDOTOOL_SOCKET_PATH
DECO_INSTALLED=$BIN/deco-watch
SERVICE_INSTALLED=$UNITDIR/deco-watch.service
SERVICE_ARMED=YES
SOURCE_MUTATION=NONE
REPOSITORY_MUTATION=NONE
EVIDENCE=$EVID
TARGET_ORDER=CHATGPT_APP_THEN_FIREFOX
NEXT=SEND_ONE_NEW_AUTHORIZED_DE_RUN_CODE_BLOCK
EOF

cat "$EVID/SUMMARY.txt"
echo "DCO1R_COMPLETE=YES"
