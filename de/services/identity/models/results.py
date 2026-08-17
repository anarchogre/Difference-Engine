from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any


@dataclass(frozen=True)
class NormalizationResult:
    profile_id: str
    profile_version: str

    raw_sha256: str
    normalized_sha256: str | None

    valid: bool
    changed: bool
    deterministic: bool

    loss_class: str
    invariants: tuple[str, ...]

    diagnostics: tuple[str, ...]
    metadata: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
