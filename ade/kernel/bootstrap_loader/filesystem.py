"""
Filesystem helpers.
"""

from pathlib import Path

def require(path: Path) -> Path:
    if not path.exists():
        raise FileNotFoundError(path)
    return path
