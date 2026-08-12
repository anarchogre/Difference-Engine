from types import SimpleNamespace

from ..validation import validate


def main():
    receipt = SimpleNamespace(receipt_id="TEST-JSON-VALIDATION")

    valid = validate(
        receipt,
        {
            "kind": "json",
            "document": {
                "alpha": 1,
            },
        },
        [],
        [],
        [],
    )
    assert valid.passed is True
    assert valid.errors == []

    missing_document = validate(
        receipt,
        {
            "kind": "json",
        },
        [],
        [],
        [],
    )
    assert missing_document.passed is False
    assert "missing_json_document" in missing_document.errors

    # Preserve the pre-existing unknown-dict behavior.
    unknown = validate(
        receipt,
        {
            "kind": "not-a-supported-kind",
        },
        [],
        [],
        [],
    )
    assert unknown.passed is False
    assert "invalid_conversation_kind" in unknown.errors
    assert "no_conversation_turns" in unknown.errors
    assert "no_assets" in unknown.errors

    print("PASS")


if __name__ == "__main__":
    main()
