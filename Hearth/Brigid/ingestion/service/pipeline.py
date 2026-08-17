from dataclasses import replace
from pathlib import Path

from .assets import extract as extract_assets
from .intake import intake
from .receipt import write_receipt
from .manifest import write_manifest
from .output import write_output
from .parser import parse
from .provenance import build as build_provenance
from .queues import generate as generate_queues
from .references import extract as extract_references
from .validation import validate
from .state import save
from .stages import Stage


def run(
    source: Path,
    receipt_id: str,
    source_class: str,
    receipt_root: Path,
    output_root: Path,
):
    state_root = Path(
        'workspace/operational/ingestion/state'
    )

    receipt = intake(
        source=source,
        receipt_id=receipt_id,
        source_class=source_class,
        receipt_root=receipt_root,
    )

    save(receipt, Stage.INTAKE, state_root)
    parsed = parse(
        source,
        source_class=receipt.source_class,
    )

    receipt = replace(
        receipt,
        parser_status="complete",
    )

    write_receipt(
        receipt,
        receipt_root / f"{receipt.receipt_id}.json",
    )

    save(receipt, Stage.PARSE, state_root)
    assets = extract_assets(parsed)
    save(receipt, Stage.ASSETS, state_root)
    references = extract_references(parsed)
    save(receipt, Stage.REFERENCES, state_root)
    queues = generate_queues(parsed, assets, references)
    save(receipt, Stage.QUEUES, state_root)
    validation = validate(
        receipt,
        parsed,
        assets,
        references,
        queues,
    )

    save(receipt, Stage.VALIDATION, state_root)

    provenance = build_provenance(receipt)
    save(receipt, Stage.PROVENANCE, state_root)

    output = write_output(
        source,
        receipt,
        parsed,
        assets,
        references,
        queues,
        validation,
        provenance,
        output_root,
    )

    save(receipt, Stage.OUTPUT, state_root)

    write_manifest(
        output,
        receipt,
        parsed,
        assets,
        references,
        queues,
        provenance,
        validation,
    )

    save(receipt, Stage.MANIFEST, state_root)
    return output, provenance
