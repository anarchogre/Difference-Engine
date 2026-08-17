from pathlib import Path
import hashlib
import json

from workspace.operational.ingestion.service.parsers.chatgpt import parse_chatgpt


SHARED = Path.home() / "storage/shared"

ROOTS = (
    Path("."),
    SHARED / "ADE",
    SHARED / "ADE_DIFFERENCE_ENGINE",
    SHARED / "ADE_UPLOAD",
    SHARED / "FILE_LIBRARY_UPLOADS",
    SHARED / "Download",
    SHARED / "Downloads",
)

EXCLUDED = (
    "/.git/",
    "/ingestion/output/",
    "/ingestion/test_output/",
    "/ingestion/parser_tests/",
    "/ingestion/chat_test.txt",
    "/ingestion/chat_pipeline_test.txt",
)

output = Path(
    "workspace/operational/ingestion/evidence/"
    "CONVERSATION_CORPUS_VERIFIED.json"
)

records = {}
rejected = []

for root in ROOTS:
    if not root.exists():
        continue

    for source in root.rglob("*"):
        if not source.is_file():
            continue

        if source.suffix.lower() not in {".txt", ".md"}:
            continue

        resolved = str(source.resolve())

        if any(token in resolved for token in EXCLUDED):
            continue

        try:
            parsed = parse_chatgpt(source)
        except Exception as error:
            rejected.append(
                {
                    "path": resolved,
                    "reason": type(error).__name__,
                }
            )
            continue

        if parsed.get("kind") != "conversation":
            continue

        turns = parsed.get("turns") or []

        speakers = {
            getattr(turn, "speaker", None)
            for turn in turns
        }

        if not {"user", "assistant"} <= speakers:
            continue

        digest = hashlib.sha256(
            source.read_bytes()
        ).hexdigest()

        candidate = {
            "sha256": digest,
            "size_bytes": source.stat().st_size,
            "path": resolved,
            "turn_count": len(turns),
            "speakers": sorted(speakers),
        }

        previous = records.get(digest)

        if (
            previous is None
            or "FILE_LIBRARY_UPLOADS" in previous["path"]
        ):
            records[digest] = candidate

payload = {
    "verified_count": len(records),
    "conversations": sorted(
        records.values(),
        key=lambda item: item["size_bytes"],
    ),
    "rejected_errors": rejected,
}

output.write_text(
    json.dumps(
        payload,
        indent=2,
        sort_keys=True,
    ) + "\n",
    encoding="utf-8",
)

print(f"Verified conversations: {len(records)}")

for item in payload["conversations"]:
    print(
        f"{item['turn_count']} turns\t"
        f"{item['size_bytes']} bytes\t"
        f"{item['path']}"
    )
