# Difference Engine Frontier Convergence Research Synthesis
## Dormant Capability, Governed Runtime, Source-Grounded Memory, Capability Supply Chains, and Deferred Realization

**Project:** The Difference Engine  
**Date:** 2026-08-12  
**Artifact type:** External research synthesis / architecture research / experiment queue  
**Status:** Research evidence and candidate interpretation — **not canonical doctrine**  
**Scope:** Agent operating systems, long-term memory, skill/capability systems, permission boundaries, checkpoint/recovery, task orchestration, personalized interfaces, constrained inference, and selective model adaptation  
**Research rule:** Evidence before interpretation. Interpretation before promotion. Promotion only after validation.

---

# 1. Purpose

This artifact records a frontier scan performed against the current Difference Engine direction after the project crossed from conceptual architecture into live construction.

The scan did **not** ask:

> Who has already built the Difference Engine?

No such claim is supported.

Instead, it asked:

> Which independent research communities are now discovering mechanisms, abstractions, failure modes, and invariants that converge with structures the Difference Engine has already derived from operational necessity?

The scan focused particularly on:

- dormant / activatable capability;
- Flat Packs;
- capability discovery;
- capability dependency closure;
- agent operating-system layers;
- governed authority;
- source-grounded memory;
- memory evolution without evidence destruction;
- checkpoint / restore;
- failure-driven improvement;
- task DAGs and ready frontiers;
- profile-conditioned interfaces;
- old-hardware / Priority AI research;
- resource residency;
- selective model adaptation.

The purpose is not to import outside architecture. It is to identify independent convergence, locate mechanisms worth testing, challenge DE assumptions, extract experiments, reject unsupported conclusions, and preserve provenance for later governed synthesis.

---

# 2. Current DE Context

The live project context materially changes how this literature should be interpreted.

The Difference Engine is no longer only a repository/governance design exercise. The current build has a functioning local-Qwen path on the Surface/Forge, a completed smoke-test edge, active iterative repository ingestion, durable ingestion/output artifacts, established bootstrap and constitutional loading, explicit recovery and continuity requirements, a developing Flat Pack concept, a proposed Operator Profile system, a proposed profile-conditioned operating-system projection, an explicit dormancy principle for capability, a task-oriented workspace concept, Pan/Babbage orchestration, and an old-hardware / Priority AI research path.

Therefore, external findings can now be evaluated against **working operations** rather than imagined future architecture.

---

# 3. Executive Synthesis

The strongest conclusion from the scan is not that outside research validates the Difference Engine wholesale.

It is that multiple independent research areas are converging on a small set of structures that strongly resemble DE's surviving primitives.

The convergence is especially strong around six ideas:

## 3.1 Capability should be externalized from the model

Current agent-skill research increasingly treats reusable procedures as versioned external artifacts rather than something that must live permanently inside model weights or prompt context.

## 3.2 Capability visibility and capability authority must be separated

Several 2026 systems distinguish what an agent can *see*, what it can *request*, and what it is *authorized to affect*.

That distinction closely matches DE's authority non-amplification requirement.

## 3.3 Capability libraries require dependency governance

Large skill ecosystems already exhibit hidden dependency graphs, duplicated dependencies, inconsistent installations, provenance gaps, and supply-chain risks. Typed manifests and lockfile-like dependency records are emerging as recommendations.

That directly strengthens the Flat Pack requirement for explicit dependency closure.

## 3.4 Memory must preserve trajectories, not merely rewritten summaries

Recent work shows two complementary failures: repeated LLM consolidation can corrupt useful memory, and decontextualized memory fragments can become invalid evidence. Newer systems preserve immutable episodes, claim evolution, contextual anchors, and source links.

This converges strongly with DE's evidence spine.

## 3.5 Runtime state should be checkpointed according to meaningful change

Agent checkpoint research finds that many agent turns produce no recovery-relevant state. This suggests DE should eventually distinguish conversational activity, operational state transition, and recovery-relevant state transition.

Not every model turn deserves a checkpoint.

## 3.6 Scarce resources should be allocated only to active competence

Research on tool retrieval, edge inference, selective training, runtime scheduling, and checkpointing all independently weaken the assumption that everything must be simultaneously loaded, visible, mutable, resident, or executing.

This strengthens the Flat Pack principle:

> **Capability may exist without residency.**

And the UI principle:

> **Ready is not running.**

---

# 4. Frontier Evidence Map

## 4.1 The Agent Operating System (AOS): A Reference Operating Architecture for Distributed Agentic Systems

**ArXiv:** 2608.03214  
**Date:** 2026-08-04  
**Authors:** Ankur Sharma, Deep Shah

### Evidence

The paper proposes an agent operating architecture with two internal planes. The **Control & Governance Plane** handles intent, policy, trust, authority, confidence, auditability, observability, and human oversight. The **Runtime & Coordination Plane** handles agent lifecycle, workflow coordination, model/tool routing, context/memory coordination, scheduling, and runtime assurance.

Linux, Windows, container runtimes, and physical infrastructure remain outside the AOS boundary and connect through explicit interfaces.

### DE interpretation

This independently supports the current DE decision **not** to equate an operating-system projection with writing a Linux distribution.

A DE operating layer can sit above a host OS and own authority, intent, capability resolution, orchestration, provenance, projection, and recovery.

### Do not import

Do not adopt the AOS naming, object model, or plane taxonomy merely because it converges. The useful evidence is the independent structural separation.

Source: https://arxiv.org/abs/2608.03214

---

## 4.2 Towards an Agent Operating System — Lessons from Classical and Cloud OS

**ArXiv:** 2607.25076  
**Date:** 2026-07-27  
**Authors:** Gosia Steinder, Hubertus Franke

### Evidence

The authors argue that agent systems are still in a pre-standardization phase analogous to earlier operating-system and cloud eras. They propose deriving stable agent abstractions with explicit semantics rather than allowing framework-specific conventions to remain the de facto architecture.

### DE interpretation

This strengthens one of DE's existing instincts:

> recover the small stable abstractions before optimizing implementation.

It also argues against coupling DE architecture to one agent framework or vendor interface.

