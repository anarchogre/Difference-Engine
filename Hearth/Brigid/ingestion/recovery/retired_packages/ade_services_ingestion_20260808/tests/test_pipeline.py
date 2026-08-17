from pathlib import Path
import json

from ade.services.ingestion.pipeline import run


def main():
    source = (
        Path.home()
        / "storage/shared/FILE_LIBRARY_UPLOADS"
        / "99_UTILITIES/Ingestion"
        / "AIS_v0.1.md"
    )

    output, provenance = run(
        source=source,
        receipt_id="TEST-PIPELINE-0003",
        source_class="file_library_upload",
        receipt_root=Path(
            "workspace/operational/ingestion/test_receipts"
        ),
        output_root=Path(
            "workspace/operational/ingestion/test_output"
        ),
    )

    assert (output / "metadata/receipt.json").is_file()
    assert (output / "provenance/provenance.json").is_file()
    assert provenance.source_sha256


    markdown_conversation = Path(
        "workspace/operational/ingestion/"
        "markdown_conversation_test.md"
    )

    markdown_conversation.write_text(
        "## You\nhello\n## ChatGPT\nhi\n",
        encoding="utf-8",
    )

    output, _ = run(
        source=markdown_conversation,
        receipt_id="TEST-PIPELINE-MD-CONV",
        source_class="conversation",
        receipt_root=Path(
            "workspace/operational/ingestion/test_receipts"
        ),
        output_root=Path(
            "workspace/operational/ingestion/test_output"
        ),
    )

    parsed = json.loads(
        (
            output / "structure/parsed.json"
        ).read_text()
    )

    assert parsed["kind"] == "conversation"
    assert len(parsed["turns"]) == 2

    print("PASS")
    print(output)


if __name__ == "__main__":
    main()
