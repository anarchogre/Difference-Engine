from dataclasses import dataclass
import re


@dataclass(frozen=True)
class Reference:
    kind: str
    value: str


FILE = re.compile(r"\b[\w.-]+\.md\b")
PATH = re.compile(r"\b[\w./-]+/[\w./-]+\b")


def extract(parsed):
    refs = []

    if isinstance(parsed, dict):
        text = "\n".join(
            turn.text
            for turn in parsed.get("turns", [])
        )
    else:
        text = "\n".join(
            [parsed.title, *parsed.headings]
        )

    for match in FILE.findall(text):
        refs.append(
            Reference(
                "repository_artifact",
                match,
            )
        )

    for match in PATH.findall(text):
        refs.append(
            Reference(
                "path",
                match,
            )
        )

    return refs
