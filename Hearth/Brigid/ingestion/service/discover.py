from pathlib import Path


SUPPORTED = {
    ".md",
    ".txt",
    ".pdf",
    ".json",
    ".yaml",
    ".yml",
}


def discover(root: Path):
    for path in sorted(root.rglob("*")):
        if (
            path.is_file()
            and path.suffix.lower() in SUPPORTED
        ):
            yield path
