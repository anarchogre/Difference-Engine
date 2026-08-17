from pathlib import Path
import shutil

from ade.services.ingestion.batch import ingest_sources


def main():
    root = Path(
        "workspace/operational/ingestion/batch_test"
    )

    if root.exists():
        shutil.rmtree(root)

    source_root = root / "sources"
    receipt_root = root / "receipts"
    output_root = root / "output"

    source_root.mkdir(parents=True)

    first = source_root / "first.txt"
    second = source_root / "second.txt"

    first.write_text(
        "User: one\nAssistant: two\n",
        encoding="utf-8",
    )

    second.write_text(
        "## You\nthree\n## ChatGPT\nfour\n",
        encoding="utf-8",
    )

    outputs = ingest_sources(
        sources=(first, second),
        receipt_root=receipt_root,
        output_root=output_root,
        source_class="conversation",
    )

    assert len(outputs) == 2

    resumed = ingest_sources(
        sources=(first, second),
        receipt_root=receipt_root,
        output_root=output_root,
        source_class="conversation",
    )

    assert resumed == []

    print("PASS")


if __name__ == "__main__":
    main()
