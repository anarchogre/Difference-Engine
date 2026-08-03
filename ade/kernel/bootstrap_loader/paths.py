"""
Canonical repository paths.
"""

from pathlib import Path

def governance(root: Path) -> Path:
    return root / "Repository" / "Governance"

def specifications(root: Path) -> Path:
    return root / "specifications"

def architecture(root: Path) -> Path:
    return root / "architecture"

def repository(root: Path) -> Path:
    return root / "Repository"