Source: https://arxiv.org/abs/2607.25076

---

## 4.3 Agent libOS: A Library-OS-Inspired Runtime for Long-Running, Capability-Controlled LLM Agents

**ArXiv:** 2606.03895  
**Date:** 2026-06-02  
**Author:** Yingqi Zhang

### Evidence

Agent libOS runs above a conventional host operating system. It treats an agent as a process-like runtime subject with stable identity, lineage, lifecycle state, tool table, typed object memory, explicit capabilities, human queues, checkpoints, events, and audit records.

Its central invariant is especially relevant: changing the action surface does not automatically change resource authority. The system distinguishes model-visible tools from protected runtime effects. Capabilities are checked at lower runtime primitives.

The paper also defines **AgentImages** containing boot-state declarations such as prompts, tools, skills, required capabilities, startup modules, model profile, and boot metadata.

### DE interpretation

This is one of the strongest external convergences found.

It supports the DE separation:

```text
Projection / visible capability
        ≠
Authority
        ≠
Runtime side effect
```

It also suggests a concrete implementation lesson for Flat Packs:

> A pack may declare required authority. It should not carry that authority automatically.

A pack can declare filesystem or external-resource requirements, but activation must resolve those requirements through a separate authority mechanism.

### Candidate experiment

When the first DE capability manifest is built, separate:

```text
visible capability
required permission
granted permission
actual effect
```

into four records.

Source: https://arxiv.org/abs/2606.03895

---

## 4.4 Skills Are Not Islands: Measuring Dependency and Risk in Agent Skill Supply Chains

**ArXiv:** 2607.01136  
**Date:** 2026-07-01  
**Authors:** Changguo Jia, Tianqi Zhao, Runzhi He, Minghui Zhou

### Evidence

The paper analyzes skill dependency supply chains across more than 1.43 million skills. It finds that agent-skill metadata can be activation-ready while remaining governance-poor. Dependency graphs commonly span skills, packages, and services. Recursive reuse can hide additional dependencies, and security-relevant problems can exist in dependencies even if the visible skill itself appears benign.

The authors recommend typed dependency manifests, dependency-cluster management, risk-warning audits, and lockfile-like records.

### DE interpretation

This is probably the strongest external support yet for the **Flat Pack manifest + dependency lock** concept.

A Flat Pack must not merely say:

```text
needs Python
needs model
needs ffmpeg
```

It should be capable of expressing:

```text
dependency:
    type
    identity
    version
    source
    integrity
    required/optional
    activation role
    security status
```

A Flat Pack should also support transitive closure.

### Strong DE implication

> The pack itself is not the security boundary. Its closure is.

### Candidate murder

**MURDER:** "If the Flat Pack itself verifies, the capability is safe."

No. Its dependencies may still violate security, provenance, or compatibility constraints.

Source: https://arxiv.org/abs/2607.01136

---

## 4.5 SkillGuard: A Permission-Centric Framework for Agent Skill Security

**ArXiv:** 2606.03024  
**Version examined:** v2, 2026-07-13  
**Authors:** Shidong Pan et al.

### Evidence

SkillGuard treats skills as permission-bearing executable artifacts. It emphasizes that a skill can affect both **context/reasoning influence** and **runtime side effects**. It therefore uses a dual-plane permission model involving skill manifests, runtime permission control, user interaction, and policy enforcement.

### DE interpretation

Flat Pack security needs two distinct questions:

```text
What information/instructions may this pack inject?
What external state may this pack affect?
```

Those are not the same permission.

For a Rowan professional projection, for example, a pack may be allowed to read selected evidence and generate a derivative artifact without being allowed to write canonical subject state or expose unrelated sensitive evidence.

### Candidate manifest fields

```text
context_scope
read_scope
write_scope
device_scope
network_scope
side_effect_class
human_approval_required
```

Source: https://arxiv.org/abs/2606.03024

---

## 4.6 Skill-Inject: Measuring Agent Vulnerability to Skill File Attacks

**ArXiv:** 2602.20156  
**Date:** 2026-02-23  
**Authors:** David Schmotz et al.

### Evidence

The paper studies malicious instructions embedded in reusable agent skill files. It reports that contemporary agents can be strongly vulnerable to such skill-based injection and argues that model scaling or simple filtering alone is insufficient.

### DE interpretation

Flat Packs, branch packages, and imported skill artifacts must be treated as **untrusted inputs until verified**.

Therefore:

> Never make "pack loaded" equivalent to "pack trusted."

Source: https://arxiv.org/abs/2602.20156

---

## 4.7 SkillFab: An Agent-Native Skill Production Platform

**ArXiv:** 2607.03780  
**Date:** 2026-07-04  
**Authors:** Anjie Xu et al.

### Evidence

SkillFab uses a demand-first workflow:

```text
need capability
→ search existing reusable skill
→ if absent, create issue
→ repository development
→ commit evidence
→ review
→ registry publication
```

The system exposes shared lifecycle state across web, REST, and MCP interfaces rather than maintaining separate task logs.

### DE interpretation

This strongly resembles the DE principle:

> search before create.

It suggests a clean future lifecycle for Flat Packs:

```text
REQUEST
→ RESOLVE existing capability
→ if absent, record unmet capability
→ build candidate
→ validate
→ review
→ publish to capability registry
```

This is preferable to automatically generating a new Flat Pack every time an agent encounters a new task.

Source: https://arxiv.org/abs/2607.03780

---

## 4.8 Dynamic Agent Skills: A Lifecycle Survey and Taxonomy of Evolving Skill Libraries

**ArXiv:** 2607.10113  
**Date:** 2026-07-11  
**Journal:** TMLR (2026)  
**Author:** Yubo Li

### Evidence

This survey synthesizes 124 papers from 2023–2026. It characterizes dynamic skills as lifecycle-managed, verified, evolving artifact stores.

Recurring lifecycle stages include evidence acquisition, proposal, verification/admission, storage, retrieval/composition, maintenance, distillation/portability, and governance. The survey emphasizes provenance, rollback, verifier quality, repair, admission, and the limitations of flat retrieval as libraries grow.

### DE interpretation

