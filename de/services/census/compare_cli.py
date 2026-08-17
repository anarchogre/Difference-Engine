from __future__ import annotations

import argparse
from pathlib import Path

from .compare import compare_censuses, write_comparison


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compare two deterministic census outputs."
    )

    parser.add_argument("left", type=Path)
    parser.add_argument("right", type=Path)
    parser.add_argument("output", type=Path)

    arguments = parser.parse_args()

    comparison = compare_censuses(
        arguments.left,
        arguments.right,
    )

    write_comparison(
        comparison,
        arguments.output,
    )

    for key, value in comparison["summary"].items():
        print(f"{key}: {value}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
