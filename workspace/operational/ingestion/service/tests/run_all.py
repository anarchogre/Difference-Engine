import importlib

TESTS = (
    "workspace.operational.ingestion.service.tests.test_intake",
    "workspace.operational.ingestion.service.tests.test_markdown_parser",
    "workspace.operational.ingestion.service.tests.test_pipeline",
    "workspace.operational.ingestion.service.tests.test_conversation_parser",
    "workspace.operational.ingestion.service.tests.test_chat_pipeline",
    "workspace.operational.ingestion.service.tests.test_batch",
    "workspace.operational.ingestion.service.tests.test_json_parser",
    "workspace.operational.ingestion.service.tests.test_json_validation",
    "workspace.operational.ingestion.service.tests.test_json_pipeline",
)


def main():
    for name in TESTS:
        module = importlib.import_module(name)
        module.main()

    print("ALL PASS")


if __name__ == "__main__":
    main()
