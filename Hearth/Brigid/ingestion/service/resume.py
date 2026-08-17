import json
from pathlib import Path


def completed(output_root: Path):
    completed = set()

    if not output_root.is_dir():
        return completed

    for artifact in output_root.iterdir():
        receipt = (
            artifact
            / "metadata"
            / "receipt.json"
        )

        if not receipt.is_file():
            continue

        data = json.loads(
            receipt.read_text(
                encoding="utf-8",
            )
        )

        completed.add(
            Path(
                data["observed_path"]
            ).resolve()
        )

    return completed
