# Recovery Verifier Specification

Status: Candidate  
Authority: Operations  
Component: ADE Bootstrap Loader

## Purpose

Provide deterministic verification that the Difference Engine can recover and resume execution from repository state.

## Inputs

Required:

- repository root;
- governance root;
- specification root;
- canonical bootstrap artifacts;
- active mission file;
- active task file.

Optional:

- File Library manifest;
- Project configuration manifest;
- queue manifest;
- repository inventory;
- framework lock.

## Outputs

The verifier must return:

- status;
- repository root;
- governance root;
- specification root;
- mission;
- task;
- execution mode;
- verified artifacts;
- missing artifacts;
- drift findings;
- blockers;
- warnings.

## Status Values

- `READY`
- `BLOCKED`
- `DEGRADED`
- `FAILED`

## Required Checks

### Repository

- root exists;
- required directories exist;
- repository is readable.

### Governance

- constitution exists;
- amendments exist;
- bootstrap exists.

### Specifications

- specification root exists;
- root is readable.

### Active State

- active mission exists;
- active task exists;
- both values are non-empty.

### Implementation

- bootstrap modules compile;
- bootstrap imports succeed;
- initialization completes;
- execution mode activates.

### Drift

- expected symbols match implemented symbols;
- active-state format matches parser support;
- required artifact paths match discovery rules.

## Blocking Conditions

- repository root missing;
- constitution missing;
- bootstrap missing;
- specification root missing;
- mission missing;
- task missing;
- bootstrap import failure;
- initialization exception;
- validation exception.

## Degraded Conditions

- File Library cannot be verified;
- Project configuration cannot be verified;
- queue state incomplete;
- Git baseline missing;
- formal test runner unavailable;
- drift detection incomplete.

## Exit Codes

- `0`: READY
- `1`: BLOCKED
- `2`: DEGRADED
- `3`: FAILED

## Artifact Contract

Each run creates:

- `readiness.json`
- `readiness.txt`
- `drift.json`
- `blockers.json`
- `verification.log`

## Implementation Location

Proposed module:

`ade/kernel/bootstrap_loader/verifier.py`

Proposed CLI:

`python -m ade.kernel.bootstrap_loader.verifier`
