# Termux Clipboard Output Integration

Status: VERIFIED

- Package: `termux-api 0.59.1`
- Android API bridge: PRESENT
- Clipboard set/get round-trip: PASS
- Helper: `$PREFIX/bin/de-copyout`
- Helper mode: `0700`
- Behavior: copies standard input to Android clipboard and prints identical output.
- Purpose: reduce mobile terminal copy/paste loss and operator burden.

Recovery requirement: recreate the helper after Termux environment loss or migration.
Repository-backed installer/source: QUEUED.
