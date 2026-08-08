from dataclasses import dataclass


@dataclass(frozen=True)
class Asset:
    asset_type: str
    value: str


def extract(parsed):
    assets = []

    if isinstance(parsed, dict):
        for turn in parsed.get("turns", []):
            assets.append(
                Asset(
                    asset_type="conversation_turn",
                    value=turn.text,
                )
            )

        for command in parsed.get("commands", []):
            assets.append(
                Asset(
                    asset_type="command",
                    value=command.text,
                )
            )

        return assets

    if parsed.title:
        assets.append(
            Asset(
                asset_type="document_title",
                value=parsed.title,
            )
        )

    for heading in parsed.headings:
        assets.append(
            Asset(
                asset_type="heading",
                value=heading,
            )
        )

    return assets
