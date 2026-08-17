# DIFFERENCE_ENGINE_ROADMAP.md
## The Difference Engine — 4-Phase Execution Roadmap

**Document Class:** Canonical Root Artifact  
**Version:** 0.1-DRAFT  
**Status:** Phase 2 Synthesis Output — Pending Review & Lock  
**Canonical Location:** `/.claude/DIFFERENCE_ENGINE_ROADMAP.md`  
**Governing Document:** ADE_Constitution_v1.4.md  
**Companion Document:** `/BLUEPRINT.md`  
**Engineering Protocol:** Execution Before Refinement — working artifacts precede refinement passes

---

## ROADMAP OVERVIEW

```
PHASE 1: FOUNDATION                [STATUS: COMPLETE — FROZEN as Foundation Gamma]
PHASE 2: CORE LOGIC CODIFICATION   [STATUS: ACTIVE]
PHASE 3: MOBILE EXECUTION LAYER    [STATUS: PENDING — blocked on Phase 2 lock]
PHASE 4: FEEDBACK + LONGITUDINAL   [STATUS: FUTURE]
```

**Absolute Rule:** Phases are sequential and non-skippable. No mobile UI, no Android code, no APK targeting until Phase 2 is explicitly locked by operator.

---

## PHASE 1 — FOUNDATION LAYER

**Status:** COMPLETE — LOCKED (Foundation Gamma)  
**Version locked:** ADE v1.4  
**Epoch:** Pre-Phase 2 baseline

### Objectives Completed

| # | Objective | Artifact | Status |
|---|---|---|---|
| 1.1 | Repository structure established | `INDEX.md`, `README.md`, directory tree | ✅ DONE |
| 1.2 | Supreme governance document | `ADE_Constitution_v1.4.md` | ✅ DONE |
| 1.3 | Foundational constitutional amendments | `ACP-0001_Foundation_Gamma_v1.4.md` | ✅ DONE |
| 1.4 | Bootstrap and session initialization | `bootstrap_download.md`, `STARTUP_PROCEDURE_v1.0.md` | ✅ DONE |
| 1.5 | Evidence standard codified | `EVIDENCE_STANDARD.md` | ✅ DONE |
| 1.6 | Epistemic hierarchy defined | Embedded in BLUEPRINT.md — L1/L2/L3 | ✅ DONE |
| 1.7 | Active state snapshot | `ACTIVE_STATE_SNAPSHOT_v1.4_REVISED.md` | ✅ DONE |
| 1.8 | Artifact delivery amendment | `CONSTITUTIONAL_AMENDMENT_FULL_ARTIFACTS.md` | ✅ DONE |
| 1.9 | Repository Charter | `REPOSITORY_CHARTER.md` | ✅ DONE |
| 1.10 | Provenance and naming conventions | `NAMING_CONVENTIONS.md`, `VERSIONING_POLICY.md` | ✅ DONE |

### Phase 1 Lock Conditions — All Met

- [x] Constitution canonical and ratified
- [x] ACP-0001 filed and incorporated
- [x] Repository structure reproducible from INDEX.md
- [x] Bootstrap procedure validated
- [x] No duplicate canonical documents in root

### Phase 1 Preservation Point

`PP/Foundation_Gamma/` — frozen snapshot of all Phase 1 artifacts. No modifications permitted to Phase 1 documents without a new ACP filing.

---

## PHASE 2 — CORE LOGIC CODIFICATION

**Status:** ACTIVE  
**Entry Trigger:** Foundation Gamma freeze confirmation  
**Exit Trigger:** All Phase 2 acceptance criteria met + operator lock command  
**Active Milestone:** Repository Archaeology Pass 1 (per ACTIVE_STATE_SNAPSHOT)

### Objectives

