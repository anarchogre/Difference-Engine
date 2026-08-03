"""
Deterministic cross-domain drift detection.
"""

from __future__ import annotations

import ast
import json
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class DriftFinding:
    domain: str
    classification: str
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
        "QueueEntry",
        "QueueState",
        "recover_queues",
    ),
    "ade/kernel/bootstrap_loader/verifier.py": (
        "verify",
        "write_reports",
        "main",
    ),
}


REQUIRED_GOVERNANCE = (
    Path("Repository/Governance/constitution.md"),
    Path("Repository/Governance/amendments.md"),
    Path("Repository/Governance/bootstrap.md"),
)


REQUIRED_OPERATIONAL = (
    Path(
        "workspace/operational/bootstrap/"
        "BOOTSTRAP_vNext.md"
    ),
    Path(
        "workspace/operational/current/"
        "ACTIVE_MISSION.md"
    ),
    Path(
        "workspace/operational/current/"
        "ACTIVE_TASK.md"
    ),
    Path(
        "workspace/operational/recovery/"
        "RECOVERY_SOP.md"
    ),
    Path(
        "workspace/operational/recovery/"
        "RECOVERY_CHECKLIST.md"
    ),
    Path(
        "workspace/operational/recovery/"
        "RECOVERY_VERIFIER_SPECIFICATION.md"
    ),
)


REQUIRED_LIBRARY = (
    Path(
        "workspace/operational/library/"
        "CANONICAL_LIBRARY_INDEX.json"
    ),
    Path(
        "workspace/operational/library/"
        "LIBRARY_GOVERNANCE.md"
    ),
    Path(
        "workspace/operational/library/"
        "UPLOAD_STANDARD.md"
    ),
    Path(
        "workspace/operational/library/"
        "ARTIFACT_LIFECYCLE.md"
    ),
)


REQUIRED_INTEGRATION = (
    Path(
        "workspace/operational/integration/"
        "FILE_LIBRARY_MANIFEST.json"
    ),
    Path(
        "workspace/operational/integration/"
        "PROJECT_CONFIGURATION_MANIFEST.json"
    ),
    Path(
        "workspace/operational/integration/"
        "EXTERNAL_VERIFICATION_STATUS.json"
    ),
)


def _finding(
    domain: str,
    classification: str,
    severity: str,
    subject: str,
    detail: str,
) -> DriftFinding:
    return DriftFinding(
        domain=domain,
        classification=classification,
        severity=severity,
        subject=subject,
        detail=detail,
    )


def _read_text(
    path: Path,
) -> str:
    return path.read_text(
        encoding="utf-8",
        errors="replace",
    )


def _read_json(
    path: Path,
) -> dict[str, Any]:
    return json.loads(
        _read_text(path)
    )


def _module_symbols(
    path: Path,
) -> set[str]:
    tree = ast.parse(
        _read_text(path)
    )

    return {
        node.name
        for node in tree.body
        if isinstance(
            node,
            (
                ast.FunctionDef,
                ast.AsyncFunctionDef,
                ast.ClassDef,
            ),
        )
    }


def _heading_value(
    path: Path,
    heading: str,
) -> str | None:
    lines = _read_text(path).splitlines()

    target = f"# {heading}".strip().lower()

    for index, line in enumerate(lines):
        if line.strip().lower() != target:
            continue

        for candidate in lines[index + 1:]:
            value = candidate.strip()

            if not value:
                continue

            if value.startswith("#"):
                return None

            return value

    return None


def _check_required_paths(
    repository_root: Path,
    paths: tuple[Path, ...],
    domain: str,
) -> list[DriftFinding]:
    findings: list[DriftFinding] = []

    for relative in paths:
        path = repository_root / relative

        if not path.is_file():
            findings.append(
                _finding(
                    domain=domain,
                    classification="missing",
                    severity="blocking",
                    subject=str(relative),
                    detail="Required artifact is missing.",
                )
            )

        elif path.stat().st_size == 0:
            findings.append(
                _finding(
                    domain=domain,
                    classification="invalid",
                    severity="blocking",
                    subject=str(relative),
                    detail="Required artifact is empty.",
                )
            )

    return findings


def _check_implementation(
    repository_root: Path,
) -> list[DriftFinding]:
    findings: list[DriftFinding] = []

    for relative, expected in EXPECTED_SYMBOLS.items():
        path = repository_root / relative

        if not path.is_file():
            findings.append(
                _finding(
                    domain="implementation",
                    classification="missing",
                    severity="blocking",
                    subject=relative,
                    detail="Required module is missing.",
                )
            )

            continue

        try:
            symbols = _module_symbols(path)
        except Exception as error:
            findings.append(
                _finding(
                    domain="implementation",
                    classification="invalid",
                    severity="blocking",
                    subject=relative,
                    detail=(
                        "Module parse failed: "
                        f"{type(error).__name__}: {error}"
                    ),
                )
            )

            continue

        for symbol in expected:
            if symbol not in symbols:
                findings.append(
                    _finding(
                        domain="implementation",
                        classification="unimplemented",
                        severity="blocking",
                        subject=relative,
                        detail=(
                            "Expected symbol is missing: "
                            f"{symbol}"
                        ),
                    )
                )

    return findings


