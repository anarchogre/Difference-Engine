"""
Bootstrap Loader contracts.
"""

from typing import Protocol
from pathlib import Path

class Loader(Protocol):
    def __call__(self, root: Path) -> Path: ...
