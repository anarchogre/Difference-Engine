# Mobile Vocabulary Placement — Recovered Schema Decision Extract

Focused contexts from recovered primary specifications. These specifications remain recovered evidence until their authority and current status are established.

## workspace/operational/ingestion/output/ING-20260804-0005/source/Artifact_Lifecycle_Specification_v0.1.md

- Matching lines: 44

### Line 1

```text
> 1: # Contents
  2: ````markdown
```

### Line 3

```text
  2: ````markdown
> 3: # Artifact Lifecycle Specification
  4: 
```

### Line 11

```text
  10: 
> 11: # Purpose
  12: 
```

### Line 13

```text
  12: 
> 13: The Artifact Lifecycle Specification defines the canonical lifecycle of every repository artifact from initial ingestion through archival.
  14: 
```

### Line 15

```text
  14: 
> 15: Every artifact SHALL occupy exactly one lifecycle state at any given time.
  16: 
```

### Line 17

```text
  16: 
> 17: Lifecycle transitions SHALL be explicit and recorded.
  18: 
```

### Line 21

```text
  20: 
> 21: # Design Principles
  22: 
```

### Line 23

```text
  22: 
> 23: - Every artifact has a lifecycle.
  24: - Lifecycle changes are recorded.
```

### Line 24

```text
  23: - Every artifact has a lifecycle.
> 24: - Lifecycle changes are recorded.
  25: - State transitions preserve provenance.
```

### Line 31

```text
  30: 
> 31: # Lifecycle States
  32: 
```

### Line 33

```text
  32: 
> 33: ## Imported
  34: 
```

### Line 35

```text
  34: 
> 35: The artifact has entered the ingestion system.
  36: 
```

### Line 41

```text
  40: 
> 41: ## Parsed
  42: 
```

### Line 49

```text
  48: 
> 49: ## Validated
  50: 
```

### Line 51

```text
  50: 
> 51: Validation has completed.
  52: 
```

### Line 57

```text
  56: 
> 57: ## Queued
  58: 
```

### Line 61

```text
  60: 
> 61: The artifact awaits downstream processing.
  62: 
```

### Line 65

```text
  64: 
> 65: ## Mapped
  66: 
```

### Line 73

```text
  72: 
> 73: ## Under Review
  74: 
```

### Line 81

```text
  80: 
> 81: ## Promoted
  82: 
```

### Line 83

```text
  82: 
> 83: The artifact has been approved for canonical promotion.
  84: 
```

### Line 85

```text
  84: 
> 85: Promotion history has been recorded.
  86: 
```

### Line 89

```text
  88: 
> 89: ## Published
  90: 
```

### Line 91

```text
  90: 
> 91: The canonical artifact has been published to its repository destination.
  92: 
```

### Line 97

```text
  96: 
> 97: ## Superseded
  98: 
```

### Line 99

```text
  98: 
> 99: A newer canonical artifact has replaced this artifact.
  100: 
```

### Line 101

```text
  100: 
> 101: The artifact remains preserved.
  102: 
```

### Line 105

```text
  104: 
> 105: ## Archived
  106: 
```

### Line 107

```text
  106: 
> 107: The artifact is retained for historical purposes.
  108: 
```

### Line 113

```text
  112: 
> 113: # State Transitions
  114: 
```

### Line 152

```text
  151: 
> 152: Rollback transitions SHALL be explicitly recorded.
  153: 
```

### Line 156

```text
  155: 
> 156: # Lifecycle Events
  157: 
```

### Line 158

```text
  157: 
> 158: Every transition SHALL record:
  159: 
```

### Line 170

```text
  169: 
> 170: # Validation
  171: 
```

### Line 172

```text
  171: 
> 172: A lifecycle transition SHALL NOT occur unless:
  173: 
```

### Line 174

```text
  173: 
> 174: - Required predecessor state exists.
  175: - Required records exist.
```

### Line 175

```text
  174: - Required predecessor state exists.
> 175: - Required records exist.
  176: - Provenance is complete.
```

### Line 180

```text
  179: 
> 180: # Failure Handling
  181: 
```

### Line 182

```text
  181: 
> 182: Failed transitions SHALL:
  183: 
```

### Line 191

```text
  190: 
> 191: # Relationship to Provenance
  192: 
```

### Line 193

```text
  192: 
> 193: Lifecycle history becomes part of the artifact provenance.
  194: 
```

### Line 195

```text
  194: 
> 195: Lifecycle events SHALL be immutable.
  196: 
```

