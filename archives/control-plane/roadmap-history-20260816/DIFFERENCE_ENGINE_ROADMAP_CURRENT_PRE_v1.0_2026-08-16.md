# Difference Engine — Current Roadmap

**Date:** 2026-08-16  
**Status:** LOCKED CURRENT ROADMAP — operator-confirmed 2026-08-16  
**Purpose:** One current execution line. Preserve queued work without confusing it with active work.

## 0. Control-plane closure

1. Keep terse execution mode.
2. LTCK v1.2.3 remains the sole active bootstrap.
3. Finish bootstrap coverage audit against the 74 preserved historical bootstraps.
4. Reduce the roadmap pile to this one current roadmap plus preserved research/future-work provenance.
5. Complete Forge consolidation, validation, post-consolidation census, coherent Git commit, private remote push, and offline recovery bundle.
6. Do not perform firmware write before the recovery gate is complete.

## 1. Firmware → AirLLM → ingestion

1. Apply/validate the required BC501 firmware path after the recovery gate.
2. Re-run the AirLLM path against the firmware-changed storage reality.
3. Establish a reproducible AirLLM success/failure result before optimization.
4. Preserve only the AirLLM artifacts needed for reconstruction, validation, compact evidence, and the surviving Pan runtime.
5. Identify and remove proven-disposable AirLLM cache/bulk only after reconstruction requirements are known.
6. Finish the ingestion pipeline.

### Proof Gate A — conversation recovery

The first hard proof is not a demo. It is the problem the ingestion system exists to solve:

> Given the exported Difference Engine conversation corpus and governed repository state, recover a previously discussed project concept, decision, dependency, reversal, or queue item with provenance without depending on chat memory or manual archaeology.

Pass requires deterministic source traversal, provenance, interruption recovery, and repeatable retrieval. The target is practical recovery in well under two hours rather than re-invention.

## 2. Recover Forge storage and convert the AirBook

1. After AirLLM disposition is proven, reclaim disposable AirLLM bulk.
2. AirBook: retain Brandon's music capability and photography capability under Linux.
3. Partition/install Linux on the AirBook.
4. Copy Brandon's material from the AirBook macOS partition to the Linux side on the same machine.
5. Verify music projects/media and photography assets before destructive partition work.
6. Establish the Linux-versioned music suite, anchored on REAPER, plus a usable photography suite.
7. Once verified, consume/remove the macOS partition.
8. Remove Brandon's verified duplicate corpus from Forge and recover approximately 45 GB there.

## 3. Research annex → full ingestion → Pan corpus

1. Finalize the research annex structure and preservation rules.
2. Measure available storage after AirLLM and Brandon-data reclamation.
3. Choose a reasonable explicit annex expansion budget in GB from measured reality.
4. Acquire/download the queued research corpus.
5. Preserve source identity, hashes, provenance, and research/future-work status.
6. Ingest the research corpus and remaining conversation/project evidence.
7. Pan consumes the resulting governed corpus through the finished ingestion path.

## 4. Build the Difference Engine layer over Linux

Use Linux as substrate first. Do not begin by replacing Linux.

Build and prove the DE layer that supplies:

- governed state and policy evaluation;
- OP_PROF / OP_REAL resolution;
- Pan orchestration;
- capability resolution;
- Pane/projection machinery;
- model/runtime registry;
- snapshots, validation, recovery, and provenance;
- activity-centric workspaces rather than application-centric desktops.

Only after the DE layer exists and can be measured should kernel specialization/optimization become an active construction target.

## 5. Pan operator interface

### Voice/persona

Recovered target:

- faint Greek accent;
- refined and precise delivery;
- playful and dry;
- lightly Diogenic;
- irreverent toward needless ceremony;
- never theatrical;
- personality never obscures operational clarity.

### Operator observation

Camera and microphone are intended as continuously available sensing channels for Pan's operator model, subject to operator authority.

Primary recognized person: operator. Other-person recognition requires operator authorization.

Observation may include:

