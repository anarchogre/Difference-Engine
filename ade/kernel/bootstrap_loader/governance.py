"""
Governance loading.
"""

from .artifacts import discover_artifacts

def load_governance(root):
    return discover_artifacts(root)
