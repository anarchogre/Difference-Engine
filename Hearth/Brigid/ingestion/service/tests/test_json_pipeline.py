import json
from pathlib import Path
from tempfile import TemporaryDirectory

from ..batch import ingest_sources


def main():
    expected = {
        "artifact": {
            "identifier": "PAN-JSON-PIPELINE-TEST",
            "title": "JSON pipeline preservation test",
            "nested": {
                "alpha": 1,
                "beta": [True, None, "x"],
            },
        }
    }

    with TemporaryDirectory(
        prefix="difference-engine-json-pipeline-"
    ) as tmp:
        root = Path(tmp)
        source = root / "fixture.json"
        receipt_root = root / "receipts"
        output_root = root / "output"

        source.write_text(
            json.dumps(expected),
            encoding="utf-8",
        )

        outputs = ingest_sources(
            sources=(source,),
            receipt_root=receipt_root,
            output_root=output_root,
            source_class="manual_batch",
        )

        assert len(outputs) == 1
        out = Path(outputs[0])

        parsed = json.loads(
            (out / "structure/parsed.json").read_text(
                encoding="utf-8"
            )
        )
        manifest = json.loads(
            (out / "reports/manifest.json").read_text(
                encoding="utf-8"
            )
        )
        validation = json.loads(
            (out / "reports/validation.json").read_text(
                encoding="utf-8"
            )
        )

        assert parsed["kind"] == "json"
        assert parsed["document"] == expected
        assert manifest["kind"] == "json"
        assert validation["passed"] is True
        assert validation["errors"] == []

    print("PASS")


if __name__ == "__main__":
    main()