| # | Objective | Artifact | Status |
|---|---|---|---|
| 2.1 | Reverse-parse repository context | Review of `ADE_full_repo_context.txt` + all subdirectory content | 🔄 IN PROGRESS |
| 2.2 | Behavioral state model finalized | `BLUEPRINT.md §4.2` | 🔄 IN PROGRESS |
| 2.3 | Intervention tiers specified (Tier 1–3) | `BLUEPRINT.md §5.3` | 🔄 IN PROGRESS |
| 2.4 | Priority queue algorithm defined | `BLUEPRINT.md §5.2` | 🔄 IN PROGRESS |
| 2.5 | Epistemic weighting framework codified | `BLUEPRINT.md §3` | ✅ DRAFTED |
| 2.6 | Data schemas defined (SQLite) | `BLUEPRINT.md §6` | ✅ DRAFTED |
| 2.7 | System execution tree mapped | `BLUEPRINT.md §7` | ✅ DRAFTED |
| 2.8 | Trigger registry seeded (TRG-01 → TRG-08) | `BLUEPRINT.md §4.3` | ✅ DRAFTED |
| 2.9 | Distraction library seed catalog | `BLUEPRINT.md §8` | ✅ DRAFTED |
| 2.10 | Subject profile ASD/ADHD codified | `BLUEPRINT.md §4` | ✅ DRAFTED |
| 2.11 | Master Blueprint file | `/BLUEPRINT.md` | ✅ GENERATED |
| 2.12 | Master Roadmap file | `/.claude/DIFFERENCE_ENGINE_ROADMAP.md` | ✅ GENERATED (this file) |

### Phase 2 Acceptance Criteria

All of the following must be true before Phase 2 is declared LOCKED:

- [ ] **AC-2.1** `BLUEPRINT.md` reviewed and approved by operator — no unresolved TODOs
- [ ] **AC-2.2** All 3 intervention tiers (Distraction / De-escalation / Safety) validated against ASD/ADHD clinical literature
- [ ] **AC-2.3** All 5 SQLite schemas reviewed, field types confirmed for Android SQLite compatibility
- [ ] **AC-2.4** Distraction library has minimum 10 operator-verified entries with preference scores
- [ ] **AC-2.5** Trigger registry has minimum 5 confirmed subject-specific entries (beyond seed)
- [ ] **AC-2.6** Priority queue logic produces deterministic output for all state permutations
- [ ] **AC-2.7** System execution tree is complete with no dead-end paths
- [ ] **AC-2.8** Epistemic framework has been applied to at least 3 historical behavioral observations (validation pass)
- [ ] **AC-2.9** BLUEPRINT.md v1.0 committed to repository root
- [ ] **AC-2.10** DIFFERENCE_ENGINE_ROADMAP.md v1.0 committed to `.claude/`
- [ ] **AC-2.11** CHANGELOG.md updated with Phase 2 completion entry
- [ ] **AC-2.12** Preservation Point created: `PP/Phase_2_Lock/`

### Phase 2 Outstanding Items (Blocked on Full Repository Archaeology)

The following require full ingestion of `ADE_full_repo_context.txt` and subdirectory contents to complete:

| Item | Blocker | Action Required |
|---|---|---|
| Historical behavioral data extraction | ADE_full_repo_context.txt inaccessible via current interface | Upload file directly or connect GitHub MCP |
| Subject-specific distraction preferences | Embedded in prior session chats (in `In ox/` or `Library/`) | Archaeology pass required |
| Prior intervention outcome data | Logs in `Research/` or `Archive/` | Archaeology pass required |
| AKS Covenant / Cultivation Model integration | `AKS_*.json` files not yet parsed | Parse and extract core logic |
| Companion Narrative integration | `AKS_Companion_Narrative_Working_Draft_v0_2.*` | Read and distill into BLUEPRINT |

### Phase 2 Sub-Milestones

