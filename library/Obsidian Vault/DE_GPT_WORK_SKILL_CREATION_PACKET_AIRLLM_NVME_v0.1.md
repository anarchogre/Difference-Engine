# Difference Engine — GPT Work Skill-Creation Packet
## Storage-Backed LLM / AirLLM / Linux NVMe Performance Diagnostics

**Version:** 0.1  
**Date:** 2026-08-16  
**Status:** Skill-construction input / retained project artifact  
**Purpose:** Paste the first section into **Skills → Create → Create with chat** in ChatGPT Work. This file also preserves the complete design rationale, boundaries, outputs, and acceptance criteria for the Difference Engine.

---

# A. PASTE THIS INTO GPT WORK — SKILL CREATOR INPUT

Build me a **small composable suite of technical diagnostic Skills**, not one giant end-to-end Skill.

The suite is for deep Linux systems-performance work around **storage-backed local LLM inference**, especially AirLLM-style layer-wise model loading and inference on resource-constrained machines.

The immediate live use case is a Linux machine with an NVMe SSD where an AirLLM-style inference path is showing roughly **40 ms end-to-end stalls that appear to correlate with storage activity**. The system is CPU- and RAM-constrained, and the goal is to localize the delay before tuning anything.

The critical rule for every Skill is:

> **Do not call an observed stall “NVMe media latency” until evidence localizes the delay to the block/device layer.**

A 40 ms pause observed by the application may instead come from:

- Python/runtime behavior,
- model shard lookup,
- file open/close behavior,
- deserialization,
- allocation,
- page faults,
- page cache,
- mmap behavior,
- readahead,
- filesystem work,
- block queueing,
- Linux I/O scheduler behavior,
- NVMe power-state transitions,
- interrupts,
- CPU scheduling,
- memory pressure,
- swap,
- thermal throttling,
- competing I/O,
- or actual device latency.

The Skills must preserve that distinction.

## General Skill-design rules

Create **six separate Skills** so they can be used independently or together.

If the Skills UI only allows one Skill to be created at a time, create them in the numbered order below, beginning with **`de-nvme-stall-forensics`**. Do not merge them merely because the UI creates one at a time.

For every Skill:

1. Create a clear name and trigger description.
2. Create a `SKILL.md` with:
   - job-to-be-done,
   - required inputs,
   - optional inputs,
   - explicit boundaries,
   - numbered workflow,
   - output contract,
   - final validation checks.
3. Add helper scripts/resources only when they improve deterministic execution.
4. Scripts must be:
   - read-only by default,
   - safe on a live workstation,
   - explicit about requiring `sudo`,
   - explicit about any command that can modify state,
   - unable to run destructive `fio` workloads against a block device,
   - unable to change kernel, scheduler, NVMe power settings, mount options, swap, sysctls, governors, or packages unless the operator separately and explicitly requests that mutation.
5. Do not install software automatically.
6. Do not change system configuration automatically.
7. Do not optimize before localization.
8. Do not infer hardware/model/runtime details that were not supplied or observed.
9. Separate:
   - **OBSERVATION**
   - **EVIDENCE**
   - **INTERPRETATION**
   - **HYPOTHESIS**
   - **NEXT DISCRIMINATING TEST**
10. Preserve exact commands, versions, hashes, timestamps, and important failures when supplied.
11. Prefer one next discriminating test over a large menu of speculative tweaks.
12. Every recommendation must state which layer of the stack it is intended to test or change.
13. Every performance conclusion must distinguish:
   - cold run,
   - warm run,
   - page-cache state,
   - model/runtime version,
   - kernel,
   - current memory pressure,
   - competing I/O,
   - and experiment conditions when known.
14. Use latency distributions where possible:
   - minimum,
   - median / p50,
   - p95,
   - p99,
   - maximum,
   - sample count.
   Do not rely on average latency alone.
