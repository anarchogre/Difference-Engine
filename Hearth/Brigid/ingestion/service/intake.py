from pathlib import Path

from .receipt import (
    IngestionReceipt,
    generate_receipt,
    write_receipt,
)


def intake(
    source: Path,
    receipt_id: str,
    source_class: str,
    receipt_root: Path,
) -> IngestionReceipt:
    receipt = generate_receipt(
        source=source,
        receipt_id=receipt_id,
        source_class=source_class,
    )

    write_receipt(
        receipt,
        receipt_root / f"{receipt.receipt_id}.json",
    )

    return receipt
