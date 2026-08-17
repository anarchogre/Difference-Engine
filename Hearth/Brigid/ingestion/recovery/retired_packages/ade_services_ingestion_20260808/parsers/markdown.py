from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class ParsedMarkdown:
    title: str
    headings: list[str]


def parse_markdown(source: Path) -> ParsedMarkdown:
    title = ""
    headings = []

    for line in source.read_text(
        encoding="utf-8",
        errors="replace",
    ).splitlines():
        if line.startswith("# "):
            if not title:
                title = line[2:].strip()
            headings.append(line[2:].strip())
        elif line.startswith("## "):
            headings.append(line[3:].strip())

    return ParsedMarkdown(
        title=title,
        headings=headings,
    )
