import tempfile
import unittest
from pathlib import Path

from ade.services.census import census_repository
from ade.services.census.report import (
    build_reports,
    write_reports,
)


class CensusReportTests(unittest.TestCase):
    def test_reports_capture_duplicates_and_empty_files(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "source"
            output = Path(temporary) / "output"

            root.mkdir()

            (root / "a.txt").write_text(
                "same",
                encoding="utf-8",
            )
            (root / "b.txt").write_text(
                "same",
                encoding="utf-8",
            )
            (root / "empty.md").write_bytes(b"")

            census = census_repository(root)
            reports = build_reports(census)

            self.assertEqual(
                reports["MANIFEST.json"]["file_count"],
                3,
            )
            self.assertEqual(
                len(reports["DUPLICATES.json"]),
                1,
            )
            self.assertEqual(
                len(reports["EMPTY_FILES.json"]),
                1,
            )

            write_reports(census, output)

            expected = {
                "MANIFEST.json",
                "FILE_INDEX.json",
                "DIRECTORY_INDEX.json",
                "EXTENSIONS.json",
                "HASH_INDEX.json",
                "DUPLICATES.json",
                "EMPTY_FILES.json",
            }

            self.assertEqual(
                {
                    path.name
                    for path in output.iterdir()
                },
                expected,
            )


if __name__ == "__main__":
    unittest.main()
