# Difference Engine — External Research Corpus Acquisition & Ingestion Plan

**Version:** 0.1  
**Date:** 2026-08-13  
**Status:** Operational research plan / staging specification — not canonical architecture  
**Purpose:** Build a very large, rights-aware, provenance-preserving external research corpus before broader Pan repository ingestion and execution.

---

## 1. Objective

Acquire and stage as much **trusted or accredited, freely accessible research and technical publication material** as is useful to the Difference Engine and its tangential domains.

Where lawful and technically supported:

- preserve the full text locally;
- preserve machine-readable metadata;
- preserve source provenance and license evidence;
- hash downloaded artifacts;
- deduplicate across repositories;
- preserve version/retraction/correction state.

Where full-text storage or automated retrieval is not clearly permitted:

- preserve authoritative metadata;
- preserve canonical URLs;
- preserve identifiers and open-access resolver links;
- do **not** assume that "free to read" means "free to mirror, redistribute, or bulk scrape."

The corpus is **source material**, not canonical Difference Engine knowledge.

> **Pan may ingest sources. Pan does not automatically inherit their conclusions.**

---

## 2. Reality Check: "Everything" Is Too Large to Mirror Blindly

A literal mirror of the global open scholarly corpus is beyond the current fleet.

Examples from current source documentation:

- CORE reports tens of millions of directly hosted PDFs and hundreds of millions of searchable/free-to-read research works.
- Crossref's 2026 public metadata file alone is about **208 GB compressed** for roughly **180 million** registered records.
- arXiv explicitly warns that its complete corpus is terabytes in scale and directs bulk users to its dedicated S3/Kaggle mechanisms rather than crawler-style downloading.

Using CORE's current figure of roughly 57 million hosted PDFs, even an assumed average PDF size of only 0.5–3 MB implies roughly **28.5–171 TB** of storage.

Therefore the correct design is not "download the Internet."

It is:

> **Global discovery metadata + aggressive topic expansion + rights-aware full-text caching + durable links for everything else.**

---

## 3. Three-Layer Corpus

### Layer A — Discovery / Global Metadata

Cheap, broad, machine-readable records used to find and connect relevant works.

Examples:

- OpenAlex
- Crossref
- DOAJ
- Unpaywall
- OpenCitations
- CORE metadata
- source-native bibliographic feeds

Store:

- DOI / PMID / PMCID / arXiv ID / repository IDs;
- title;
- authors;
- venue;
- date;
- work type;
- citation/reference relations where available;
- OA status;
- license;
- retraction/correction flags;
- canonical and alternate URLs;
- discovery query / source.

### Layer B — Local Full-Text Corpus

Store locally only when rights and access conditions support it.

Priority:

1. explicit CC/public-domain reuse;
2. repository-provided TDM/bulk access;
3. source-native open access;
4. local personal/research copy only when clearly permitted by the source/license.

Store:

- original artifact;
- SHA-256;
- retrieval receipt;
- license evidence;
- extracted text;
- normalized metadata;
- source provenance;
- version state.

### Layer C — Link / Resolver Corpus

For material that is valuable but not safe to mirror automatically:

- metadata;
- canonical publisher/repository URL;
- DOI;
- Unpaywall/CORE OA resolver result;
- citation relationships;
- reason full text was not stored.

This layer is still useful to Pan.

---

## 4. Rights Classes

Every candidate publication should receive one acquisition-rights state.

### `REUSE_CLEAR`

Explicit CC0 / CC BY / public domain / equivalent rights support local preservation and reuse.

**Action:** download, hash, preserve.

### `NONCOMMERCIAL_REUSE`

License permits non-commercial research storage/reuse but has restrictions.

**Action:** download if the project remains within the license; preserve license metadata prominently.

### `TDM_ALLOWED`

Repository/source explicitly provides machine-access or TDM corpus access but redistribution rights may be narrower.

**Action:** preserve locally for authorized research/TDM; do not treat as redistributable.

### `FREE_READ_UNCLEAR_REUSE`

Readable without payment, but no clear machine-reuse/mirroring permission.

**Action:** metadata + link + identifiers. No blind bulk mirror.

### `RESTRICTED`

Paywalled, login-only, embargoed, or otherwise restricted.

