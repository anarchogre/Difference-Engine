"""
Bootstrap initialization result.
"""

from dataclasses import dataclass

from .artifacts import BootstrapArtifacts
from .models import Specifications
from .state import OperationalState

@dataclass(slots=True)
class BootstrapResult:
    artifacts: BootstrapArtifacts
    specifications: Specifications
    state: OperationalState
