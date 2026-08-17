"""
Mission recovery.
"""

from pathlib import Path
import re


MISSION_SOURCES = (
    Path("workspace/operational/current/ACTIVE_MISSION.md"),
    Path("workspace/operational/current/COMPLETED_TASK_BLOCK.md"),
    Path("workspace/operational/bootstrap/INITIALIZATION_ORDER.md"),
    Path("workspace/operational/Continue DifferenceEngine.md"),
)


def _extract_mission(text: str) -> str | None:
    patterns = (
        r"(?im)^current mission\s*:?\s*(.+)$",
        r"(?im)^active mission\s*:?\s*(.+)$",
        r"(?im)^mission\s*:?\s*(.+)$",
        r"(?im)^#+\s*current mission\s*$\s*(.+)$",
        r"(?im)^#+\s*active mission\s*$\s*(.+)$",
    )

    for pattern in patterns:
        match = re.search(pattern, text)

        if match:
            value = match.group(1).strip()

            if value:
                return value

    return None


def recover_mission() -> str | None:
    for path in MISSION_SOURCES:
        if not path.is_file():
            continue

        text = path.read_text(
            encoding="utf-8",
            errors="replace",
        )

        mission = _extract_mission(text)

        if mission:
            return mission

    fallback = Path(
        "workspace/operational/current/"
        "COMPLETED_TASK_BLOCK.md"
    )

    if fallback.is_file():
        text = fallback.read_text(
            encoding="utf-8",
            errors="replace",
        )

        match = re.search(
            r"(?im)^(.+?)\s+remains the active mission\.$",
            text,
        )

        if match:
            return match.group(1).strip()

    return None