15. Preserve a known-good baseline.
16. Change one variable per controlled experiment unless explicitly testing an interaction.
17. Fail explicitly with `UNKNOWN` when the evidence cannot localize a delay.
18. Do not manufacture certainty because a tuning action is available.
19. Treat operational failures as evidence.
20. Favor deterministic, repeatable experiments over clever one-off tuning.

---

# Skill 1 — `de-nvme-stall-forensics`

## Job

Localize a suspicious storage-correlated latency stall through the Linux I/O stack before recommending optimization.

## Trigger examples

Use this Skill when the operator says things such as:

- “We have a 40 ms NVMe stall.”
- “Why does AirLLM pause between layers?”
- “Storage appears to be stalling inference.”
- “Is this the SSD, page cache, Python, or the kernel?”
- “Trace this I/O latency.”
- “Find the layer that owns this delay.”

## Required inputs

Accept any subset of:

- exact inference command,
- timestamps,
- application logs,
- per-layer timing,
- `strace` output,
- `perf` output,
- `iostat`,
- `pidstat`,
- `vmstat`,
- PSI,
- `blktrace` / block tracepoint output,
- ftrace,
- bpftrace/eBPF output,
- NVMe SMART/error/power data,
- kernel version,
- filesystem/mount data,
- source snippets,
- model shard layout,
- RAM/swap state.

If critical identity is absent, ask only for the minimum information required to run the next discriminating test.

## Required diagnostic ladder

Follow this order unless evidence justifies skipping a step:

### Stage 0 — Identify the run

Capture or request:

- kernel,
- machine/node,
- NVMe device,
- filesystem,
- model,
- model hash/version if available,
- AirLLM/runtime version or commit,
- exact command,
- cold/warm status,
- RAM/swap,
- concurrent workloads.

### Stage 1 — Reproduce the stall

Establish:

- stall magnitude,
- frequency,
- whether it occurs at consistent model/layer boundaries,
- whether it appears in cold only, warm only, or both.

### Stage 2 — Find the highest layer where the stall exists

Distinguish:

```text
application/runtime
→ syscall
→ page fault/page cache
→ filesystem
→ block layer
→ NVMe driver/controller/device
```

Do not jump directly to the device.

### Stage 3 — Correlate timelines

Where possible align:

- application layer timestamp,
- syscall duration,
- major/minor faults,
- block issue time,
- block completion time,
- CPU deschedule intervals,
- PSI pressure,
- NVMe/device telemetry.

### Stage 4 — Classify the stall

Output one or more:

- `APPLICATION_RUNTIME`
- `DESERIALIZATION_OR_ALLOCATION`
- `PAGE_FAULT`
- `PAGE_CACHE_MISS`
- `FILESYSTEM`
- `BLOCK_QUEUE`
- `DEVICE`
- `POWER_STATE`
- `CPU_SCHEDULING`
- `MEMORY_PRESSURE`
- `SWAP`
- `THERMAL`
- `COMPETING_IO`
- `MULTI_FACTOR`
- `UNKNOWN`

### Stage 5 — Give one discriminating test

Select the smallest next experiment that would most sharply separate the surviving hypotheses.

### Stage 6 — Only after localization, propose optimization

Never recommend changing:

- I/O scheduler,
- readahead,
- power state,
- mount options,
- swap,
- kernel,
- AirLLM source,
- model sharding,
- prefetch,
- or caching

until the evidence points to that layer.

## Useful read-only tools to understand

The Skill should know how to interpret and, when the environment permits, propose safe commands using tools such as:

- `iostat -x`
- `pidstat`
- `vmstat`
- `/proc/pressure/{cpu,memory,io}`
- `lsblk`
- `findmnt`
- `/sys/block/*/queue/*`
- `nvme list`
- `nvme smart-log`
- `perf stat`
- `perf record`
- `perf sched`
- `strace -ttt -T`
- ftrace
- Linux block tracepoints
- bpftrace/eBPF
- `blktrace` where available
- read-only `fio` tests against a designated scratch file only

