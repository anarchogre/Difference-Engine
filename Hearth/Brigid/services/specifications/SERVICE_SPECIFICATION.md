# Difference Engine Service Specification

Status: Candidate  
Authority: Operations

## Purpose

Define the canonical specification required before implementing any repository service.

## Every service shall define

- identifier;
- name;
- purpose;
- inputs;
- outputs;
- dependencies;
- validation;
- recovery behavior;
- implementation mapping;
- lifecycle state;
- governing standards.

A specification precedes implementation.

## Service Identity

Each service shall have:

- stable identifier;
- canonical name;
- version;
- authority;
- lifecycle state.

Service identity shall not depend on:

- interface;
- shell command;
- implementation language;
- execution environment.

## Contract Boundary

A service contract defines behavior.

A service specification defines requirements.

An implementation satisfies the specification.

An interface invokes the implementation.

## Required Sections

Every service specification shall include:

1. Identity
2. Purpose
3. Inputs
4. Outputs
5. Dependencies
6. Preconditions
7. Postconditions
8. Failure Conditions
9. Recovery Behavior
10. Validation Contract
11. Implementation Mapping
12. Interface Mapping
13. Lifecycle State
14. Provenance

## Determinism Rule

Given equivalent validated inputs and repository state, a service shall produce equivalent outputs or an explicit classified failure.

## Construction Grammar

A service specification shall be constructed in this order:

1. Strike the Root  
   Define the irreducible repository capability.

2. Lay Mortar  
   Establish contracts, standards, identifiers, validation, and recovery.

3. Build Stout  
   Create durable structures before optimization.

4. Forge  
   Produce the implementation.

5. Validate  
   Verify contract satisfaction.

6. Promote  
   Advance lifecycle only after successful validation.

Implementation is evidence of the specification.

The specification is never inferred from the implementation.

