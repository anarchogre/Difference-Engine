import json
from pathlib import Path

from workspace.operational.ingestion.service.pipeline import run


def main():
    source = Path(
        "workspace/operational/ingestion/chat_pipeline_test.txt"
    )

    source.write_text(
        "\n".join(
            (
                "User: mkdir demo",
                "Assistant: ok",
                "User: cat README.md",
                "User: TODO implement parser",
            )
        ),
        encoding="utf-8",
    )

    output, provenance = run(
        source=source,
        receipt_id="TEST-CHAT-0002",
        source_class="conversation",
        receipt_root=Path(
            "workspace/operational/ingestion/test_receipts"
        ),
        output_root=Path(
            "workspace/operational/ingestion/test_output"
        ),
    )

    manifest = json.loads(
        (output / "reports/manifest.json").read_text()
    )

    assert manifest["kind"] == "conversation"
    assert manifest["turn_count"] == 4
    assert manifest["command_count"] == 2
    assert manifest["validation"]["passed"] is True
    assert provenance.source_sha256

    print("PASS")
    print(output)


if __name__ == "__main__":
    main()