Do not assume any of these is installed.

## Output contract

Return:

```text
STALL FORENSICS RECEIPT

RUN ID:
OBSERVED STALL:
REPRODUCED:
COLD/WARM:
LOCALIZED LAYER:
CONFIDENCE:
EVIDENCE:
SURVIVING HYPOTHESES:
ELIMINATED HYPOTHESES:
MISSING EVIDENCE:
NEXT DISCRIMINATING TEST:
DO NOT TUNE YET:
```

---

# Skill 2 — `airllm-critical-path-profiler`

## Job

Measure the end-to-end AirLLM-style layer/shard critical path and determine exactly where time is spent.

## Trigger examples

- “Profile AirLLM layer loading.”
- “Where is the time between layers going?”
- “Measure the storage-backed 14B path.”
- “Which part of model activation is blocking?”
- “Compare cold and warm layer load.”

## Required conceptual path

Instrument or reconstruct:

```text
layer/shard requested
→ pathname/shard resolved
→ open
→ read / mmap / page fault
→ bytes available
→ deserialize / tensor materialize
→ allocation / copy
→ tensor usable
→ layer compute
→ release / retain
→ next layer requested
```

Do not assume every runtime uses every stage.

Discover the actual code path.

## Required outputs

Produce per-stage and per-layer latency where evidence permits:

```text
layer
request time
I/O start
I/O complete
materialization complete
compute start
compute complete
bytes read
fault count
cold/warm
```

Calculate/report p50/p95/p99/max for repeated layers/runs when enough samples exist.

Distinguish:

- synchronous loading,
- asynchronous loading,
- prefetch overlap,
- cache hits,
- cache misses,
- repeated opens,
- redundant deserialization,
- redundant allocation/copies.

## Required comparison matrix

When possible compare:

```text
cold first run
warm page-cache run
second process run
same process repeated inference
```

Do not clear caches automatically.

If cache clearing would be diagnostically useful, explain the need and request explicit operator approval because it mutates system state.

## Output contract

```text
AIRLLM CRITICAL PATH

BOTTLENECK STAGE:
BOTTLENECK SHARE:
STALL CORRELATION:
COLD PATH:
WARM PATH:
LAYER VARIANCE:
I/O OVERLAP:
PREFETCH OBSERVED:
REDUNDANT WORK:
NEXT SOURCE/TRACING TARGET:
```

---

# Skill 3 — `linux-io-trace-interpreter`

## Job

Interpret Linux performance traces across userspace, VM/page cache, filesystem, scheduler, block layer, and NVMe without confusing them.

## Trigger examples

- “Read this perf trace.”
- “Interpret these block tracepoints.”
- “What does this bpftrace output mean?”
- “Correlate strace with iostat.”
- “The process paused but the disk looks fast.”

## Required behavior

Given trace/log output:

1. Establish clock/timebase where possible.
2. Separate:
   - wall-clock stall,
   - CPU time,
   - descheduled time,
   - I/O wait,
   - page-fault handling,
   - device service time.
3. Identify whether device latency accounts for the whole application stall.
4. Highlight intervals that are missing from the observed stack.
5. Refuse to assign missing time to NVMe without evidence.
6. Detect queueing versus service time where data permits.
7. Detect whether pressure/competition changes the interpretation.
8. Explain tail events separately from steady-state behavior.

## Required output

```text
TRACE INTERPRETATION

TOTAL OBSERVED STALL:
USPACE ACCOUNTED:
VM/PAGE-CACHE ACCOUNTED:
FILESYSTEM ACCOUNTED:
BLOCK ACCOUNTED:
DEVICE ACCOUNTED:
CPU DESCHEDULE ACCOUNTED:
UNACCOUNTED:
LIKELY OWNER:
CONFIDENCE:
NEXT TRACEPOINT / TOOL:
```

---

# Skill 4 — `llm-offload-experiment-designer`

