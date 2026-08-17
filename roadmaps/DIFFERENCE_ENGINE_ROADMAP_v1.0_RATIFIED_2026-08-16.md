# Difference Engine — Current Roadmap v1.0
## Ratified Execution Baseline: Milestones, Sprints, Task Blocks

**Date:** 2026-08-16  
**Status:** RATIFIED / LOCKED CURRENT ROADMAP v1.0  
**Supersedes:** `DIFFERENCE_ENGINE_ROADMAP_CURRENT_2026-08-16.md` hash `355f7cc864268fecf32202ee99433cb0f4e2f8f33a3b18304eda739367d2ab1f`  
**Authority:** Operator ratification effective 2026-08-16. This file is the sole current roadmap baseline. New ideas enter SIQ unless required to execute an already-ratified block.  
**Purpose:** One current execution line with dependency order, proof gates, task blocks, and preserved future direction.

---

# 1. Execution Model

A **Sprint** is not a calendar interval. It is a bounded work package that ends in evidence.

A **Task Block** is the smallest roadmap unit worth tracking. Each block must have:

- an explicit input state;
- one bounded objective;
- a durable output or state change;
- a validation condition;
- provenance/evidence;
- a next cursor.

A **Milestone** is complete only when its proof gate passes.

Normal flow:

```text
ROADMAP
    ↓
SPRINT
    ↓
TASK BLOCK
    ↓
EVIDENCE
    ↓
VALIDATION
    ↓
PROMOTION / NEXT BLOCK
```

New discoveries that are not required by the active block:

```text
Conversation
    ↓
SIQ — Suggested Implementation Queue
    ↓
Review
    ↓
IQ — Implementation Queue
    ↓
Mission / Sprint
    ↓
Complete
```

Core SIQ rule:

> Nothing gets lost. Nothing gets implemented accidentally.

Only one exact next operation should be active during Grindstone execution unless reality requires parallelism.

---

# 2. North Star — The Golden Orb

The long-range end state is **The Golden Orb**: governed recursive learning and recursive improvement.

The path is deliberately indirect.

```text
durable memory
→ recovery
→ provenance
→ validation
→ operator model
→ governed capability resolution
→ Pan
→ fleet
→ continuous observation / testing
→ learning from outcomes
→ proposing improvements
→ validating improvements
→ bounded implementation
→ recursive improvement
```

The target is not unconstrained self-modification.

The target is a system that can increasingly learn, model, test, rebuild, and improve the machinery that performs those same functions while remaining inside authority, evidence, recovery, and non-regression constraints.

The Golden Orb is a direction and proof ladder, not permission to skip intermediate construction.

Operator provenance note for the eventual event horizon:

> **“You OWE me, fucker.”**

---

# 3. Native Architecture Language — Governing Decision Rules

The sayings are architecture. They are not decoration.

Known recovered primitives are seed entries only; the conversation corpus remains the source for full recovery.

## 3.1 More Birds / BRICK

> “Two birds with one stone? Fuck that. More birds.”

Recovered architectural meaning:

> One stable primitive should yield multiple legitimate capabilities, views, or consequences without multiplying truth, authority, maintenance, or ceremony.

**More Birds outta More Birds** is the recursive form: one multifunction primitive creates outputs that themselves enable additional multifunction primitives.

`BRICK` is mapped to **More Birds**. No acronym expansion is promoted until recovered.

## 3.2 Mortar

Relationships that make durable pieces usable together:

- provenance;
- dependencies;
- constraints;
- interfaces;
- rationale;
- queues;
- recovery state;
- continuity.

## 3.3 Molasses

Deliberate inevitability: proceed slowly enough that dependency order, evidence, and validation remain intact; do not confuse speed with progress.

## 3.4 Blacksmith / Forge / tools-to-build-tools

Build capability that builds further capability. Prefer machinery that reduces future operator work.

## 3.5 Legs for Legs

A capability that enables another capability to operate, propagate, recover, or create still more capability.

