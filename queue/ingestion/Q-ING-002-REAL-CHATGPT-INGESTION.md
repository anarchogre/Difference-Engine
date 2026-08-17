# Q-ING-002 Real ChatGPT Conversation Ingestion

Status: ACTIVE
Priority: CRITICAL

Mission

Replace the prototype conversation parser.

Execute the complete ingestion pipeline against one real exported
Difference Engine conversation.

Acceptance Criteria

- Receipt generated.
- Original conversation preserved.
- Conversation metadata extracted.
- Every turn identified.
- Speaker attribution preserved.
- Message ordering preserved.
- Markdown blocks preserved.
- Code fences preserved.
- Shell commands extracted.
- Python extracted.
- File paths extracted.
- Repository references extracted.
- URLs extracted.
- Queue candidates generated.
- Provenance attached to every extracted object.
- Deterministic output package produced.
- Entire pipeline passes regression.

Canonical Test Corpus

Difference Engine conversations.

No synthetic conversations except unit tests.

Definition of Done

The ingester can ingest one actual exported project conversation from
start to finish without manual intervention.
