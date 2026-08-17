from dataclasses import asdict, dataclass


@dataclass(frozen=True)
class FileRecord:
    path: str
    size_bytes: int
    sha256: str
    extension: str
    empty: bool

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass(frozen=True)
class DirectoryRecord:
    path: str

    def to_dict(self) -> dict:
        return asdict(self)