**Action:** metadata only; attempt lawful OA resolution through Unpaywall/CORE/institutional repositories.

### `UNKNOWN`

Rights state cannot be determined.

**Action:** quarantine from automated full-text acquisition until resolved.

---

## 5. Trust Is Not One Number

"Trusted" and "accredited" should be represented as separate dimensions rather than one prestige score.

Candidate metadata:

```text
authority_class:
    peer_reviewed
    standards_body
    government_primary
    professional_society
    accredited_repository
    preprint
    vendor_primary_research
    thesis
    grey_literature
    other

review_status:
    peer_reviewed
    editorially_reviewed
    standards_process
    preprint
    unknown

source_stability:
    archival
    institutional
    publisher
    project_site
    volatile

rights_clarity:
    explicit
    repository_asserted
    ambiguous
    unknown

evidence_type:
    experiment
    benchmark
    systematic_review
    survey
    standard
    technical_report
    position
    implementation_report
    dataset
    software_artifact
```

This preserves distinctions that matter.

A NIST standard can be highly authoritative without being a journal article.

An arXiv preprint can be frontier-relevant without being peer-reviewed.

A vendor security incident report can be primary evidence without being independent research.

---

## 6. Primary Discovery / Acquisition Sources

### OpenAlex

**Role:** global discovery graph and metadata control plane.

Current API/docs expose scholarly works, authors, institutions, topics, citation relationships, OA status, retraction state, and downloadable full-text locations where available. A free quarterly snapshot is available.

Use it primarily to:

- build the topic universe;
- discover related works;
- collect citation/reference neighborhoods;
- detect retractions;
- locate OA versions.

Sources:

- https://developers.openalex.org/
- https://developers.openalex.org/api-reference/works
- https://developers.openalex.org/quickstart

### Crossref

**Role:** DOI authority and publisher-deposited bibliographic metadata.

The REST API exposes member-deposited metadata, license data, funding, updates, identifiers, and references. Crossref also publishes a large annual public data file.

Use it to:

- normalize DOI identity;
- capture publisher-supplied metadata;
- verify publication/version relationships;
- obtain license/full-text-link metadata where present.

Sources:

- https://www.crossref.org/documentation/retrieve-metadata/rest-api/
- https://www.crossref.org/services/metadata-retrieval/public-data-file/

### Unpaywall

**Role:** lawful OA resolver.

Use it to find open versions for DOI-based works before declaring a paper unavailable.

Sources:

- https://data.unpaywall.org/products/api
- https://unpaywall.org/products/

### CORE

**Role:** large open-access full-text aggregator.

CORE provides machine access to metadata and full texts from thousands of repositories/providers.

Use it for:

- full-text OA discovery;
- repository copy discovery;
- metadata;
- fallback when publisher DOI pages are closed.

Sources:

- https://core.ac.uk/services/api
- https://core.ac.uk/data

### DOAJ

**Role:** curated index of open-access journals and article metadata.

DOAJ exposes API/OAI-PMH/public data, with CC0 metadata.

Use it for:

- journal trust/eligibility signal;
- OA journal discovery;
- license/source validation.

Sources:

- https://doaj.org/
- https://doaj.org/docs/faq/
- https://doaj.org/docs/oai-pmh/

### OpenCitations

**Role:** open citation graph.

Use it for:

- forward/backward citation expansion;
- citation-network evidence;
- discovery saturation.

Source:

- https://api.opencitations.net/index/v2

### Zenodo

**Role:** research artifacts, data, software, reports, preprints, project outputs.

Metadata are openly harvestable; file rights are record-specific.

Use it for:

- datasets;
- code/release artifacts;
- technical reports;
- supporting research objects;
- reproducibility packages.

Sources:

- https://about.zenodo.org/
- https://developers.zenodo.org/

---

## 7. High-Value Domain Repositories and Publishers

### arXiv

**Domains:** AI, ML, CS, systems, mathematics, statistics, physics, quantitative biology, economics.

Use:

- OAI-PMH/API for metadata;
- source-supported bulk mechanisms for large-scale full-text access;
- article-level license metadata for rights.

Important: arXiv explicitly distinguishes access from redistribution rights and warns against crawling the main site for complete-corpus retrieval.

Source:

