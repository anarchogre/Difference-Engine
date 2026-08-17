import tempfile
import unittest
from pathlib import Path

from ade.services.census import census_repository
from ade.services.census.compare import compare_censuses
from ade.services.census.report import write_reports


class CensusComparisonTests(unittest.TestCase):
    def test_comparison_finds_shared_and_unique_hashes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)

            left_root = base / "left"
            right_root = base / "right"
            left_output = base / "left_output"
            right_output = base / "right_output"

            left_root.mkdir()
            right_root.mkdir()

            (left_root / "shared.txt").write_text(
                "shared",
                encoding="utf-8",
            )
            (right_root / "renamed.txt").write_text(
                "shared",
                encoding="utf-8",
            )
            (left_root / "left.txt").write_text(
                "left",
                encoding="utf-8",
            )
            (right_root / "right.txt").write_text(
                "right",
                encoding="utf-8",
            )

            write_reports(
                census_repository(left_root),
                left_output,
            )
            write_reports(
                census_repository(right_root),
                right_output,
            )

            comparison = compare_censuses(
                left_output,
                right_output,
            )

            summary = comparison["summary"]

            self.assertEqual(summary["shared_hash_count"], 1)
            self.assertEqual(summary["left_only_hash_count"], 1)
            self.assertEqual(summary["right_only_hash_count"], 1)
            self.assertEqual(summary["shared_left_file_count"], 1)
            self.assertEqual(summary["shared_right_file_count"], 1)


if __name__ == "__main__":
    unittest.main()
