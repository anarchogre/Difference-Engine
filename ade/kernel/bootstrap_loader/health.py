"""
Bootstrap Loader health.
"""

from .loader import initialize

def check() -> bool:
    initialize()
    return True