### Line 199

```text
  198: 
> 199: # Design Philosophy
  200: 
```

### Line 205

```text
  204: 
> 205: The lifecycle records the evolution of repository stewardship rather than changes to the underlying evidence.
  206: 
```

## workspace/operational/ingestion/output/ING-20260804-0006/source/Artifact_Schema_v0.1.md

- Matching lines: 35

### Line 1

```text
> 1: # Artifact Schema
  2: 
```

### Line 9

```text
  8: 
> 9: # Purpose
  10: 
```

### Line 11

```text
  10: 
> 11: The Artifact Schema defines the canonical structural representation for all repository artifacts.
  12: 
```

### Line 13

```text
  12: 
> 13: Every ingested object SHALL conform to this schema prior to semantic processing.
  14: 
```

### Line 19

```text
  18: 
> 19: # Artifact Hierarchy
  20: 
```

### Line 21

```text
  20: 
> 21: Artifact
  22: 
```

### Line 37

```text
  36: 
> 37: ├── Validation
  38: 
```

### Line 39

```text
  38: 
> 39: └── Lifecycle
  40: 
```

### Line 43

```text
  42: 
> 43: # Metadata
  44: 
```

### Line 45

```text
  44: 
> 45: Required:
  46: 
```

### Line 47

```text
  46: 
> 47: - Artifact ID
  48: - Title
```

### Line 49

```text
  48: - Title
> 49: - Artifact Type
  50: - Source Platform
```

### Line 65

```text
  64: 
> 65: # Provenance
  66: 
```

### Line 67

```text
  66: 
> 67: Required:
  68: 
```

### Line 69

```text
  68: 
> 69: - Source Artifact
  70: - Original Location
```

### Line 70

```text
  69: - Source Artifact
> 70: - Original Location
  71: - Parser Version
```

### Line 76

```text
  75: 
> 76: Every artifact SHALL preserve provenance.
  77: 
```

### Line 80

```text
  79: 
> 80: # Content
  81: 
```

### Line 82

```text
  81: 
> 82: The original content SHALL remain unmodified.
  83: 
```

### Line 84

```text
  83: 
> 84: Normalized representations MAY exist but SHALL NOT replace the source.
  85: 
```

### Line 95

```text
  94: 
> 95: # Structure
  96: 
```

### Line 114

```text
  113: 
> 114: # Assets
  115: 
```

### Line 116

```text
  115: 
> 116: Reusable components extracted from the artifact.
  117: 
```

### Line 133

```text
  132: 
> 133: Assets SHALL retain provenance.
  134: 
```

### Line 137

```text
  136: 
> 137: # References
  138: 
```

### Line 142

```text
  141: - Repository artifacts
> 142: - External URLs
  143: - Files
```

### Line 153

```text
  152: 
> 153: # Queue Candidates
  154: 
```

### Line 159

```text
  158: 
> 159: Promotion requires review.
  160: 
```

### Line 163

```text
  162: 
> 163: # Validation
  164: 
```

### Line 165

```text
  164: 
> 165: Every artifact SHALL validate:
  166: 
```

### Line 183

```text
  182: 
> 183: # Lifecycle
  184: 
```

### Line 185

```text
  184: 
> 185: Every artifact exists in one lifecycle state.
  186: 
```

### Line 197

```text
  196: 
> 197: Lifecycle state SHALL be explicit.
  198: 
```

### Line 201

```text
  200: 
> 201: # Extension Model
  202: 
```

### Line 218

```text
  217: 
> 218: # Design Principles
  219: 
```

## workspace/operational/ingestion/output/ING-20260804-0007/source/Asset_Schema_v0.1.md

- Matching lines: 36

### Line 1

```text
> 1: # Asset Schema
  2: 
```

### Line 9

```text
  8: 
> 9: # Purpose
  10: 
```

### Line 11

```text
  10: 
> 11: The Asset Schema defines the canonical representation of reusable assets extracted from repository artifacts.
  12: 
```

### Line 17

```text
  16: 
> 17: They retain lineage to their parent artifact.
  18: 
```

### Line 21

```text
  20: 
> 21: # Design Principles
  22: 
```

### Line 27

```text
  26: - Assets are immutable.
> 27: - Assets never replace their parent artifact.
  28: 
```

### Line 31

```text
  30: 
> 31: # Required Fields
  32: 
```

### Line 33

```text
  32: 
> 33: Every asset SHALL contain:
  34: 
```

### Line 35

