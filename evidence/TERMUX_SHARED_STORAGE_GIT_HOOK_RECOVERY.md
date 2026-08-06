# Termux Shared-Storage Git Hook Recovery

Status: VERIFIED

- Repository hook: `.githooks/pre-commit`
- Shared storage does not retain its executable bit.
- Direct Bash execution: PASS
- Native Git hook execution before shim: FAIL
- Private executable shim: `$HOME/.local/libexec/DifferenceEngine-hooks/pre-commit`
- Shim mode: `0700`
- `core.hooksPath` points to the private shim directory.
- `git hook run pre-commit`: PASS
- Hook is informational and always exits successfully.

Recovery requirement: recreate the private shim after migration or environment loss.
