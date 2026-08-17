#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT="$HOME/Difference-Engine"
TREE_HOME="$HOME/Forge-File-Tree-Directories"
SERVICE="$CURRENT/workspace/operational/ingestion/service"
PYTHON="/usr/bin/python3"
RUN_ALL="$SERVICE/tests/run_all.py"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$TREE_HOME/PAN_BUILD_SANDBOX_DOCX_ADAPTER_$TS-STAGE49"
SANDBOX="$OUT/sandbox"
mkdir -p "$OUT" "$SANDBOX"

echo "=== PAN — SANDBOX DOCX ADAPTER / STAGE 49 ==="

STAGE48="$(
"$PYTHON" - "$TREE_HOME" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]); hits=[]
for d in root.iterdir():
    s=d/"SUMMARY.txt"
    if d.is_dir() and s.is_file():
        t=s.read_text(encoding="utf-8",errors="replace")
        if ("PAN_RECOVER_DOCX_CAPABILITY_AND_QUALIFY_FRONTIER_STAGE48" in t
            and "STATUS=PASS" in t
            and "DOCX_FRONTIER=11" in t
            and "NEXT=RECOVER_OR_DEFINE_MINIMAL_DOCX_EXTRACTION_CONTRACT_FROM_SURVIVING_REPOSITORY_PRIMITIVES_AND_BUILD_SANDBOX_ADAPTER_ONLY" in t):
            hits.append((d.stat().st_mtime_ns,d))
if hits: print(max(hits)[1])
PY
)"
[ -n "$STAGE48" ] || { echo "BLOCKER: Stage48 not found"; exit 20; }

QUAL="$STAGE48/03_DOCX_QUALIFICATION_LEDGER.tsv"
CAP="$STAGE48/08_CAPABILITY_RECOVERY_CLASSIFICATION.txt"
[ -f "$QUAL" ] && [ -f "$CAP" ] || { echo "BLOCKER: Stage48 artifacts missing"; exit 21; }

grep -Fqx "REPOSITORY_DOCX_STATE=DOCX_REFERENCES_FOUND_NO_CONFIRMED_SERVICE_IMPLEMENTATION" "$CAP" || exit 22
grep -Fqx "RUNTIME_PYTHON_DOCX=NO" "$CAP" || exit 23

git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/00_GIT_PRE.z" 2>/dev/null || true
RECEIPTS="$CURRENT/workspace/operational/ingestion/receipts"
OUTPUT="$CURRENT/workspace/operational/ingestion/output"
find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c > "$OUT/00_OUTPUT_PRE.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c > "$OUT/00_RECEIPTS_PRE.txt"

(
 cd "$CURRENT"
 PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" "$PYTHON" "$RUN_ALL"
) > "$OUT/01_PRE_REGRESSION.txt" 2>&1 || {
 echo "BLOCKER: pre-regression failed"; tail -60 "$OUT/01_PRE_REGRESSION.txt"; exit 24;
}

cat > "$OUT/02_CANDIDATE_CONTRACT.txt" <<'EOF'
STATUS=EXPERIMENTAL_UNPROMOTED
INPUT=STANDARD_DOCX_OOXML
DEPENDENCIES=PYTHON_STDLIB_ZIPFILE_XML_ETREE_ONLY
SOURCE_MUTATION=FORBIDDEN
NETWORK_ACCESS=FORBIDDEN
EXTERNAL_RELATIONSHIP_DEREFERENCE=FORBIDDEN
EMBEDDED_OBJECT_EXECUTION=FORBIDDEN
EXTRACTION=PRESERVE_DOCUMENT_PARAGRAPH_ORDER
TRIAL_A=PLAIN_PARAGRAPH_TEXT_TO_EXISTING_TXT_ROUTER
TRIAL_B=SOURCE_SUPPORTED_DOCX_TITLE_AND_HEADING_STYLES_TO_MARKDOWN_THEN_EXISTING_TXT_ROUTER
CONVERSATION_CLASSIFICATION=EXISTING_PARSE_CHATGPT
VALIDATION=EXISTING_VALIDATOR
LIVE_INGESTION=FORBIDDEN
EOF

export PAN49_QUAL="$QUAL"
export PAN49_OUT="$OUT"
export PAN49_SANDBOX="$SANDBOX"

