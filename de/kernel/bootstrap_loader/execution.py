"""
Execution activation.
"""

from .state import OperationalState

def enter_execution_mode(state: OperationalState) -> OperationalState:
    state.execution_mode = "Execution"
    return state
