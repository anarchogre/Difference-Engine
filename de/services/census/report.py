from __future__ import annotations

import json
from collections import Counter, defaultdict
from pathlib import Path


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    path.write_text(
        json.dumps(
            payload,
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )


def build_reports(census: dict) -> dict:
    files = census["files"]
    directories = census["directories"]

    extension_counts = Counter(
        record["extension"] or "[no extension]"
        for record in files
    )

    hash_groups: dict[str, list[str]] = defaultdict(list)

    for record in files:
        hash_groups[record["sha256"]].append(
            record["path"]
        )

    duplicates = {
        digest: sorted(paths)
        for digest, paths in sorted(hash_groups.items())
        if len(paths) > 1
    }

    empty_files = [
        record
        for record in files
        if record["empty"]
    ]

    return {
        "MANIFEST.json": {
            "root": census["root"],
            "directory_count": census["directory_count"],
            "file_count": census["file_count"],
            "total_bytes": sum(
                record["size_bytes"]
                for record in files
            ),
        },
        "FILE_INDEX.json": files,
        "DIRECTORY_INDEX.json": directories,
        "EXTENSIONS.json": dict(
            sorted(extension_counts.items())
        ),
        "HASH_INDEX.json": {
            digest: sorted(paths)
            for digest, paths in sorted(hash_groups.items())
        },
        "DUPLICATES.json": duplicates,
        "EMPTY_FILES.json": empty_files,
    }


def write_reports(
    census: dict,
    output_directory: Path,
) -> None:
    reports = build_reports(census)

    for filename, payload in reports.items():
        write_json(
            output_directory / filename,
            payload,
        )
