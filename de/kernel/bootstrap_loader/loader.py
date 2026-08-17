"""
Bootstrap Loader.
"""

from .discover import discover_repository
from .execution import enter_execution_mode
from .governance import load_governance
from .logging import log
from .mission import recover_mission
from .modes import activate_modes
from .queue import recover_queues
from .readiness import verify_readiness
from .recovery import recover_state
from .result import BootstrapResult
from .specifications import load_specifications
from .state import OperationalState
from .task import recover_task
from .validators import validate

def initialize() -> BootstrapResult:
    log("Discovering repository...")
    root = discover_repository()

    artifacts = load_governance(root)
    specifications = load_specifications(root)

    validate(artifacts, specifications)

    if not verify_readiness(root):
        raise RuntimeError("Operational Readiness failed.")

    state = OperationalState(
        repository_root=root,
        governance_root=artifacts.constitution.parent,
        specification_root=specifications.root,
        execution_mode=activate_modes()["primary"],
        mission=recover_mission(),
        task=recover_task(),
    )

    recover_queues()
    state = recover_state(state)
    state = enter_execution_mode(state)

    return BootstrapResult(
        artifacts=artifacts,
        specifications=specifications,
        state=state,
    )
