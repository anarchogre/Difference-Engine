from pathlib import Path

from ade.services.ingestion import intake


def main():
    receipt = intake(
        source=(
            Path.home()
            / "storage/shared/FILE_LIBRARY_UPLOADS"
            / "99_UTILITIES/Ingestion"
            / "AIS_v0.1.md"
        ),
        receipt_id="TEST-0001",
        source_class="file_library_upload",
        receipt_root=Path("workspace/operational/ingestion/test_receipts"),
    )

    assert receipt.receipt_id == "TEST-0001"

    print("PASS")


if __name__ == "__main__":
    main()