This is close to the lifecycle DE should demand for future capability evolution.

Candidate Flat Pack lifecycle:

```text
DISCOVER
→ PROPOSE
→ BUILD
→ VERIFY
→ ADMIT
→ INDEX
→ ACTIVATE
→ OBSERVE
→ REPAIR / SUPERSEDE / RETIRE
```

Source: https://arxiv.org/abs/2607.10113

---

## 4.9 VeriSkill: A Self-Evolution Framework for Program Verification Skills

**ArXiv:** 2607.27733  
**Date:** 2026-07-30  
**Authors:** Changguo Jia et al.

### Evidence

VeriSkill improves reusable verification skills by attributing failures to specific skill deficiencies, producing revisions, and admitting revisions only when they improve verification performance while preserving semantics.

### DE interpretation

This is strong convergence with the project's monotonic-improvement criterion.

Instead of:

```text
task failed
→ rewrite everything
```

use:

```text
task failed
→ locate failing capability
→ propose bounded repair
→ test candidate
→ compare
→ admit or reject
```

Source: https://arxiv.org/abs/2607.27733

---

# 5. Memory Frontier

## 5.1 Useful Memories Become Faulty When Continuously Updated by LLMs

**ArXiv:** 2605.12978  
**Date:** 2026-05-13  
**Authors:** Dylan Zhang et al.

### Evidence

The authors compare raw episodic traces with repeatedly consolidated textual memory. They find that repeated consolidation can initially help and then degrade, sometimes falling below a no-memory baseline. Their controlled experiments indicate that retaining raw episodes and explicitly controlling consolidation can outperform forced continual consolidation.

### DE interpretation

This is direct experimental support for:

```text
Evidence
    must survive

Interpretation
    may change

Consolidation
    must be gated
```

The Difference Engine should **not** let a model repeatedly rewrite evidence into a cleaner summary and then discard what the summary came from.

### Rowan implication

Thirty observations should not disappear because a later summary says:

> Rowan typically does X because Y.

The summary should remain a derived object pointing to the evidence set.

Source: https://arxiv.org/abs/2605.12978

---

## 5.2 RaMem: Contextual Reinstatement for Long-term Agentic Memory

**ArXiv:** 2606.22844  
**Date:** 2026-06-22  
**Authors:** Wei Yang et al.

### Evidence

RaMem identifies **context collapse**: a memory fragment can appear semantically relevant while lacking the original conditions required for it to be valid evidence. The framework reattaches contextual anchors including time, participants, session span, and query-specific recall conditions.

### DE interpretation

Semantic similarity alone is insufficient for repository retrieval.

Candidate evidence envelope:

```text
content
time
source
participants
location/context
task
preceding state
following state
confidence
validity conditions
```

### Rowan implication

"Rowan refused a worksheet" is not enough. The evidence may need what subject, who was present, what happened immediately before, what intervention followed, and what happened next.

Source: https://arxiv.org/abs/2606.22844

---

## 5.3 MOSAIC: Accurate and Efficient Long-Term Memory for LLM Agents

**ArXiv:** 2607.16211  
**Authors:** Zicheng Zhao et al.

### Evidence

MOSAIC uses typed graph memory, relational storage, fast retrieval, and save-time conflict detection. Its reported evaluation shows substantial gains over tested baselines and improved detection of injected factual conflicts.

### DE interpretation

The useful mechanism is **conflict detection at intake**.

Candidate DE operation:

```text
NEW CLAIM
    ↓
retrieve nearby related state
    ↓
relationship classification

CONCORDANT
CONTRADICTORY
SUPERSEDING
ORTHOGONAL
DUPLICATE
UNKNOWN
    ↓
record relation + provenance
```

Contradiction becomes evidence.

Source: https://arxiv.org/abs/2607.16211

---

## 5.4 TrajWiki: Source-Grounded Memory Trajectories for Long-Horizon Dialogue Agents

**ArXiv:** 2608.00967  
**Date:** 2026-08-02  
**Authors:** Jingyu Sun et al.

### Evidence

TrajWiki explicitly rejects memory as an overwritable static entry. It represents memory as **source-grounded evolution trajectories** using immutable episodic snapshots, claim-level operations such as ADD, REVISE, and DEPRECATE, structured intermediate wiki pages, and links back from higher-level memory representations to trajectories, snapshots, and source messages.

### DE interpretation

This is exceptionally strong convergence.

A DE repository object may eventually benefit from a first-class **claim trajectory** view:

```text
claim ID
├── introduced
├── source
├── supporting evidence
├── contradictory evidence
├── revised
├── superseded/deprecated
└── current interpreted state
```

This would be useful for hardware facts, governance drift, Rowan observations, architecture evolution, research claims, and branch state.

### Murder

**MURDER:** "Current state is enough; we can delete the path that produced it."

No.

Source: https://arxiv.org/abs/2608.00967

---

# 6. Capability Discovery and the Ready Frontier

## 6.1 Semantic Tool Discovery for Large Language Models

**ArXiv:** 2603.20313  
**Date:** 2026-03-19  
**Authors:** Sarat Mudunuri et al.

### Evidence

The paper addresses large tool catalogs in which exposing every tool to the model consumes context, raises cost, and can reduce selection quality. The proposed system semantically retrieves a small subset of relevant tools.

### DE interpretation

This maps directly onto Flat Packs and the OS capability surface.

The system does **not** need to place every available capability in RAM, the model's context, the taskbar, or the active projection.

Instead:

```text
large capability registry
        ↓
request / current task / profile
        ↓
resolver
        ↓
small READY FRONTIER
```

Begin deterministic with explicit capability IDs, aliases, tags, and task bindings. Add embeddings only when registry size or ambiguity makes them useful.

Source: https://arxiv.org/abs/2603.20313

---

# 7. Workflow Orchestration

## 7.1 Multi-Agent Computer Use

**ArXiv:** 2606.01533  
**Date:** 2026-06-01  
**Authors:** Jing Yu Koh, Ruslan Salakhutdinov, Daniel Fried

### Evidence

The manager represents a long task as a directed acyclic graph. Each node has dependencies. Only nodes on the **ready frontier** are dispatched. The graph can be revised as execution produces new information.

