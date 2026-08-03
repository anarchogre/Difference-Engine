"""
Canonical specification loading.
"""

from .models import Specifications
from .paths import specifications

def load_specifications(root):
    return Specifications(
        root=specifications(root)
    )
