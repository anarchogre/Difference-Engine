from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Iterable

from .models.records import DirectoryRecord, FileRecord


def sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as handle:
        while chunk := handle.read(chunk_size):
            digest.update(chunk)

    return digest.hexdigest()


def _is_excluded(
    relative: Path,
    excluded_prefixes: tuple[Path, ...],
) -> bool:
    if ".git" in relative.parts:
        return True

    return any(
        relative == prefix or prefix in relative.parents
        for prefix in excluded_prefixes
    )


def census_repository(
    root: Path,
    exclude: Iterable[Path | str] = (),
) -> dict:
    root = root.resolve()

    if not root.is_dir():
        raise NotADirectoryError(root)

    excluded_prefixes = tuple(
        Path(item)
        for item in exclude
    )

    for prefix in excluded_prefixes:
        if prefix.is_absolute():
            raise ValueError(
                f"Exclusions must be relative paths: {prefix}"
            )

    files: list[FileRecord] = []
    directories: list[DirectoryRecord] = []

    for path in sorted(root.rglob("*"), key=lambda item: item.as_posix()):
        relative = path.relative_to(root)

        if _is_excluded(relative, excluded_prefixes):
            continue

        relative_path = relative.as_posix()

        if path.is_dir():
            directories.append(
                DirectoryRecord(path=relative_path)
            )
            continue

        if not path.is_file():
            continue

        size = path.stat().st_size

        files.append(
            FileRecord(
                path=relative_path,
                size_bytes=size,
                sha256=sha256_file(path),
                extension=path.suffix.lower(),
                empty=size == 0,
            )
        )

    return {
        "root": str(root),
        "excluded": [
            prefix.as_posix()
            for prefix in excluded_prefixes
        ],
        "directory_count": len(directories),
        "file_count": len(files),
        "directories": [
            record.to_dict()
            for record in directories
        ],
        "files": [
            record.to_dict()
            for record in files
        ],
    }