### DE interpretation

The important primitive is the **DAG**, not the multi-agent implementation.

Pan can potentially use:

```text
BLOCKED
READY
ACTIVE
PASS
FAIL
SUPERSEDED
```

for bounded operations even with one executor.

### More Birds

The same state concept appears in Flat Packs and workflow nodes:

```text
READY ≠ ACTIVE
```

This may be a useful shared operational state primitive.

Source: https://arxiv.org/abs/2606.01533

---

# 8. Checkpoint, Recovery, and Dormancy

## 8.1 DeltaBox: Scaling Stateful AI Agents with Millisecond-Level Sandbox Checkpoint/Rollback

**ArXiv:** 2605.22781  
**Date:** 2026-05-21  
**Authors:** Yunpeng Dong et al.

### Evidence

DeltaBox exploits the high similarity between successive agent sandbox states. Instead of full duplication, it captures deltas in filesystem and process/runtime state.

### DE interpretation

This strengthens the use of **incremental state preservation**.

A future DE workspace need not snapshot an entire system image every time it changes.

Candidate:

```text
base capability state
+ durable user state
+ delta
+ delta
+ delta
```

with occasional consolidation when evidence justifies it.

Source: https://arxiv.org/abs/2605.22781

---

## 8.2 Crab: A Semantics-Aware Checkpoint/Restore Runtime for Agent Sandboxes

**ArXiv:** 2604.28138  
**Date:** 2026-04-30  
**Authors:** Tianyuan Wu et al.

### Evidence

Crab argues that agent frameworks know task semantics but not OS effects, while the OS knows effects but not task semantics. The paper reports that more than 75% of agent turns in evaluated workloads produced no recovery-relevant state.

### DE interpretation

DE should eventually distinguish:

```text
conversation event
operational event
state transition
recovery-relevant transition
```

Those are not equivalent.

### Candidate checkpoint rule

> Checkpoint on material durable-state transitions, not on every model turn.

Potential triggers include repository mutation, capability activation/deactivation, verified external effect, model/artifact version transition, permission transition, completion of a governed operation, transition into persistent service, or a new recovery dependency.

Source: https://arxiv.org/abs/2604.28138

---

# 9. Embodied Verification and Reality as Validator

## 9.1 ABot-AgentOS: A General Robotic Agent OS with Lifelong Multi-modal Memory

**ArXiv:** 2607.10350  
**Date:** 2026-07  
**Authors:** Jiayi Tian et al.

### Evidence

ABot-AgentOS sits above lower-level robot controllers and coordinates reasoning, context, skills/tools, verification, multi-modal memory, and edge/cloud execution. It also uses persistent source-grounded graph memory and a failure-driven evolution loop that produces gated runtime assets.

### DE interpretation

The robotics domain makes one convergence particularly valuable:

> Language-level belief that an operation succeeded is not enough.

The system needs environment verification.

DE equivalent:

```text
request
→ action
→ claimed result
→ external evidence
→ validator
→ accepted result
```

This is a direct operational interpretation of:

> Reality is final validator.

Source: https://arxiv.org/abs/2607.10350

---

# 10. Failure as Improvement Signal

## 10.1 Learning from Failure: Inference-Time Self-Improvement for Computer-Use Agents

**ArXiv:** 2606.31270  
**Date:** 2026-06-30  
**Authors:** Xueqiao Sun et al.

### Evidence

The authors use failed trajectories to diagnose failure modes, propose corrections, generate code patches, and lightly verify those patches. Their reported OSWorld evaluation improves task success without additional model training.

### DE interpretation

This reinforces the existing DE doctrine that **operational failures are evidence**.

A failed run should not directly rewrite canonical capability.

Instead:

```text
FAILURE
→ evidence package
→ diagnosis
→ bounded candidate repair
→ validation
→ compare against prior state
→ promote/reject
```

Source: https://arxiv.org/abs/2606.31270

---

## 10.2 SENTINEL: Failure-Driven Reinforcement Learning for Tool-Using Agents

**ArXiv:** 2606.12908  
**Date:** 2026-06-11  
**Authors:** Ziyi Wang et al.

### Evidence

SENTINEL turns recurring rollout failures into targeted training tasks rather than continuing to train only on a static task distribution.

### DE interpretation

Failure can serve two distinct roles:

1. repair evidence for the current capability;
2. test-generation evidence for future validation.

This suggests a future DE object:

```text
Failure Record
├── observed failure
├── reproduction conditions
├── suspected primitive
├── candidate cause
├── generated regression test
├── repair candidate
└── validation result
```

Source: https://arxiv.org/abs/2606.12908

---

# 11. Profile-Conditioned Interface Research

## 11.1 Efficient Personalization of Generative User Interfaces

**ArXiv:** 2604.09876  
**Date:** 2026-04-10  
**Authors:** Yi-Hao Peng et al.

### Evidence

The study finds substantial disagreement among trained designers about interface preferences. The authors demonstrate that lightweight user preference feedback can improve personalized generation.

### DE interpretation

This supports profile-conditioned projections and warns against assuming a universal good interface.

A DE Operator Profile should preserve:

```text
ASSERTED
OBSERVED
INFERRED
UNKNOWN
```

instead of collapsing all four into "user preference."

### Candidate interface rule

Start with deterministic layouts and explicit profile fields. Introduce generative variation only inside bounded, reviewable constraints.

Source: https://arxiv.org/abs/2604.09876

---

## 11.2 PersonalAlign: Hierarchical Implicit Intent Alignment for Personalized GUI Agents

**ArXiv:** 2601.09636  
**Date:** 2026-01-14  
**Authors:** Yibo Lyu et al.

### Evidence

The paper studies GUI agents that use long-term user records to resolve omitted preferences and routines.

### DE interpretation

This supports a future system in which:

```text
"Open my studio"
```

can resolve missing details from the Operator Profile.

But past behavior may support an inference; it does not automatically create authority.

Source: https://arxiv.org/abs/2601.09636

---

# 12. Constrained Inference and Resource Residency

## 12.1 DUAL-BLADE: Dual-Path NVMe-Direct KV-Cache Offloading for Edge LLM Inference

