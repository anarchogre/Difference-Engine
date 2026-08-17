import unittest

from ade.services.identity import compare_bytes


class ComparisonResultTests(unittest.TestCase):
    def test_raw_and_profile_equivalence_are_distinct(self) -> None:
        result = compare_bytes(
            b"alpha\r\nbeta\r\n",
            b"alpha\nbeta\n",
        )

        self.assertTrue(result.operation_completed)
        self.assertFalse(result.raw_equal)
        self.assertTrue(
            result.equivalent_under_profile
        )

        self.assertEqual(
            result.profile_id,
            "TEXT_LINE_ENDINGS",
        )
        self.assertEqual(
            result.profile_version,
            "1",
        )

    def test_non_equivalent_text_remains_distinct(self) -> None:
        result = compare_bytes(
            b"alpha\n",
            b"beta\n",
        )

        self.assertTrue(result.operation_completed)
        self.assertFalse(result.raw_equal)
        self.assertFalse(
            result.equivalent_under_profile
        )

    def test_invalid_input_prevents_equivalence_claim(self) -> None:
        result = compare_bytes(
            b"alpha\n",
            b"\xff\xfe\x00",
        )

        self.assertFalse(result.operation_completed)
        self.assertFalse(result.raw_equal)
        self.assertIsNone(
            result.equivalent_under_profile
        )
        self.assertTrue(result.diagnostics)

    def test_exact_bytes_are_raw_equal(self) -> None:
        result = compare_bytes(
            b"alpha\n",
            b"alpha\n",
        )

        self.assertTrue(result.operation_completed)
        self.assertTrue(result.raw_equal)
        self.assertTrue(
            result.equivalent_under_profile
        )


if __name__ == "__main__":
    unittest.main()