## 3.6 Strike the Root

Repair the primitive or control layer producing repeated symptoms rather than repeatedly treating leaves.

## 3.7 No validation without validation

A claimed pass is not a pass until the thing that matters has actually been tested with sufficient evidence.

## 3.8 Elegance Results

Elegance is an outcome of correct reduction, composition, reuse, and recursion. It is not a design objective that overrides reality.

## 3.9 Additional durable sayings to preserve during recovery

Known sayings requiring exact lineage/provenance recovery include:

- “Always build for the future.”
- “Never tomorrow what we can do like right now.”
- “Reduce until there’s no other choice; multifunction first; recursion next; elegance follows.”
- “It’s still all about Rowan.”
- “DE is a cage for AI.”
- “Not for sale of ownership/control.”

The **System Language** sprint must recover every architectural saying from the conversations, preserve exact wording and provenance, distinguish slogan from architecture, and record implementation consequences.

---

# 4. Milestone Map

| Milestone | Name | Completion Proof |
|---|---|---|
| M0 | Control Plane + System Language + Repository Lock | one bootstrap, one roadmap, language registry seeded, historical material accounted, consolidated repo recoverable |
| M1 | Firmware → AirLLM → Ingestion | AirLLM result is reproducible; ingestion recovers conversation knowledge with provenance |
| M2 | Storage Recovery + AirBook Conversion | Brandon capability preserved under Linux; macOS removed only after validation; Forge space reclaimed |
| M3 | Research Annex + Full Corpus | research annex sized, acquired, provenance-preserved, ingested, retrievable by Pan |
| M4 | DE Layer over Linux + Continuous Security | DE layer runs above Linux; security plane continuously tests and produces evidence |
| M5 | Pan + OP_PROF/OP_REAL + Panes | operator-aware Pan and one dormant capability resolve into a useful JIT Pane and tear down cleanly |
| M6 | Fleet + Phylactery | nodes can leave/rejoin; recovery placement adapts; complete Phylactery invariant survives catastrophe drill |
| M7 | Governed Income Block | at least one auditable legitimate income workflow is exercised without bypassing governance |
| M8 | Golden Orb Learning Ladder | closed evidence-bearing improvement loop demonstrated without bypassing authority/non-regression |
| M9 | IP / Patent Evaluation | provable implemented subject matter mapped to provenance before any filing decision |

---

# 5. M0 — Control Plane, System Language, Repository Lock

## Sprint 0.1 — System Language Recovery

**Objective:** Build one canonical machine-readable vocabulary from recovered project language; render the human glossary from it.

### TB-0.1.1 — Recover existing language artifacts

Search bounded repository/corpus surfaces for:

- vocabularies;
- glossaries;
- lexicons;
- aliases;
- naming maps;
- terminology files;
- architecture sayings;
- statuettes;
- historical names.

**Output:** source manifest with hashes and provenance.

**Pass:** every recovered source is accounted for; no source is silently overwritten.

### TB-0.1.2 — Recover architectural sayings from conversations

Recover exact wording, first-known context, later refinements, and architectural consequence for all operator sayings.

Seed list includes:

- More Birds / BRICK;
- More Birds outta More Birds;
- Mortar;
- Molasses;
- Inevitable;
- Blacksmith / Forge;
- tools-to-build-tools;
- Legs for Legs;
- Strike the Root;
- No validation without validation;
- Elegance Results;
- Always build for the future;
- Never tomorrow what we can do like right now;
- Reduce until there’s no other choice;
- It’s still all about Rowan;
- DE is a cage for AI;
- Not for sale of ownership/control.

**Pass:** phrases are source-backed and separated into:
`ARCHITECTURE / GOVERNANCE / OPERATOR_PREFERENCE / HISTORICAL / UNRESOLVED`.

### TB-0.1.3 — Build System Language registry

The registry is canonical. The glossary is generated from it.

Minimum fields:

