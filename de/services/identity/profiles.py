from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class NormalizationProfile:
    profile_id: str
    version: str
    domain: str
    loss_class: str
    invariants: tuple[str, ...]


TEXT_LINE_ENDINGS_V1 = NormalizationProfile(
    profile_id="TEXT_LINE_ENDINGS",
    version="1",
    domain="UTF-8-compatible textual byte streams",
    loss_class="representation-normalizing",
    invariants=(
        "decoded text content",
        "line order",
        "horizontal whitespace",
        "terminal blank-line count",
    ),
)