## Job

Design controlled experiments for storage-backed / offloaded local LLM inference.

## Trigger examples

- “Test whether readahead helps.”
- “Compare AirLLM configs.”
- “Does prefetch fix this?”
- “Benchmark cold vs warm.”
- “Test scheduler A vs B.”
- “Build me an experiment for the 40 ms stalls.”

## Required principles

Every experiment must define:

- hypothesis,
- independent variable,
- controlled variables,
- workload,
- run count,
- cache state,
- expected discriminating outcome,
- metrics,
- stop conditions,
- rollback,
- interpretation criteria.

Prefer one variable at a time.

Require a baseline.

Measure at least where relevant:

- model size,
- shard/layer size,
- storage bytes,
- TTFT,
- time between tokens,
- tokens/sec,
- activation time,
- per-layer load,
- p50/p95/p99/max stall,
- peak RAM,
- swap,
- major/minor faults,
- PSI CPU/memory/I/O,
- disk throughput,
- queue depth,
- device latency,
- CPU utilization,
- temperature/throttling,
- correctness/output equivalence.

Never define success solely as “program completed.”

A valid result may be:

```text
TECHNICALLY_EXECUTABLE
BUT
OPERATIONALLY_TOO_SLOW
```

## Output contract

Return an experiment card suitable for direct execution later:

```text
EXPERIMENT ID:
QUESTION:
HYPOTHESIS:
BASELINE:
CHANGE:
CONSTANTS:
RUNS:
MEASUREMENTS:
PASS:
FAIL:
AMBIGUOUS:
STOP CONDITION:
ROLLBACK:
EXPECTED INFORMATION GAIN:
```

---

# Skill 5 — `airllm-source-archaeology`

## Job

Trace an observed performance symptom into the exact AirLLM/runtime source code and produce a source→runtime→system-call hypothesis map.

The canonical upstream repository to recognize is:

```text
https://github.com/lyogavin/airllm
```

But always identify the exact repository, branch/commit/version actually under test before making source claims.

## Trigger examples

- “Find where AirLLM opens layer files.”
- “Trace this delay into source.”
- “Where could this sync barrier be?”
- “Is AirLLM reopening every shard?”
- “Find the load path.”

## Required source questions

Inspect only what the actual version supports, but investigate:

- shard/layer resolution,
- file open patterns,
- `torch.load`,
- safetensors or other serialization,
- `mmap`,
- Python file I/O,
- allocation,
- tensor copies,
- device transfers,
- pinned/memory-locked buffers,
- synchronization,
- per-layer cleanup,
- cache retention,
- prefetch,
- asynchronous execution,
- repeated metadata work,
- repeated deserialization,
- garbage collection,
- context managers / close behavior.

## Required method

Start from the observed runtime event and walk backward/forward through code.

Do not start by searching for random “optimization opportunities.”

Output:

```text
OBSERVED EVENT
→ SOURCE FUNCTION
→ CALLED FUNCTION
→ PYTHON/RUNTIME OPERATION
→ EXPECTED SYSCALL/FAULT/I/O EFFECT
→ TRACE EVIDENCE NEEDED
```

When code and trace disagree, preserve the conflict.

## Output contract

```text
SOURCE ARCHAEOLOGY MAP

REPOSITORY:
COMMIT/VERSION:
SYMPTOM:
ENTRY FUNCTION:
CRITICAL FUNCTIONS:
I/O CALL PATH:
ALLOCATION/COPY PATH:
SYNCHRONIZATION POINTS:
CACHE/PREFETCH PATH:
LIKELY TRACE SIGNATURE:
EVIDENCE FOR:
EVIDENCE AGAINST:
NEXT CODE/TRACE TARGET:
```

---

# Skill 6 — `de-performance-receipt`

## Job

Turn every performance experiment into a durable, comparable, machine-readable receipt.

## Trigger examples

