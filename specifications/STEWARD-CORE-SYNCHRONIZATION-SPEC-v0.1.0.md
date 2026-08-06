# Steward Core Synchronization Specification v0.1.0

Status: CANDIDATE
Authority: NONE
Canonical status: NOT PROMOTED
Owner: Branch Ω — Pan Orchestration

## Purpose

Define deterministic synchronization among the Human, Head Steward, Branch Ω, Integration, Operations, Task Manager, and Branch Stewards.

Synchronization SHALL be deliberate, not constant.

## Authority Boundaries

Human:
Final project authority.

Head Steward:
Owns active attention, priority, process blockers, and summit readiness.
May halt defective process.
May not determine truth or perform canonical promotion.

Branch Ω:
Composes current project state, routes work, detects drift, and prepares checkpoints.
May not absorb branch authority or ratify its own output.

Integration:
Owns classification, acceptance, rejection, supersession, and canonical promotion records.

Operations:
Owns serialization, validation, event recording, execution evidence, and recovery tooling.

Task Manager:
Owns queues, dependencies, schedules, completion criteria, and operational blockers.

Branch Stewards:
Own branch-local state, unresolved questions, artifacts, and cross-branch obligations.

## State Objects

- `workspace/operational/state/STEWARD_CORE_STATE.json`
- `workspace/operational/state/PROJECT_STATE.md`
- `workspace/operational/state/TASK_MANAGER_STATE.json`
- `workspace/operational/state/branches/*.json`
- `workspace/operational/events/STEWARD_CORE_EVENTS.jsonl`

## Synchronization Triggers

Synchronize only after a material transition:

- repository HEAD change;
- validation pass or failure;
- blocker creation or resolution;
- mission or priority change;
- queue or dependency change;
- source disposition;
- promotion, rejection, or supersession;
- checkpoint or recovery;
- material terminology or governance change.

Chat activity alone is not a synchronization trigger.

## Transition Protocol

1. Read the current validated state.
2. Identify the field owner.
3. Stage the proposed transition.
4. Validate schema and authority.
5. Append an immutable event.
6. Write new state atomically.
7. Verify hashes and repository status.
8. Expose the resulting projection.

## Invariants

- No authority amplification.
- No silent overwrite.
- No chat-only canonical state.
- Unknown state remains unknown.
- Conflicts remain unresolved until reviewed.
- Events are append-only.
- Every mutable field has one declared owner.
- Promotion requires Integration.
- Evidence and provenance travel with transitions.

## Failure Handling

On validation, authority, or write failure:

- preserve the attempted transition;
- record the failure;
- leave prior valid state intact;
- create or update a blocker;
- do not promote;
- emit a recovery checkpoint.

## Recovery

Cold start SHALL reconstruct current project state from:

- validated repository state;
- event history;
- recorded hashes;
- latest recovery record.

Recovery SHALL NOT depend on conversational memory.

## Acceptance Gate

The specification passes only when:

- equivalent runs produce equivalent state;
- forced interruption resumes without state loss;
- stale state is detected;
- unauthorized mutation is rejected;
- conflicts do not silently resolve;
- promotion cannot occur without Integration;
- continuation succeeds without chat context.

## Promotion

Promotion requires:

1. Head Steward process review;
2. Integration classification;
3. Operations attack testing;
4. Task Manager registration;
5. recorded canonical promotion.

This document does not promote itself.
