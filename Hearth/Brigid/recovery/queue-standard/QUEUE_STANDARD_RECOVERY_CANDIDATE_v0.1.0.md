# Queue Standard — Recovery Candidate

Status: Candidate
Version: 0.1.0
Canonical: No
Promotion: Not authorized

## Recovery Basis

The canonical-path file:

standards/v1/QUEUE_STANDARD_v1.0.md

was committed as a zero-byte file in recovered baseline commit 66528a2.
No earlier version exists on any available Git ref.

This document is a reconstruction from surviving pre-baseline sources.
It is not a restoration of lost wording and must not be represented as one.

## Purpose

Queues preserve work without confusing discovery, approval, execution,
completion, or canonical promotion.

## Recovered Lifecycle

SIQ
→ Review
→ IQ
→ MQ, when selected as mission work
→ Completed

Canonical promotion is a separate governed operation.

## Lifecycle Classes

### SIQ — Suggested Implementation Queue

Meaning:

- captured;
- awaiting review;
- not approved;
- not an implementation commitment.

Nothing in SIQ is discarded without review.

### Review

Meaning:

- under explicit evaluation;
- awaiting disposition.

Every reviewed proposal receives an explicit destination.

### IQ — Implementation Queue

Meaning:

- approved;
- actionable;
- not necessarily active.

### MQ — Mission Queue

Meaning:

- selected for mission execution;
- bounded by the active mission.

### Active

Meaning:

- presently executing.

Active state must be supported by current operational evidence.
A stale declaration does not override newer execution evidence.

### Completed

Meaning:

- execution obligations satisfied;
- preserved as historical state.

Completion does not itself authorize canonical promotion.

### Rejected

Meaning:

- reviewed and declined;
- preserved with rationale.

## Domain Classification

Domain and lifecycle are independent dimensions.

Examples of domains may include:

- ingestion;
- governance;
- research;
- tooling.

A domain path such as:

queue/ingestion/

does not establish whether a record is suggested, approved, active,
completed, deferred, blocked, or rejected.

## Required Record Fields

Each live queue record should declare:

- identifier;
- title;
- lifecycle;
- domain;
- priority;
- origin or provenance;
- purpose;
- acceptance or disposition criteria.

Legacy `Status:` fields may be read as evidence but must not be trusted
when their meaning is ambiguous or contradicted by newer evidence.

`Status: Queued` does not uniquely identify a lifecycle class.

## Classification Precedence

Classify records using this order:

1. current validated execution evidence;
2. explicit lifecycle metadata;
3. lifecycle-specific location;
4. recovered historical evidence;
5. filename convention.

Domain location alone is insufficient.

When evidence does not establish a lifecycle, classify the record as
unresolved and report degradation. Do not guess.

## Promotion Rules

Promotion requires review and an explicit disposition.

Promotion must preserve:

- original identifier;
- source provenance;
- prior lifecycle;
- decision rationale;
- promotion evidence.

Moving or reclassifying a record must not erase its history.

Canonical promotion remains distinct from queue completion and requires
its own governing authority.

## Recovery Rules

Queue recovery must:

- distinguish live state from recovery evidence, caches, test output,
  generated packages, and retired code;
- report unresolved records;
- detect stale lifecycle declarations;
- preserve contradictory evidence;
- avoid inferring lifecycle from domain folders;
- avoid silently rewriting queue records.

## Candidate Validation Requirements

Before promotion, validate this candidate against:

- surviving queue source documents;
- current repository topology;
- queue recovery implementation;
- verifier behavior;
- representative SIQ, IQ, active, completed, and unresolved records;
- forced cases where domain and lifecycle differ.

## Known Unresolved Questions

- Final canonical directory topology.
- Whether MQ is represented as a directory, mission record, or both.
- Formal ownership of lifecycle transitions.
- Required decision-record format.
- Relationship among Session, Promotion, Review, Primitive, Concept,
  and Tool queues.
- Whether these specialized queues are lifecycle classes, domains,
  processing stages, or projections.

These questions must not be silently resolved by this candidate.
