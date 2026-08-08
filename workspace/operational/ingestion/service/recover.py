import json
from pathlib import Path


def pending(state_root: Path):
    latest = {}

    for path in state_root.glob("*.json"):
        data = json.loads(
            path.read_text(
                encoding="utf-8",
            )
        )

        latest[data["receipt"]] = data

    return latest


if __name__ == "__main__":
    state = pending(
        Path(
            "workspace/operational/ingestion/state"
        )
    )

    for receipt, data in sorted(state.items()):
        print(
            receipt,
            "->",
            data["stage"],
        )
