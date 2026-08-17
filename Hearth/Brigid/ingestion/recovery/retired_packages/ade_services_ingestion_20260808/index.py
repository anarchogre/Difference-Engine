import json
from pathlib import Path


def rebuild(output_root: Path):
    artifacts = []

    for artifact in sorted(output_root.iterdir()):
        receipt = (
            artifact
            / "metadata"
            / "receipt.json"
        )

        manifest = (
            artifact
            / "reports"
            / "manifest.json"
        )

        if not (
            receipt.is_file()
            and manifest.is_file()
        ):
            continue

        artifacts.append(
            {
                "artifact": artifact.name,
                "receipt": json.loads(
                    receipt.read_text(
                        encoding="utf-8",
                    )
                ),
                "manifest": json.loads(
                    manifest.read_text(
                        encoding="utf-8",
                    )
                ),
            }
        )

    index = output_root / "INDEX.json"

    index.write_text(
        json.dumps(
            artifacts,
            indent=2,
            sort_keys=True,
        ) + "\n",
        encoding="utf-8",
    )

    return index
