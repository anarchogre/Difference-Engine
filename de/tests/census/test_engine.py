import hashlib
import tempfile
import unittest
from pathlib import Path

from ade.services.census import census_repository


class CensusEngineTests(unittest.TestCase):
    def test_census_is_deterministic_and_excludes_git(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)

            (root / "docs").mkdir()
            (root / ".git").mkdir()

            (root / "docs" / "alpha.txt").write_text(
                "alpha",
                encoding="utf-8",
            )
            (root / "empty.md").write_bytes(b"")
            (root / ".git" / "ignored").write_text(
                "ignore",
                encoding="utf-8",
            )

            first = census_repository(root)
            second = census_repository(root)

            self.assertEqual(first, second)
            self.assertEqual(first["directory_count"], 1)
            self.assertEqual(first["file_count"], 2)

            paths = [
                record["path"]
                for record in first["files"]
            ]

            self.assertEqual(
                paths,
                ["docs/alpha.txt", "empty.md"],
            )

            alpha = first["files"][0]

            self.assertEqual(
                alpha["sha256"],
                hashlib.sha256(b"alpha").hexdigest(),
            )
            self.assertFalse(alpha["empty"])

            empty = first["files"][1]

            self.assertTrue(empty["empty"])
            self.assertEqual(empty["extension"], ".md")


if __name__ == "__main__":
    unittest.main()
