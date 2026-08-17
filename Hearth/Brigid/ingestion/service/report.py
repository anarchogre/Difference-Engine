from pathlib import Path


def write_report(
    root: Path,
    manifest: dict,
):
    lines = [
        "# Ingestion Report",
        "",
        f"Receipt: {manifest['receipt']}",
        f"Kind: {manifest['kind']}",
        f"Title: {manifest['title']}",
        "",
        "## Counts",
        f"- Turns: {manifest['turn_count']}",
        f"- Commands: {manifest['command_count']}",
        f"- Assets: {manifest['asset_count']}",
        f"- References: {manifest['reference_count']}",
        f"- Queue Candidates: {manifest['queue_count']}",
        "",
        "## Validation",
        f"- Passed: {manifest['validation']['passed']}",
    ]

    (root / "reports" / "ingestion_report.md").write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
    )