```
M2.1 — Repository Archaeology Pass 1 (ACTIVE)
    ├─ Census all files in all subdirectories
    ├─ Classify each by type (spec / evidence / governance / archive / inbox)
    └─ Output: Repository_Census_v0.1.md

M2.2 — Schema Validation Pass
    ├─ Validate SQLite schemas against Android API compatibility
    ├─ Confirm column types, index strategy, query patterns
    └─ Output: Schema_Validation_v0.1.md

M2.3 — Intervention Protocol Review Pass
    ├─ Cross-reference Tier 1–3 protocols against clinical frameworks
    │   (Zones of Regulation, PBS, ABA de-escalation literature)
    ├─ Operator validation of all protocol steps
    └─ Output: Protocol_Review_Sign-off.md

M2.4 — Distraction Library Population
    ├─ Operator populates subject-specific entries (minimum 10)
    ├─ Score initial preference weights
    └─ Output: distraction_library_seed_v0.1.json

M2.5 — Phase 2 Freeze + Preservation Point
    ├─ Commit BLUEPRINT.md v1.0
    ├─ Commit DIFFERENCE_ENGINE_ROADMAP.md v1.0
    ├─ Update CHANGELOG.md
    └─ Create PP/Phase_2_Lock/
```

---

## PHASE 3 — MOBILE EXECUTION LAYER

**Status:** PENDING — DO NOT BEGIN until Phase 2 LOCKED  
**Entry Condition:** Phase 2 lock confirmed by operator  
**Target Platform:** Android 64-bit (Motorola G Power 2021 / Android 11)

### Objectives

| # | Objective | Artifact | Status |
|---|---|---|---|
| 3.1 | Android project scaffold | `Tools/android/ADE_app/` | 🔒 PENDING |
| 3.2 | SQLite integration layer | `db/` package — all 5 schema tables | 🔒 PENDING |
| 3.3 | State assessment UI | Trigger input screen + state selector | 🔒 PENDING |
| 3.4 | Protocol delivery UI | Step-by-step intervention display | 🔒 PENDING |
| 3.5 | Timer integration | Per-tier countdown / elapsed timer | 🔒 PENDING |
| 3.6 | Outcome logging UI | Post-session log entry screen | 🔒 PENDING |
| 3.7 | Distraction library browser | Searchable by sensory type / preference | 🔒 PENDING |
| 3.8 | Offline-native validation | All functions tested with airplane mode ON | 🔒 PENDING |
| 3.9 | APK build + sideload | Signed debug APK for test device | 🔒 PENDING |
| 3.10 | Field testing pass | Operator uses system in 5 live sessions | 🔒 PENDING |

### Phase 3 Technical Constraints

```
TARGET_SDK:       Android 11 (API 30)
MIN_SDK:          Android 9 (API 28) recommended minimum
ARCHITECTURE:     arm64-v8a (64-bit) primary; armeabi-v7a fallback optional
BUILD_SYSTEM:     Gradle
LANGUAGE:         Kotlin (preferred) or Java
DATABASE:         SQLite via Room Persistence Library (Android Jetpack)
UI_FRAMEWORK:     Jetpack Compose OR XML Views — decide before M3.3
OFFLINE_STORAGE:  Internal storage only — no SD card dependency
NETWORK_CALLS:    ZERO required network calls for any core function
PERMISSIONS_REQ:  Minimal — no location, no camera, no contacts
APK_SIZE_TARGET:  <20MB uncompressed (offline distraction content excluded)
```

### Phase 3 Sub-Milestones

```
M3.1 — Android Project Scaffold
    ├─ Create Android Studio project
    ├─ Configure Gradle for arm64 target
    └─ Establish package structure

M3.2 — Database Layer
    ├─ Implement Room entities from Phase 2 schemas
    ├─ Write DAOs for all 5 tables
    └─ Unit test CRUD operations

M3.3 — Core UI — State Assessment Flow
    ├─ Trigger selection screen
    ├─ State confirmation screen
    └─ Protocol dispatch

M3.4 — Core UI — Protocol Execution Flow
    ├─ Step-by-step display with timer
    ├─ Escalation/resolution buttons
    └─ Auto-advance to next tier on escalation

M3.5 — Outcome Logging
    ├─ Post-session input screen
    └─ Automatic effectiveness score update

M3.6 — Field Testing
    ├─ 5 minimum live sessions with operator
    ├─ Bug capture and iteration
    └─ Phase 3 lock decision
```

