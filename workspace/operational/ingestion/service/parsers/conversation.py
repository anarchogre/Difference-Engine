from dataclasses import dataclass
from pathlib import Path
import re


@dataclass(frozen=True)
class Turn:
    number: int
    speaker: str
    text: str


COMMAND = re.compile(
    r"^\s*("
    r"\$|>|>>>|python\b|git\b|find\b|grep\b|sed\b|"
    r"cat\b|mkdir\b|cp\b|mv\b|rm\b|tree\b|ls\b"
    r")"
)

INLINE_SPEAKER = re.compile(
    r"^(User|Assistant|System|ChatGPT):\s*(.*)$"
)

HEADING_SPEAKER = re.compile(
    r"^##\s+(You|User|Assistant|System|ChatGPT)\s*$"
)

SPEAKER_MAP = {
    "you": "user",
    "user": "user",
    "assistant": "assistant",
    "chatgpt": "assistant",
    "system": "system",
}


def parse_conversation(source: Path):
    turns = []
    speaker = None
    buffer = []

    def emit() -> None:
        nonlocal buffer

        if speaker is None:
            buffer = []
            return

        text = "\n".join(buffer).strip()

        turns.append(
            Turn(
                number=len(turns) + 1,
                speaker=speaker,
                text=text,
            )
        )

        buffer = []

    lines = source.read_text(
        encoding="utf-8",
        errors="replace",
    ).splitlines()

    for line in lines:
        heading = HEADING_SPEAKER.match(line)

        if heading:
            emit()
            speaker = SPEAKER_MAP[
                heading.group(1).lower()
            ]
            continue

        inline = INLINE_SPEAKER.match(line)

        if inline:
            emit()
            speaker = SPEAKER_MAP[
                inline.group(1).lower()
            ]
            buffer = [inline.group(2)]
            continue

        if speaker is not None:
            buffer.append(line)

    emit()

    commands = [
        turn
        for turn in turns
        for line in turn.text.splitlines()
        if COMMAND.match(line)
    ]

    return {
        "turns": turns,
        "commands": commands,
    }