(
 cd "$CURRENT"
 PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" "$PYTHON" - <<'PY'
from pathlib import Path
from collections import Counter
import csv, hashlib, json, os, re, zipfile
import xml.etree.ElementTree as ET

from workspace.operational.ingestion.service.parsers.chatgpt import parse_chatgpt
from workspace.operational.ingestion.service.validation import validate

qual=Path(os.environ["PAN49_QUAL"])
out=Path(os.environ["PAN49_OUT"])
sandbox=Path(os.environ["PAN49_SANDBOX"])

with qual.open("r",encoding="utf-8",newline="") as h:
    rows=list(csv.DictReader(h,delimiter="\t"))
if len(rows)!=11:
    raise SystemExit(f"expected 11 rows, got {len(rows)}")

W="{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"

def styles(z):
    if "word/styles.xml" not in z.namelist(): return {}
    root=ET.fromstring(z.read("word/styles.xml")); d={}
    for s in root.iter(W+"style"):
        sid=s.attrib.get(W+"styleId","")
        n=s.find(W+"name")
        if sid: d[sid]=n.attrib.get(W+"val","") if n is not None else ""
    return d

def core_title(z):
    if "docProps/core.xml" not in z.namelist(): return ""
    root=ET.fromstring(z.read("docProps/core.xml"))
    for n in root:
        if n.tag.rsplit("}",1)[-1]=="title" and n.text:
            return n.text.strip()
    return ""

def extract(source):
    with zipfile.ZipFile(source,"r") as z:
        if z.testzip() is not None: raise ValueError("bad zip member")
        smap=styles(z); title=core_title(z)
        root=ET.fromstring(z.read("word/document.xml"))
        paras=[]
        for idx,p in enumerate(root.iter(W+"p"),1):
            parts=[]
            for n in p.iter():
                if n.tag==W+"t" and n.text: parts.append(n.text)
                elif n.tag==W+"tab": parts.append("\t")
                elif n.tag==W+"br": parts.append("\n")
            text="".join(parts).strip()
            if not text: continue
            sid=""
            ppr=p.find(W+"pPr")
            if ppr is not None:
                ps=ppr.find(W+"pStyle")
                if ps is not None: sid=ps.attrib.get(W+"val","")
            paras.append((idx,text,sid,smap.get(sid,"")))
        return title,paras

def heading_level(sid,sname):
    raw=(sid+" "+sname).lower()
    if sname.strip().lower()=="title": return 1
    m=re.search(r"heading\s*([1-6])",raw) or re.search(r"heading([1-6])",raw)
    return int(m.group(1)) if m else None

def plain(paras):
    return "\n\n".join(x[1] for x in paras).strip()+"\n"

def structured(title,paras):
    lines=[]; prov=[]; has_h1=any(heading_level(x[2],x[3])==1 for x in paras)
    if title and not has_h1:
        lines += ["# "+title,""]; prov.append("core:title")
    for idx,text,sid,sname in paras:
        level=heading_level(sid,sname)
        if level:
            lines.append("#"*level+" "+text)
            prov.append(f"p{idx}:{sname or sid}:h{level}")
        else:
            lines.append(text)
        lines.append("")
    return "\n".join(lines).rstrip()+"\n",prov

def psum(parsed):
    kind=""; title=""; roles=[]; turns=""
    if isinstance(parsed,dict):
        kind=str(parsed.get("kind",""))
        title=str(parsed.get("title","") or "")
        t=parsed.get("turns")
        if isinstance(t,list):
            turns=len(t)
            for x in t:
                if isinstance(x,dict):
                    r=x.get("role") or x.get("speaker") or x.get("author")
                    if isinstance(r,dict): r=r.get("role") or r.get("name")
                    if r is not None: roles.append(str(r).lower())
    else:
        title=str(getattr(parsed,"title","") or "")
    return type(parsed).__name__,kind,title,turns,roles

results=[]; hashfails=[]
for i,row in enumerate(rows,1):
    src=Path(row["source"]).resolve()
    expected=row["sha256"].strip()
    before=hashlib.sha256(src.read_bytes()).hexdigest()
    if before!=expected: hashfails.append(str(src)); continue
    title,paras=extract(src)
    text_b,prov=structured(title,paras)
    variants=[("PLAIN_TEXT",plain(paras),[]),("STRUCTURED_MARKDOWN",text_b,prov)]
    case=sandbox/f"{i:02d}"; case.mkdir(parents=True,exist_ok=True)
    for variant,text,pv in variants:
        p=case/("plain.txt" if variant=="PLAIN_TEXT" else "structured.txt")
        p.write_text(text,encoding="utf-8")
        parsed=parse_chatgpt(p); vr=validate(parsed)
        typ,kind,ptitle,turns,roles=psum(parsed)
        errors=[str(x) for x in getattr(vr,"errors",())]
        results.append({
            "source":str(src),
            "stage48_class":row["qualification_class"],
            "variant":variant,
            "core_title":title,
            "paragraph_count":len(paras),
            "structure_provenance":json.dumps(pv,ensure_ascii=False),
            "parsed_runtime_type":typ,
            "parsed_kind":kind,
            "parsed_title":ptitle,
            "turn_count":turns,
            "roles":json.dumps(roles),
            "validation_passed":bool(getattr(vr,"passed",False)),
            "validation_errors":json.dumps(errors,ensure_ascii=False,sort_keys=True),
            "candidate_path":str(p),
        })
        if hashlib.sha256(src.read_bytes()).hexdigest()!=expected:
            hashfails.append(str(src))
        print(f"[{i:02d}/11] {variant:19s} {row['qualification_class']:43s} kind={kind or typ} pass={bool(getattr(vr,'passed',False))}")

if hashfails:
    raise SystemExit("source hash drift: "+repr(sorted(set(hashfails))))

fields=list(results[0])
with (out/"03_TRIAL_LEDGER.tsv").open("w",encoding="utf-8",newline="") as h:
    w=csv.DictWriter(h,fieldnames=fields,delimiter="\t"); w.writeheader(); w.writerows(results)

passc=Counter(); kindc=Counter(); errc=Counter()
for r in results:
    passc[(r["variant"],str(r["validation_passed"]))]+=1
    kindc[(r["variant"],r["parsed_kind"] or r["parsed_runtime_type"])]+=1
    for e in json.loads(r["validation_errors"]): errc[(r["variant"],e)]+=1

def dump(path,header,c):
    with path.open("w",encoding="utf-8") as h:
        h.write("\t".join(header)+"\n")
        for k,n in sorted(c.items(),key=lambda kv:(-kv[1],str(kv[0]))):
            if not isinstance(k,tuple): k=(k,)
            h.write(str(n)+"\t"+"\t".join(map(str,k))+"\n")

dump(out/"04_VARIANT_PASS_COUNTS.tsv",["count","variant","passed"],passc)
dump(out/"05_VARIANT_KIND_COUNTS.tsv",["count","variant","kind_or_type"],kindc)
dump(out/"06_VARIANT_ERROR_COUNTS.tsv",["count","variant","error"],errc)

explicit=[r for r in results if r["stage48_class"]=="DOCX_EXPLICIT_SPEAKER_MARKERS"]
plain_exp=sum(1 for r in explicit if r["variant"]=="PLAIN_TEXT" and r["parsed_kind"]=="conversation")
struct_exp=sum(1 for r in explicit if r["variant"]=="STRUCTURED_MARKDOWN" and r["parsed_kind"]=="conversation")
plain_conv=kindc.get(("PLAIN_TEXT","conversation"),0)
struct_conv=kindc.get(("STRUCTURED_MARKDOWN","conversation"),0)
plain_pass=passc.get(("PLAIN_TEXT","True"),0)
struct_pass=passc.get(("STRUCTURED_MARKDOWN","True"),0)

(out/"07_OBSERVATIONS.txt").write_text(
    f"DOCX_FRONTIER=11\n"
    f"PLAIN_TEXT_VALIDATION_PASS={plain_pass}\n"
    f"STRUCTURED_MARKDOWN_VALIDATION_PASS={struct_pass}\n"
    f"PLAIN_TEXT_CONVERSATION_CLASSIFICATIONS={plain_conv}\n"
    f"STRUCTURED_MARKDOWN_CONVERSATION_CLASSIFICATIONS={struct_conv}\n"
    f"EXPLICIT_CASE_PLAIN_CONVERSATION={plain_exp}\n"
    f"EXPLICIT_CASE_STRUCTURED_CONVERSATION={struct_exp}\n"
    "SOURCE_HASHES=PASS_11_OF_11\n",encoding="utf-8")

if plain_exp==1 and plain_conv==1:
    nxt="BOUND_DOCX_PLAIN_TEXT_ADAPTER_AS_MINIMAL_CONVERSATION_SAFE_BASELINE_AND_CLASSIFY_10_NONCONVERSATION_DOCX_RESULTS_BEFORE_PROMOTION"
elif struct_exp==1 and struct_conv==1:
    nxt="BOUND_DOCX_STRUCTURED_MARKDOWN_ADAPTER_AS_CONVERSATION_SAFE_CANDIDATE_AND_CLASSIFY_10_NONCONVERSATION_DOCX_RESULTS_BEFORE_PROMOTION"
else:
    nxt="BOUND_DOCX_CONVERSATION_DETECTION_MISMATCH_BEFORE_ANY_ADAPTER_PROMOTION"

(out/"08_CANDIDATE_NEXT.txt").write_text("CANDIDATE_NEXT="+nxt+"\n",encoding="utf-8")
print("--- observations ---")
print((out/"07_OBSERVATIONS.txt").read_text(),end="")
print("--- candidate next ---")
print((out/"08_CANDIDATE_NEXT.txt").read_text(),end="")
PY
) > "$OUT/03_TRIAL_RUN.txt" 2>&1 || {
 echo "BLOCKER: adapter trial failed"; tail -120 "$OUT/03_TRIAL_RUN.txt"; exit 27;
}