- speech tone and cadence;
- interaction tempo;
- facial expression;
- posture/visible behavior where available;
- explicit statements and corrections;
- contextual changes over time.

Inferences such as mood remain inferences, with confidence/provenance, rather than silently becoming facts in OP_PROF.

### Life Companion lineage

The Companion Profile is an ancestor of OP_PROF: a living, revisable human model rather than a diagnosis or fixed identity. Preserve that lineage when OP_PROF is reconstructed.

## 6. Panes and deferred realization — "not a flatpack"

Do not define one universal package format.

Preserve the surviving primitive:

> A dormant capability is a verified reconstructable possibility, resolved into a bounded runtime only when intent and reality require it.

Capability resolution uses task + OP_PROF + OP_REAL + authority + node reality + available realizations.

Panes are just-in-time projections/capability surfaces. They may design themselves for purpose and current device reality, while remaining live-adjustable by the operator.

Example: story time may resolve to a parchment-like narrative Pane with framed images, suitable typography, and a selected Pan voice. Operator directives such as "blue", "red", "bigger font", or "different voice" re-resolve the current Pane. One-off directives do not silently become durable preferences.

### Proof Gate B — dormant capability / Pane

Prove one small capability that is:

1. known and verified while dormant;
2. visible/ready without heavyweight residency;
3. resolved from current reality;
4. activated on demand;
5. useful;
6. checkpointed;
7. torn down with evidence;
8. reproducible from its durable closure.

## 7. Fleet

After the Forge/AirBook path is stable:

1. enroll the AirBook as a DE node;
2. enroll the White Mac;
3. investigate/enroll the iPad where technically useful;
4. investigate the Amazon tablet;
5. inspect and enroll useful incoming phones from Brandon;
6. continue scavenger-fleet enrollment from other viable phones/devices.

Longer-term household model:

- laptops/compute nodes become mostly infrastructure;
- phones/tablets become distributed Pan interfaces around the house;
- ambient voice/visual operator interaction becomes the ordinary interface;
- hardware may improve later without changing the governing interaction model.

### Phylactery as fleet survivability

The Phylactery is a **fleet property**, not a designated machine.

Preserve a **self-describing recovery nucleus**: the minimum sufficient identity, lineage, maps, governing state, recovery machinery, and reconstruction knowledge required for Pan to rebuild the Difference Engine after catastrophic loss.

Working reduction:

> Full replicas preserve the whole bird. Partial replicas preserve enough bones, maps, lineage, and recovery machinery to regrow it.

Rules:

1. **Always maintain at least one complete Phylactery somewhere.**
2. Spread additional reconstructive material across as many lawful/available nodes and storage surfaces as practical.
3. No single node is "the Phylactery node."
4. Node loss is an operational state transition, not immediately a catastrophe.
5. When a node drops:
   - detect the loss;
   - recompute current capability and redundancy;
   - distinguish temporarily absent from lost/retired;
   - redistribute/regenerate endangered recovery material;
   - preserve at least one complete recovery path.
6. When a node returns:
   - detect reappearance;
   - verify identity and integrity;
   - reconcile against newer state and provenance;
   - reassign storage/compute/recovery responsibilities from current reality rather than blindly restoring the old arrangement.
7. Fleet placement remains dynamic: capability, compute, dormant closures, checkpoints, and Phylactery fragments may move as birds enter and leave the flock.

Survivability test:

> **What dies if this bird disappears right now?**

The corresponding operational primitive is **dynamic survivability accounting**.

### RAID, but not RAID

Use RAID as an analogy for the **survivability behavior**, not as the architecture.

What survives from RAID:

- redundancy;
- failure tolerance;
- rebuild after loss;
- rebalancing after membership changes;
- no single ordinary component should be indispensable.

What does **not** carry over:

- fixed disks;
- fixed array membership;
- block-level striping as the governing abstraction;
- homogeneous hardware assumptions;
- static parity layout;
- one chassis / one controller boundary.

