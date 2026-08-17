from pathlib import Path

from ade.services.ingestion.parsers.chatgpt import parse_chatgpt


def main():
    root = Path(
        "workspace/operational/ingestion/parser_tests"
    )

    root.mkdir(
        parents=True,
        exist_ok=True,
    )

    inline = root / "inline.txt"

    inline.write_text(
        "\n".join(
            (
                "User: hello",
                "Assistant: hi",
                "User: build the ingester",
            )
        ),
        encoding="utf-8",
    )

    parsed = parse_chatgpt(inline)

    assert parsed["kind"] == "conversation"
    assert len(parsed["turns"]) == 3
    assert parsed["turns"][0].speaker == "user"
    assert parsed["turns"][1].speaker == "assistant"

    headings = root / "headings.txt"

    headings.write_text(
        "\n".join(
            (
                "## You",
                "",
                "First line.",
                "Second line.",
                "",
                "## ChatGPT",
                "",
                "Response line.",
            )
        ),
        encoding="utf-8",
    )

    parsed = parse_chatgpt(headings)

    assert parsed["kind"] == "conversation"
    assert len(parsed["turns"]) == 2
    assert parsed["turns"][0].speaker == "user"
    assert parsed["turns"][1].speaker == "assistant"
    assert "First line." in parsed["turns"][0].text
    assert "Second line." in parsed["turns"][0].text

    print("PASS")


if __name__ == "__main__":
    main()
