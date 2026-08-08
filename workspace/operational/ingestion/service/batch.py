from pathlib import Path

from .discover import discover
from .ids import next_receipt_id
from .pipeline import run
from .resume import completed


def ingest_directory(
    source_root: Path,
    receipt_root: Path,
    output_root: Path,
    source_class: str,
):
    outputs = []

    already_done = completed(output_root)

    for source in discover(source_root):
        source = source.resolve()

        if source in already_done:
            continue

        output, _ = run(
            source=source,
            receipt_id=next_receipt_id(receipt_root),
            source_class=source_class,
            receipt_root=receipt_root,
            output_root=output_root,
        )

        outputs.append(output)

    return outputs


def ingest_sources(
    sources,
    receipt_root: Path,
    output_root: Path,
    source_class: str,
):
    outputs = []
    already_done = completed(output_root)

    for source in sources:
        source = Path(source).resolve()

        if source in already_done:
            continue

        output, _ = run(
            source=source,
            receipt_id=next_receipt_id(receipt_root),
            source_class=source_class,
            receipt_root=receipt_root,
            output_root=output_root,
        )

        outputs.append(output)
        already_done.add(source)

    return outputs
