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

    sources = artifacts.initialization
    assert sources.ltck.exists()
    assert sources.kernel.exists()
    assert sources.babbage.exists()
    assert sources.operator_profile.exists()
    assert sources.reckless_ideator.exists()
    assert sources.operational_reality.exists()
    assert sources.meta_changelog.exists()

    assert specifications.root.exists()
