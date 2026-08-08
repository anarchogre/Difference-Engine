from dataclasses import dataclass


@dataclass(frozen=True)
class QueueCandidate:
    queue: str
    value: str


def generate(parsed, assets, references):
    candidates = []

    if isinstance(parsed, dict):
        for command in parsed.get("commands", []):
            candidates.append(
                QueueCandidate(
                    queue="linux_command",
                    value=command.text,
                )
            )

        for turn in parsed.get("turns", []):
            if "TODO" in turn.text or "FIXME" in turn.text:
                candidates.append(
                    QueueCandidate(
                        queue="implementation",
                        value=turn.text,
                    )
                )

    else:
        for heading in parsed.headings:
            candidates.append(
                QueueCandidate(
                    queue="structure",
                    value=heading,
                )
            )

    for reference in references:
        candidates.append(
            QueueCandidate(
                queue="reference",
                value=reference.value,
            )
        )

    return candidates