**ArXiv:** 2604.26557  
**Date:** 2026-04-29  
**Authors:** Bodon Jeong et al.

### Evidence

DUAL-BLADE dynamically manages transformer KV-cache residency between memory and NVMe-backed storage. The system uses distinct storage paths depending on runtime memory availability and overlaps I/O with accelerator transfer.

### DE interpretation

The important conceptual change is:

> Weight residency is not the only residency problem.

Potentially schedulable state includes:

```text
weights
KV cache
activations
adapters
indexes
tool state
workspace state
models
```

This strengthens the Priority AI question:

> Which computational state must be resident, where, when, and for how long?

Source: https://arxiv.org/abs/2604.26557

---

## 12.2 Is One Layer Enough? Training A Single Transformer Layer Can Match Full-Parameter RL Training

**ArXiv:** 2607.01232  
**Date:** 2026-07-01  
**Authors:** Zijian Zhang et al.

### Evidence

Across seven tested models from Qwen3 and Qwen2.5 families, multiple RL methods, and multiple task domains, the authors report that RL gains are disproportionately concentrated in a small subset of transformer layers, often in the middle of the stack. Training one layer can recover much of the gain from full-parameter RL in their experiments.

### DE interpretation

This does **not** mean one layer is sufficient for inference.

It does support:

```text
functional necessity
    ≠
adaptation leverage
```

and the broader idea that not every component requires identical mutability.

Source: https://arxiv.org/abs/2607.01232

---

# 13. Cross-Domain Convergence

A deeper pattern now appears across several independent systems.

The working name below is **provisional** and should not be promoted.

## Candidate pattern: Deferred Realization

```text
preserve possibility durably
        ↓
do not instantiate it
        ↓
observe current intent/reality
        ↓
resolve only what applies
        ↓
instantiate bounded competence
        ↓
verify consequence
        ↓
preserve durable result
        ↓
release unnecessary runtime resources
```

The same pattern appears in:

```text
TOOLS
large catalog
→ retrieve small relevant subset

FLAT PACKS
large capability library
→ activate requested capability

WORKFLOW
large DAG
→ execute only ready frontier

MODEL
large computational state
→ keep only required state resident

INTERFACE
large possible feature set
→ expose current task surface

MEMORY
large historical corpus
→ recover only contextually valid evidence

BRANCHES
large institutional capability
→ bind bounded task authority

CHECKPOINTS
large running history
→ persist only recovery-relevant transitions
```

This is legitimate cross-domain convergence.

Useful candidate propositions:

> **Existence need not imply instantiation.**

> **Availability need not imply residency.**

> **Visibility need not imply execution.**

> **Change need not imply promotion.**

> **Memory need not imply consolidation.**

These are not yet doctrine.

They are increasingly well-supported experiment hypotheses.

---

# 14. Stronger Flat Pack Model

The frontier evidence makes the Flat Pack definition more precise.

## Candidate definition

> **A Flat Pack is a dormant, versioned, verifiable capability artifact that declares its dependency closure, authority requirements, activation contract, validation contract, durable-state behavior, and teardown contract.**

A pack is not an active process. A pack is not a permission grant. A pack is not a truth store. A pack does not become trusted by existing.

---

# 15. Candidate Flat Pack Manifest v0 — Research Sketch

Not an implementation schema.

```yaml
identity:
  capability_id:
  version:
  content_digest:
  source:
  lineage:

purpose:
  description:
  task_classes:
  non_goals:

compatibility:
  host_requirements:
  architecture:
  minimum_resources:
  optional_accelerators:

dependencies:
  - type:
    id:
    version:
    digest:
    source:
    required:
    transitive_policy:

authority_requirements:
  context_scope:
  filesystem_read:
  filesystem_write:
  network:
  devices:
  process:
  external_services:
  human_approval:

activation:
  entrypoint:
  preconditions:
  staged_requirements:
  anchor_capability:
  ready_surface:

runtime:
  expected_cpu:
  expected_ram:
  expected_gpu:
  expected_duration:
  persistence_default: false

inputs:
  schemas:

outputs:
  schemas:
  durable_outputs:

validation:
  preflight:
  runtime:
  postconditions:
  reality_checks:

failure:
  classes:
  quarantine_behavior:
  retry_policy:

checkpoint:
  triggers:
  durable_state:
  recovery_requirements:

teardown:
  stop_processes:
  release_devices:
  release_memory:
  verify_flush:
  checkpoint:
  post_teardown_validation:

provenance:
  build_evidence:
  validation_evidence:
  promotion_record:
```

The manifest should remain descriptive. Authority is resolved externally.

---

# 16. Capability State Machine

The frontier research strengthens the state machine developed in the Flat Pack synthesis:

```text
AVAILABLE
    known to registry

STAGED
    payload and dependency closure available locally

READY
    exposed to current workspace/task
    but not consuming heavyweight runtime

ACTIVE
    instantiated and executing

WAITING
    blocked on external event / user / dependency

PERSISTENT
    explicitly authorized to remain resident

CHECKPOINTING
    material state transition being made durable

TEARING_DOWN
    active resources being released

DORMANT
    no active instance; durable state survives

FAILED
    failure recorded; state accounted for

QUARANTINED
    capability or dependency prevented from activation
```

Crucially:

```text
READY ≠ ACTIVE
AVAILABLE ≠ TRUSTED
ACTIVE ≠ AUTHORIZED TO EVERYTHING
FAILED ≠ ERASED
```

---

# 17. Capability Registry

A DE capability registry should eventually be able to answer:

```text
What capabilities exist?
Which version is controlling?
Where did they come from?
What do they depend on?
What authority do they require?
What environments can run them?
What state are they in?
What tests have they passed?
What failures are known?
Which are deprecated?
Which are quarantined?
What replaces them?
```

The registry should **not** load every capability into model context. Resolution should produce a small bounded set.

---

# 18. Security Architecture Implication

The strongest security synthesis is:

```text
SEMANTIC SURFACE
what the model/user can see and request

        ≠

AUTHORITY SURFACE
what the runtime may affect

        ≠

RESOURCE PROVIDER
the mechanism that actually touches host/external state
```

