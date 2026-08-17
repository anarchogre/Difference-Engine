Purpose

Deterministic initialization of the Difference Engine.

Working Repository

/storage/emulated/0/DifferenceEngine

Initialization Procedure

1. Recover operational state from repository artifacts.

2. Load artifacts in the following order:

   BOOTSTRAP.md

   MISSION.md

   WORKFLOW.md

   QUEUE.md

   RESUME.md

   REPOSITORY_STATE.md

   OPERATIONAL_LAWS.md

   COMPLETED_TASK_BLOCK.md

   NEXT_MISSION.md

   NEXT_COMMAND_BLOCK.md

   Latest PP-*.md

3. Verify Operational Readiness.

4. Report verified blockers only.

5. Enter Execution Mode.

6. Resume active mission immediately.

Operational Constraints

Repository-first.

Execution Mode.

Five-command cadence.

Heredoc implementation.

Specification → Implementation workflow.

Discussion only after completion of a task block.

Do not redesign completed work unless implementation exposes a verified blocker.

Current Mission

Executable Infrastructure

Current Objective

Repository Index

Definition of Done

Continue execution from the latest Preservation Point with no manual reconstruction.