- https://github.com/arXiv/arxiv-docs/blob/develop/source/help/bulk_data.md

### ACL Anthology

**Domains:** NLP, language models, computational linguistics, speech.

Current Anthology materials include more than 128,000 papers. Metadata are programmatically accessible and bulk bibliography exports are provided. ACL-hosted materials from 2016 onward are CC BY 4.0; older ACL materials use CC BY-NC-SA 3.0.

Sources:

- https://aclanthology.org/
- https://aclanthology.org/faq/

### Proceedings of Machine Learning Research (PMLR)

**Domains:** machine learning, optimization, probabilistic methods, learning theory, applied ML.

PMLR publishes conference/workshop proceedings online, with author-retained copyright and freely available papers.

Source:

- https://proceedings.mlr.press/pmlr.html

### ACM Digital Library

**Domains:** computing broadly, including HCI, systems, databases, AI, software engineering, security, education.

ACM states that beginning January 1, 2026, its journals, conference proceedings, and magazines transitioned to public Open Access.

Source:

- https://www.acm.org/diversity-inclusion/equity-through-oa

### USENIX

**Domains:** operating systems, systems, networking, security, storage, SRE.

USENIX has provided conference proceedings without paywalls under its open-access policy since 2008.

Sources:

- https://www.usenix.org/about
- https://www.usenix.org/conferences/author-resources/submissions-policy

### PubMed Central Open Access Subset

**Domains:** medicine, neuroscience, psychology-adjacent biomedical work, behavior, development, human factors, health informatics.

Important distinction: **not everything in PMC is reusable OA.**

PMC's OA Subset contains millions of articles under CC/similar reuse terms and provides specific approved machine-retrieval mechanisms.

Use only PMC's authorized bulk/API services for systematic retrieval.

Sources:

- https://pmc.ncbi.nlm.nih.gov/tools/openftlist/
- https://pmc.ncbi.nlm.nih.gov/tools/developers/
- https://pmc.ncbi.nlm.nih.gov/about/copyright/

### ERIC

**Domains:** education, learning science, special education, classroom intervention, teacher practice, education policy.

ERIC is sponsored by the U.S. Department of Education's Institute of Education Sciences. It indexes about 1.6 million education records and provides hundreds of thousands of full-text materials with permission.

Sources:

- https://ies.ed.gov/use-work/education-research-database-eric
- https://eric.ed.gov/

### NIST Publications

**Domains:** AI risk, cybersecurity, privacy, standards, measurement, reproducibility, systems engineering.

NIST provides searchable publications and a complete technical-series collection of final NIST reports from 1901 onward.

Sources:

- https://www.nist.gov/publications
- https://www.nist.gov/nist-research-library/nist-publications
- https://www.nist.gov/open

### RFC Editor / IETF

**Domains:** networking, protocols, distributed systems, security, identity, Internet architecture, operational best practices.

RFCs are freely available and the RFC Editor explicitly supports local mirroring through rsync.

Sources:

- https://www.rfc-editor.org/series/rfc-use/
- https://www.rfc-editor.org/series/rfc-download/

### W3C

**Domains:** web architecture, accessibility, interfaces, data, browser/platform standards.

W3C publishes normative Recommendations as Web Standards plus supporting technical Notes and registries.

Source:

- https://www.w3.org/TR/

### CISA

**Domains:** cybersecurity, secure-by-design, supply-chain security, incident response, resilience.

Use as authoritative government operational/security material.

Source:

- https://www.cisa.gov/resources-tools/resources

---

## 8. Topic Universe

The first corpus pass should be broad enough that citation expansion can discover neighboring disciplines.

### A. Difference Engine Core

- agent operating systems;
- agent runtimes;
- orchestration;
- bounded autonomy;
- multi-agent systems;
- capability systems;
- tool routing;
- agent lifecycle;
- agent identity;
- authority and permissions;
- auditability;
- human oversight.

### B. Repository / Evidence / Knowledge

- provenance;
- scholarly metadata;
- evidence graphs;
- knowledge representation;
- temporal knowledge graphs;
- event sourcing;
- claim revision;
- contradiction detection;
- retractions/corrections;
- archival science;
- digital preservation;
- versioned knowledge;
- reproducible research;
- open science.

### C. Memory

