from pathlib import Path

from .parsers.chatgpt import parse_chatgpt
from .registry import parser_for


def parse(
    source: Path,
    source_class: str | None = None,
):
    if source_class == "conversation":
        return parse_chatgpt(source)

    return parser_for(source)(source)
