import json
from dataclasses import asdict
from pathlib import Path

from .report import write_report


def write_manifest(
    root: Path,
    receipt,
    parsed,
    assets,
    references,
    queues,
    provenance,
    validation,
):
    if isinstance(parsed, dict):
        title = ""
        kind = parsed.get("kind", "unknown")
        turn_count = len(parsed.get("turns", []))
        command_count = len(parsed.get("commands", []))
    else:
        title = parsed.title
        kind = "markdown"
        turn_count = 0
        command_count = 0

    manifest = {
        "receipt": receipt.receipt_id,
        "kind": kind,
        "title": title,
        "turn_count": turn_count,
        "command_count": command_count,
        "asset_count": len(assets),
        "reference_count": len(references),
        "queue_count": len(queues),
        "validation": asdict(validation),
        "provenance": asdict(provenance),
    }

    (root / "reports" / "manifest.json").write_text(
        json.dumps(
            manifest,
            indent=2,
            sort_keys=True,
        ) + "\n",
        encoding="utf-8",
    )

    write_report(
        root,
        manifest,
    )
