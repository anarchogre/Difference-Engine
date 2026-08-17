from __future__ import annotations

import hashlib
import json
import mimetypes
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path


@dataclass(frozen=True)
class IngestionReceipt:
    receipt_id: str
    schema_version: str
    observed_path: str
    observed_at: str
    size_bytes: int
    sha256: str
    media_type: str
    source_class: str
    original_name: str
    parser_status: str = "not_started"
    canonical_status: str = "unreviewed"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)

    return digest.hexdigest()


def generate_receipt(
    source: Path,
    receipt_id: str,
    source_class: str,
) -> IngestionReceipt:
    source = source.resolve()

    if not source.is_file():
        raise FileNotFoundError(source)

    media_type = (
        mimetypes.guess_type(source.name)[0]
        or "application/octet-stream"
    )

    return IngestionReceipt(
        receipt_id=receipt_id,
        schema_version="0.1.0",
        observed_path=str(source),
        observed_at=datetime.now().astimezone().isoformat(),
        size_bytes=source.stat().st_size,
        sha256=sha256_file(source),
        media_type=media_type,
        source_class=source_class,
        original_name=source.name,
    )


def write_receipt(
    receipt: IngestionReceipt,
    destination: Path,
) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)

    destination.write_text(
        json.dumps(
            asdict(receipt),
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