cat "$OUT/03_TRIAL_RUN.txt"

(
 cd "$CURRENT"
 PYTHONPATH="$CURRENT:$SERVICE${PYTHONPATH:+:$PYTHONPATH}" "$PYTHON" "$RUN_ALL"
) > "$OUT/09_POST_REGRESSION.txt" 2>&1 || {
 echo "BLOCKER: post-regression failed"; tail -60 "$OUT/09_POST_REGRESSION.txt"; exit 28;
}

git -C "$CURRENT" status --porcelain=v1 -z > "$OUT/10_GIT_POST.z" 2>/dev/null || true
find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d -printf . 2>/dev/null | wc -c > "$OUT/10_OUTPUT_POST.txt"
find "$RECEIPTS" -maxdepth 1 -type f -name '*.json' -printf . 2>/dev/null | wc -c > "$OUT/10_RECEIPTS_POST.txt"

GM=NONE; cmp -s "$OUT/00_GIT_PRE.z" "$OUT/10_GIT_POST.z" || GM=DETECTED
LM=NONE
[ "$(cat "$OUT/00_OUTPUT_PRE.txt")" = "$(cat "$OUT/10_OUTPUT_POST.txt")" ] || LM=DETECTED
[ "$(cat "$OUT/00_RECEIPTS_PRE.txt")" = "$(cat "$OUT/10_RECEIPTS_POST.txt")" ] || LM=DETECTED

