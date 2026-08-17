# Evidence-Producing Service Pattern

Version: 0.1
Status: Locked for Epoch II implementation
Authority: Operator decision
Promotion state: Operational architecture; not canonical doctrine

## Pattern

A repository service produces typed evidence.

It does not silently promote interpretation, authority, validity, identity,
equivalence, or canonical status.

Execution pattern:

Input
→ governed operation
→ typed result
→ preserved provenance
→ diagnostics
→ downstream interpretation

## Required Result Properties

Every evidence-producing result should expose, where applicable:

- operation identity;
- operation version;
- input identity;
- output identity;
- provenance;
- deterministic status;
- validation status;
- diagnostics;
- warnings;
- errors;
- declared losses;
- declared invariants.

## Separation of Responsibility

Producer responsibilities:

- execute the named operation;
- preserve evidence of execution;
- report transformation effects;
- report failures explicitly;
- avoid interpretation beyond the operation contract.

Consumer responsibilities:

- compare results;
- interpret evidence;
- apply governance;
- determine admissibility;
- propose promotion;
- authorize mutation.

## Initial Service Family

- Census produces CensusResult.
- Identity produces NormalizationResult and ComparisonResult.
- Parser produces ParseResult.
- Classifier produces ClassificationResult.
- Relationship construction produces RelationshipResult.
- Validator produces ValidationResult.

## Constraints

- Content equality does not establish artifact identity.
- Normalization does not establish semantic equivalence.
- Parsing does not establish correctness.
- Classification does not establish authority.
- Validation does not establish canonical status.
- Canonical promotion remains a separate governed operation.

## Lock

This pattern governs new Epoch II services unless repository evidence
demonstrates that a different contract is required.