DE operates over **semantic recovery objects, capabilities, provenance, authority, and reconstruction contracts** across heterogeneous nodes that may appear and disappear.

The Phylactery therefore behaves like a dynamic, semantic, self-repairing recovery fabric:

```text
complete Phylactery exists somewhere
        +
distributed reconstructive fragments elsewhere
        +
continuous node awareness
        +
dynamic redistribution / regeneration
        +
reconciliation when nodes return
```

The invariant is not "all fragments always present everywhere."

The invariant is:

> **Pan can still reconstruct the whole Difference Engine after the allowed failures.**

### More Birds — fleet form

Use each additional viable device for more than one purpose where reality permits:

- execution node;
- dormant-capability store;
- recovery/Phylactery carrier;
- evidence/cache holder;
- Pan interface;
- sensing endpoint;
- reconstruction source.

The objective is not maximum replication everywhere. It is maximum useful capability and recoverability from the available flock, with redundancy continuously adjusted as nodes join, leave, fail, or return.

## 8. Income block

After the initial fleet/capability path is usable, spend a bounded block of days proving governed income workflows.

Priority research lane already identified: bug bounties/security work. Also retain other legitimate recurring-income experiments that can be made auditable and low-touch.

Do not let economic automation bypass authority, provenance, or accountability.

## 9. Continue DE refinement

After the bounded income block:

- optimize/tune the DE layer;
- mature Panes and projections;
- mature dormant-capability resolution;
- refine fleet placement and heterogeneous execution;
- continue Priority AI / Pan runtime work;
- recover and validate remaining frontier concepts before promotion.

The post-proof frontier remains intentionally less specific than the constructed path before it.

## 10. IP / patent work

Queue IP/patent analysis and preservation, but do not let it precede construction proof.

Trigger: at least one reproducible, evidence-bearing DE capability/projection/ingestion proof exists and its lineage is preserved well enough to describe what was actually built rather than what might someday be built.

No patentability or filing conclusion is asserted by this roadmap.

---

# Recovered queue / memory primitives

## SIQ — Suggested Implementation Queue

Exact recovered lifecycle:

```text
Conversation
    ↓
SIQ (Suggested Implementation Queue)
    ↓
Review
    ↓
IQ (Implementation Queue)
    ↓
Mission
    ↓
Complete
```

Recovered meanings:

- **Suggested** → not yet accepted.
- **Implementation** → concrete enough to build.
- **Queue** → ordered, not forgotten.

Core rule:

> Nothing gets lost. Nothing gets implemented accidentally.

SIQ bridges the gap between a random idea and approved work. Nothing in SIQ is approved merely because it was captured; nothing is discarded without review.

## Memory Palace / statuettes

Recovered operator-cognition sequence:

```text
Structural Transform
    ↓
Facet
    ↓
Statuette
    ↓
Expanded Structure
```

Recovered definition:

> The statuette isn't the knowledge. It's a compressed index.

Examples recovered from the conversations:

- **Blacksmith** reconstructs an entire capability cluster.
- **More Birds** reconstructs a production operator rather than merely a slogan.
- **Molasses** reconstructs phase discipline, dependency order, reluctance to promote, bounded refinement, and external stop conditions.

Reduction criterion:

> Reduction isn't merely making things smaller. It's producing an object that can regenerate the larger structure.

A good statuette is compact, distinctive, structurally rich, and reconstructive. If it cannot regenerate the larger reasoning, it is bad compression.

The Memory Palace remains the operator's cognitive navigation/addressing structure, not repository canon. Simonides is the operator's internal custodian/guide of that Palace.

---

# Governing execution principle

Construction precedes optimization. Capability precedes complexity. Evidence precedes interpretation. Interpretation precedes promotion. Reality is final validator.


---

# Operator Lock

On 2026-08-16 the operator confirmed that this document captures the current roadmap.

No further speculative expansion belongs in the active roadmap unless new evidence or operator direction changes the plan.

New ideas enter through SIQ unless they are required to execute an already-locked step.

