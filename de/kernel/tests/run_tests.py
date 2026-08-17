"""
Repository-controlled deterministic test runner.
"""

from __future__ import annotations

import importlib
import inspect
import sys
import traceback
from pathlib import Path
from types import ModuleType
from typing import Callable


TEST_MODULES = (
    "ade.kernel.tests.test_bootstrap_loader",
)


def discover_tests(
    module: ModuleType,
) -> list[tuple[str, Callable[[], None]]]:
    tests: list[tuple[str, Callable[[], None]]] = []

    for name, value in inspect.getmembers(
        module,
        inspect.isfunction,
    ):
        if name.startswith("test_"):
            tests.append(
                (
                    f"{module.__name__}.{name}",
                    value,
                )
            )

    return tests


def run() -> int:
    passed = 0
    failed = 0
    discovered = 0

    for module_name in TEST_MODULES:
        try:
            module = importlib.import_module(
                module_name
            )
        except Exception:
            failed += 1
            print(
                f"IMPORT_FAIL {module_name}"
            )
            traceback.print_exc()
            continue

        tests = discover_tests(module)
        discovered += len(tests)

        for test_name, test in tests:
            try:
                test()
            except Exception:
                failed += 1
                print(
                    f"FAIL {test_name}"
                )
                traceback.print_exc()
            else:
                passed += 1
                print(
                    f"PASS {test_name}"
                )

    print(
        f"DISCOVERED={discovered}"
    )
    print(
        f"PASSED={passed}"
    )
    print(
        f"FAILED={failed}"
    )

    if discovered == 0:
        return 2

    if failed:
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(run())