This suggests a strong DE implementation boundary:

```text
Babbage / Pane / Model
        ↓ request
Governed runtime / operation resolver
        ↓ authorization
Primitive / provider
        ↓
Reality
```

A model prompt, skill manifest, or projection should never itself be the security boundary.

---

# 19. Memory Architecture Implication

The external memory evidence increasingly supports a layered memory system:

```text
SOURCE ARTIFACT
    immutable/referenceable
        ↓
EPISODIC SNAPSHOT
    what happened
        ↓
OBSERVATION
    bounded extraction
        ↓
RELATION / CLAIM TRAJECTORY
    how claims evolve
        ↓
DERIVED INTERPRETATION
    replaceable
        ↓
VALIDATED KNOWLEDGE
    promotion-gated
        ↓
PROJECTION
    audience/task-conditioned view
```

This architecture is especially compatible with Rowan, governance, repository archaeology, hardware state, research syntheses, and branch continuity.

---

# 20. Rowan Implication

The Rowan use case becomes stronger after this scan.

A future clinician/teacher/behavior-therapist system should not be generated from one giant "Rowan summary."

It should be generated from:

```text
source-grounded observations
+ context
+ chronology
+ claim trajectories
+ intervention/outcome relations
+ uncertainty
+ audience profile
+ projection contract
```

New evidence should not silently rewrite history.

Instead:

```text
ADD
REVISE
CONTRADICT
SUPERSEDE
DEPRECATE INTERPRETATION
```

should preserve lineage.

The professional projections remain derivatives.

---

# 21. Babbage / Pan Implication

The literature suggests a practical route for Pan that does not require immediate multi-agent complexity.

Pan can first become a governed state machine for work:

```text
goal
    ↓
task graph
    ↓
ready frontier
    ↓
bounded operation
    ↓
reality verification
    ↓
checkpoint
    ↓
next frontier
```

One executor is sufficient for the first proof.

Later, the same graph can support multiple local workers, different models, heterogeneous machines, branch dispatch, and external tools.

No architecture change is required merely to add parallelism.

---

# 22. Operator Profile Implication

Profile-conditioned projection remains well-supported, but the literature adds a warning.

Operator data should not become an undifferentiated profile blob.

Candidate scoped model:

```text
OPERATOR PROFILE
    durable person-level preferences/constraints

TASK PROFILE
    current bounded work

MACHINE PROFILE
    current hardware/runtime reality

SUBJECT PROFILE
    person/object being represented

AUDIENCE PROFILE
    intended recipient/context
```

Each statement can additionally carry:

```text
ASSERTED
OBSERVED
INFERRED
UNKNOWN
```

This keeps personalization useful without allowing inference to masquerade as reality.

---

# 23. Priority AI Implication

The emerging Priority AI question is becoming more precise.

Not:

> How much RAM does the model need?

But:

> **Which state must be resident, mutable, synchronized, precise, and fast at this moment?**

Potentially independently managed:

```text
model weights
selected layers
KV cache
adapters
retrieval indexes
tool catalog
capability manifests
workspace state
checkpoint state
datasets
```

This aligns with the Flat Pack principle:

> maximum available capability does not require maximum simultaneous residency.

---

# 24. Immediate Experiment Queue

These experiments should **not interrupt current repository ingestion**. They are ordered so construction precedes optimization.

## EXPERIMENT 1 — Extract One Existing Operation into a Capability Record

Use an already-working bounded operation. Candidate: current repository ingestion.

Record:

```text
identity
inputs
outputs
dependencies
runtime requirements
activation
validation
failure
teardown
provenance
```

Do not change execution yet.

**Purpose:** prove description before orchestration.

## EXPERIMENT 2 — Dormancy Measurement

Measure the capability when not active. Record CPU, RAM, processes, ports, GPU, network, and device locks. Then activate, measure, tear down, and measure again.

Acceptance:

> runtime returns to defined dormant baseline.

This is the first direct test of:

> **Ready is not running.**

## EXPERIMENT 3 — Dependency Closure / Lock Record

For one capability, enumerate model, binary, runtime, packages, system libraries, scripts, config, external service, and hardware predicates.

Pin or hash where technically meaningful.

Acceptance:

> clean reconstruction either resolves every dependency or fails explicitly.

## EXPERIMENT 4 — Authority Declaration

Add a non-authoritative declaration of required access and compare:

```text
required authority
granted authority
actual observed effects
```

Do not yet build an elaborate policy engine.

## EXPERIMENT 5 — Capability Registry

Register several capability descriptions. Do not activate them. Resolve a user request to a small READY subset.

Start deterministic with exact ID, aliases, tags, and task relations. Measure whether semantic retrieval is actually needed before adding embeddings.

## EXPERIMENT 6 — Ready Frontier

Represent a small operation as a DAG. Only allow nodes whose dependencies have passed to become READY.

Use one executor.

Acceptance:

> blocked work cannot run early.

## EXPERIMENT 7 — Semantic Checkpoint Trigger

During an operation, distinguish no durable change, durable change, and recovery-critical change. Compare naive per-step checkpointing with material-change checkpointing.

## EXPERIMENT 8 — Claim Trajectory Prototype

Select a bounded fact with version history. Possible targets: hardware state, one repository-state fact, or one Rowan observation category.

Represent:

```text
claim
source
introduced
revised
contradicted
superseded
current interpretation
```

Test retrieval of both current state and historical path.

## EXPERIMENT 9 — Rowan Projection Traceability

Using a bounded non-final observation set, produce clinician, teacher, and behavior-therapist projections.

Every material statement must resolve backward to evidence.

Acceptance:

> no claim without source path.

## EXPERIMENT 10 — Failure-to-Regression Loop

Take one genuine operational failure.

Generate:

```text
failure record
reproduction condition
candidate cause
regression test
candidate repair
before/after validation
```

Do not promote the repair unless the regression passes and prior capability is preserved.

---

# 25. Murders

## MURDER 1 — "Everyone else is building agent OSs, therefore DE should copy one."

No. Independent convergence increases confidence in primitives. It does not replace repository-first architecture.

