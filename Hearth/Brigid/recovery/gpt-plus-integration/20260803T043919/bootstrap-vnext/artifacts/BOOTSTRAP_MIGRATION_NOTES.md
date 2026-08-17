# Bootstrap Migration Notes

## Migration Objective

Move from conversational bootstrap assumptions to deterministic repository-backed initialization.

## Canonical Active State

Create and maintain:

- `workspace/operational/current/ACTIVE_MISSION.md`
- `workspace/operational/current/ACTIVE_TASK.md`

These files are authoritative for mission and task recovery.

## Code Changes

Modified:

- `ade/kernel/bootstrap_loader/bootstrap.py`
- `ade/kernel/bootstrap_loader/mission.py`
- `ade/kernel/bootstrap_loader/task.py`

## Compatibility

The historical `load_bootstrap(root)` interface is preserved.

Artifact discovery now uses the canonical `discover_artifacts(root)` implementation.

## Validation

Verified:

- Python compilation;
- bootstrap imports;
- repository discovery;
- governance discovery;
- specification discovery;
- mission recovery;
- task recovery;
- execution-mode activation;
- package execution.

## Known Limitations

- No Git commit baseline exists.
- `pytest` is unavailable.
- File Library cannot yet be verified by repository tooling.
- queue recovery does not yet recover complete operational queue state.
- drift detection remains specification-only.
- ChatGPT Project verification remains external to the repository runtime.

## Migration Rule

Do not replace the repository-first architecture.

Integrate new ChatGPT capabilities as adapters and execution surfaces.

## Next Migration Block

Implement:

1. recovery SOP;
2. recovery checklist;
3. recovery verifier specification;
4. executable readiness report;
5. deterministic drift-report scaffold.
