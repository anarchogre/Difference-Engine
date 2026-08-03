"""
Bootstrap Loader exceptions.
"""

class BootstrapError(Exception):
    """Base bootstrap exception."""

class ReadinessError(BootstrapError):
    """Operational readiness failed."""