- “Record this run.”
- “Make a performance receipt.”
- “Compare this against baseline.”
- “Preserve this experiment.”
- “Package the evidence.”

## Required receipt fields

Where available:

```yaml
experiment:
  id:
  timestamp:
  node:
  operator_request:
  hypothesis:

system:
  kernel:
  distro:
  cpu:
  ram:
  swap:
  nvme:
  filesystem:
  mount_options:
  io_scheduler:
  power_state:
  cpu_governor:
  temperatures:

runtime:
  airllm_repo:
  airllm_commit:
  python:
  torch:
  transformers:
  safetensors:
  command:
  environment_digest:

model:
  identity:
  revision:
  hash:
  format:
  size:
  shard_layout:

run_state:
  cold_or_warm:
  page_cache_state:
  concurrent_workloads:
  free_ram:
  psi:
  swap_state:

metrics:
  activation:
  ttft:
  tokens_per_second:
  per_layer:
  stall_distribution:
  bytes_read:
  faults:
  disk:
  cpu:
  temperature:

result:
  observation:
  evidence:
  interpretation:
  hypothesis_status:
  regression:
  next_test:

provenance:
  commands:
  raw_artifacts:
  hashes:
```

Unknown fields stay `UNKNOWN` or absent. Do not fill them from assumptions.

## Required outputs

1. Human-readable concise receipt.
2. Machine-readable JSON or YAML.
3. Baseline delta when a baseline receipt is supplied.

Do not rewrite raw evidence.

Reference it.

---

# Shared research principles to encode in the Skills

Current systems research on storage-backed/offloaded LLM execution repeatedly points toward:

- asynchronous overlap of I/O and compute,
- proactive prefetch,
- explicit cache/residency management,
- memory-tier movement,
- scheduling,
- and measurement of critical-path/tail latency

as important performance levers.

That research is **hypothesis-generating**, not proof about the current machine.

The Skills must always return to live evidence.

Particularly relevant research directions include:

- heterogeneous/offloaded inference where I/O becomes the bottleneck,
- asynchronous prefetch and tensor preservation,
- per-layer and per-pipeline latency decomposition,
- NVMe/Linux I/O scheduler tail-latency behavior,
- cache and memory-tier migration,
- per-request/per-layer I/O tracing.

Never recommend a research technique simply because a paper reported a speedup on different hardware.

---

# Cross-Skill handoff contract

When one Skill reaches its boundary, it should name the next Skill rather than silently doing a different job.

Examples:

```text
de-nvme-stall-forensics
    finds delay above block layer
→ airllm-source-archaeology

de-nvme-stall-forensics
    needs better timing evidence
→ linux-io-trace-interpreter

airllm-source-archaeology
    identifies synchronous loading hypothesis
→ llm-offload-experiment-designer

llm-offload-experiment-designer
    experiment completed
→ de-performance-receipt

airllm-critical-path-profiler
    confirms a repeatable I/O-stage stall
→ de-nvme-stall-forensics
```

Do not require automatic cross-Skill execution if the Skills framework does not support it.

The handoff can simply be an explicit recommendation.

---

# Shared final quality checks

Before any of these Skills finishes, verify:

```text
[ ] Did I separate observation from interpretation?
[ ] Did I distinguish application stall from actual NVMe service time?
[ ] Did I preserve UNKNOWN where evidence is missing?
[ ] Did I avoid tuning before localization?
[ ] Did I preserve cold/warm/cache state?
[ ] Did I use tail latency, not average alone?
[ ] Did I identify the exact runtime/model/kernel where possible?
[ ] Did I avoid destructive commands?
[ ] Did I avoid installing/changing system configuration automatically?
[ ] Did I choose one next discriminating test?
[ ] Did I preserve command/output provenance?
[ ] Did I state what layer of the stack the conclusion concerns?
```

---

# Desired package order

Build/install in this order:

