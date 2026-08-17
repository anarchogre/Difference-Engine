from pathlib import Path

from ade.services.ingestion.parsers import parse_markdown


def main():
    source = (
        Path.home()
        / "storage/shared/FILE_LIBRARY_UPLOADS"
        / "99_UTILITIES/Ingestion"
        / "AIS_v0.1.md"
    )

    parsed = parse_markdown(source)

    assert parsed.title == "Artifact Ingestion Specification (AIS)"
    assert "Mission" in parsed.headings
    assert "Pipeline" in parsed.headings

    print("PASS")


if __name__ == "__main__":
    main()