```text
term identity
canonical term
literal/operator wording
kind/status
meaning
architectural role
aliases / historical names
relationships
provenance
supersession
confidence / uncertainty
implementation consequence
```

Required seed concepts include:

```text
DE
Pan
Pane / Panes
Phylactery
H / recovery nucleus
More Birds
BRICK
Mortar
Molasses
Inevitable
Blacksmith
Forge
Legs for Legs
Strike the Root
Elegance Results
Memory Palace
Simonides
Facet
Statuette
SIQ
IQ
OP_PROF
OP_REAL
Projection
Dormant Capability
Capability Resolution Contract
Flat Pack [historical/candidate terminology]
Warden
Bursar
Black Ice
Ice-9
Decoy
Honeypot
Golden Orb
```

Known alias/provenance mappings to preserve:

```text
ADE → historical alias for DE
Qwen / Quinn → historical/provenance names inside current Pan lineage
Flat Pack → research lineage; do not force as universal package format
```

### TB-0.1.4 — Generate human glossary

Render a readable glossary from the registry. No second hand-maintained source of truth.

**Milestone contribution:** system language becomes a deterministic aid for later corpus reduction and retrieval.

---

## Sprint 0.2 — Historical Roadmap Reduction

Current evidence:

```text
ROADMAP_COVERAGE_AUDIT=PASS
HISTORICAL_SOURCES=72
CURRENT_BLOCKS=86
HISTORICAL_BLOCKS=1064
CANDIDATE_BLOCKS=1063
```

The initial raw-similarity filter is insufficient; do not manually review 1,063 blocks one by one.

### TB-0.2.1 — Family-collapse historical roadmap blocks

Use:

- source chronology;
- recovered system language;
- native terminology;
- shared nouns/verbs/dependencies;
- exact duplicates;
- supersession chains;
- research/future-work markers.

Produce semantic/provenance families.

### TB-0.2.2 — Classify surviving families

Allowed dispositions:

```text
ABSORB
RESEARCH_FUTURE_WORK
CONTEXT_PROVENANCE
OBSOLETE
HISTORICAL_ONLY
```

No deletion before every family has a disposition.

### TB-0.2.3 — Reconcile omissions into this roadmap

Only unique, still-valid execution commitments enter the current roadmap.

Research and speculative future work remain outside active execution but are preserved.

### TB-0.2.4 — Retire historical roadmap control-plane status

After coverage closes:

```text
ACTIVE_ROADMAP_COUNT=1
```

Historical roadmaps remain provenance/history, not competing current authority.

---

## Sprint 0.3 — Bootstrap Coverage Closure

### TB-0.3.1

Finish the archived-bootstrap coverage audit against LTCK v1.2.3.

### TB-0.3.2

Classify surviving bootstrap-only material:

```text
ABSORB
ROADMAP
CONTEXT
OBSOLETE
HISTORICAL_ONLY
```

### TB-0.3.3

If actual initialization law is missing, amend forward to a new LTCK version. Do not mutate v1.2.3 invisibly.

**Pass:** `ACTIVE_BOOTSTRAP_COUNT=1`.

---

## Sprint 0.4 — Whole-System Consolidation

### TB-0.4.1 — Finish capability ownership

Place implementation with the capability it implements:

```text
ingestion machinery → ingestion
Pan interface/runtime → Pan
recovery tooling → recovery
evidence/census tooling → evidence/operations
generic utilities only → scripts/
```

### TB-0.4.2 — Repair paths/callers

No compatibility alias remains merely because it once existed.

### TB-0.4.3 — Validate surviving capabilities

Each moved/reduced capability receives a runnable validation or explicit `UNVERIFIED` status.

### TB-0.4.4 — Post-consolidation census

Diff against the sealed pre-consolidation census and produce compact receipts.

### TB-0.4.5 — Git boundary

Create one coherent local commit only after classification/validation.

Then:

- connect new **private** remote;
- push;
- verify remote state;
- do not commit secrets, model weights, caches, raw bulk evidence, or external preserved source payloads.

