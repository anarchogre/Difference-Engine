import unittest

from ade.services.identity import (
    normalize_text_line_endings,
)


class NormalizationResultTests(unittest.TestCase):
    def test_line_ending_equivalence_is_profile_relative(self) -> None:
        left = normalize_text_line_endings(
            b"alpha\r\nbeta\r\n"
        )
        right = normalize_text_line_endings(
            b"alpha\nbeta\n"
        )

        self.assertTrue(left.valid)
        self.assertTrue(right.valid)

        self.assertNotEqual(
            left.raw_sha256,
            right.raw_sha256,
        )
        self.assertEqual(
            left.normalized_sha256,
            right.normalized_sha256,
        )

        self.assertEqual(
            left.profile_id,
            "TEXT_LINE_ENDINGS",
        )
        self.assertEqual(
            left.profile_version,
            "1",
        )

    def test_invalid_utf8_fails_explicitly(self) -> None:
        result = normalize_text_line_endings(
            b"\xff\xfe\x00"
        )

        self.assertFalse(result.valid)
        self.assertIsNone(result.normalized_sha256)
        self.assertTrue(result.diagnostics)

    def test_trailing_whitespace_is_preserved(self) -> None:
        left = normalize_text_line_endings(
            b"alpha  \n"
        )
        right = normalize_text_line_endings(
            b"alpha\n"
        )

        self.assertNotEqual(
            left.normalized_sha256,
            right.normalized_sha256,
        )


if __name__ == "__main__":
    unittest.main()
