"""
Bootstrap Loader models.
"""

from dataclasses import dataclass
from pathlib import Path

@dataclass(slots=True)
class Governance:
    constitution: Path
    amendments: Path

@dataclass(slots=True)
class Specifications:
    root: Path
