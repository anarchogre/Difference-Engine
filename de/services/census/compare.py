from __future__ import annotations

import json
from pathlib import Path

from .report import write_json


def load_json(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def compare_censuses(
    left_directory: Path,
    right_directory: Path,
) -> dict:
    left_files = load_json(left_directory / "FILE_INDEX.json")
    right_files = load_json(right_directory / "FILE_INDEX.json")

    left_by_hash: dict[str, list[str]] = {}
    right_by_hash: dict[str, list[str]] = {}

    for record in left_files:
        left_by_hash.setdefault(record["sha256"], []).append(
            record["path"]
        )

    for record in right_files:
        right_by_hash.setdefault(record["sha256"], []).append(
            record["path"]
        )

    left_hashes = set(left_by_hash)
    right_hashes = set(right_by_hash)

    shared_hashes = sorted(left_hashes & right_hashes)
    unique_left_hashes = sorted(left_hashes - right_hashes)
    unique_right_hashes = sorted(right_hashes - left_hashes)

    return {
        "shared_hashes": {
            digest: {
                "left_paths": sorted(left_by_hash[digest]),
                "right_paths": sorted(right_by_hash[digest]),
            }
            for digest in shared_hashes
        },
        "unique_left": {
            digest: sorted(left_by_hash[digest])
            for digest in unique_left_hashes
        },
        "unique_right": {
            digest: sorted(right_by_hash[digest])
            for digest in unique_right_hashes
        },
        "summary": {
            "left_file_count": len(left_files),
            "right_file_count": len(right_files),
            "left_unique_hash_count": len(left_hashes),
            "right_unique_hash_count": len(right_hashes),
            "shared_hash_count": len(shared_hashes),
            "left_only_hash_count": len(unique_left_hashes),
            "right_only_hash_count": len(unique_right_hashes),
            "shared_left_file_count": sum(
                len(left_by_hash[digest])
                for digest in shared_hashes
            ),
            "shared_right_file_count": sum(
                len(right_by_hash[digest])
                for digest in shared_hashes
            ),
        },
    }


def write_comparison(
    comparison: dict,
    output_directory: Path,
) -> None:
    write_json(
        output_directory / "SHARED_HASHES.json",
        comparison["shared_hashes"],
    )
    write_json(
        output_directory / "UNIQUE_DE.json",
        comparison["unique_left"],
    )
    write_json(
        output_directory / "UNIQUE_ADE.json",
        comparison["unique_right"],
    )
    write_json(
        output_directory / "SUMMARY.json",
        comparison["summary"],
    )
