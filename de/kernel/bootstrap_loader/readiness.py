"""
Operational readiness verification.
"""

from .paths import architecture, repository, specifications

def verify_readiness(root) -> bool:
    required = (
        repository(root),
        architecture(root),
        specifications(root),
    )

    return all(path.exists() for path in required)