### TB-0.4.6 — Offline recovery bundle

Create and verify an offline recovery bundle before firmware write.

**M0 PASS:** repository state is coherent, source/recovery lineage is preserved, control plane is singular, and catastrophic recovery is possible.

---

# 6. M1 — Firmware → AirLLM → Ingestion

## Sprint 1.1 — Firmware Recovery Gate

### TB-1.1.1

Verify:

- exact NVMe/controller identity;
- current firmware;
- candidate firmware identity;
- power/recovery prerequisites;
- offline recovery bundle;
- rollback/recovery procedure where technically possible.

### TB-1.1.2

Apply the validated BC501 firmware path.

### TB-1.1.3

Capture post-write identity and storage health.

**Pass:** firmware state is known and Forge remains recoverable.

---

## Sprint 1.2 — AirLLM Re-Proof

### TB-1.2.1

Re-run the AirLLM workload under the new storage reality.

### TB-1.2.2

Capture reproducible:

- model identity;
- configuration;
- launch command;
- timing;
- storage behavior;
- result;
- failures.

### TB-1.2.3

Compare against the sealed pre-firmware NVMe evidence.

**Pass:** AirLLM has a reproducible PASS or a bounded, evidence-backed failure.

---

## Sprint 1.3 — AirLLM Bulk Reduction

### TB-1.3.1

Account for Hugging Face cache, shards, venv, pip cache, raw trace forests, and duplicate payload.

### TB-1.3.2

For each bulk class determine:

```text
RECONSTRUCTABLE?
UNIQUE?
REQUIRED_FOR_CURRENT_RUNTIME?
PROVENANCE_PRESERVED?
SAFE_TO_DELETE?
```

### TB-1.3.3

Delete only proven-disposable bulk and record freed space.

---

## Sprint 1.4 — Finish Ingestion Pipeline

### TB-1.4.1

Recover remaining unfinished ingestion stages before recreation.

### TB-1.4.2

Complete deterministic discovery, parsing, identity, deduplication, provenance, receipts, interruption recovery, and replay.

### TB-1.4.3

Integrate conversation exports as first-class sources.

---

## Sprint 1.5 — Proof Gate A: Conversation Recovery

Required demonstration:

> Given the exported Difference Engine conversation corpus and governed repository state, recover a previously discussed project concept, decision, dependency, reversal, saying, or queue item with provenance without depending on chat memory or manual archaeology.

Test targets should include difficult recovered concepts such as:

- SIQ;
- statuettes;
- Life Companion → Companion Profile → OP_PROF;
- More Birds / BRICK;
- Warden/Bursar/Ice lineage.

**Pass:** repeatable recovery in practical time, with source provenance and interruption-safe state.

**M1 PASS:** the system built to stop losing the conversations actually does so.

---

# 7. M2 — Storage Recovery + AirBook Conversion

## Sprint 2.1 — AirBook Preservation Inventory

### TB-2.1.1

Inventory Brandon's:

- music projects;
- media;
- personal documents;
- photography assets;
- required applications/workflows.

### TB-2.1.2

Establish hashes/counts/size before destructive changes.

---

## Sprint 2.2 — Linux on AirBook

### TB-2.2.1

Allocate Linux space while preserving macOS until validation.

### TB-2.2.2

Install and verify Linux.

### TB-2.2.3

Copy Brandon's data from macOS to Linux on the same AirBook.

---

## Sprint 2.3 — Capability Replacement

### TB-2.3.1 — Music

Establish REAPER-centered Linux studio capability and open/recover representative real projects/media.

### TB-2.3.2 — Photography

Establish a usable Linux photography workflow and verify representative assets.

### TB-2.3.3

Document novice-friendly start/recover/session-finish operations.

---

## Sprint 2.4 — Reclaim Space

Only after validation:

- remove/consume the macOS partition;
- reclaim its space;
- remove verified Brandon duplicates from Forge;
- record actual Forge space recovered.

