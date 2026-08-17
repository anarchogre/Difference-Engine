"""
Bootstrap validation.
"""

from .artifacts import BootstrapArtifacts
from .models import Specifications

def validate(
    artifacts: BootstrapArtifacts,
    specifications: Specifications,
) -> None:
    assert artifacts.constitution.exists()
    assert artifacts.amendments.exists()
    assert artifacts.bootstrap.exists()
    assert specifications.root.exists()
