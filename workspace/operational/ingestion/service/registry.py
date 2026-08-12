from pathlib import Path

from .parsers.chatgpt import parse_chatgpt
from .parsers.markdown import parse_markdown
from .parsers.json_document import parse_json


PARSERS = {
    ".md": parse_markdown,
    ".txt": parse_chatgpt,
    ".json": parse_json,
}


def parser_for(path: Path):
    suffix = path.suffix.lower()

    if suffix not in PARSERS:
        raise ValueError(
            f"No parser registered for {suffix}"
        )

    return PARSERS[suffix]
