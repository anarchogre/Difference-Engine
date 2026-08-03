"""
Bootstrap execution context.
"""

from dataclasses import dataclass

from .state import OperationalState

@dataclass(slots=True)
class BootstrapContext:
    state: OperationalState
