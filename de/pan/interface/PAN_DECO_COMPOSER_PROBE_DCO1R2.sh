#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$HOME/Forge-File-Tree-Directories/DECO_COMPOSER_PROBE_${TS}-DCO1R2"
mkdir -p "$OUT"

python3 - "$OUT" <<'PY'
from pathlib import Path
import sys
import gi

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi

OUT = Path(sys.argv[1])
desktop = Atspi.get_desktop(0)

def role(o):
    try: return o.get_role_name() or ""
    except Exception: return ""

def name(o):
    try: return o.get_name() or ""
    except Exception: return ""

def states(o):
    out=[]
    try:
        s=o.get_state_set()
        for st,n in [
            (Atspi.StateType.FOCUSED,"FOCUSED"),
            (Atspi.StateType.EDITABLE,"EDITABLE"),
            (Atspi.StateType.ENABLED,"ENABLED"),
            (Atspi.StateType.SENSITIVE,"SENSITIVE"),
            (Atspi.StateType.SHOWING,"SHOWING"),
            (Atspi.StateType.VISIBLE,"VISIBLE"),
        ]:
            if s.contains(st): out.append(n)
    except Exception:
        pass
    return ",".join(out)

def children(o):
    out=[]
    try:
        for i in range(o.get_child_count()):
            c=o.get_child_at_index(i)
            if c is not None: out.append(c)
    except Exception:
        pass
    return out

def walk(root, limit=30000):
    stack=[(root,0)]
    n=0
    while stack and n < limit:
        o,d=stack.pop()
        n+=1
        yield o,d
        cs=children(o)
        for c in reversed(cs):
            stack.append((c,d+1))

rows=[]
apps=children(desktop)

for ai,app in enumerate(apps):
    appname=name(app)
    rows.append(f"APP\t{ai}\t{appname!r}\trole={role(app)!r}")
    for o,d in walk(app):
        r=role(o).lower()
        n=name(o)
        st=states(o)
        interesting = (
            r in {"entry","text","paragraph","terminal","button","push button","document web","document frame","frame","application"}
            or "chatgpt" in n.lower()
            or "send" in n.lower()
            or "message" in n.lower()
            or "ask chatgpt" in n.lower()
        )
        if interesting:
            rows.append(
                f"NODE\tapp={ai}\tdepth={d}\trole={r!r}\tname={n!r}\tstates={st}"
            )

(OUT/"01_ATSPI_INTERESTING.tsv").write_text("\n".join(rows)+"\n", encoding="utf-8")

print("=== DECO COMPOSER PROBE / DCO1R2 ===")
print(f"APP_COUNT={len(apps)}")
for line in rows:
    if line.startswith("APP\t"):
        print(line)
print(f"EVIDENCE={OUT}/01_ATSPI_INTERESTING.tsv")
print("DCO1R2_STATUS=PASS")
print("DCO1R2_COMPLETE=YES")
print("NEXT=UPLOAD_OR_PASTE_ATSPI_INTERESTING_TSV")
PY
