from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any


@dataclass(frozen=True)
class ComparisonResult:
    operator_id: str
    operator_version: str

    left_raw_sha256: str
    right_raw_sha256: str

    profile_id: str | None
    profile_version: str | None

    operation_completed: bool
    raw_equal: bool
    equivalent_under_profile: bool | None

    deterministic: bool
    diagnostics: tuple[str, ...]
    metadata: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
