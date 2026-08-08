#!/usr/bin/env python3

import gi
import os
import re
import subprocess
import sys
import time
import warnings

warnings.filterwarnings("ignore", category=DeprecationWarning)

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi

RUNTIME = os.environ.get(
    "XDG_RUNTIME_DIR",
    f"/run/user/{os.getuid()}",
)
SOCKET = os.environ.get(
    "YDOTOOL_SOCKET",
    os.path.join(RUNTIME, "de-ydotool.sock"),
)

PLACEHOLDER = "Ask ChatGPT"


def fail(message, code=1):
    print(message)
    raise SystemExit(code)


def keycode(name):
    rx = re.compile(rf"^#define\s+{re.escape(name)}\s+(\d+)")
    path = "/usr/include/linux/input-event-codes.h"

    with open(path) as fh:
        for line in fh:
            match = rx.match(line)
            if match:
                return int(match.group(1))

    fail(f"KEYCODE_NOT_FOUND={name}")


def find_firefox_composer():
    desktop = Atspi.get_desktop(0)

    for i in range(desktop.get_child_count()):
        app = desktop.get_child_at_index(i)

        try:
            if "firefox" not in (app.get_name() or "").lower():
                continue
        except Exception:
            continue

        stack = [app]

        while stack:
            obj = stack.pop()

            try:
                if (
                    obj.get_role_name() == "entry"
                    and obj.get_name() == "Chat with ChatGPT"
                ):
                    return app, obj
            except Exception:
                pass

            try:
                for j in range(obj.get_child_count() - 1, -1, -1):
                    child = obj.get_child_at_index(j)
                    if child is not None:
                        stack.append(child)
            except Exception:
                pass

    return None, None


def find_send(firefox):
    stack = [firefox]

    while stack:
        obj = stack.pop()

        try:
            if (
                obj.get_role_name().lower() in ("button", "push button")
                and obj.get_name() == "Send prompt"
            ):
                return obj
        except Exception:
            pass

        try:
            for j in range(obj.get_child_count() - 1, -1, -1):
                child = obj.get_child_at_index(j)
                if child is not None:
                    stack.append(child)
        except Exception:
            pass

    return None


def text_of(obj):
    count = Atspi.Text.get_character_count(obj)
    return Atspi.Text.get_text(obj, 0, count)


def payload_present(composer, payload):
    stack = [composer]

    while stack:
        obj = stack.pop()

        try:
            value = text_of(obj)

            if (
                value == payload
                or value.rstrip("\n") == payload.rstrip("\n")
            ):
                return True
        except Exception:
            pass

        try:
            for j in range(obj.get_child_count() - 1, -1, -1):
                child = obj.get_child_at_index(j)
                if child is not None:
                    stack.append(child)
        except Exception:
            pass

    return False


# Clipboard is the transport from de-copyout.
result = subprocess.run(
    ["wl-paste", "--no-newline", "--type", "text"],
    capture_output=True,
    text=True,
)

if result.returncode != 0:
    fail("CLIPBOARD_READ=FAIL")

payload = result.stdout

if not payload:
    fail("CLIPBOARD_PAYLOAD=EMPTY")

if not os.path.exists(SOCKET):
    fail(f"YDOTOOL_SOCKET=ABSENT:{SOCKET}")

firefox, composer = find_firefox_composer()

if composer is None:
    fail("COMPOSER=NOT_FOUND")

# Fail closed: never overwrite an occupied composer.
if composer.get_child_count() != 1:
    fail("EMPTY_GATE=FAIL")

editor = composer.get_child_at_index(0)

try:
    before = text_of(editor)
except Exception:
    fail("EMPTY_GATE=UNREADABLE")

if before.strip() != PLACEHOLDER:
    fail("EMPTY_GATE=FAIL")

print("EMPTY_GATE=PASS")

Atspi.Component.grab_focus(composer)

focused = False

for _ in range(30):
    try:
        focused = composer.get_state_set().contains(
            Atspi.StateType.FOCUSED
        )
    except Exception:
        focused = False

    if focused:
        break

    time.sleep(0.1)

if not focused:
    fail("FOCUS_GATE=FAIL")

print("FOCUS_GATE=PASS")

ctrl = keycode("KEY_LEFTCTRL")
v = keycode("KEY_V")

env = dict(os.environ)
env["YDOTOOL_SOCKET"] = SOCKET

subprocess.run(
    [
        "ydotool",
        "key",
        f"{ctrl}:1",
        f"{v}:1",
        f"{v}:0",
        f"{ctrl}:0",
    ],
    env=env,
    check=True,
)

# State-based payload gate.
payload_ok = False

for _ in range(50):
    firefox, composer = find_firefox_composer()

    if composer is not None and payload_present(composer, payload):
        payload_ok = True
        break

    time.sleep(0.1)

if not payload_ok:
    fail("PAYLOAD_GATE=FAIL")

print("PAYLOAD_GATE=PASS")

# State-based Send gate.
send = None

for _ in range(150):
    firefox, composer = find_firefox_composer()

    if firefox is None:
        time.sleep(0.1)
        continue

    candidate = find_send(firefox)

    if candidate is not None:
        states = candidate.get_state_set()

        enabled = states.contains(Atspi.StateType.ENABLED)
        sensitive = states.contains(Atspi.StateType.SENSITIVE)

        if enabled and sensitive:
            send = candidate
            break

    time.sleep(0.1)

if send is None:
    fail("SEND_STATE_GATE=FAIL")

print("SEND_STATE_GATE=PASS")

count = Atspi.Action.get_n_actions(send)

if count != 1:
    fail(f"ACTION_GATE=FAIL:COUNT={count}")

name = Atspi.Action.get_action_name(send, 0)

if name != "press":
    fail(f"ACTION_GATE=FAIL:NAME={name!r}")

print("ACTION_GATE=PASS")

if not Atspi.Action.do_action(send, 0):
    fail("SEND_ACTION=FAIL")

print("SEND_ACTION=PASS")
print("CHATGPT_RETURN_TEXT=PASS")
