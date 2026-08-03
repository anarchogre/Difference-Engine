# Difference Engine File Library Governance

Status: Candidate  
Authority: Operations

## Purpose

Govern File Library artifacts used for recovery, coordination, and repository reconstruction.

## Authority

The repository remains canonical.

The File Library is governed recovery infrastructure.

A File Library artifact does not become canonical knowledge solely because it is uploaded.

## Required Metadata

Every governed artifact must have:

- stable identifier;
- canonical name;
- source upload name when different;
- classification;
- lifecycle state;
- required status;
- verification status;
- provenance.

## Lifecycle States

- `candidate`
- `canonical`
- `active`
- `snapshot`
- `historical`
- `superseded`
- `experimental`
- `queued`
- `retired`

## Promotion

Promotion requires:

1. provenance;
2. classification;
3. validation;
4. conflict review;
5. canonical destination;
6. explicit status change.

## Replacement

A replacement artifact must identify:

- artifact replaced;
- replacement artifact;
- effective date;
- reason;
- preserved history.

No artifact is silently overwritten.

## Duplication

Exact duplicates may be deduplicated after hash verification.

Near duplicates require comparison before removal.

Filename suffixes do not establish semantic difference.

## Recovery

Recovery uses the Canonical Library Index.

Unindexed files are not silently treated as canonical.

Missing required artifacts must be reported.

## Repository Synchronization

Canonical repository artifacts supersede File Library copies when conflict exists.

Conflicts must be recorded as drift.
