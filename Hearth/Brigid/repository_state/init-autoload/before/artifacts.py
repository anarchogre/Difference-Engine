"""
Canonical artifact discovery.
"""

from dataclasses import dataclass
from pathlib import Path

from .filesystem import require

@dataclass(slots=True)
class BootstrapArtifacts:
    constitution: Path
    amendments: Path
    bootstrap: Path

def discover_artifacts(root: Path) -> BootstrapArtifacts:
    governance = root / "Repository" / "Governance"

    return BootstrapArtifacts(
        constitution=require(governance / "constitution.md"),
        amendments=require(governance / "amendments.md"),
        bootstrap=require(governance / "bootstrap.md"),
    )
