#!/usr/bin/env python3
from pathlib import Path
import argparse
import importlib.util
import json
import time

HERE = Path(__file__).resolve().parent
REC = HERE / "recovery/census_baseline/census_recovery_archive.py"
DOMAINS = HERE / "evidence/CONVERSATION_SOURCE_DOMAINS.tsv"

spec = importlib.util.spec_from_file_location(
    "recovered_census",
    REC,
)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

def load_domains():
    result = {}

    for line in DOMAINS.read_text().splitlines()[1:]:
        if not line.strip():
            continue

        domain, path, role = line.split("\t", 2)

        result[domain] = {
            "path": path,
            "role": role,
        }

    return result

REC_JSON = HERE / "recovery/census_baseline/RECOVERY_CANDIDATE_CENSUS.json"
VERIFIED = HERE / "evidence/CONVERSATION_CORPUS_VERIFIED.json"
OUTROOT = HERE / "evidence/delta"


def baseline_hashes():
    data = json.loads(REC_JSON.read_text())
    return {
        r["sha256"]
        for r in data["records"]
        if r.get("conversation_candidate")
    }


def verified_hashes():
    data = json.loads(VERIFIED.read_text())
    return {
        r["sha256"]
        for r in data["conversations"]
    }

def excluded(domain, root, path):
    rel = path.relative_to(root)

    if ".git" in rel.parts:
        return True

    if domain in {"forge_differenceengine", "phone_differenceengine"}:
        s = rel.as_posix()

        blocked = (
            "workspace/operational/ingestion/output",
            "workspace/operational/ingestion/evidence",
            "workspace/operational/ingestion/recovery",
            "workspace/operational/ingestion/baselines",
            "workspace/operational/ingestion/batch_test",
            "workspace/operational/ingestion/parser_tests",
            "workspace/operational/ingestion/test_output",
            "workspace/operational/ingestion/chat_test.txt",
            "workspace/operational/ingestion/chat_pipeline_test.txt",
            "workspace/operational/ingestion/markdown_conversation_test.md",
        )

        return any(
            s == x or s.startswith(x + "/")
            for x in blocked
        )

    return False

def iter_files(domain, root):
    if domain == "phone_shared_root":
        for path in sorted(root.iterdir()):
            if path.is_file():
                yield path
        return

    for path in sorted(root.rglob("*")):
        if path.is_file() and not excluded(
            domain, root, path
        ):
            yield path

from collections import Counter, defaultdict

def inspect_file(path):
    data = path.read_bytes()
    kind = mod.sniff(data)

    record = {
        "path": str(path),
        "size": len(data),
        "sha256": mod.sha256(data),
        "container": kind,
        "extraction": "not_applicable",
        "signals": {},
        "roles": {},
    }

    text = ""


    try:
        if kind == "docx":
            text = mod.docx_text(data)
        elif kind == "pdf":
            text = mod.pdf_text(data)
        elif kind == "json":
            value = json.loads(data)
            shape, roles = mod.json_shape(value)
            record["json_shape"] = shape
            record["roles"] = dict(roles)
            text = data.decode("utf-8", "replace")
        elif kind in {"text", "json-like-invalid"}:
            text = data.decode("utf-8", "replace")

        if text:
            record["extraction"] = "ok"

    except Exception as exc:
        record["extraction"] = "error"
        record["error"] = f"{type(exc).__name__}: {exc}"

    record["text_chars"] = len(text)

    record["signals"] = {
        name: len(pattern.findall(text))
        for name, pattern in mod.TURN_PATTERNS.items()
    }

    roles = record["roles"]
    evidence = []

    if roles.get("user", 0) and roles.get("assistant", 0):
        evidence.append("structured user+assistant roles")

    if record["signals"]["user_assistant_labels"] >= 2:
        evidence.append("repeated user/assistant labels")

    if record["signals"]["chatgpt_headings"] >= 2:
        evidence.append("repeated You/ChatGPT headings")

    if record["signals"]["role_fields"] >= 2:
        evidence.append("repeated serialized role fields")

    if record["signals"]["chatgpt_conversation_url"]:
        evidence.append("embedded ChatGPT conversation URL")

    if (
        kind == "pdf"
        and record["signals"]["chatgpt_conversation_url"]
        and "ChatGPT" in text[:3000]
    ):
        evidence.append("ChatGPT PDF export header")

    if (
        kind == "docx"
        and mod.CONVERSATION_NAME.search(path.name)
        and len(text) >= 1000
    ):
        evidence.append(
            "conversation-bearing name plus substantive dialogue-like content"
        )

    record["candidate_evidence"] = evidence
    record["conversation_candidate"] = bool(evidence)

    strong = {
        "structured user+assistant roles",
        "embedded ChatGPT conversation URL",
        "repeated user/assistant labels",
        "repeated You/ChatGPT headings",
    }

    record["candidate_strength"] = (
        "strong"
        if any(x in evidence for x in strong)
        else "provisional"
        if evidence
        else "none"
    )

    return record


