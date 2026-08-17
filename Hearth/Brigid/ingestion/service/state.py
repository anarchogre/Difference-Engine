import json
from dataclasses import asdict
from pathlib import Path

from .stages import Stage


def save(
    receipt,
    stage: Stage,
    state_root: Path,
):
    state_root.mkdir(
        parents=True,
        exist_ok=True,
    )

    path = (
        state_root
        / f"{receipt.receipt_id}.json"
    )

    payload = {
        "receipt": receipt.receipt_id,
        "stage": stage.value,
        "receipt_data": asdict(receipt),
    }

    path.write_text(
        json.dumps(
            payload,
            indent=2,
            sort_keys=True,
        ) + "\n",
        encoding="utf-8",
    )

    return path
