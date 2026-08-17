"""
Repository discovery.
"""

from pathlib import Path

from .config import REPOSITORY_ROOT

REPOSITORY_MARKERS = (
    "Repository",
    "architecture",
    "specifications",
)

def discover_repository(start: Path | None = None) -> Path:
    root = (start or REPOSITORY_ROOT).resolve()

    for marker in REPOSITORY_MARKERS:
        if not (root / marker).exists():
            raise FileNotFoundError(marker)

    return root
