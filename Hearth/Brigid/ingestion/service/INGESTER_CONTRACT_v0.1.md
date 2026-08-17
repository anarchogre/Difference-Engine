# Ingester Contract

Version: 0.1
Status: Recovered Implementation Contract
Source: FILE_LIBRARY_UPLOADS/99_UTILITIES/Ingestion

## Mission

Transform source artifacts into deterministic, provenance-preserving, repository-ready evidence without interpretation.

## First Operation

Every observed source receives an immutable ingestion receipt before parsing, relocation, or transformation.

## Pipeline

Receipt
→ Artifact Intake
→ Structural Parsing
→ Asset Extraction
→ Reference Extraction
→ Queue Candidate Generation
→ Validation
→ Repository Mapping
→ Human Review
→ Canonical Promotion
→ Publication
→ Repository Index Update

## Required Objects

- Ingestion Receipt
- Artifact Record
- Provenance Record
- Conversation Artifact
- Asset Record
- Reference Collection
- Queue Candidates
- Validation Record
- Ingestion Report
- Output Package

## Invariants

- Preserve original source unchanged.
- Preserve complete provenance.
- Preserve ordering.
- Parser observes; parser does not interpret.
- References remain unresolved until repository mapping.
- Queue assignments remain provisional.
- Validation never modifies artifacts.
- Promotion requires human review.
- Derived products are separate artifacts.
- Assets never replace parent artifacts.
- Every stage records its result.
- Failures preserve source and permit restart.
- No stage assumes authority beyond its responsibility.

## Output Package

artifact-id/
├── source/
├── metadata/
├── structure/
├── queues/
├── provenance/
└── reports/

## Acceptance Test

Ingest one modern Linux-heavy project conversation.

The test passes only when:

- receipt exists;
- complete source is preserved;
- turns and commands are extracted;
- reusable Linux guidance is emitted as candidate artifacts;
- provenance traverses to exact source messages;
- validation passes;
- output package is deterministic;
- interruption recovery succeeds;
- no canonical promotion occurs without review.