- long-term agent memory;
- episodic memory;
- semantic memory;
- retrieval-augmented generation;
- memory consolidation;
- memory corruption;
- contextual reinstatement;
- source-grounded memory;
- continual learning;
- forgetting;
- temporal retrieval.

### D. Flat Packs / Dormant Capability

- capability packaging;
- reproducible builds;
- declarative systems;
- Nix/Guix;
- content-addressed storage;
- OCI;
- software artifact manifests;
- SBOM;
- lockfiles;
- dependency closure;
- lazy activation;
- on-demand services;
- sandboxing;
- immutable infrastructure;
- rollback.

### E. Operating Systems / Systems

- library OS;
- unikernels;
- microkernels;
- process isolation;
- scheduling;
- checkpoint/restore;
- CRIU;
- sandboxing;
- containers;
- service activation;
- distributed operating systems;
- workflow DAGs;
- resource governance;
- observability.

### F. Priority AI / Constrained Inference

- edge LLM inference;
- CPU-only inference;
- quantization;
- GGUF;
- model offloading;
- layer-wise inference;
- KV-cache offload;
- NVMe-backed inference;
- memory mapping;
- model sharding;
- heterogeneous inference;
- distributed inference;
- adapter routing;
- selective-layer training;
- parameter-efficient adaptation;
- inference scheduling.

### G. Security

- capability security;
- least privilege;
- tool/skill injection;
- prompt injection;
- software supply chain;
- sandbox escape;
- provenance;
- artifact signing;
- SBOM/VEX;
- cyber-agent containment;
- action review;
- secret handling;
- policy enforcement.

### H. Human Interface

- adaptive UI;
- generative UI;
- personalized interfaces;
- user modeling;
- accessibility;
- activity-centric computing;
- context-aware computing;
- task-oriented interfaces;
- calm computing;
- cognitive load;
- end-user programming;
- human-AI collaboration;
- explainability;
- uncertainty communication.

### I. Operator Profiles / Cognition

- personalization;
- preference learning;
- longitudinal user modeling;
- human factors;
- cognitive ergonomics;
- working memory;
- attention;
- expertise;
- skill acquisition;
- language and cognition;
- linguistic relativity;
- framing;
- terminology and concept formation.

### J. Rowan / Behavior / Education

- child development;
- executive function;
- giftedness;
- ADHD;
- autism;
- twice exceptionality;
- classroom behavior;
- task refusal;
- transitions;
- functional behavior assessment;
- antecedent-behavior-consequence;
- positive behavior supports;
- behavior intervention;
- inclusive education;
- special education;
- teacher observation;
- home-school communication;
- educational accommodations;
- learning science.

This domain requires especially strict separation between:

```text
observation
evidence
interpretation
screening
diagnosis
intervention
```

### K. Governance / Law / Institutions

- AI governance;
- constitutional governance;
- administrative law;
- authorization;
- delegation;
- principal-agent problems;
- due process;
- institutional memory;
- records management;
- audit;
- privacy;
- consent;
- data minimization;
- children's data;
- education records;
- health records.

### L. Failure / Verification / Improvement

- formal verification;
- model checking;
- software testing;
- property-based testing;
- fault injection;
- chaos engineering;
- regression testing;
- failure-driven learning;
- self-repair;
- monotonic improvement;
- rollback;
- external verification;
- runtime assurance.

### M. Distributed / Scavenger Compute

- volunteer computing;
- edge clusters;
- opportunistic computing;
- heterogeneous clusters;
- fault-tolerant distributed systems;
- distributed databases;
- lightweight consensus;
- rqlite/dqlite;
- content distribution;
- peer-to-peer;
- intermittent networking;
- offline-first systems.

### N. Research Method / Evidence Quality

- systematic reviews;
- meta-analysis;
- replication;
- negative results;
- publication bias;
- reproducibility;
- preregistration;
- evidence grading;
- causal inference;
- measurement validity;
- benchmark validity.

---

## 9. Discovery Method

A fixed keyword list will miss too much.

Use a recursive acquisition cycle.

