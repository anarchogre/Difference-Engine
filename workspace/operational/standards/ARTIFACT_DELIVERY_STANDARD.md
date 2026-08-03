# Difference Engine Artifact Delivery Standard

Status: Candidate Standard
Authority: Operations

## Purpose

Standardize every repository artifact produced during implementation.

## Required Delivery Format

Every requested artifact shall be delivered in exactly this order:

1. Filename block
2. Artifact body block
3. Repository destination

No explanatory text shall be inserted between these sections unless explicitly requested.

## Content Requirements

Artifacts shall be complete.

Artifacts shall never contain placeholders when sufficient information exists to populate them.

Artifacts shall be immediately writable to disk without manual reconstruction.

Artifacts shall preserve provenance, deterministic formatting, and repository compatibility.

## Operational Constraint

When delivering implementation artifacts during chat:

- each output block shall fit within the smallest expected copy buffer;
- large artifacts shall be emitted as sequential continuation blocks;
- each continuation shall resume exactly where the previous block ended;
- no block shall require editing before use;
- artifact integrity takes precedence over conversational brevity.

## Default Artifact Response

Unless another format is explicitly requested, every artifact shall be emitted in this exact order:

Filename

    filename.md

Artifact Body

    <complete artifact body>

Repository Destination

    relative/repository/path/

The filename block shall appear directly above the artifact body block.


## Continuation Rule

If an artifact exceeds a single copy buffer:

- preserve exact ordering;
- continue exactly where the previous block ended;
- never summarize omitted content;
- never replace content with placeholders;
- terminate only after the complete artifact has been emitted.

## Operational Default

When the Difference Engine requests a repository artifact without specifying a format, this standard is the default contract.

## Prohibited Behavior

- incomplete artifacts;
- placeholder text;
- silent truncation;
- omitted repository destinations;
- explanatory prose inserted into artifact bodies;
- repository paths changed without evidence.