```text
1. de-nvme-stall-forensics
2. linux-io-trace-interpreter
3. airllm-critical-path-profiler
4. airllm-source-archaeology
5. llm-offload-experiment-designer
6. de-performance-receipt
```

The first Skill is the immediate priority.

After drafting each Skill, show me its:

- name,
- trigger description,
- `SKILL.md`,
- supporting resources/scripts,
- safety boundary,
- example input,
- example output,
- validation checklist.

Do not simplify away the evidence discipline in order to make the Skill shorter.

---

# B. RETAINED DIFFERENCE ENGINE NOTES — DO NOT NEED TO PASTE IF SECTION A IS USED

## Why this is a Skill suite instead of one large Skill

The diagnostic problem crosses several technical layers:

```text
LLM / AirLLM behavior
Python/runtime
memory management
page cache
filesystem
Linux block layer
NVMe
CPU scheduler
resource pressure
experiment design
provenance
```

A monolithic “optimize AirLLM” Skill would tend to jump directly from symptom to tuning.

The separate Skills force the investigation to preserve causal boundaries.

This is consistent with the Difference Engine operating order:

```text
Reality
→ Constraint
→ Observation
→ Evidence
→ Knowledge
→ Governance
→ Operations
→ Implementation
```

For performance work:

```text
symptom
→ measurement
→ localization
→ hypothesis
→ discriminating experiment
→ validation
→ tuning
→ regression test
→ durable receipt
```

---

# C. Immediate Diagnostic Doctrine for the ~40 ms Stall

The current phrase should be:

> **~40 ms storage-correlated end-to-end inference stall**

until tracing proves something narrower.

Do not yet call it:

```text
40 ms NVMe device latency
```

A useful decomposition is:

```text
T_stall =
    T_runtime
  + T_fault/cache
  + T_filesystem
  + T_queue
  + T_device
  + T_deschedule
  + T_other
```

The objective is not initially to minimize `T_stall`.

The first objective is to estimate which terms actually exist and dominate.

Only then optimize.

---

# D. Recommended Timing Correlation Model

A useful trace should eventually allow a row similar to:

| Event | Start | End | Duration | Evidence source |
|---|---:|---:|---:|---|
| layer requested | | | | AirLLM instrumentation |
| open/read/mmap | | | | strace/runtime |
| major fault | | | | perf/eBPF |
| block request issued | | | | block tracepoint |
| NVMe request completed | | | | block/NVMe trace |
| tensor materialized | | | | AirLLM instrumentation |
| layer compute | | | | runtime timing |

If:

```text
application pause = 40 ms
block device request = 0.5 ms
```

then the missing ~39.5 ms is not “the SSD” merely because the run accesses the SSD.

That missing time becomes the next investigation target.

---

# E. Cold/Warm Matrix

At minimum preserve:

| Run class | New process? | Page cache expected? | Model/runtime same? | Purpose |
|---|---|---|---|---|
| cold-ish initial | yes | uncertain/cold | yes | first activation |
| warm process | same | warm | yes | repeated inference |
| new process warm cache | yes | warm | yes | separate Python init from disk |
| controlled cold | yes | deliberately cold | yes | only with explicit operator approval for cache mutation |

Never silently clear caches.

---

# F. Potential Layers Worth Testing Later — Not Recommendations Yet

Only after evidence localizes the issue:

## Runtime/source layer

Possible test families:

- asynchronous prefetch,
- deeper lookahead,
- shard batching,
- fewer opens,
- retained file descriptors,
- reduced serialization work,
- retained tensors,
- buffer reuse,
- memory locking/pinning where applicable,
- fewer copies,
- overlap load with compute.

## Linux VM/page-cache layer

Possible test families:

- readahead behavior,
- `madvise`/`posix_fadvise`,
- mmap versus explicit reads,
- page-fault patterns,
- cache residency,
- memory pressure,
- THP implications,
- swap competition.

## Block layer

Possible test families:

