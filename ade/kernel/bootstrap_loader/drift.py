"""
Deterministic bootstrap drift detection.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class DriftFinding:
    category: str
    severity: str
    subject: str
    detail: str


EXPECTED_SYMBOLS = {
    "ade/kernel/bootstrap_loader/artifacts.py": (
        "BootstrapArtifacts",
        "discover_artifacts",
    ),
    "ade/kernel/bootstrap_loader/bootstrap.py": (
        "load_bootstrap",
    ),
    "ade/kernel/bootstrap_loader/mission.py": (
        "recover_mission",
    ),
    "ade/kernel/bootstrap_loader/task.py": (
        "recover_task",
    ),
    "ade/kernel/bootstrap_loader/queue.py": (
        "recover_queues",
        "QueueState",
        "QueueEntry",
    ),
    "ade/kernel/bootstrap_loader/verifier.py": (
        "verify",
        "write_reports",
        "main",
    ),
}


REQUIRED_ACTIVE_STATE = (
    Path(
        "workspace/operational/current/"
        "ACTIVE_MISSION.md"
    ),
    Path(
        "workspace/operational/current/"
        "ACTIVE_TASK.md"
    ),
)


REQUIRED_GOVERNANCE = (
    Path(
        "Repository/Governance/"
        "constitution.md"
    ),
    Path(
        "Repository/Governance/"
        "amendments.md"
    ),
    Path(
        "Repository/Governance/"
        "bootstrap.md"
    ),
)


def _module_symbols(
    path: Path,
) -> set[str]:
    import ast

    source = path.read_text(
        encoding="utf-8",
        errors="replace",
    )

    tree = ast.parse(source)

    symbols: set[str] = set()

    for node in tree.body:
        if isinstance(
            node,
            (
                ast.FunctionDef,
                ast.AsyncFunctionDef,
                ast.ClassDef,
            ),
        ):
            symbols.add(node.name)

    return symbols


def detect(
    root: Path | None = None,
) -> list[DriftFinding]:
    repository_root = (
        root.resolve()
        if root is not None
        else Path.cwd().resolve()
    )

    findings: list[DriftFinding] = []

    for relative, expected in EXPECTED_SYMBOLS.items():
        path = repository_root / relative

        if not path.is_file():
            findings.append(
                DriftFinding(
                    category="implementation",
                    severity="blocking",
                    subject=relative,
                    detail="Required module missing.",
                )
            )

            continue

        try:
            actual = _module_symbols(path)
        except Exception as error:
            findings.append(
                DriftFinding(
                    category="implementation",
                    severity="blocking",
                    subject=relative,
                    detail=(
                        "Module parsing failed: "
                        f"{type(error).__name__}: "
                        f"{error}"
                    ),
                )
            )

            continue

        for symbol in expected:
            if symbol not in actual:
                findings.append(
                    DriftFinding(
                        category="implementation",
                        severity="blocking",
                        subject=relative,
                        detail=(
                            "Expected symbol missing: "
                            f"{symbol}"
                        ),
                    )
                )

    for path in REQUIRED_ACTIVE_STATE:
        resolved = repository_root / path

        if not resolved.is_file():
            findings.append(
                DriftFinding(
                    category="active_state",
                    severity="blocking",
                    subject=str(path),
                    detail="Required active-state file missing.",
                )
            )

    for path in REQUIRED_GOVERNANCE:
        resolved = repository_root / path

        if not resolved.is_file():
            findings.append(
                DriftFinding(
                    category="governance",
                    severity="blocking",
                    subject=str(path),
                    detail="Required governance artifact missing.",
                )
            )

    bootstrap_vnext = repository_root / (
        "workspace/operational/bootstrap/"
        "BOOTSTRAP_vNext.md"
    )

    if not bootstrap_vnext.is_file():
        findings.append(
            DriftFinding(
                category="bootstrap",
                severity="warning",
                subject=str(
                    bootstrap_vnext.relative_to(
                        repository_root
                    )
                ),
                detail="Bootstrap vNext missing.",
            )
        )

    queue_root = repository_root / "queue"

    if not queue_root.is_dir():
        findings.append(
            DriftFinding(
                category="queue",
                severity="warning",
                subject="queue",
                detail="Queue root missing.",
            )
        )

    git_head = repository_root / ".git/HEAD"

    if not git_head.is_file():
        findings.append(
            DriftFinding(
                category="repository",
                severity="warning",
                subject=".git/HEAD",
                detail="Git repository metadata missing.",
            )
        )

    return findings


def summarize(
    findings: list[DriftFinding],
) -> dict[str, Any]:
    blocking = [
        finding
        for finding in findings
        if finding.severity == "blocking"
    ]

    warnings = [
        finding
        for finding in findings
        if finding.severity == "warning"
    ]

    return {
        "total": len(findings),
        "blocking": len(blocking),
        "warnings": len(warnings),
        "findings": [
            {
                "category": finding.category,
                "severity": finding.severity,
                "subject": finding.subject,
                "detail": finding.detail,
            }
            for finding in findings
        ],
    }


def write_report(
    summary: dict[str, Any],
    output_root: Path,
) -> None:
    output_root.mkdir(
        parents=True,
        exist_ok=True,
    )

    json_path = (
        output_root / "drift-detection.json"
    )
    text_path = (
        output_root / "drift-detection.txt"
    )

    json_path.write_text(
        json.dumps(
            summary,
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )

    lines = [
        f"TOTAL={summary['total']}",
        f"BLOCKING={summary['blocking']}",
        f"WARNINGS={summary['warnings']}",
    ]

    for finding in summary["findings"]:
        lines.append(
            "|".join(
                (
                    finding["severity"],
                    finding["category"],
                    finding["subject"],
                    finding["detail"],
                )
            )
        )

    text_path.write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    findings = detect()
    summary = summarize(findings)

    output_root = Path(
        "workspace/operational/recovery/runtime"
    )

    write_report(
        summary,
        output_root,
    )

    print(
        f"TOTAL={summary['total']}"
    )
    print(
        f"BLOCKING={summary['blocking']}"
    )
    print(
        f"WARNINGS={summary['warnings']}"
    )
    print(
        f"OUTPUT={output_root}"
    )

    if summary["blocking"]:
        return 1

    if summary["warnings"]:
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
