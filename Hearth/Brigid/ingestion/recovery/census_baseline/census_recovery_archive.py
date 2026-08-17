#!/usr/bin/env python3
"""Content-first census of the mounted Difference Engine recovery archive."""

from __future__ import annotations

import hashlib
import io
import json
import re
import subprocess
import tempfile
import zipfile
from collections import Counter, defaultdict
from pathlib import Path

ARCHIVE = Path("upload/Archive_Recovery.zip")
OUT_JSON = Path("RECOVERY_CANDIDATE_CENSUS.json")
OUT_MD = Path("RECOVERY_CANDIDATE_CENSUS.md")

TURN_PATTERNS = {
    "user_assistant_labels": re.compile(r"(?im)^\s*(?:user|assistant)\s*:\s*"),
    "chatgpt_headings": re.compile(r"(?im)^\s*#{1,6}\s*(?:you|chatgpt)\s*$"),
    "role_fields": re.compile(r'(?i)["\']role["\']\s*:\s*["\'](?:user|assistant)["\']'),
    "chatgpt_conversation_url": re.compile(r"https://chatgpt\.com/c/[0-9a-z-]+", re.I),
}

CONVERSATION_NAME = re.compile(
    r"(?:\b(?:first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth|"
    r"eleventh|twelfth|thirteenth|fourteenth|fifteenth|sixteenth|seventeenth|"
    r"eighteenth|nineteenth|twenty|master)\s+conversations?\b|"
    r"last chat before|forensic parser workflow start)",
    re.I,
)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sniff(data: bytes) -> str:
    if data.startswith(b"%PDF-"):
        return "pdf"
    if data.startswith(b"PK\x03\x04"):
        try:
            with zipfile.ZipFile(io.BytesIO(data)) as zf:
                names = set(zf.namelist())
                if "word/document.xml" in names:
                    return "docx"
        except zipfile.BadZipFile:
            pass
        return "zip"
    stripped = data.lstrip()
    if stripped[:1] in (b"{", b"["):
        try:
            json.loads(stripped)
            return "json"
        except (UnicodeDecodeError, json.JSONDecodeError):
            return "json-like-invalid"
    try:
        data.decode("utf-8")
        return "text"
    except UnicodeDecodeError:
        return "binary"


def docx_text(data: bytes) -> str:
    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        xml = zf.read("word/document.xml").decode("utf-8", "replace")
    xml = re.sub(r"</w:p>", "\n", xml)
    xml = re.sub(r"<w:tab[^>]*/>", "\t", xml)
    return re.sub(r"<[^>]+>", "", xml)


