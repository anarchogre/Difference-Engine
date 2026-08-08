from pathlib import Path
import sys

from .batch import ingest_directory
from .ids import next_receipt_id
from .index import rebuild
from .pipeline import run


def main():
    if len(sys.argv) != 2:
        raise SystemExit(
            "usage: python -m workspace.operational.ingestion.service.cli <file|directory>"
        )

    target = Path(sys.argv[1])

    receipt_root = Path(
        "workspace/operational/ingestion/receipts"
    )

    output_root = Path(
        "workspace/operational/ingestion/output"
    )

    if target.is_dir():
        outputs = ingest_directory(
            source_root=target,
            receipt_root=receipt_root,
            output_root=output_root,
            source_class="manual_batch",
        )

        index = rebuild(output_root)
        print(f"Ingested {len(outputs)} artifacts.")
        print(index)
        return

    output, _ = run(
        source=target,
        receipt_id=next_receipt_id(receipt_root),
        source_class="manual",
        receipt_root=receipt_root,
        output_root=output_root,
    )

    index = rebuild(output_root)
    print(output)
    print(index)


if __name__ == "__main__":
    main()
