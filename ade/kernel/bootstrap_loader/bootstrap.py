from pathlib import Path

from .artifacts import BootstrapArtifacts
from .artifacts import discover_artifacts


def load_bootstrap(
    root: Path,
) -> BootstrapArtifacts:
    """
    Load the bootstrap artifact set for a repository root.

    This module preserves the historical load_bootstrap interface
    while delegating artifact discovery to the canonical
    discover_artifacts implementation.
    """
    return discover_artifacts(root)
