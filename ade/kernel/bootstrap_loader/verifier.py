"""
Deterministic Difference Engine recovery verifier.
"""

from __future__ import annotations

import json
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .drift import detect as detect_drift
from .drift import summarize as summarize_drift
from .loader import initialize
from .queue import recover_queues


READY = "READY"
BLOCKED = "BLOCKED"
DEGRADED = "DEGRADED"
FAILED = "FAILED"


REQUIRED_PATHS = (
    Path("Repository/Governance/constitution.md"),
    Path("Repository/Governance/amendments.md"),
    Path("Repository/Governance/bootstrap.md"),
    Path("workspace/operational/bootstrap/BOOTSTRAP_vNext.md"),
    Path("workspace/operational/current/ACTIVE_MISSION.md"),
    Path("workspace/operational/current/ACTIVE_TASK.md"),
    Path("workspace/operational/recovery/RECOVERY_SOP.md"),
    Path("workspace/operational/recovery/RECOVERY_CHECKLIST.md"),
    Path(
        "workspace/operational/recovery/"
        "RECOVERY_VERIFIER_SPECIFICATION.md"
    ),
)


DEGRADED_CHECKS = (
    "file_library_verification",
    "project_configuration_verification",
    "queue_recovery",
    "git_baseline",
    "formal_test_runner",
    "drift_detection",
)


def _path_result(
    path: Path,
) -> dict[str, Any]:
    return {
        "path": str(path),
        "exists": path.exists(),
        "is_file": path.is_file(),
        "size": (
            path.stat().st_size
            if path.is_file()
            else None
        ),
    }