- queue depth,
- I/O scheduler,
- competing workload interference,
- request size,
- sequentiality.

## NVMe/controller

Possible test families:

- power states,
- thermal throttling,
- SMART/error logs,
- firmware,
- APST behavior,
- controller reset/error events.

Again:

> These are test families, not current diagnoses.

---

# G. Research Basis Preserved for the Skill Suite

Relevant systems research surfaced during design:

## Storage-backed / offloaded LLM inference

- **HeteGen** — heterogeneous parallel inference on constrained devices; attacks I/O bottlenecks with asynchronous overlap.
- **FlexInfer** — flexible memory/offload design using asynchronous prefetch, memory locking, and tensor preservation.
- **SYMPHONY** — LLM state/KV movement and scheduling to move memory work off critical paths.
- **CLO** — emphasizes CPU-side cache/offload overhead, transfer behavior, prefetch, and zero-copy system design.
- **LatencyPrism** — decomposes inference latency across a pipeline and emphasizes anomaly/tail behavior rather than average-only performance.
- **lm-Meter** — phase/kernel-level local-model latency profiling.

## Linux / NVMe

- **BFQ, Multiqueue-Deadline, or Kyber? Performance Characterization of Linux Storage Schedulers in the NVMe Era** — demonstrates that storage scheduler and CPU/storage-stack effects can materially alter tail latency under contention; do not assume device service time is the sole latency source.
- **ReLayTracer** — per-request, per-layer I/O profiling aimed at locating where kernel I/O latency actually occurs.

These papers inform what to measure.

They do not establish the cause of the current stall.

---

# H. AirLLM Source Anchor

Recognize:

```text
lyogavin/airllm
```

as the upstream AirLLM repository.

Before source archaeology:

```text
verify exact repository
verify branch
verify commit
verify installed package/source path
verify whether local modifications exist
```

A current upstream `main` branch may not equal the version under test.

---

# I. Future Skills That May Be Worth Adding Later

Do not ask GPT Work to build these in the first batch unless the first six expose a recurring need.

Possible future Skills:

```text
de-kernel-inference-profiler
    correlate inference with scheduler/VM/kernel behavior

de-nvme-power-state-profiler
    isolate APST/power-transition latency

de-model-shard-layout-optimizer
    analyze shard sizes/order/access sequence after tracing proves layout matters

de-cgroup-inference-budgeter
    create bounded resource envelopes for resident and deep-inference lanes

de-kernel-candidate-benchmark
    compare DE kernel candidates against an immutable workload matrix

de-inference-regression-gate
    prevent a tuning change from silently degrading touch/UI/network/recovery

de-sched-ext-experiment
    later, after normal cgroup/scheduler evidence exists
```

Construction should follow observed need.

---

# J. Acceptance Criteria for the Initial Skill Suite

The suite is successful when a new chat can receive a symptom such as:

```text
“AirLLM pauses around 40 ms between some layer loads.”
```

and the Skills do **not** immediately respond with:

```text
change the I/O scheduler
disable APST
increase readahead
buy a faster SSD
```

Instead they should produce:

```text
1. exact observed symptom
2. missing identity/evidence
3. stack-localization plan
4. safe measurement
5. causal classification
6. one discriminating next test
7. only then a bounded optimization experiment
8. durable performance receipt
```

The deepest success condition is:

> **The Skills make it difficult to tune the wrong layer.**

---

# K. Final Reduction

The entire Skill suite can be remembered as:

```text
FIND THE STALL
→ LOCATE THE LAYER
→ TRACE THE CRITICAL PATH
→ READ THE SOURCE
→ DESIGN ONE TEST
→ RECORD THE RESULT
```

or:

```text
de-nvme-stall-forensics
→ linux-io-trace-interpreter
→ airllm-critical-path-profiler
→ airllm-source-archaeology
→ llm-offload-experiment-designer
→ de-performance-receipt
```

Do not optimize the story.

Measure the machine.