def _check_active_state(
    repository_root: Path,
) -> list[DriftFinding]:
    findings: list[DriftFinding] = []

    mission_path = repository_root / (
        "workspace/operational/current/"
        "ACTIVE_MISSION.md"
    )

    task_path = repository_root / (
        "workspace/operational/current/"
        "ACTIVE_TASK.md"
    )

    if mission_path.is_file():
        mission = _heading_value(
            mission_path,
            "Active Mission",
        )

        if not mission:
            findings.append(
                _finding(
                    domain="active_state",
                    classification="invalid",
                    severity="blocking",
                    subject=str(
                        mission_path.relative_to(
                            repository_root
                        )
                    ),
                    detail="Active mission value is missing.",
                )
            )

    if task_path.is_file():
        task = _heading_value(
            task_path,
            "Active Task",
        )

        if not task:
            findings.append(
                _finding(
                    domain="active_state",
                    classification="invalid",
                    severity="blocking",
                    subject=str(
                        task_path.relative_to(
                            repository_root
                        )
                    ),
                    detail="Active task value is missing.",
                )
            )

    return findings


def _check_library(
    repository_root: Path,
) -> list[DriftFinding]:
    findings: list[DriftFinding] = []

    index_path = repository_root / (
        "workspace/operational/library/"
        "CANONICAL_LIBRARY_INDEX.json"
    )

    manifest_path = repository_root / (
        "workspace/operational/integration/"
        "FILE_LIBRARY_MANIFEST.json"
    )

    if not (
        index_path.is_file()
        and manifest_path.is_file()
    ):
        return findings

    try:
        index = _read_json(index_path)
        manifest = _read_json(manifest_path)
    except Exception as error:
        findings.append(
            _finding(
                domain="file_library",
                classification="invalid",
                severity="blocking",
                subject="library metadata",
                detail=(
                    "Library metadata parse failed: "
                    f"{type(error).__name__}: {error}"
                ),
            )
        )

        return findings

    indexed = index.get(
        "artifacts",
        [],
    )

    declared = manifest.get(
        "canonical_artifacts",
        [],
    )

    identifiers = [
        artifact.get("id")
        for artifact in indexed
    ]

    canonical_names = [
        artifact.get("canonical_name")
        for artifact in indexed
    ]

    declared_names = [
        artifact.get("name")
        for artifact in declared
    ]

    if len(identifiers) != len(set(identifiers)):
        findings.append(
            _finding(
                domain="file_library",
                classification="duplicated",
                severity="blocking",
                subject="artifact identifiers",
                detail="Duplicate stable identifiers detected.",
            )
        )

    if len(canonical_names) != len(
        set(canonical_names)
    ):
        findings.append(
            _finding(
                domain="file_library",
                classification="duplicated",
                severity="blocking",
                subject="canonical names",
                detail="Duplicate canonical names detected.",
            )
        )

    missing_from_index = sorted(
        set(declared_names)
        - set(canonical_names)
    )

    for name in missing_from_index:
        findings.append(
            _finding(
                domain="file_library",
                classification="unindexed",
                severity="warning",
                subject=name,
                detail=(
                    "Manifest artifact is absent from "
                    "the canonical index."
                ),
            )
        )

    required_unverified = [
        artifact.get("canonical_name")
        for artifact in indexed
        if artifact.get("required") is True
        and artifact.get("verified") is not True
    ]

    for name in required_unverified:
        findings.append(
            _finding(
                domain="file_library",
                classification="unverified",
                severity="blocking",
                subject=str(name),
                detail="Required artifact is not verified.",
            )
        )

    return findings


def _check_project_configuration(
    repository_root: Path,
) -> list[DriftFinding]:
    findings: list[DriftFinding] = []

    project_path = repository_root / (
        "workspace/operational/integration/"
        "PROJECT_CONFIGURATION_MANIFEST.json"
    )

    status_path = repository_root / (
        "workspace/operational/integration/"
        "EXTERNAL_VERIFICATION_STATUS.json"
    )

    if not (
        project_path.is_file()
        and status_path.is_file()
    ):
        return findings

    try:
        project = _read_json(project_path)
        status = _read_json(status_path)
    except Exception as error:
        findings.append(
            _finding(
                domain="project_configuration",
                classification="invalid",
                severity="blocking",
                subject="project integration metadata",
                detail=(
                    "Project metadata parse failed: "
                    f"{type(error).__name__}: {error}"
                ),
            )
        )

        return findings

    required_configuration = project.get(
        "required_configuration",
        {},
    )

    false_requirements = sorted(
        name
        for name, value
        in required_configuration.items()
        if value is not True
    )

    for name in false_requirements:
        findings.append(
            _finding(
                domain="project_configuration",
                classification="conflicting",
                severity="blocking",
                subject=name,
                detail=(
                    "Required project configuration "
                    "is not enabled."
                ),
            )
        )

    external = status.get(
        "project_configuration",
        {},
    )

    if external.get(
        "externally_verified"
    ) is not True:
        findings.append(
            _finding(
                domain="project_configuration",
                classification="unverified",
                severity="warning",
                subject="external verification",
                detail=(
                    "Project configuration lacks "
                    "external verification."
                ),
            )
        )

    return findings


