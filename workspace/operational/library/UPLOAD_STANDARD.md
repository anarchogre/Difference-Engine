# Difference Engine File Library Upload Standard

Status: Candidate  
Authority: Operations

## Filename

Use:

`IDENTIFIER__DESCRIPTIVE_NAME__VERSION.ext`

Avoid:

- automatic numeric suffixes;
- ambiguous spaces;
- unexplained abbreviations;
- duplicate canonical names;
- filenames containing status without metadata.

## Required Upload Record

Record:

- stable artifact identifier;
- canonical filename;
- source filename;
- repository destination;
- classification;
- lifecycle state;
- provenance;
- version;
- verification status.

## Upload Procedure

1. identify artifact;
2. classify artifact;
3. determine repository destination;
4. assign lifecycle state;
5. upload artifact;
6. verify availability;
7. update Canonical Library Index;
8. record aliases;
9. detect duplicates;
10. commit repository metadata.

## Replacement Uploads

Do not delete the prior artifact before:

- verifying the replacement;
- recording supersession;
- preserving provenance;
- updating the index.

## Prohibited Behavior

- silent canonical promotion;
- silent overwrite;
- untracked renaming;
- deletion without replacement evidence;
- treating upload order as authority.