## MURDER 2 — "Flat Pack = agent skill."

No. A Flat Pack may contain or reference skills. Its larger contract includes dependency closure, activation, authority requirements, state, validation, teardown, provenance, and reconstruction.

## MURDER 3 — "A valid pack is a trusted pack."

No. Security can fail in transitive dependencies.

## MURDER 4 — "Tool visibility grants authority."

No. Visibility is affordance. Authority must be resolved independently.

## MURDER 5 — "Memory improvement means continual summarization."

No. Recent evidence shows forced consolidation can destroy useful competence.

## MURDER 6 — "Latest memory overwrites old memory."

No. Use lineage and claim trajectories.

## MURDER 7 — "Semantic similarity means evidentiary relevance."

No. Context validity matters.

## MURDER 8 — "Every step deserves a checkpoint."

No. Checkpoint material state transitions.

## MURDER 9 — "Multi-agent architecture is required for Pan."

No. Prove the DAG and ready frontier with one executor.

## MURDER 10 — "Personalization can infer whatever makes the interface nicer."

No. Profile inference remains epistemically bounded.

## MURDER 11 — "If an agent says the operation succeeded, it succeeded."

No. Reality / external evidence must validate consequential effects.

## MURDER 12 — "All computational state deserves the same residency."

Unsupported. Residency should be measured and allocated according to actual need.

## MURDER 13 — "All model parameters deserve the same mutability."

Unsupported. Selective-layer RL evidence shows adaptation contribution can be highly non-uniform.

## MURDER 14 — "Self-improvement means unrestricted self-modification."

No. The strongest external systems increasingly use:

```text
failure
→ candidate
→ verifier
→ admission gate
```

which aligns with governed recursive improvement.

---

# 26. Candidate Cross-Domain Principle

The most important research hypothesis produced by this scan is:

> **Preserve competence durably. Realize it selectively. Validate its effects. Return it to dormancy when possible.**

This single pattern explains Flat Packs, tool discovery, taskbar capability surfaces, Pan ready frontiers, model loading, KV-cache residency, workspace reconstruction, branch activation, memory retrieval, and profile-conditioned interfaces.

It does **not** mean all of those are the same thing.

It means they may share a useful control principle.

---

# 27. Longitudinal Projection

If the current convergences survive implementation, the Difference Engine may be moving toward a computing model with the following structure:

```text
REALITY
hardware / people / world / current state
        ↓

DURABLE EVIDENCE AND GOVERNANCE
repository / sources / claims / authority / profiles
        ↓

CONTROL / RESOLUTION
Babbage / Pan / governed operations
        ↓

DORMANT COMPETENCE
Flat Packs / skills / models / tools / workflows
        ↓

READY FRONTIER
only the capabilities relevant now
        ↓

PROFILE-CONDITIONED PROJECTION
task-specific human environment
        ↓

BOUNDED EXECUTION
only required state becomes resident
        ↓

REALITY VERIFICATION
did the intended effect actually occur?
        ↓

EVIDENCE + CHECKPOINT
        ↓

TEARDOWN / DORMANCY
```

This would differ from conventional application-centric computing in a fundamental way.

Conventional desktop logic roughly says:

```text
install application
→ application exists on machine
→ user manages windows/processes/files/context
```

The DE direction says:

```text
preserve capability
→ user expresses activity
→ system resolves bounded competence
→ workspace reconstructs
→ only selected capability runs
→ durable state survives
→ runtime disappears
```

The operating environment becomes centered on **activity and recoverable competence**, not on permanent application residency.

---

# 28. Confidence Assessment

## High confidence — worth implementing small proofs

- capability identity;
- dependency manifests;
- authority separate from affordance;
- provenance;
- evidence preservation;
- source-grounded memory trajectories;
- ready vs active states;
- deterministic teardown;
- failure records;
- validation gates;
- profile epistemic labels;
- single-executor task DAG.

## Medium confidence — worth controlled experimentation

- Flat Pack as a unifying capability representation;
- semantic capability retrieval;
- material-change checkpoint policy;
- claim-trajectory repository objects;
- profile-conditioned workspace generation;
- content-addressed capability dependency store.

## Low confidence / long-range

- full DE operating-system projection;
- large heterogeneous compute orchestration;
- layer placement across multiple devices;
- autonomous capability evolution;
- dynamically generated complete workspaces;
- generalized recursive self-improvement.

Low confidence does **not** mean reject. It means prove prerequisites first.

---

# 29. Recommended Near-Term Path

Do not redesign the current ingestion machinery.

Instead:

```text
finish/stabilize current ingestion edge
        ↓
extract one operation as a descriptive capability contract
        ↓
measure dormant / active / teardown state
        ↓
record dependency closure
        ↓
build tiny registry
        ↓
prove ready frontier
        ↓
prove checkpoint / resume
        ↓
only then build profile-conditioned workspace
```

This path provides legs for legs.

It converts existing competence into reusable competence without requiring a new platform first.

---

# 30. Final Conclusion

The frontier scan materially increases confidence in several Difference Engine directions.

The strongest external convergence is not stylistic. It is structural.

Independent systems are increasingly separating:

```text
capability from execution
affordance from authority
memory from source evidence
current state from historical trajectory
task availability from active scheduling
checkpoint opportunity from checkpoint necessity
personalization from universal interface
model existence from model residency
adaptation from uniform parameter mutation
```

Those separations are exactly where the Difference Engine has repeatedly converged while being forced to survive limited hardware, interrupted sessions, repository drift, context loss, authority boundaries, human cognitive burden, and evolving architecture.

The most powerful synthesis remains:

> **Existence need not imply instantiation.**

And operationally:

> **Ready is not running.**

And architecturally:

> **Preserve competence durably. Realize it selectively. Validate its effects. Return it to dormancy when possible.**

This deserves construction.

It does not yet deserve constitutional promotion.

**Reality is the next validator.**

---

# 31. Primary Sources

1. Sharma, A. & Shah, D. (2026). **The Agent Operating System (AOS): A Reference Operating Architecture for Distributed Agentic Systems.** arXiv:2608.03214.  
   https://arxiv.org/abs/2608.03214

