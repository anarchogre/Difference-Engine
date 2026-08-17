from pathlib import Path
from tempfile import TemporaryDirectory

from ..parsers.chatgpt import parse_chatgpt
from ..parsers.markdown import parse_markdown


def main():
    with TemporaryDirectory(
        prefix="difference-engine-txt-fallback-"
    ) as tmp:
        root = Path(tmp)

        plain = root / "plain.txt"
        plain.write_text(
            "# Plain Artifact\n\n"
            "This is ordinary non-conversation text.\n",
            encoding="utf-8",
        )

        expected = parse_markdown(plain)
        actual = parse_chatgpt(plain)

        assert not isinstance(actual, dict)
        assert type(actual) is type(expected)
        assert actual == expected

        chat = root / "chat.txt"
        chat.write_text(
            "User: hello\nAssistant: hi\n",
            encoding="utf-8",
        )

        conversation = parse_chatgpt(chat)
        assert isinstance(conversation, dict)
        assert conversation.get("kind") == "conversation"

    print("PASS")


if __name__ == "__main__":
    main()