**M2 PASS:** Brandon's capabilities survive under Linux and Forge has reclaimed the duplicate burden.

---

# 8. M3 — Research Annex + Full Corpus

## Sprint 3.1 — Annex Capacity

### TB-3.1.1

Measure free storage after AirLLM and Brandon reclamation.

### TB-3.1.2

Set an explicit research-annex GB budget from measured reality.

### TB-3.1.3

Finalize annex structure, source identity, and preservation rules.

---

## Sprint 3.2 — Research Acquisition

Prioritize `~/Downloads/DE*`, then wider bounded surfaces.

Acquire/download queued research while preserving:

- source;
- title;
- authors;
- date;
- URL/identifier where available;
- content hash;
- acquisition time;
- classification;
- provenance.

---

## Sprint 3.3 — Full Ingestion

Ingest:

- research corpus;
- conversation corpus;
- surviving project evidence;
- roadmap/research future-work material.

Research evidence remains distinguishable from canonical knowledge.

---

## Sprint 3.4 — Pan Corpus Proof

Pan must be able to retrieve:

- source evidence;
- conflicting evidence;
- historical lineage;
- current controlling state;
- uncertainty.

**M3 PASS:** the corpus is not merely stored; it is recoverable and provenance-bearing.

---

# 9. M4 — Difference Engine Layer over Linux + Continuous Security

Linux is substrate first. DE is not initially a new Linux distribution.

Security is co-developed with the layer. It is not a later hardening pass.

## Sprint 4.1 — Minimal DE Layer

Build the smallest coherent layer providing:

- governed durable state;
- policy evaluation;
- OP_PROF / OP_REAL access;
- Pan orchestration hooks;
- capability registry/resolution;
- validation receipts;
- recovery hooks;
- provenance.

**Pass:** one real capability executes through the DE layer rather than beside it.

---

## Sprint 4.2 — Warden + Bursar

### Warden

Recovered responsibility includes defensive observation and evidence:

- tamper evidence;
- anomaly/intrusion observation;
- decoy/honeypot telemetry;
- containment signaling;
- preserved attack/security evidence.

### Bursar

Recovered responsibility includes custody/release accounting:

- secrets;
- credentials;
- key hierarchy;
- rotation;
- revocation;
- recovery shares;
- cryptographic-erasure authority where governed.

### TB-4.2.1

Recover exact historical definitions and boundaries from conversations before implementation hardens them.

### TB-4.2.2

Define Warden/Bursar interface boundaries without merging observation authority into custody authority.

### TB-4.2.3

Implement the smallest measurable Warden and Bursar capabilities.

---

## Sprint 4.3 — Black Ice / Ice-9 / Decoys / Honeypots

### Black Ice

Passive defensive denial/deception: make unauthorized interaction unrewarding while remaining defensive.

### Ice-9

Exceptional irreversible containment/revocation boundary after validated compromise. Exact historical semantics must be recovered before promotion.

### TB-4.3.1

Recover exact DE-specific definitions of Black Ice, Ice-9, decoys, and honeypots.

### TB-4.3.2

Build bounded defensive deception capability:

- decoy services/data where appropriate;
- honeypot telemetry;
- honey artifacts/tokens where appropriate;
- isolation;
- evidence capture;
- no uncontrolled outward retaliation.

### TB-4.3.3

Define explicit containment gates for irreversible actions.

---

## Sprint 4.4 — Penetration/Security Test Capability

Do **not** clone Kali as an operating environment.

Build a curated DE security-testing capability from the tools actually needed.

### TB-4.4.1

Create tool capability inventory by purpose:

- attack-surface discovery;
- network/service inspection;
- vulnerability assessment;
- web/application testing;
- credential/authentication testing;
- packet/protocol observation;
- configuration auditing;
- static/dynamic code analysis where applicable;
- fuzzing where applicable;
- exploitation proof only in owned/authorized test environments.