def pdf_text(data: bytes) -> str:
    with tempfile.TemporaryDirectory() as td:
        src = Path(td) / "source.pdf"
        dst = Path(td) / "source.txt"
        src.write_bytes(data)
        run = subprocess.run(
            ["pdftotext", "-layout", str(src), str(dst)],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if run.returncode:
            raise RuntimeError(run.stderr.strip() or f"pdftotext exit {run.returncode}")
        return dst.read_text(errors="replace")


def json_shape(value) -> tuple[str, Counter]:
    roles = Counter()

    def walk(node):
        if isinstance(node, dict):
            role = node.get("role")
            if isinstance(role, str) and role.lower() in {"user", "assistant", "system", "tool"}:
                roles[role.lower()] += 1
            author = node.get("author")
            if isinstance(author, dict):
                arole = author.get("role")
                if isinstance(arole, str):
                    roles[arole.lower()] += 1
            for child in node.values():
                walk(child)
        elif isinstance(node, list):
            for child in node:
                walk(child)

    walk(value)
    if isinstance(value, list):
        shape = "array"
    elif isinstance(value, dict):
        shape = "object"
    else:
        shape = type(value).__name__
    return shape, roles


def main() -> None:
    records = []
    with zipfile.ZipFile(ARCHIVE) as archive:
        for info in archive.infolist():
            if info.is_dir():
                continue
            data = archive.read(info)
            kind = sniff(data)
            record = {
                "path": info.filename,
                "size": len(data),
                "sha256": sha256(data),
                "container": kind,
                "extraction": "not_applicable",
                "text_chars": 0,
                "signals": {},
                "json_shape": None,
                "roles": {},
            }
            text = ""
            try:
                if kind == "docx":
                    text = docx_text(data)
                    record["extraction"] = "ok"
                elif kind == "pdf":
                    text = pdf_text(data)
                    record["extraction"] = "ok"
                elif kind == "json":
                    value = json.loads(data)
                    shape, roles = json_shape(value)
                    record["json_shape"] = shape
                    record["roles"] = dict(roles)
                    text = data.decode("utf-8", "replace")
                    record["extraction"] = "ok"
                elif kind in {"text", "json-like-invalid"}:
                    text = data.decode("utf-8", "replace")
                    record["extraction"] = "ok"
            except Exception as exc:
                record["extraction"] = "error"
                record["error"] = f"{type(exc).__name__}: {exc}"
            record["text_chars"] = len(text)
            record["signals"] = {name: len(pattern.findall(text)) for name, pattern in TURN_PATTERNS.items()}
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
            if kind == "pdf" and record["signals"]["chatgpt_conversation_url"] and "ChatGPT" in text[:3000]:
                evidence.append("ChatGPT PDF export header")
            if kind == "docx" and CONVERSATION_NAME.search(info.filename) and len(text) >= 1000:
                evidence.append("conversation-bearing name plus substantive dialogue-like content")
            record["candidate_evidence"] = evidence
            record["conversation_candidate"] = bool(evidence)
            record["candidate_strength"] = (
                "strong" if any(x in evidence for x in (
                    "structured user+assistant roles",
                    "embedded ChatGPT conversation URL",
                    "repeated user/assistant labels",
                    "repeated You/ChatGPT headings",
                )) else "provisional" if evidence else "none"
            )
            records.append(record)

    hashes = defaultdict(list)
    for record in records:
        hashes[record["sha256"]].append(record["path"])
    duplicate_families = [paths for paths in hashes.values() if len(paths) > 1]
    summary = {
        "archive": str(ARCHIVE),
        "archive_sha256": sha256(ARCHIVE.read_bytes()),
        "files": len(records),
        "containers": dict(sorted(Counter(r["container"] for r in records).items())),
        "extraction": dict(sorted(Counter(r["extraction"] for r in records).items())),
        "conversation_candidates": sum(r["conversation_candidate"] for r in records),
        "strong_candidates": sum(r["candidate_strength"] == "strong" for r in records),
        "provisional_candidates": sum(r["candidate_strength"] == "provisional" for r in records),
        "exact_duplicate_families": len(duplicate_families),
        "exact_duplicate_paths": sum(len(paths) for paths in duplicate_families),
    }
    payload = {
        "scope_note": "Content-first candidate census; conversation_candidate is a structural signal, not semantic qualification or canonical status.",
        "summary": summary,
        "duplicate_families": duplicate_families,
        "records": records,
    }
    OUT_JSON.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")

    candidates = [r for r in records if r["conversation_candidate"]]
    lines = [
        "# Recovery Candidate Census",
        "",
        "## Scope",
        "",
        payload["scope_note"],
        "",
        "## Summary",
        "",
        f"- Archive SHA-256: `{summary['archive_sha256']}`",
        f"- Files: {summary['files']}",
        f"- Containers: {json.dumps(summary['containers'], sort_keys=True)}",
        f"- Extraction: {json.dumps(summary['extraction'], sort_keys=True)}",
        f"- Structurally signaled conversation candidates: {summary['conversation_candidates']}",
        f"- Strong candidates: {summary['strong_candidates']}",
        f"- Provisional candidates: {summary['provisional_candidates']}",
        f"- Exact duplicate families: {summary['exact_duplicate_families']} ({summary['exact_duplicate_paths']} paths)",
        "",
        "## Structurally Signaled Candidates",
        "",
    ]
    for record in candidates:
        reasons = "; ".join(record["candidate_evidence"])
        lines.append(f"- **{record['candidate_strength']}** — `{record['path']}` — {record['container']}; {record['text_chars']} extracted characters; {reasons}; `{record['sha256']}`")
    lines += ["", "## Extraction Errors", ""]
    errors = [r for r in records if r["extraction"] == "error"]
    lines.extend(f"- `{r['path']}` — {r.get('error', 'unknown error')}" for r in errors)
    if not errors:
        lines.append("- None.")
    OUT_MD.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
