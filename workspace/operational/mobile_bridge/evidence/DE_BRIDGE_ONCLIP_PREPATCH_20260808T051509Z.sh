#!/usr/bin/env bash
set -u

REPO="${HOME}/DifferenceEngine"
BIN="${HOME}/.local/bin"
TMPBASE="${XDG_RUNTIME_DIR:-/tmp}"
IN="$(mktemp "${TMPBASE}/de-bridge-in.XXXXXX")"
OUT="$(mktemp "${TMPBASE}/de-bridge-out.XXXXXX")"

cleanup() {
    rm -f "$IN" "$OUT"
}
trap cleanup EXIT

cat > "$IN"

FIRST="$(head -n 1 "$IN" 2>/dev/null || true)"

# Fail closed. Only explicitly marked ChatGPT command blocks execute.
[ "$FIRST" = '# DE-RUN' ] || exit 0

{
    printf '=== DE BRIDGE EXECUTION ===\n'
    printf 'DATE_UTC=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'SOURCE=WAYLAND_CLIPBOARD\n'
    printf 'REPOSITORY=%s\n' "$REPO"
    printf '%s\n' '--- OUTPUT ---'

    cd "$REPO" || exit 1

    set +e
    bash "$IN"
    RC=$?
    set -e

    printf '%s\n' '--- RESULT ---'
    printf 'EXIT=%s\n' "$RC"

    exit "$RC"
} >"$OUT" 2>&1
RC=$?

"$BIN/de-copyout" "$OUT"

exit "$RC"