### TB-4.4.2

Package/document each selected tool as a governed dormant capability where practical.

### TB-4.4.3

Create test targets/labs that cannot be confused with unauthorized external targets.

---

## Sprint 4.5 — Continuous Adversarial Validation

Every material DE-layer change triggers appropriate security checks.

Cycle:

```text
BUILD
→ ATTACK / TEST
→ WARDEN OBSERVES
→ EVIDENCE
→ STRIKE THE ROOT
→ REPAIR
→ RETEST
→ PROMOTE
```

Include regression tests for previously discovered weaknesses.

Security findings enter evidence and task flow; they are not buried in terminal history.

---

## Sprint 4.6 — Kernel Optimization Gate

Only after the DE layer exists and baseline measurements are captured:

- measure kernel/system bottlenecks;
- identify changes justified by evidence;
- apply one bounded optimization at a time;
- compare against baseline;
- retain only monotonic or explicitly justified changes.

**M4 PASS:** DE operates as a measurable layer over Linux and continuously tests its own security assumptions.

---

# 10. M5 — Pan, Operator Model, Dormant Capabilities, Panes

## Sprint 5.1 — Pan Runtime Identity

Unify Pan/Qwen/Quinn historical lineage without losing provenance.

Preserve recovered voice/persona target:

- faint Greek accent;
- refined;
- precise;
- playful;
- dry;
- lightly Diogenic;
- irreverent toward needless ceremony;
- never theatrical;
- personality never obscures operational clarity.

---

## Sprint 5.2 — Life Companion → Companion Profile → OP_PROF

### TB-5.2.1

Recover exact Life Companion Constitution / Companion Profile source and provenance.

### TB-5.2.2

Establish what survives into OP_PROF.

### TB-5.2.3

Keep:

```text
OP_PROF = longitudinal human model
OP_REAL = current perishable reality
```

Observation is not inference. Inference is not fact.

---

## Sprint 5.3 — Ambient Operator Observation

Use authorized microphones/cameras as continuous available sensing channels where enabled.

Possible observations:

- speech tone/cadence;
- interaction tempo;
- facial expression;
- posture/visible behavior;
- explicit corrections;
- context changes.

Mood remains an inference with confidence/provenance unless explicitly stated.

One-off interface preference changes do not silently become durable OP_PROF preferences.

---

## Sprint 5.4 — Dormant Capability Resolver

Universal principle:

> Do not define one universal package format. Define one universal capability-resolution contract above multiple realization mechanisms.

Resolve:

```text
task / intent
+ authority
+ OP_PROF
+ OP_REAL
+ node reality
+ available realizations
→ Activation Plan
→ Runtime Instance
→ Receipt / teardown
```

---

## Sprint 5.5 — Proof Gate B: Just-in-Time Pane

Prove one capability that is:

1. known and verified while dormant;
2. visible/ready without heavyweight residency;
3. resolved from current reality;
4. activated on demand;
5. projected as a useful Pane;
6. live-adjustable by operator;
7. checkpointed;
8. torn down with evidence;
9. reproducible from durable closure.

Example presentation behavior may include story-time visual/voice re-resolution, but presentation never changes canonical truth.

**M5 PASS:** Pan can resolve a dormant capability into a purpose-built operator-facing projection and release it cleanly.

---

# 11. M6 — Fleet + Phylactery

## Sprint 6.1 — Node Identity and Liveness

Each node needs:

- stable identity;
- capabilities;
- resources;
- trust/authority status;
- current liveness;
- last-known state;
- recovery contribution.

Detect nodes joining, leaving, failing, and returning.

---

## Sprint 6.2 — Dynamic Fleet Resolution

When a node drops:

```text
detect
→ recompute available capability
→ recompute redundancy
→ distinguish absent vs lost/retired
→ move/regenerate endangered work/recovery state
→ continue
```

When it returns:

```text
detect
→ verify identity/integrity
→ reconcile against newer state
→ reassign work/recovery role from current reality
→ continue
```

