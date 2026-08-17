"""
Bootstrap operational state.
"""

from dataclasses import dataclass
from pathlib import Path

@dataclass(slots=True)
class OperationalState:
    repository_root: Path
    governance_root: Path
    specification_root: Path
    execution_mode: str
    mission: str | None = None
    task: str | None = None