def scan_domain(domain, root, old_hashes, verified):
    records = []

    for path in iter_files(domain, root):
        record = inspect_file(path)
        record["domain"] = domain
        record["known_recovery_candidate"] = (
            record["sha256"] in old_hashes
        )
        record["known_verified_conversation"] = (
            record["sha256"] in verified
        )
        records.append(record)

    return records


def summarize(records):
    candidates = [
        r for r in records
        if r["conversation_candidate"]
    ]

    return {
        "files": len(records),
        "conversation_candidates": len(candidates),
        "strong_candidates": sum(
            r["candidate_strength"] == "strong"
            for r in candidates
        ),
        "provisional_candidates": sum(
            r["candidate_strength"] == "provisional"
            for r in candidates
        ),
        "new_candidate_hashes": len({
            r["sha256"]
            for r in candidates
            if not r["known_recovery_candidate"]
        }),
    }


def delta_counts(records):
    candidates = [
        r for r in records
        if r["conversation_candidate"]
    ]

    return {
        "known_verified_paths": sum(
            r["known_verified_conversation"]
            for r in candidates
        ),
        "unverified_candidate_paths": sum(
            not r["known_verified_conversation"]
            for r in candidates
        ),
        "unverified_candidate_hashes": len({
            r["sha256"]
            for r in candidates
            if not r["known_verified_conversation"]
        }),
    }


def write_domain_json(domain, root, records):
    outdir = OUTROOT / domain
    outdir.mkdir(parents=True, exist_ok=True)

    summary = summarize(records)
    summary.update(delta_counts(records))

    payload = {
        "scope_note": (
            "Structural conversation delta census; "
            "candidate status is not semantic qualification "
            "or canonical promotion."
        ),
        "domain": domain,
        "root": str(root),
        "generated_utc": time.strftime(
            "%Y-%m-%dT%H:%M:%SZ",
            time.gmtime(),
        ),
        "summary": summary,
        "records": records,
    }

    path = outdir / "DELTA_CENSUS.json"
    path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
    )
    return path, payload


def write_domain_md(domain, root, records, payload):
    summary = payload["summary"]
    candidates = [
        r for r in records
        if r["conversation_candidate"]
    ]

    lines = [
        f"# Conversation Delta Census — {domain}",
        "",
        "Structural candidates only; not semantic qualification.",
        "",
        f"- Root: `{root}`",
        f"- Files: {summary['files']}",
        f"- Candidates: {summary['conversation_candidates']}",
        f"- Strong: {summary['strong_candidates']}",
        f"- Provisional: {summary['provisional_candidates']}",
        f"- New candidate hashes: {summary['new_candidate_hashes']}",
        f"- Unverified candidate hashes: {summary['unverified_candidate_hashes']}",
        "",
        "## Candidates",
        "",
    ]

    for r in candidates:
        reasons = "; ".join(r["candidate_evidence"])
        lines.append(
            f"- **{r['candidate_strength']}** — `{r['path']}` "
            f"— {reasons} — `{r['sha256']}`"
        )

    path = OUTROOT / domain / "DELTA_CENSUS.md"
    path.write_text("\n".join(lines) + "\n")
    return path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("domain")
    args = parser.parse_args()

    domains = load_domains()
    if args.domain not in domains:
        raise SystemExit(
            f"unknown domain: {args.domain}"
        )

    info = domains[args.domain]
    raw = info["path"]

    if raw.startswith("non_filesystem:"):
        raise SystemExit(
            f"non-filesystem domain: {args.domain}"
        )

    root = Path(raw)
    if not root.exists():
        raise SystemExit(
            f"missing domain root: {root}"
        )

    old_hashes = baseline_hashes()
    verified = verified_hashes()

    records = scan_domain(
        args.domain,
        root,
        old_hashes,
        verified,
    )

    json_path, payload = write_domain_json(
        args.domain,
        root,
        records,
    )

    md_path = write_domain_md(
        args.domain,
        root,
        records,
        payload,
    )

    s = payload["summary"]

    print(f"DOMAIN={args.domain}")
    print(f"FILES={s['files']}")
    print(f"CANDIDATES={s['conversation_candidates']}")
    print(f"STRONG={s['strong_candidates']}")
    print(f"PROVISIONAL={s['provisional_candidates']}")
    print(f"NEW_HASHES={s['new_candidate_hashes']}")
    print(f"UNVERIFIED_HASHES={s['unverified_candidate_hashes']}")
    print(f"JSON={json_path}")
    print(f"MD={md_path}")


if __name__ == "__main__":
    main()