---

## Sprint 6.3 — Phylactery / H

The Phylactery is a **fleet property**, not a designated machine.

`H` is the minimum recovery nucleus Pan needs to reconstruct the whole system.

Invariant:

> **Always have a complete Phylactery somewhere.**

Additional reconstructive material should be distributed across lawful/available surfaces.

Analogy:

> **RAID, but not RAID.**

Keep from RAID:

- redundancy;
- loss tolerance;
- rebuild;
- rebalancing.

Do not inherit:

- fixed disks;
- fixed membership;
- one controller/chassis;
- homogeneous nodes;
- block-level striping as the governing abstraction.

DE distributes semantic recovery objects, lineage, capabilities, provenance, and reconstruction knowledge.

Survivability question:

> **What dies if this bird disappears right now?**

---

## Sprint 6.4 — More Birds Fleet Enrollment

Order:

1. AirBook;
2. White Mac;
3. iPad where technically useful;
4. Amazon tablet;
5. Brandon's incoming phones;
6. other viable scavenged devices.

Each bird should serve as many legitimate functions as reality permits:

- compute;
- dormant-capability store;
- Phylactery carrier;
- evidence/cache holder;
- Pan interface;
- sensing endpoint;
- reconstruction source.

This is **More Birds applied to More Birds**.

---

## Sprint 6.5 — Catastrophe Drill

Simulate/perform bounded failures:

- ordinary node disappears;
- current compute node disappears;
- recovery carrier disappears;
- multiple non-critical birds disappear.

Prove that the surviving fleet detects, rebalances, and preserves the complete-recovery invariant.

**M6 PASS:** a bird can vanish without silently taking irreplaceable DE state with it.

---

# 12. M7 — Governed Income Block

After initial fleet/capability usefulness is proven, spend a bounded block of days on legitimate auditable income experiments.

## Sprint 7.1 — Bug Bounty / Security Work

Build a governed workflow for authorized programs:

- program scope intake;
- target/scope verification;
- evidence;
- reproducible findings;
- report construction;
- submission tracking;
- payout/result tracking;
- lessons returned to Warden/DE security.

## Sprint 7.2 — Other Recurring Income Experiments

Evaluate other legitimate low-touch workflows using the same evidence/accountability standard.

**M7 PASS:** at least one workflow has been executed end-to-end with auditable inputs/actions/results.

---

# 13. M8 — Golden Orb Learning Ladder

Do not jump directly to recursive self-modification.

## Sprint 8.1 — Outcome Learning

Pan records:

- attempted operation;
- assumptions;
- evidence;
- outcome;
- failure/success;
- corrections;
- reusable lesson;
- confidence.

## Sprint 8.2 — Improvement Proposals Through SIQ

Pan may generate candidate improvements.

They enter:

```text
Observation / Evidence
→ Interpretation
→ Proposed improvement
→ SIQ
→ Review
```

No automatic promotion merely because Pan proposed it.

## Sprint 8.3 — Bounded Improvement Execution

For approved improvements:

```text
baseline
→ change
→ test
→ compare
→ non-regression
→ promote or revert
```

Preserve the ability to explain why the change occurred.

## Sprint 8.4 — Meta-Capability Improvement

Allow Pan to improve bounded machinery used to:

- retrieve;
- test;
- schedule;
- resolve capabilities;
- generate Panes;
- place work on fleet;
- produce recovery material.

Each improvement remains governed and reversible where technically possible.

## Sprint 8.5 — Recursive Improvement Proof

Demonstrate at least one chain where an improvement to the improvement machinery leads to a later measurable improvement without loss of:

- provenance;
- authority;
- recovery;
- validation;
- monotonic/non-regression checks.

**M8 PASS:** recursive learning exists as an evidence-bearing governed loop rather than a slogan.

---

# 14. M9 — IP / Patent Evaluation

Trigger: a concrete DE implementation is demonstrably reproducible and its lineage is preserved.

