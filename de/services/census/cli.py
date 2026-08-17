from __future__ import annotations

import argparse
from pathlib import Path

from .engine import census_repository
from .report import write_reports


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate a deterministic repository census."
    )

    parser.add_argument("root", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        help="Relative path prefix to exclude; repeatable.",
    )

    arguments = parser.parse_args()

    census = census_repository(
        arguments.root,
        exclude=arguments.exclude,
    )

    write_reports(
        census,
        arguments.output,
    )

    print(f"Root: {census['root']}")
    print(f"Directories: {census['directory_count']}")
    print(f"Files: {census['file_count']}")
    print(f"Output: {arguments.output}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
