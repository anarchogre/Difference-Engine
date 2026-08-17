"""
Bootstrap artifact and initialization-source discovery.
"""

from dataclasses import dataclass
from pathlib import Path

from .filesystem import require


@dataclass(slots=True)
class InitializationSources:
    ltck: Path
    kernel: Path
    babbage: Path
    operator_profile: Path
    reckless_ideator: Path
    operational_reality: Path
    meta_changelog: Path


@dataclass(slots=True)
class BootstrapArtifacts:
    constitution: Path
    amendments: Path
    bootstrap: Path
    initialization: InitializationSources


def discover_artifacts(root: Path) -> BootstrapArtifacts:
    governance = root / "Repository" / "Governance"

    initialization = InitializationSources(
        ltck=require(
            root / "BOOTSTRAP" / "Load The Constitutional Kernel.md"
        ),
        kernel=require(
            root / "governance" / "kernel"
            / "KRN-0001_Common_Constitutional_Kernel_v0.1.0.md"
        ),
        babbage=require(
            root / "workspace/operational/ingestion/output"
            / "ING-20260804-0082/source/Babbage_GPT_Initialization.md.txt"
        ),
        operator_profile=require(
            root / "workspace/operational/corpus/chatgpt/Operator Profile.md"
        ),
        reckless_ideator=require(
            root / "workspace/operational/corpus/chatgpt/Reckless Ideator.md"
        ),
        operational_reality=require(
            root / "workspace/operational/corpus/chatgpt/Operational Reality.txt"
        ),
        meta_changelog=require(root / "META_CHANGELOG.md"),
    )

    return BootstrapArtifacts(
        constitution=require(governance / "constitution.md"),
        amendments=require(governance / "amendments.md"),
        bootstrap=require(governance / "bootstrap.md"),
        initialization=initialization,
    )