def verify(
    root: Path | None = None,
) -> tuple[int, dict[str, Any]]:
    repository_root = (
        root.resolve()
        if root is not None
        else Path.cwd().resolve()
    )

    blockers: list[str] = []
    warnings: list[str] = []
    verified_artifacts: list[dict[str, Any]] = []
    missing_artifacts: list[str] = []

    try:
        result = initialize()
    except Exception as error:
        payload = {
            "status": FAILED,
            "timestamp": datetime.now(
                timezone.utc
            ).isoformat(),
            "repository_root": str(repository_root),
            "blockers": [
                (
                    "BOOTSTRAP_INITIALIZATION_FAILED: "
                    f"{type(error).__name__}: {error}"
                )
            ],
            "warnings": [],
        }

        return 3, payload

    state = result.state
    artifacts = result.artifacts

    for path in REQUIRED_PATHS:
        resolved = repository_root / path
        item = _path_result(resolved)
        verified_artifacts.append(item)

        if not item["exists"]:
            missing_artifacts.append(str(path))

    if missing_artifacts:
        blockers.extend(
            f"MISSING_ARTIFACT: {path}"
            for path in missing_artifacts
        )

    if not state.repository_root.is_dir():
        blockers.append(
            "REPOSITORY_ROOT_MISSING"
        )

    if not state.governance_root.is_dir():
        blockers.append(
            "GOVERNANCE_ROOT_MISSING"
        )

    if not state.specification_root.is_dir():
        blockers.append(
            "SPECIFICATION_ROOT_MISSING"
        )

    if not state.mission:
        blockers.append(
            "MISSION_NOT_FOUND"
        )

    if not state.task:
        blockers.append(
            "TASK_NOT_FOUND"
        )

    if state.execution_mode != "Execution":
        blockers.append(
            "EXECUTION_MODE_INACTIVE"
        )

    git_head = repository_root / ".git/HEAD"
    git_refs = repository_root / ".git/refs/heads"

    has_commit = False

    if git_head.is_file():
        head_value = git_head.read_text(
            encoding="utf-8",
            errors="replace",
        ).strip()

        if head_value.startswith("ref: "):
            ref_path = (
                repository_root
                / ".git"
                / head_value[5:]
            )
            has_commit = ref_path.is_file()
        else:
            has_commit = bool(head_value)

    queue_state = recover_queues(
        repository_root
    )

    queue_recovery_ok = (
        len(queue_state.unknown) == 0
    )

    drift_summary = summarize_drift(
        detect_drift(repository_root)
    )

    drift_detection_ok = (
        drift_summary["blocking"] == 0
        and drift_summary["warnings"] == 0
    )

    formal_test_runner_path = (
        repository_root
        / "ade/kernel/tests/run_tests.py"
    )

    formal_test_runner_ok = (
        formal_test_runner_path.is_file()
        and formal_test_runner_path.stat().st_size > 0
    )

    external_status_path = (
        repository_root
        / "workspace/operational/integration/"
        "EXTERNAL_VERIFICATION_STATUS.json"
    )

    file_library_verification_ok = False
    project_configuration_verification_ok = False
    external_verification_status = {}

    if external_status_path.is_file():
        try:
            external_verification_status = json.loads(
                external_status_path.read_text(
                    encoding="utf-8",
                )
            )

            file_library_verification_ok = bool(
                external_verification_status
                .get("file_library", {})
                .get("externally_verified", False)
            )

            project_configuration_verification_ok = bool(
                external_verification_status
                .get("project_configuration", {})
                .get("externally_verified", False)
            )

        except Exception as error:
            warnings.append(
                "DEGRADED: external_verification_status_invalid"
            )

    library_index_path = (
        repository_root
        / "workspace/operational/library/"
        "CANONICAL_LIBRARY_INDEX.json"
    )

    library_governance_path = (
        repository_root
        / "workspace/operational/library/"
        "LIBRARY_GOVERNANCE.md"
    )

    upload_standard_path = (
        repository_root
        / "workspace/operational/library/"
        "UPLOAD_STANDARD.md"
    )

    artifact_lifecycle_path = (
        repository_root
        / "workspace/operational/library/"
        "ARTIFACT_LIFECYCLE.md"
    )

    library_governance_ok = False
    library_governance_status = {}

    try:
        if all(
            path.is_file()
            and path.stat().st_size > 0
            for path in (
                library_index_path,
                library_governance_path,
                upload_standard_path,
                artifact_lifecycle_path,
            )
        ):
            library_index = json.loads(
                library_index_path.read_text(
                    encoding="utf-8",
                )
            )

            library_artifacts = library_index.get(
                "artifacts",
                [],
            )

            identifiers = [
                artifact.get("id")
                for artifact in library_artifacts
            ]

            names = [
                artifact.get("canonical_name")
                for artifact in library_artifacts
            ]

            library_governance_ok = (
                bool(library_artifacts)
                and len(identifiers)
                == len(set(identifiers))
                and len(names)
                == len(set(names))
                and all(
                    artifact.get("verified") is True
                    for artifact in library_artifacts
                )
            )

            library_governance_status = {
                "artifacts": len(library_artifacts),
                "unique_identifiers": (
                    len(identifiers)
                    == len(set(identifiers))
                ),
                "unique_names": (
                    len(names)
                    == len(set(names))
                ),
                "verified": library_governance_ok,
            }

    except Exception as error:
        warnings.append(
            "DEGRADED: library_governance_invalid"
        )

        library_governance_status = {
            "verified": False,
            "error": (
                f"{type(error).__name__}: {error}"
            ),
        }

    degraded = {
        "file_library_verification": (
            file_library_verification_ok
        ),
        "project_configuration_verification": (
            project_configuration_verification_ok
        ),
        "library_governance": (
            library_governance_ok
        ),
        "queue_recovery": queue_recovery_ok,
        "git_baseline": has_commit,
        "formal_test_runner": formal_test_runner_ok,
        "drift_detection": drift_detection_ok,
    }

    for check in DEGRADED_CHECKS:
        if not degraded[check]:
            warnings.append(
                f"DEGRADED: {check}"
            )

    if blockers:
        status = BLOCKED
        exit_code = 1
    elif warnings:
        status = DEGRADED
        exit_code = 2
    else:
        status = READY
        exit_code = 0

    payload = {
        "status": status,
        "timestamp": datetime.now(
            timezone.utc
        ).isoformat(),
        "repository_root": str(
            state.repository_root
        ),
        "governance_root": str(
            state.governance_root
        ),
        "specification_root": str(
            state.specification_root
        ),
        "mission": state.mission,
        "task": state.task,
        "execution_mode": state.execution_mode,
        "artifacts": {
            "constitution": str(
                artifacts.constitution
            ),
            "amendments": str(
                artifacts.amendments
            ),
            "bootstrap": str(
                artifacts.bootstrap
            ),
        },
        "verified_artifacts": verified_artifacts,
        "missing_artifacts": missing_artifacts,
        "external_verification_status": (
            external_verification_status
        ),
        "library_governance_status": (
            library_governance_status
        ),
        "queue_state": {
            "suggested": len(
                queue_state.suggested
            ),
            "implementation": len(
                queue_state.implementation
            ),
            "active": len(
                queue_state.active
            ),
            "completed": len(
                queue_state.completed
            ),
            "deferred": len(
                queue_state.deferred
            ),
            "unknown": len(
                queue_state.unknown
            ),
        },
        "drift_summary": drift_summary,
        "degraded_checks": degraded,
        "blockers": blockers,
        "warnings": warnings,
    }

    return exit_code, payload