NEXT="$(sed -n 's/^CANDIDATE_NEXT=//p' "$OUT/08_CANDIDATE_NEXT.txt")"
STATUS=PASS
if [ "$GM" != NONE ] || [ "$LM" != NONE ]; then STATUS=FAIL; NEXT=PRESERVE_STAGE49_MUTATION_EVIDENCE; fi

cat > "$OUT/SUMMARY.txt" <<EOF
PAN_BUILD_SANDBOX_DOCX_ADAPTER_STAGE49
UTC=$TS
STATUS=$STATUS
STAGE48=$STAGE48
DOCX_FRONTIER=11
CANDIDATE_STATUS=EXPERIMENTAL_UNPROMOTED
DEPENDENCIES=PYTHON_STDLIB_ZIPFILE_XML_ETREE_ONLY
SOURCE_HASHES=PASS_11_OF_11
PRE_CANDIDATE_REGRESSION=PASS
POST_CANDIDATE_REGRESSION=PASS
REPOSITORY_STATUS_MUTATION=$GM
LIVE_OUTPUT_MUTATION=$LM
SOURCE_MUTATION=NONE
LIVE_INGESTION_EXECUTED=NO
PARSER_CODE_MODIFIED=NO
COMMIT_CREATED=NO
EVIDENCE=$OUT
CANDIDATE_CONTRACT=$OUT/02_CANDIDATE_CONTRACT.txt
TRIAL_LEDGER=$OUT/03_TRIAL_LEDGER.tsv
VARIANT_PASS_COUNTS=$OUT/04_VARIANT_PASS_COUNTS.tsv
VARIANT_KIND_COUNTS=$OUT/05_VARIANT_KIND_COUNTS.tsv
VARIANT_ERRORS=$OUT/06_VARIANT_ERROR_COUNTS.tsv
OBSERVATIONS=$OUT/07_OBSERVATIONS.txt
CANDIDATE_NEXT=$OUT/08_CANDIDATE_NEXT.txt
NEXT=$NEXT
EOF

cat "$OUT/SUMMARY.txt"
echo
cat "$OUT/07_OBSERVATIONS.txt"
echo
tail -30 "$OUT/09_POST_REGRESSION.txt"
echo
[ "$STATUS" = PASS ] && echo "STAGE49_COMPLETE=YES"
