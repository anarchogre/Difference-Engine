from pathlib import Path

from workspace.operational.ingestion.service.parsers import parse_markdown


def main():
    source = (
        Path(__file__).resolve().parent
        / "fixtures"
        / "AIS_v0.1.md"
    )

    parsed = parse_markdown(source)

    assert parsed.title == "Artifact Ingestion Specification (AIS)"
    assert "Mission" in parsed.headings
    assert "Pipeline" in parsed.headings

    print("PASS")


if __name__ == "__main__":
    main()
