from __future__ import annotations

import hashlib

from .models.results import NormalizationResult
from .profiles import (
    NormalizationProfile,
    TEXT_LINE_ENDINGS_V1,
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalize_text_line_endings(
    data: bytes,
    profile: NormalizationProfile = TEXT_LINE_ENDINGS_V1,
) -> NormalizationResult:
    diagnostics: list[str] = []

    raw_sha256 = sha256_bytes(data)

    working = data

    if working.startswith(b"\xef\xbb\xbf"):
        working = working[3:]
        diagnostics.append("UTF-8 BOM removed.")

    try:
        text = working.decode(
            "utf-8",
            errors="strict",
        )
    except UnicodeDecodeError as error:
        return NormalizationResult(
            profile_id=profile.profile_id,
            profile_version=profile.version,
            raw_sha256=raw_sha256,
            normalized_sha256=None,
            valid=False,
            changed=False,
            deterministic=True,
            loss_class=profile.loss_class,
            invariants=profile.invariants,
            diagnostics=(
                f"UTF-8 decoding failed: {error}",
            ),
            metadata={
                "input_bytes": len(data),
                "output_bytes": None,
            },
        )

    normalized_text = (
        text
        .replace("\r\n", "\n")
        .replace("\r", "\n")
    )

    normalized = normalized_text.encode("utf-8")
    normalized_sha256 = sha256_bytes(normalized)

    if normalized != data:
        diagnostics.append(
            "Input representation changed under profile."
        )

    return NormalizationResult(
        profile_id=profile.profile_id,
        profile_version=profile.version,
        raw_sha256=raw_sha256,
        normalized_sha256=normalized_sha256,
        valid=True,
        changed=normalized != data,
        deterministic=True,
        loss_class=profile.loss_class,
        invariants=profile.invariants,
        diagnostics=tuple(diagnostics),
        metadata={
            "input_bytes": len(data),
            "output_bytes": len(normalized),
        },
    )
