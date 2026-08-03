# Difference Engine File Library Artifact Lifecycle

## States

### Candidate

Uploaded or recovered but not validated.

### Canonical

Validated and designated as the authoritative recovery copy.

### Active

Operational artifact currently receiving updates.

### Snapshot

Point-in-time representation of repository or execution state.

### Historical

Preserved for provenance but not active.

### Superseded

Replaced by an identified successor.

### Experimental

Branch or exploratory artifact not integrated.

### Queued

Awaiting review, implementation, or promotion.

### Retired

No longer operationally required but preserved where provenance requires.

## Transitions

`candidate → canonical`

Requires validation and explicit promotion.

`candidate → experimental`

Used when evidence or authority is incomplete.

`canonical → superseded`

Requires a named replacement.

`active → snapshot`

Used when closing a task, session, phase, or repository state.

`snapshot → historical`

Used when no longer part of current recovery.

`queued → active`

Requires accepted execution scope.

`experimental → canonical`

Requires integration and validation.

## Invariants

- history is preserved;
- provenance is preserved;
- canonical identity is unique;
- supersession is explicit;
- deletion is exceptional;
- repository authority is unchanged.