### Phase 3 Acceptance Criteria

- [ ] **AC-3.1** App installs via sideload on Motorola G Power 2021
- [ ] **AC-3.2** All 5 SQLite tables persist data across app restarts
- [ ] **AC-3.3** Full intervention session (trigger → state → protocol → outcome) completable in under 60 seconds setup time
- [ ] **AC-3.4** App functions identically with WiFi and mobile data disabled
- [ ] **AC-3.5** No crash observed across 5 live field sessions
- [ ] **AC-3.6** Outcome logs retrievable and readable in app
- [ ] **AC-3.7** Timer accuracy within ±5 seconds over 15-minute session

---

## PHASE 4 — FEEDBACK LOOP + LONGITUDINAL ANALYSIS ENGINE

**Status:** FUTURE — Requires 30+ logged sessions for meaningful pattern extraction  
**Entry Condition:** Phase 3 locked + minimum 30 behavioral event records in database

### Objectives

| # | Objective | Description |
|---|---|---|
| 4.1 | Automated trigger frequency analysis | Rank triggers by frequency × time-of-day correlation |
| 4.2 | Intervention effectiveness scoring | Auto-update distraction library scores from outcome logs |
| 4.3 | State transition pattern extraction | Identify common escalation paths (trigger → YELLOW → ORANGE sequences) |
| 4.4 | Longitudinal subject profile evolution | Track changes in trigger sensitivity and intervention effectiveness over time |
| 4.5 | Report generation | Clinician-shareable summary export (PDF or shareable text format) |
| 4.6 | Predictive state modeling | Given current time + recent triggers → predict likely state in next 2 hours |

### Phase 4 Technical Notes

- Pattern extraction runs as background process on-device — no cloud required
- Predictive modeling limited to statistical pattern matching (no ML model training on device given hardware constraints)
- All analysis remains epistemic-level tagged (L1 for raw events, L2 for derived patterns)
- Report exports clearly labeled with evidence confidence levels

---

## ENFORCEMENT RULES

### DO NOT SKIP PHASES

```
IF Phase_2_status != LOCKED:
  DO NOT begin Phase 3 work
  DO NOT generate Android project files
  DO NOT write Kotlin/Java code
  DO NOT design UI screens
```

### INTERVENTION PROTOCOL LOCK

Tier 1, 2, and 3 protocols in BLUEPRINT.md are locked at Phase 2 completion. They cannot be modified in Phase 3. If protocol changes are required, file as a Phase 2 revision → re-lock → then proceed.

### SCHEMA LOCK

SQLite schemas in BLUEPRINT.md §6 are locked at Phase 2 completion. Schema migrations in Phase 3 require explicit migration scripts filed in `Specifications/DB_Migrations/`.

### EVIDENCE INTEGRITY

At no point in any phase may L3 evidence be used to override L1 evidence in protocol selection, trigger weighting, or effectiveness scoring.

---

## CURRENT ACTIVE TASK (Phase 2)

**Immediate next step:** Operator must provide one of:
1. Direct upload of `ADE_full_repo_context.txt` for full archaeology ingestion
2. GitHub MCP connection with write access for direct commit of BLUEPRINT.md + this file
3. Confirmation that the Phase 2 DRAFT artifacts (BLUEPRINT.md + DIFFERENCE_ENGINE_ROADMAP.md) are accurate and ready for v1.0 lock

**Pending operator action before proceeding.**

---

## CHANGELOG — ROADMAP HISTORY

| Version | Date | Changes |
|---|---|---|
| 0.1-DRAFT | 2026-07-26 | Initial synthesis from repository archaeology + Phase 2 prompt. Generated as downloadable artifact pending repository write access. |

---

*This roadmap is a Phase 2 canonical output artifact. It is the authoritative execution sequence for The Difference Engine. All engineering decisions reference this document. Do not begin Phase 3 work until this document reaches v1.0-LOCKED status.*
