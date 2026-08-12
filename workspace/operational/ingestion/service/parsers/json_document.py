import json
from pathlib import Path


def parse_json(source: Path):
    with source.open(
        "r",
        encoding="utf-8-sig",
    ) as handle:
        document = json.load(handle)

    return {
        "kind": "json",
        "document": document,
    }
