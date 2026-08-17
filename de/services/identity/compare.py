from __future__ import annotations

from .models.comparison import ComparisonResult
from .normalize import normalize_text_line_endings
from .profiles import (
    NormalizationProfile,
    TEXT_LINE_ENDINGS_V1,
)


OPERATOR_ID = "BYTE_AND_PROFILE_COMPARISON"
OPERATOR_VERSION = "1"


def compare_bytes(
    left: bytes,
    right: bytes,
    profile: NormalizationProfile | None = None,
) -> ComparisonResult:
    diagnostics: list[str] = []

    selected_profile = profile or TEXT_LINE_ENDINGS_V1

    left_result = normalize_text_line_endings(
        left,
        profile=selected_profile,
    )
    right_result = normalize_text_line_endings(
        right,
        profile=selected_profile,
    )

    raw_equal = (
        left_result.raw_sha256
        == right_result.raw_sha256
    )

    if not left_result.valid:
        diagnostics.append(
            "Left input failed normalization."
        )

    if not right_result.valid:
        diagnostics.append(
            "Right input failed normalization."
        )

    operation_completed = (
        left_result.valid
        and right_result.valid
    )

    equivalent_under_profile: bool | None

    if operation_completed:
        equivalent_under_profile = (
            left_result.normalized_sha256
            == right_result.normalized_sha256
        )
    else:
        equivalent_under_profile = None

    return ComparisonResult(
        operator_id=OPERATOR_ID,
        operator_version=OPERATOR_VERSION,
        left_raw_sha256=left_result.raw_sha256,
        right_raw_sha256=right_result.raw_sha256,
        profile_id=selected_profile.profile_id,
        profile_version=selected_profile.version,
        operation_completed=operation_completed,
        raw_equal=raw_equal,
        equivalent_under_profile=equivalent_under_profile,
        deterministic=True,
        diagnostics=tuple(diagnostics),
        metadata={
            "left_changed_under_profile": (
                left_result.changed
            ),
            "right_changed_under_profile": (
                right_result.changed
            ),
            "left_normalized_sha256": (
                left_result.normalized_sha256
            ),
            "right_normalized_sha256": (
                right_result.normalized_sha256
            ),
        },
    )