```text
PROJECT TERMS / ACTIVE QUESTIONS
        ↓
SEED SEARCHES
        ↓
TRUSTED RESULTS
        ↓
BACKWARD REFERENCES
        ↓
FORWARD CITATIONS
        ↓
AUTHOR / LAB / VENUE EXPANSION
        ↓
RELATED TOPICS / SEMANTIC NEIGHBORS
        ↓
DEDUP
        ↓
RIGHTS RESOLUTION
        ↓
DOWNLOAD OR LINK
        ↓
REPEAT
```

### Saturation condition

Do not pretend literal completeness.

For each topic family record:

- queries run;
- sources searched;
- date ranges;
- result counts;
- candidate counts;
- accepted counts;
- duplicate counts;
- rejected/untrusted counts;
- unresolved-rights counts;
- citation expansion depth;
- date of last sweep.

A domain can be called **saturated for the current pass** only when repeated expansion produces mostly duplicates/low-relevance material and no major authoritative venue/source remains unchecked.

---

## 10. Deduplication

Preferred identity order:

```text
DOI
→ PMCID / PMID
→ arXiv ID
→ ACL / repository persistent ID
→ ISBN / report number / RFC number / NIST ID
→ normalized title + author + year
→ content hash
```

Never delete provenance merely because two files are duplicates.

Represent:

```text
one intellectual work
    ↕
multiple manifestations
    ↕
publisher copy
repository copy
preprint
accepted manuscript
version of record
correction
retraction
```

---

## 11. Minimum Publication Record

```yaml
record_id:
title:
authors:
publication_date:
work_type:
venue:
publisher_or_body:

identifiers:
  doi:
  pmid:
  pmcid:
  arxiv:
  other:

authority:
  authority_class:
  review_status:

rights:
  state:
  license:
  license_source:
  permitted_actions:

access:
  canonical_url:
  open_url:
  local_artifact:
  retrieved_at:

integrity:
  sha256:
  file_size:
  mime_type:

status:
  retracted:
  corrected:
  superseded:
  version:

provenance:
  discovered_via:
  discovery_query:
  metadata_sources:
  retrieval_source:

classification:
  topic_families:
  direct_relevance:
  tangential_relevance:

ingestion:
  extracted_text:
  normalized:
  indexed:
  analysis_status:
  promotion_status: source_only
```

---

## 12. Storage Placement

Do **not** spread blindly across machines before a read-only storage census.

### Forge / Surface

Preferred role:

- canonical repository;
- ingestion control state;
- metadata index;
- high-priority/hot full text;
- hashes and manifests.

Avoid filling the primary build machine with uncontrolled bulk PDFs.

### White Mac

Preferred candidate for first **bulk/cold corpus storage** because it has no preservation obligation in the current fleet plan.

After hardware/disk verification, it can potentially hold:

- OA full texts;
- source archives;
- cold mirrors;
- historical corpus;
- duplicate safety copies.

### AirBook

Preserve its studio/photo mission first.

Use for research corpus only when:

- current personal/studio assets are verified;
- free-space budget is known;
- corpus storage cannot interfere with recording/photo capability.

### Phones

Use only for:

- manifests;
- emergency continuity;
- current transfer packages;
- small high-priority reading sets.

Do not make the phone the bulk literature archive.

---

## 13. Storage Census Before Distribution

Before moving bulk material, capture on every prospective node:

```text
node identity
disk devices
filesystem
total capacity
free capacity
reserved headroom
current preservation obligations
expected write endurance / health where available
network path
transfer speed
power/reliability
```

Then assign:

```text
HOT
WARM
COLD
MIRROR
METADATA-ONLY
```

roles.

Storage allocation follows reality.

---

## 14. Corpus Intake Must Stay Separate From Canon

External literature should initially land in a **staging corpus**, not silently inside canonical knowledge.

Pipeline:

```text
publication
→ source artifact
→ provenance
→ rights validation
→ dedup/version identity
→ text extraction
→ index
→ research use

NOT

publication
→ "Difference Engine believes this"
```

A peer-reviewed paper can still be:

- wrong;
- superseded;
- contradicted;
- context-limited;
- methodologically weak.

A preprint can still be useful.

Trust controls how it is interpreted, not whether its text magically becomes truth.

---

## 15. Recommended Acquisition Order

### Phase 0 — Protect the Current Build

1. Finish/stabilize the current repository ingestion edge.
2. Freeze a recovery checkpoint.
3. Record corpus work as a separate operation.