```text
  34: 
> 35: - Asset ID
  36: - Parent Artifact ID
```

### Line 36

```text
  35: - Asset ID
> 36: - Parent Artifact ID
  37: - Asset Type
```

### Line 37

```text
  36: - Parent Artifact ID
> 37: - Asset Type
  38: - Title
```

### Line 46

```text
  45: 
> 46: # Optional Fields
  47: 
```

### Line 54

```text
  53: - Description
> 54: - Related Asset IDs
  55: - Related Artifact IDs
```

### Line 55

```text
  54: - Related Asset IDs
> 55: - Related Artifact IDs
  56: - Reviewer Notes
```

### Line 60

```text
  59: 
> 60: # Supported Asset Types
  61: 
```

### Line 87

```text
  86: 
> 87: Additional asset types MAY be defined through future specifications.
  88: 
```

### Line 91

```text
  90: 
> 91: # Asset Content
  92: 
```

### Line 93

```text
  92: 
> 93: Asset content SHALL preserve the extracted structure.
  94: 
```

### Line 95

```text
  94: 
> 95: Formatting SHALL be retained whenever practical.
  96: 
```

### Line 97

```text
  96: 
> 97: Normalization SHALL NOT destroy information.
  98: 
```

### Line 101

```text
  100: 
> 101: # Provenance
  102: 
```

### Line 103

```text
  102: 
> 103: Every asset SHALL retain:
  104: 
```

### Line 105

```text
  104: 
> 105: - Parent Artifact ID
  106: - Source Location
```

### Line 106

```text
  105: - Parent Artifact ID
> 106: - Source Location
  107: - Extraction Method
```

### Line 111

```text
  110: 
> 111: Assets SHALL never lose their lineage.
  112: 
```

### Line 115

```text
  114: 
> 115: # Validation
  116: 
```

### Line 117

```text
  116: 
> 117: A valid asset SHALL:
  118: 
```

### Line 119

```text
  118: 
> 119: - Reference an existing parent artifact.
  120: - Declare an asset type.
```

### Line 120

```text
  119: - Reference an existing parent artifact.
> 120: - Declare an asset type.
  121: - Preserve provenance.
```

### Line 126

```text
  125: 
> 126: # Lifecycle
  127: 
```

### Line 128

```text
  127: 
> 128: Assets SHALL exist in one of the following states:
  129: 
```

### Line 136

```text
  135: 
> 136: Assets SHALL NOT be deleted solely because the parent artifact changes.
  137: 
```

### Line 140

```text
  139: 
> 140: # Relationship to Artifacts
  141: 
```

### Line 146

```text
  145: 
> 146: Multiple assets MAY originate from a single artifact.
  147: 
```

### Line 150

```text
  149: 
> 150: # Design Philosophy
  151: 
```

### Line 154

```text
  153: 
> 154: Assets preserve utility.
  155: 
```

## workspace/operational/ingestion/output/ING-20260804-0026/source/Output_Package_Specificatiom_v0.1.md

- Matching lines: 26

### Line 1

```text
> 1: # Output Package Specification
  2: 
```

### Line 9

```text
  8: 
> 9: # Purpose
  10: 
```

### Line 11

```text
  10: 
> 11: The Output Package Specification defines the canonical directory structure produced by the ingestion pipeline.
  12: 
```

### Line 13

```text
  12: 
> 13: Every successful ingestion SHALL produce a complete, deterministic output package.
  14: 
```

### Line 17

```text
  16: 
> 17: # Design Principles
  18: 
```

### Line 27

```text
  26: 
> 27: # Standard Output Package
  28: 
```

### Line 29

```text
  28: 
> 29: artifact-id/
  30: 
```

### Line 39

```text
  38: 
> 39: │   └── artifact.yaml
  40: 
```

### Line 53

```text
  52: 
> 53: │   └── validation.md
  54: 
```

### Line 95

```text
  94: 
> 95: # Required Components
  96: 
```

### Line 97

```text
  96: 
> 97: ## source/
  98: 
```

### Line 99

```text
  98: 
> 99: Contains the original immutable artifact.
  100: 
```

### Line 103

```text
  102: 
> 103: ## metadata/
  104: 
```

### Line 109

```text
  108: 
> 109: ## structure/
  110: 
```

### Line 115

```text
  114: 
> 115: ## queues/
  116: 
```

### Line 121

```text
  120: 
> 121: ## provenance/
  122: 
```

### Line 127

```text
  126: 
> 127: ## reports/
  128: 
```

### Line 133