def _check_queue(
    repository_root: Path,
) -> list[DriftFinding]:
    findings: list[DriftFinding] = []

    queue_root = repository_root / "queue"

    if not queue_root.is_dir():
        findings.append(
            _finding(
                domain="queue",
                classification="missing",
                severity="blocking",
                subject="queue",
                detail="Queue root is missing.",
            )
        )

        return findings

    queue_files = sorted(
        path
        for path in queue_root.rglob("*")
        if path.is_file()
    )

    if not queue_files:
        findings.append(
            _finding(
                domain="queue",
                classification="missing",
                severity="warning",
                subject="queue contents",
                detail="Queue root contains no artifacts.",
            )
        )

    return findings


def _check_specifications(
    repository_root: Path,
) -> list[DriftFinding]:
    findings: list[DriftFinding] = []

    specification_root = (
        repository_root / "specifications"
    )

    if not specification_root.is_dir():
        findings.append(
            _finding(
                domain="specifications",
                classification="missing",
                severity="blocking",
                subject="specifications",
                detail="Specification root is missing.",
            )
        )

    return findings


def _check_repository(
    repository_root: Path,
) -> list[DriftFinding]:
    findings: list[DriftFinding] = []

    git_root = repository_root / ".git"

    if not git_root.is_dir():
        findings.append(
            _finding(
                domain="repository",
                classification="missing",
                severity="blocking",
                subject=".git",
                detail="Git repository metadata is missing.",
            )
        )

        return findings

    try:
        result = subprocess.run(
            [
                "git",
                "status",
                "--short",
            ],
            cwd=repository_root,
            check=True,
            capture_output=True,
            text=True,
        )

        changed = [
            line
            for line in result.stdout.splitlines()
            if line.strip()
        ]

        if changed:
            findings.append(
                _finding(
                    domain="repository",
                    classification="working_state",
                    severity="informational",
                    subject="Git working tree",
                    detail=(
                        "Working tree contains "
                        f"{len(changed)} changed path(s)."
                    ),
                )
            )

    except Exception as error:
        findings.append(
            _finding(
                domain="repository",
                classification="unknown",
                severity="warning",
                subject="Git status",
                detail=(
                    "Git status failed: "
                    f"{type(error).__name__}: {error}"
                ),
            )
        )

    return findings


def detect(
    root: Path | None = None,
) -> list[DriftFinding]:
    repository_root = (
        root.resolve()
        if root is not None
        else Path.cwd().resolve()
    )

    findings: list[DriftFinding] = []

    findings.extend(
        _check_required_paths(
            repository_root,
            REQUIRED_GOVERNANCE,
            "governance",
        )
    )

    findings.extend(
        _check_required_paths(
            repository_root,
            REQUIRED_OPERATIONAL,
            "bootstrap",
        )
    )

    findings.extend(
        _check_required_paths(
            repository_root,
            REQUIRED_LIBRARY,
            "file_library",
        )
    )

    findings.extend(
        _check_required_paths(
            repository_root,
            REQUIRED_INTEGRATION,
            "project_configuration",
        )
    )

    findings.extend(
        _check_implementation(
            repository_root
        )
    )

    findings.extend(
        _check_active_state(
            repository_root
        )
    )

    findings.extend(
        _check_library(
            repository_root
        )
    )

    findings.extend(
        _check_project_configuration(
            repository_root
        )
    )

    findings.extend(
        _check_queue(
            repository_root
        )
    )

    findings.extend(
        _check_specifications(
            repository_root
        )
    )

    findings.extend(
        _check_repository(
            repository_root
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

    informational = [
        finding
        for finding in findings
        if finding.severity == "informational"
    ]

    domains: dict[str, int] = {}

    for finding in findings:
        domains[finding.domain] = (
            domains.get(
                finding.domain,
                0,
            )
            + 1
        )

    return {
        "total": len(findings),
        "blocking": len(blocking),
        "warnings": len(warnings),
        "informational": len(informational),
        "domains": domains,
        "findings": [
            {
                "domain": finding.domain,
                "classification": (
                    finding.classification
                ),
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
        output_root
        / "drift-detection.json"
    )

    text_path = (
        output_root
        / "drift-detection.txt"
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
        (
            "INFORMATIONAL="
            f"{summary['informational']}"
        ),
    ]

    for finding in summary["findings"]:
        lines.append(
            "|".join(
                (
                    finding["severity"],
                    finding["domain"],
                    finding["classification"],
                    finding["subject"],
                    finding["detail"],
                )
            )
        )

    text_path.write_text(
        "\n".join(lines)
        + "\n",
        encoding="utf-8",
    )


def main() -> int:
    findings = detect()
    summary = summarize(findings)

    output_root = Path(
        "workspace/operational/drift/runtime"
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
        "INFORMATIONAL="
        f"{summary['informational']}"
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