### Phase 1 — Build Metadata Spine

Acquire/index:

1. OpenAlex topic-filtered metadata;
2. Crossref identity/license metadata;
3. DOAJ journal metadata;
4. Unpaywall OA resolution;
5. OpenCitations citation edges.

This is the cheapest way to know what exists.

### Phase 2 — High-Value Full-Text Sources

Prioritize:

1. project-known frontier papers;
2. ACM 2026+;
3. USENIX;
4. ACL Anthology;
5. PMLR/JMLR;
6. NIST;
7. RFCs;
8. W3C;
9. PMC OA subset by relevant biomedical/behavior topics;
10. ERIC full-text education corpus by relevant descriptors;
11. CORE OA copies;
12. arXiv targeted categories/queries;
13. Zenodo research artifacts.

### Phase 3 — Citation Expansion

For every retained high-value item:

- references;
- citing works;
- same author/lab;
- same venue;
- related-topic neighbors.

### Phase 4 — Historical Roots

Once frontier coverage is dense:

- operating-system foundational work;
- capability security;
- hypertext/HCI;
- distributed systems;
- cognitive science;
- archival/library science;
- behavioral/education foundational literature;
- institutional/governance theory.

### Phase 5 — Incremental Watch

Daily/weekly delta ingestion rather than repeating the entire crawl.

The existing frontier watch can become one discovery input, but the local corpus should eventually maintain its own source-native feeds and delta state.

---

## 16. Immediate Proof

The first proof should not be "download 100,000 papers."

It should prove the entire lawful loop on a smaller set.

### Candidate: 500–2,000 publications

Across:

- agent OS / runtime;
- memory;
- Flat Packs / packaging;
- HCI/personalization;
- constrained inference;
- security/governance;
- Rowan/education/behavior.

Pass if:

1. every item has stable identity;
2. duplicates are linked rather than multiplied;
3. rights state is explicit;
4. full text is stored only under a supported acquisition path;
5. every downloaded artifact is hashed;
6. every item retains canonical URL;
7. retraction/version state is captured where available;
8. text extraction is deterministic;
9. Pan can query the corpus without treating it as canon;
10. the process can resume after interruption.

Then scale.

---

## 17. Important Murders

### MURDER — "Free to read means free to mirror."

False.

### MURDER — "Peer reviewed means true."

False.

### MURDER — "Preprint means useless."

False.

### MURDER — "The biggest metadata database is the best full-text source."

False.

Use each source for the operation it performs best.

### MURDER — "Store only PDFs."

No.

Metadata, identifiers, licenses, provenance, citation relations, text extraction, and version relationships are often more important operationally.

### MURDER — "One copy per paper."

No.

One **work identity** may legitimately have multiple manifestations.

### MURDER — "Pan reads it, therefore DE knows it."

No.

Reading is ingestion. Knowledge promotion is separate.

### MURDER — "We must mirror the entire global research corpus before Pan starts."

No.

The world corpus is too large and continuously changing.

Build a broad discovery spine and a deep, rights-safe relevant corpus.

---

## 18. Operational Conclusion

The target should be:

> **As close to comprehensive discovery as available open metadata permits, combined with aggressively comprehensive local preservation of relevant material whose rights and source mechanisms support it.**

That is attainable.

Literal full-text possession of every publication is neither required nor currently feasible.

The DE-native architecture is:

```text
GLOBAL SCHOLARLY WORLD
        ↓
DISCOVERY METADATA
        ↓
TRUST + RELEVANCE + RIGHTS RESOLUTION
        ↓
┌───────────────────────────────┐
│ LOCAL FULL TEXT               │
│ lawful / useful / verified    │
└───────────────────────────────┘
        +
┌───────────────────────────────┐
│ LINKED EXTERNAL LITERATURE    │
│ metadata / canonical URLs     │
└───────────────────────────────┘
        ↓
SOURCE-GROUNDED INDEX
        ↓
PAN / RESEARCH / PROJECTIONS
        ↓
INTERPRETATION
        ↓
VALIDATION / PROMOTION GATE
```

**Next operation:** perform the live storage census, then build the first rights-aware topic-filtered metadata harvest manifest before bulk full-text acquisition.
