from datetime import datetime
from pathlib import Path


def next_receipt_id(
    receipt_root: Path,
) -> str:
    day = datetime.now().strftime("%Y%m%d")
    prefix = f"ING-{day}-"

    existing = [
        path.stem
        for path in receipt_root.glob(f"{prefix}*.json")
    ]

    numbers = []

    for value in existing:
        try:
            numbers.append(int(value.rsplit("-", 1)[1]))
        except (IndexError, ValueError):
            continue

    number = max(numbers, default=0) + 1

    return f"{prefix}{number:04d}"