def write_reports(
    payload: dict[str, Any],
    output_root: Path,
) -> None:
    output_root.mkdir(
        parents=True,
        exist_ok=True,
    )

    readiness_json = (
        output_root / "readiness.json"
    )
    readiness_txt = (
        output_root / "readiness.txt"
    )
    drift_json = (
        output_root / "drift.json"
    )
    blockers_json = (
        output_root / "blockers.json"
    )
    verification_log = (
        output_root / "verification.log"
    )

    readiness_json.write_text(
        json.dumps(
            payload,
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )

    readiness_txt.write_text(
        "\n".join(
            (
                f"STATUS={payload['status']}",
                (
                    "REPOSITORY="
                    f"{payload.get('repository_root')}"
                ),
                (
                    "GOVERNANCE="
                    f"{payload.get('governance_root')}"
                ),
                (
                    "SPECIFICATIONS="
                    f"{payload.get('specification_root')}"
                ),
                (
                    "MISSION="
                    f"{payload.get('mission')}"
                ),
                (
                    "TASK="
                    f"{payload.get('task')}"
                ),
                (
                    "EXECUTION_MODE="
                    f"{payload.get('execution_mode')}"
                ),
                (
                    "BLOCKERS="
                    f"{len(payload.get('blockers', []))}"
                ),
                (
                    "WARNINGS="
                    f"{len(payload.get('warnings', []))}"
                ),
            )
        )
        + "\n",
        encoding="utf-8",
    )

    drift_json.write_text(
        json.dumps(
            {
                "status": payload["status"],
                "warnings": payload.get(
                    "warnings",
                    [],
                ),
                "degraded_checks": payload.get(
                    "degraded_checks",
                    {},
                ),
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )

    blockers_json.write_text(
        json.dumps(
            {
                "status": payload["status"],
                "blockers": payload.get(
                    "blockers",
                    [],
                ),
                "missing_artifacts": payload.get(
                    "missing_artifacts",
                    [],
                ),
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )

    verification_log.write_text(
        json.dumps(
            payload,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )


def main() -> int:
    output_root = Path(
        "workspace/operational/recovery/runtime"
    )

    exit_code, payload = verify()
    write_reports(
        payload,
        output_root,
    )

    print(
        f"STATUS={payload['status']}"
    )
    print(
        f"MISSION={payload.get('mission')}"
    )
    print(
        f"TASK={payload.get('task')}"
    )
    print(
        "EXECUTION_MODE="
        f"{payload.get('execution_mode')}"
    )
    print(
        "BLOCKERS="
        f"{len(payload.get('blockers', []))}"
    )
    print(
        "WARNINGS="
        f"{len(payload.get('warnings', []))}"
    )
    print(
        f"OUTPUT={output_root}"
    )

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
