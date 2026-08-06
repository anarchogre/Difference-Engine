# Mobile Vocabulary Placement — Targeted Schema Sections

Recovered primary specification excerpts selected for the placement decision. No authority or canonical status is inferred.

## workspace/operational/ingestion/output/ING-20260804-0006/source/Artifact_Schema_v0.1.md

### Artifact Hierarchy — lines 19–42

```text
19: # Artifact Hierarchy
20: 
21: Artifact
22: 
23: ├── Metadata
24: 
25: ├── Provenance
26: 
27: ├── Content
28: 
29: ├── Structure
30: 
31: ├── Assets
32: 
33: ├── References
34: 
35: ├── Queue Candidates
36: 
37: ├── Validation
38: 
39: └── Lifecycle
40: 
41: ---
42: 
```

### Assets — lines 114–136

```text
114: # Assets
115: 
116: Reusable components extracted from the artifact.
117: 
118: Examples:
119: 
120: - Markdown templates
121: - JSON
122: - YAML
123: - Code
124: - Diagrams
125: - Charts
126: - Graphs
127: - Tables
128: - Checklists
129: - Folder structures
130: - Specifications
131: - Prompts
132: 
133: Assets SHALL retain provenance.
134: 
135: ---
136: 
```

### Extension Model — lines 201–217

```text
201: # Extension Model
202: 
203: Specialized schemas extend this specification.
204: 
205: Examples:
206: 
207: - Conversation Schema
208: - PDF Schema
209: - Image Schema
210: - Research Paper Schema
211: - Governance Document Schema
212: - Observation Schema
213: 
214: Extensions inherit this schema.
215: 
216: ---
217: 
```

## workspace/operational/ingestion/output/ING-20260804-0007/source/Asset_Schema_v0.1.md

### Supported Asset Types — lines 60–90

```text
60: # Supported Asset Types
61: 
62: Examples include:
63: 
64: - Markdown
65: - Template
66: - Prompt
67: - Specification
68: - JSON
69: - YAML
70: - XML
71: - Python
72: - Bash
73: - PowerShell
74: - SQL
75: - Mermaid Diagram
76: - ASCII Diagram
77: - Table
78: - Chart
79: - Graph
80: - Checklist
81: - Decision Tree
82: - Folder Structure
83: - Configuration
84: - Citation
85: - Regular Expression
86: 
87: Additional asset types MAY be defined through future specifications.
88: 
89: ---
90: 
```

### Relationship to Artifacts — lines 140–159

```text
140: # Relationship to Artifacts
141: 
142: Artifacts contain evidence.
143: 
144: Assets expose reusable components of that evidence.
145: 
146: Multiple assets MAY originate from a single artifact.
147: 
148: ---
149: 
150: # Design Philosophy
151: 
152: Artifacts preserve history.
153: 
154: Assets preserve utility.
155: 
156: Together they create a reusable institutional memory.
157: 
158: ---
159: 
```

## workspace/operational/ingestion/output/ING-20260804-0026/source/Output_Package_Specificatiom_v0.1.md

### Purpose, Principles, and Package Start — lines 9–40

```text
9: # Purpose
10: 
11: The Output Package Specification defines the canonical directory structure produced by the ingestion pipeline.
12: 
13: Every successful ingestion SHALL produce a complete, deterministic output package.
14: 
15: ---
16: 
17: # Design Principles
18: 
19: - Consistent structure
20: - Predictable locations
21: - Complete provenance
22: - Immutable source preservation
23: - Extensible organization
24: 
25: ---
26: 
27: # Standard Output Package
28: 
29: artifact-id/
30: 
31: ├── source/
32: 
33: │   └── original
34: 
35: │
36: 
37: ├── metadata/
38: 
39: │   └── artifact.yaml
40: 
```

## workspace/operational/ingestion/output/ING-20260804-0059/source/Workflow_Service_Capability_Specification_v0.1.md

### Capability Categories — lines 100–121

```text
100: # Capability Categories
101: 
102: Capability categories MAY include:
103: 
104: - Intake
105: - Parsing
106: - Asset Extraction
107: - Metadata Extraction
108: - Reference Resolution
109: - Validation
110: - Mapping
111: - Transformation
112: - Publication
113: - Governance
114: - Monitoring
115: - Reporting
116: - Utility
117: 
118: Additional categories MAY be established through governance.
119: 
120: ---
121: 
```

### Repository Integration — lines 277–293

```text
277: # Repository Integration
278: 
279: Workflow Service Capabilities integrate with:
280: 
281: - Workflow Service Registry
282: - Workflow Service Discovery
283: - Workflow Service Contracts
284: - Workflow Definition Schema
285: - Workflow Orchestration
286: - Event Processing
287: - Repository Indexes
288: - Observability
289: 
290: Capability management SHALL preserve repository integrity and institutional accountability.
291: 
292: ---
293: 
```
