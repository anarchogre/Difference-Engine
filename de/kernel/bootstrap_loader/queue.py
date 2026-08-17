"""
Deterministic queue recovery.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class QueueEntry:
    path: Path
    queue: str
    status: str
    title: str


@dataclass(frozen=True)
class QueueState:
    suggested: tuple[QueueEntry, ...]
    implementation: tuple[QueueEntry, ...]
    active: tuple[QueueEntry, ...]
    completed: tuple[QueueEntry, ...]
    deferred: tuple[QueueEntry, ...]
    unknown: tuple[QueueEntry, ...]


def _first_heading(
    path: Path,
) -> str:
    text = path.read_text(
        encoding="utf-8",
        errors="replace",
    )

    for line in text.splitlines():
        stripped = line.strip()

        if stripped.startswith("#"):
            title = stripped.lstrip("#").strip()

            if title:
                return title

    return path.stem


def _classify(
    path: Path,
) -> tuple[str, str]:
    relative = path.as_posix().lower()
    name = path.name.lower()

    if "/completed/" in relative:
        return "completed", "Completed"

    if "/active/" in relative:
        return "active", "Active"

    if "/deferred/" in relative:
        return "deferred", "Deferred"

    if "/implementation/" in relative:
        return "implementation", "Accepted"

    if (
        name.startswith("siq")
        or "suggested_implementation" in name
        or "suggested-implementation" in name
    ):
        return "suggested", "Suggested"

    if name.startswith("iq"):
        return "implementation", "Accepted"

    if name.startswith("q-"):
        return "unknown", "Unknown"

    return "unknown", "Unknown"


def recover_queues(
    root: Path | None = None,
) -> QueueState:
    repository_root = (
        root.resolve()
        if root is not None
        else Path.cwd().resolve()
    )

    queue_root = repository_root / "queue"

    buckets: dict[str, list[QueueEntry]] = {
        "suggested": [],
        "implementation": [],
        "active": [],
        "completed": [],
        "deferred": [],
        "unknown": [],
    }

    if queue_root.is_dir():
        files = sorted(
            path
            for path in queue_root.rglob("*")
            if path.is_file()
        )

        for path in files:
            queue, status = _classify(path)

            entry = QueueEntry(
                path=path,
                queue=queue,
                status=status,
                title=_first_heading(path),
            )

            buckets[queue].append(entry)

    return QueueState(
        suggested=tuple(buckets["suggested"]),
        implementation=tuple(
            buckets["implementation"]
        ),
        active=tuple(buckets["active"]),
        completed=tuple(buckets["completed"]),
        deferred=tuple(buckets["deferred"]),
        unknown=tuple(buckets["unknown"]),
    )