```text
  132: 
> 133: # Naming Rules
  134: 
```

### Line 135

```text
  134: 
> 135: Directories SHALL use lowercase.
  136: 
```

### Line 137

```text
  136: 
> 137: Files SHALL use snake_case where practical.
  138: 
```

### Line 139

```text
  138: 
> 139: Artifact identifiers SHALL be globally unique.
  140: 
```

### Line 143

```text
  142: 
> 143: # Extensibility
  144: 
```

### Line 147

```text
  146: 
> 147: Required directories SHALL NOT be omitted.
  148: 
```

### Line 151

```text
  150: 
> 151: # Design Philosophy
  152: 
```

### Line 153

```text
  152: 
> 153: Every output package should be understandable by both humans and machines.
  154: 
```

### Line 155

```text
  154: 
> 155: Directory structure is part of the interface.
  156: 
```

## workspace/operational/ingestion/output/ING-20260804-0059/source/Workflow_Service_Capability_Specification_v0.1.md

- Matching lines: 70

### Line 1

```text
> 1: # Workflow Service Capability Specification
  2: 
```

### Line 9

```text
  8: 
> 9: # Purpose
  10: 
```

### Line 11

```text
  10: 
> 11: The Workflow Service Capability Specification defines the canonical model for describing, advertising, validating, and governing the functional capabilities of services participating in the Repository Ingestion Framework.
  12: 
```

### Line 17

```text
  16: 
> 17: # Design Principles
  18: 
```

### Line 24

```text
  23: - Capabilities preserve provenance.
> 24: - Capability definitions are implementation-neutral.
  25: 
```

### Line 28

```text
  27: 
> 28: # Scope
  29: 
```

### Line 42

```text
  41: 
> 42: # Capability Definition
  43: 
```

### Line 44

```text
  43: 
> 44: A capability is a formal declaration describing a unit of functionality that a service provides.
  45: 
```

### Line 46

```text
  45: 
> 46: Capabilities SHALL describe **what** a service can perform rather than **how** it performs the operation.
  47: 
```

### Line 50

```text
  49: 
> 50: # Capability Objectives
  51: 
```

### Line 52

```text
  51: 
> 52: Capability definitions SHALL enable:
  53: 
```

### Line 56

```text
  55: - Workflow planning
> 56: - Capability validation
  57: - Compatibility verification
```

### Line 63

```text
  62: 
> 63: # Canonical Capability Schema
  64: 
```

### Line 65

```text
  64: 
> 65: Every capability definition SHALL contain:
  66: 
```

### Line 67

```text
  66: 
> 67: | Field | Required | Description |
  68: |--------|----------|-------------|
```

### Line 69

```text
  68: |--------|----------|-------------|
> 69: | Capability ID | Yes | Unique capability identifier |
  70: | Capability Name | Yes | Human-readable capability name |
```

### Line 70

```text
  69: | Capability ID | Yes | Unique capability identifier |
> 70: | Capability Name | Yes | Human-readable capability name |
  71: | Capability Version | Yes | Semantic version |
```

### Line 71

```text
  70: | Capability Name | Yes | Human-readable capability name |
> 71: | Capability Version | Yes | Semantic version |
  72: | Description | Yes | Functional description |
```

### Line 73

```text
  72: | Description | Yes | Functional description |
> 73: | Capability Category | Yes | Functional classification |
  74: | Input Schemas | Yes | Accepted schemas |
```

### Line 76

```text
  75: | Output Schemas | Yes | Produced schemas |
> 76: | Required Contracts | Yes | Required service contracts |
  77: | Supported Workflow Types | Yes | Compatible workflow categories |
```

### Line 78

```text
  77: | Supported Workflow Types | Yes | Compatible workflow categories |
> 78: | Preconditions | No | Required execution conditions |
  79: | Postconditions | No | Expected execution results |
```

### Line 81

```text
  80: | Provenance ID | Yes | Provenance reference |
> 81: | Metadata | No | Supplemental capability information |
  82: 
```

### Line 85

```text
  84: 
> 85: # Capability Identifier
  86: 
```

### Line 87

```text
  86: 
> 87: Capability identifiers SHALL:
  88: 
```

### Line 100

```text
  99: 
> 100: # Capability Categories
  101: 
```

### Line 102

```text
  101: 
> 102: Capability categories MAY include:
  103: 
```

### Line 106

```text
  105: - Parsing
> 106: - Asset Extraction
  107: - Metadata Extraction
```

### Line 109

