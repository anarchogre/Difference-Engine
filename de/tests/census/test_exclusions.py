import tempfile
import unittest
from pathlib import Path

from ade.services.census import census_repository


class CensusExclusionTests(unittest.TestCase):
    def test_relative_prefix_is_excluded(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)

            (root / "source").mkdir()
            (root / "generated" / "nested").mkdir(parents=True)

            (root / "source" / "kept.txt").write_text(
                "kept",
                encoding="utf-8",
            )
            (root / "generated" / "report.json").write_text(
                "{}",
                encoding="utf-8",
            )
            (root / "generated" / "nested" / "more.json").write_text(
                "{}",
                encoding="utf-8",
            )

            census = census_repository(
                root,
                exclude=["generated"],
            )

            self.assertEqual(
                [item["path"] for item in census["files"]],
                ["source/kept.txt"],
            )
            self.assertEqual(
                [item["path"] for item in census["directories"]],
                ["source"],
            )
            self.assertEqual(
                census["excluded"],
                ["generated"],
            )

    def test_absolute_exclusion_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)

            with self.assertRaises(ValueError):
                census_repository(
                    root,
                    exclude=[root / "generated"],
                )


if __name__ == "__main__":
    unittest.main()