## Sprint 9.1 — Invention/Provenance Map

For each potentially protectable implemented concept:

- first-known source;
- operator contribution;
- research prior art;
- implementation date;
- proof artifact;
- public disclosure history;
- dependencies;
- distinctions from prior art.

## Sprint 9.2 — Prior-Art / Patentability Review

Use qualified research/legal process before concluding patentability.

## Sprint 9.3 — Filing Decision

No roadmap assumption that a patent should be filed. Decide from evidence, cost, disclosure consequences, strategic fit, and governing ownership/control principles.

IP work must not delay getting the first provable system built.

---

# 15. Persistent Cross-Cutting Task Blocks

These repeat across milestones.

## X-1 — Evidence

Every meaningful change produces compact durable evidence.

## X-2 — Recovery

Every destructive or high-risk change has a recovery path before execution.

## X-3 — System Language

New project-specific terminology is captured with provenance and queued for review. Do not permit uncontrolled synonym drift.

## X-4 — SIQ

Interesting but non-blocking ideas go to SIQ.

## X-5 — Security

Warden/security validation evolves alongside the DE layer and later every fleet node/capability.

## X-6 — Phylactery

Re-evaluate the complete-recovery invariant whenever fleet membership/storage topology changes.

## X-7 — More Birds

For every new primitive ask:

> Can this sound primitive legitimately solve additional problems without multiplying authority, truth, maintenance, or ceremony?

Do not force multifunctionality where it makes the primitive less stout.

## X-8 — Strike the Root

Repeated operational failures trigger root/control-layer investigation before workaround accumulation.

## X-9 — Elegance Results

Do not spend roadmap time polishing elegance directly. Reduce correctly; validate; reuse; compose. Elegance may result.

---

# 16. Current Cursor

Current control-plane reality:

- locked roadmap installed and hash-verified;
- historical roadmap coverage audit passed;
- raw block similarity reduction was not discriminating enough;
- system language/glossary recovery is now required before final roadmap-family reduction;
- bootstrap coverage closure remains pending;
- whole-system consolidation remains before Git;
- firmware/AirLLM begins only after recovery/consolidation gate.

Therefore the next execution sequence is:

```text
SYSTEM LANGUAGE RECOVERY
→ ROADMAP FAMILY REDUCTION
→ BOOTSTRAP COVERAGE CLOSURE
→ WHOLE-SYSTEM CONSOLIDATION
→ POST-CENSUS
→ GIT / PRIVATE REMOTE / OFFLINE RECOVERY
→ FIRMWARE
→ AIRLLM
→ INGESTION
```

No additional remembered idea needs to interrupt this sequence unless it changes a dependency or safety condition. Capture it in SIQ and continue.

---

# 17. Final Reduction

```text
Build the memory.
Build the recovery.
Build the language.
Build the capability.
Test it.
Attack it.
Preserve it.
Spread it.
Learn from it.
Improve it.
Then improve the improving.
```

**Construction precedes optimization. Capability precedes complexity. Evidence precedes interpretation. Interpretation precedes promotion. Reality is final validator.**

---

# 18. Ratification and Change Control

**Operator ratification:** 2026-08-16.

This roadmap is now the current Difference Engine execution baseline.

Rules:

1. This version is immutable historical evidence once installed.
2. Execution proceeds from its milestones, sprints, task blocks, dependencies, and proof gates.
3. New remembered ideas do not silently alter the baseline.
4. Non-blocking discoveries enter SIQ.
5. A dependency, safety condition, or materially changed reality may justify amendment.
6. Amendments occur by explicit forward versioning with provenance; never by invisible mutation.
7. Historical roadmap artifacts may be reduced or archived only after their unique surviving information has been accounted for.
8. Reality remains the final validator.

Lock statement:

> **Build the memory. Build the recovery. Build the language. Build the capability. Test it. Attack it. Preserve it. Spread it. Learn from it. Improve it. Then improve the improving.**