```text
  108: - Reference Resolution
> 109: - Validation
  110: - Mapping
```

### Line 116

```text
  115: - Reporting
> 116: - Utility
  117: 
```

### Line 122

```text
  121: 
> 122: # Capability Declaration
  123: 
```

### Line 124

```text
  123: 
> 124: Every registered capability SHALL declare:
  125: 
```

### Line 127

```text
  126: - Functional purpose
> 127: - Required inputs
  128: - Produced outputs
```

### Line 130

```text
  129: - Execution guarantees
> 130: - Validation requirements
  131: - Related specifications
```

### Line 133

```text
  132: 
> 133: Declarations SHALL remain versioned.
  134: 
```

### Line 137

```text
  136: 
> 137: # Capability Composition
  138: 
```

### Line 141

```text
  140: 
> 141: Composed capabilities SHALL:
  142: 
```

### Line 148

```text
  147: 
> 148: Composition SHALL NOT obscure individual capability definitions.
  149: 
```

### Line 152

```text
  151: 
> 152: # Capability Compatibility
  153: 
```

### Line 154

```text
  153: 
> 154: Capability compatibility SHALL verify:
  155: 
```

### Line 163

```text
  162: 
> 163: Compatibility SHALL be explicitly documented.
  164: 
```

### Line 167

```text
  166: 
> 167: # Capability Discovery
  168: 
```

### Line 169

```text
  168: 
> 169: Capability discovery SHALL support searching by:
  170: 
```

### Line 171

```text
  170: 
> 171: - Capability ID
  172: - Capability Name
```

### Line 172

```text
  171: - Capability ID
> 172: - Capability Name
  173: - Category
```

### Line 174

```text
  173: - Category
> 174: - Workflow Type
  175: - Supported Contract
```

### Line 179

```text
  178: 
> 179: Discovery SHALL rely upon the authoritative Service Registry.
  180: 
```

### Line 183

```text
  182: 
> 183: # Capability Validation
  184: 
```

### Line 185

```text
  184: 
> 185: Capability definitions SHALL validate:
  186: 
```

### Line 194

```text
  193: 
> 194: Invalid capabilities SHALL NOT become Active.
  195: 
```

### Line 198

```text
  197: 
> 198: # Capability Evolution
  199: 
```

### Line 202

```text
  201: 
> 202: Major versions SHALL indicate incompatible functional changes.
  203: 
```

### Line 204

```text
  203: 
> 204: Minor versions SHALL introduce backward-compatible enhancements.
  205: 
```

### Line 206

```text
  205: 
> 206: Patch versions SHALL provide non-breaking refinements.
  207: 
```

### Line 208

```text
  207: 
> 208: Historical capability definitions SHALL remain preserved.
  209: 
```

### Line 212

```text
  211: 
> 212: # Capability Lifecycle
  213: 
```

### Line 214

```text
  213: 
> 214: Capability definitions SHALL progress through:
  215: 
```

### Line 242

```text
  241: 
> 242: Lifecycle transitions SHALL be governed by repository policy.
  243: 
```

### Line 246

```text
  245: 
> 246: # Capability Metrics
  247: 
```

### Line 248

```text
  247: 
> 248: Capability services SHOULD expose:
  249: 
```

### Line 257

```text
  256: 
> 257: Metrics SHALL support governance and optimization.
  258: 
```

### Line 261

```text
  260: 
> 261: # Audit Requirements
  262: 
```

### Line 263

```text
  262: 
> 263: Capability operations SHALL record:
  264: 
```

### Line 265

```text
  264: 
> 265: - Capability registration
  266: - Capability modification
```

### Line 266

```text
  265: - Capability registration
> 266: - Capability modification
  267: - Version publication
```

### Line 268

```text
  267: - Version publication
> 268: - Validation results
  269: - Discovery operations
```

### Line 273

```text
  272: 
> 273: Audit records SHALL preserve provenance and remain immutable.
  274: 
```

### Line 277

```text
  276: 
> 277: # Repository Integration
  278: 
```

### Line 290

```text
  289: 
> 290: Capability management SHALL preserve repository integrity and institutional accountability.
  291: 
```

### Line 294

```text
  293: 
> 294: # Design Philosophy
  295: 
```

### Line 300

```text
  299: 
> 300: By governing capabilities as first-class repository assets, the Repository Ingestion Framework separates functional intent from implementation, enabling services to evolve independently while preserving deterministic workflow composition, discoverability, interoperability, and long-term architectural stability.
  301: 
```

