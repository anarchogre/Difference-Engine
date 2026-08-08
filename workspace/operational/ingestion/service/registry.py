from pathlib import Path

from .parsers.chatgpt import parse_chatgpt
from .parsers.markdown import parse_markdown


PARSERS = {
    ".md": parse_markdown,
    ".txt": parse_chatgpt,
}


def parser_for(path: Path):
    suffix = path.suffix.lower()

    if suffix not in PARSERS:
        raise ValueError(
            f"No parser registered for {suffix}"
        )

    return PARSERS[suffix]
