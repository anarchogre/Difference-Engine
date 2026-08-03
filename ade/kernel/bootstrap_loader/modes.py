"""
Operational mode activation.
"""

from .constants import (
    DISCUSSION_MODE,
    EXECUTION_MODE,
    PRESERVATION_MODE,
    RECOVERY_MODE,
)

def activate_modes():
    return {
        "primary": EXECUTION_MODE,
        "discussion": DISCUSSION_MODE,
        "recovery": RECOVERY_MODE,
        "preservation": PRESERVATION_MODE,
    }
