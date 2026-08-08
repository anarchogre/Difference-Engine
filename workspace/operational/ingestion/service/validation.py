from dataclasses import dataclass


@dataclass(frozen=True)
class ValidationResult:
    passed: bool
    errors: list[str]


def validate(
    receipt,
    parsed,
    assets,
    references,
    queues,
):
    errors = []

    if not receipt.receipt_id:
        errors.append("missing_receipt_id")

    if isinstance(parsed, dict):
        if parsed.get("kind") != "conversation":
            errors.append("invalid_conversation_kind")

        turns = parsed.get("turns") or []

        if not turns:
            errors.append("no_conversation_turns")
        else:
            speakers = {
                turn.get("speaker")
                if isinstance(turn, dict)
                else getattr(turn, "speaker", None)
                for turn in turns
            }

            if "user" not in speakers:
                errors.append("missing_user_turn")

            if "assistant" not in speakers:
                errors.append("missing_assistant_turn")
    else:
        if not parsed.title:
            errors.append("missing_title")

    if not assets:
        errors.append("no_assets")

    if queues is None:
        errors.append("no_queue_candidates")

    return ValidationResult(
        passed=not errors,
        errors=errors,
    )
