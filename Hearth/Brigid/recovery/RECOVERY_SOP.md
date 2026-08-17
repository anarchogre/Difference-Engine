# Difference Engine Recovery SOP

Status: Candidate  
Authority: Operations  
Scope: Session and execution recovery

## Purpose

Recover the Difference Engine from repository state without relying on conversational memory.

## Recovery Sequence

1. Locate ChatGPT Project.
2. Load bootstrap.
3. Verify repository root.
4. Verify governance root.
5. Verify specification root.
6. Verify canonical bootstrap.
7. Verify active mission.
8. Verify active task.
9. Verify queue state.
10. Detect drift.
11. Report blockers.
12. Enter execution mode.
13. Resume active task.

## Project Verification

Confirm:

- correct ChatGPT Project;
- project instructions loaded;
- expected File Library available;
- branch identity known;
- current execution role known.

Project verification is external to repository runtime until a connector or manifest exists.

## Repository Verification

Confirm:

- repository root exists;
- expected top-level directories exist;
- governance artifacts exist;
- specification root exists;
- executable bootstrap imports;
- repository status is recorded.

## File Library Verification

Confirm:

- expected canonical recovery artifacts are present;
- artifact names match the Canonical Library Index;
- missing artifacts are reported;
- duplicate or superseded artifacts are not silently promoted.

## Canonical Artifact Verification

Verify:

- constitution;
- amendments;
- bootstrap;
- operational doctrine;
- operational reality;
- operator profile;
- active mission;
- active task;
- active queues;
- framework lock;
- current repository inventory.

## Drift Detection

Compare:

- governance against bootstrap;
- bootstrap against implementation;
- active state against queues;
- repository state against inventories;
- specifications against implementation;
- Project configuration against repository doctrine.

Classify drift as:

- missing;
- conflicting;
- duplicated;
- superseded;
- unimplemented;
- experimental;
- unknown.

## Mission Recovery

Canonical source:

`workspace/operational/current/ACTIVE_MISSION.md`

Recovery must fail if no active mission is found.

## Task Recovery

Canonical source:

`workspace/operational/current/ACTIVE_TASK.md`

Recovery must fail if no active task is found.

## Blocker Reporting

Report:

- missing initialization;
- implementation failure;
- missing canonical artifact;
- unresolved drift;
- unavailable dependency;
- uncommitted repository baseline;
- unsupported external verification.

## Execution Entry

Execution begins only when:

- initialization passes;
- mission is recovered;
- task is recovered;
- execution mode is active;
- no blocking validation failure remains.

## Output Requirements

Every recovery run emits:

- initialization report;
- artifact verification report;
- drift report;
- blocker report;
- active-state report;
- execution log.
