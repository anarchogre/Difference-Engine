import json
import shutil
from dataclasses import asdict
from pathlib import Path


def _write(path, obj):
    path.write_text(
        json.dumps(
            obj,
            indent=2,
            sort_keys=True,
        ) + "\n",
        encoding="utf-8",
    )


def write_output(
    source,
    receipt,
    parsed,
    assets,
    references,
    queues,
    validation,
    provenance,
    output_root,
):
    root = output_root / receipt.receipt_id

    for name in (
        "source",
        "metadata",
        "structure",
        "queues",
        "provenance",
        "reports",
    ):
        (root / name).mkdir(
            parents=True,
            exist_ok=True,
        )

    shutil.copy2(
        source,
        root / "source" / source.name,
    )

    _write(
        root / "metadata/receipt.json",
        asdict(receipt),
    )

    if isinstance(parsed, dict):
        parsed_data = {
            "kind": parsed.get("kind"),
            "turns": [
                asdict(x)
                for x in parsed.get("turns", [])
            ],
            "commands": [
                asdict(x)
                for x in parsed.get("commands", [])
            ],
        }
    else:
        parsed_data = asdict(parsed)

    _write(
        root / "structure/parsed.json",
        parsed_data,
    )

    _write(
        root / "structure/assets.json",
        [asdict(x) for x in assets],
    )

    _write(
        root / "structure/references.json",
        [asdict(x) for x in references],
    )

    _write(
        root / "queues/candidates.json",
        [asdict(x) for x in queues],
    )

    _write(
        root / "provenance/provenance.json",
        asdict(provenance),
    )

    _write(
        root / "reports/validation.json",
        asdict(validation),
    )

    return root
