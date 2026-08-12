import json
from pathlib import Path
from tempfile import TemporaryDirectory

from ..parsers.json_document import parse_json
from ..registry import parser_for


def main():
    expected = {
        "alpha": 1,
        "nested": [True, None, "x"],
    }

    with TemporaryDirectory(
        prefix="difference-engine-json-parser-"
    ) as tmp:
        source = Path(tmp) / "fixture.json"
        source.write_text(
            json.dumps(expected),
            encoding="utf-8",
        )

        parsed = parse_json(source)

        assert parsed["kind"] == "json"
        assert parsed["document"] == expected
        assert parser_for(source) is parse_json

    print("PASS")


if __name__ == "__main__":
    main()
