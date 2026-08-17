# Difference Engine Service Contract

Status: Candidate
Authority: Operations
Scope: Repository service layer

## Purpose

Define repository services independently from interface, shell, agent, or execution environment.

## Service Rule

A repository service shall provide:

- stable identity;
- defined inputs;
- defined outputs;
- deterministic behavior;
- explicit dependencies;
- explicit validation;
- explicit recovery behavior;
- implementation mapping.

Interfaces invoke services.

Interfaces never define canonical repository behavior.


## Required Service Metadata

Every service shall declare:

- service identifier;
- purpose;
- inputs;
- outputs;
- dependencies;
- recovery behavior;
- validation contract;
- implementation location;
- lifecycle state.

## Lifecycle

- proposed
- candidate
- implemented
- validated
- canonical
- superseded
- retired


## Construction Rule

A repository service shall not be implemented until its contract exists.

Implementation follows contract.

Contract follows governance.

Governance follows evidence.

## Interface Independence

A service may be invoked by:

- CLI;
- Python;
- automation;
- AI agent;
- future interfaces.

Invocation changes.

The service contract does not.