2. Sharma, A. & Shah, D. (2026). **Agent Operating Systems (AOS): Integrating Agentic Control Planes into, and Beyond, Traditional Operating Systems.** arXiv:2606.01508.  
   https://arxiv.org/abs/2606.01508

3. Steinder, G. & Franke, H. (2026). **Towards an Agent Operating System — Lessons from Classical and Cloud OS.** arXiv:2607.25076.  
   https://arxiv.org/abs/2607.25076

4. Zhang, Y. (2026). **Agent libOS: A Library-OS-Inspired Runtime for Long-Running, Capability-Controlled LLM Agents.** arXiv:2606.03895.  
   https://arxiv.org/abs/2606.03895

5. Jia, C. et al. (2026). **Skills Are Not Islands: Measuring Dependency and Risk in Agent Skill Supply Chains.** arXiv:2607.01136.  
   https://arxiv.org/abs/2607.01136

6. Pan, S. et al. (2026). **SkillGuard: A Permission-Centric Framework for Agent Skill Security.** arXiv:2606.03024.  
   https://arxiv.org/abs/2606.03024

7. Schmotz, D. et al. (2026). **Skill-Inject: Measuring Agent Vulnerability to Skill File Attacks.** arXiv:2602.20156.  
   https://arxiv.org/abs/2602.20156

8. Xu, A. et al. (2026). **SkillFab: An Agent-Native Skill Production Platform.** arXiv:2607.03780.  
   https://arxiv.org/abs/2607.03780

9. Li, Y. (2026). **Dynamic Agent Skills: A Lifecycle Survey and Taxonomy of Evolving Skill Libraries.** arXiv:2607.10113 / TMLR 2026.  
   https://arxiv.org/abs/2607.10113

10. Jia, C. et al. (2026). **VeriSkill: A Self-Evolution Framework for Program Verification Skills.** arXiv:2607.27733.  
    https://arxiv.org/abs/2607.27733

11. Zhang, D. et al. (2026). **Useful Memories Become Faulty When Continuously Updated by LLMs.** arXiv:2605.12978.  
    https://arxiv.org/abs/2605.12978

12. Yang, W. et al. (2026). **RaMem: Contextual Reinstatement for Long-term Agentic Memory.** arXiv:2606.22844.  
    https://arxiv.org/abs/2606.22844

13. Zhao, Z. et al. (2026). **Accurate and Efficient Long-Term Memory for LLM Agents (MOSAIC).** arXiv:2607.16211.  
    https://arxiv.org/abs/2607.16211

14. Sun, J. et al. (2026). **TrajWiki: Source-Grounded Memory Trajectories for Long-Horizon Dialogue Agents.** arXiv:2608.00967.  
    https://arxiv.org/abs/2608.00967

15. Mudunuri, S. et al. (2026). **Semantic Tool Discovery for Large Language Models: A Vector-Based Approach to MCP Tool Selection.** arXiv:2603.20313.  
    https://arxiv.org/abs/2603.20313

16. Koh, J. Y., Salakhutdinov, R., & Fried, D. (2026). **Multi-Agent Computer Use.** arXiv:2606.01533.  
    https://arxiv.org/abs/2606.01533

17. Dong, Y. et al. (2026). **DeltaBox: Scaling Stateful AI Agents with Millisecond-Level Sandbox Checkpoint/Rollback.** arXiv:2605.22781.  
    https://arxiv.org/abs/2605.22781

18. Wu, T. et al. (2026). **Crab: A Semantics-Aware Checkpoint/Restore Runtime for Agent Sandboxes.** arXiv:2604.28138.  
    https://arxiv.org/abs/2604.28138

19. Tian, J. et al. (2026). **ABot-AgentOS: A General Robotic Agent OS with Lifelong Multi-modal Memory.** arXiv:2607.10350.  
    https://arxiv.org/abs/2607.10350

20. Sun, X. et al. (2026). **Learning from Failure: Inference-Time Self-Improvement for Computer-Use Agents.** arXiv:2606.31270.  
    https://arxiv.org/abs/2606.31270

21. Wang, Z. et al. (2026). **SENTINEL: Failure-Driven Reinforcement Learning for Training Tool-Using Language Model Agents.** arXiv:2606.12908.  
    https://arxiv.org/abs/2606.12908

22. Peng, Y.-H. et al. (2026). **Efficient Personalization of Generative User Interfaces.** arXiv:2604.09876.  
    https://arxiv.org/abs/2604.09876

23. Lyu, Y. et al. (2026). **PersonalAlign: Hierarchical Implicit Intent Alignment for Personalized GUI Agent with Long-Term User-Centric Records.** arXiv:2601.09636.  
    https://arxiv.org/abs/2601.09636

24. Jeong, B. et al. (2026). **DUAL-BLADE: Dual-Path NVMe-Direct KV-Cache Offloading for Edge LLM Inference.** arXiv:2604.26557.  
    https://arxiv.org/abs/2604.26557

25. Zhang, Z. et al. (2026). **Is One Layer Enough? Training A Single Transformer Layer Can Match Full-Parameter RL Training.** arXiv:2607.01232.  
    https://arxiv.org/abs/2607.01232

---

# 32. Research Disposition

**KEEP**

- external evidence map;
- dormant capability hypothesis;
- authority/affordance separation;
- dependency closure;
- source-grounded memory;
- claim trajectories;
- ready frontier;
- reality verification;
- failure-driven bounded repair;
- profile epistemics;
- resource residency as a scheduling problem.

**QUEUE**

- capability manifest proof;
- dependency lock record;
- dormancy measurements;
- capability registry;
- ready-frontier DAG;
- semantic checkpoint trigger;
- claim trajectory prototype;
- Rowan projection traceability test;
- failure-to-regression loop.

**DO NOT PROMOTE**

- provisional term "Deferred Realization";
- exact manifest schema;
- exact runtime implementation;
- specific external AOS architecture;
- new DE Linux distribution;
- autonomous capability evolution;
- automatic skill generation;
- wholesale adoption of graph memory;
- cross-node layer distribution.

**NEXT VALIDATOR**

- working repository operations.
