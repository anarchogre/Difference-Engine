import importlib

TESTS = (
    "ade.services.ingestion.tests.test_intake",
    "ade.services.ingestion.tests.test_markdown_parser",
    "ade.services.ingestion.tests.test_pipeline",
    "ade.services.ingestion.tests.test_conversation_parser",
    "ade.services.ingestion.tests.test_chat_pipeline",
    "ade.services.ingestion.tests.test_batch",
)


def main():
    for name in TESTS:
        module = importlib.import_module(name)
        module.main()

    print("ALL PASS")


if __name__ == "__main__":
    main()
