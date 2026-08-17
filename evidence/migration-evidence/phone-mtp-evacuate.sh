#!/usr/bin/env bash

set -u

PHONE_URI='mtp://motorola_moto_g_power__2021__ZY22BQZ88B/'

BASE="$HOME/phone-evacuation/moto-g-power-2021"
DEST="$BASE/shared-critical"
EVID="$HOME/migration-evidence"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$EVID/PHONE_MTP_EVAC_${STAMP}.log"
INV="$EVID/PHONE_MTP_INVENTORY_${STAMP}.txt"
MANIFEST="$EVID/PHONE_MTP_DEST_MANIFEST_${STAMP}.tsv"

mkdir -p "$DEST" "$EVID"

exec > >(tee -a "$LOG") 2>&1

echo "=== PHONE MTP EVACUATION ==="
date --iso-8601=seconds
echo "DEST=$DEST"

if ! command -v rsync >/dev/null 2>&1; then
    echo "FATAL: rsync is not installed."
    exit 10
fi

echo
echo "=== WAITING FOR MTP ==="

PHONE_MOUNT=""

for attempt in $(seq 1 60); do
    gio mount "$PHONE_URI" >/dev/null 2>&1 || true

    PHONE_MOUNT="$(
        find "/run/user/$UID/gvfs" \
            -maxdepth 1 \
            -type d \
            -name 'mtp:host=*' \
            -print -quit 2>/dev/null
    )"

    if [ -n "$PHONE_MOUNT" ]; then
        break
    fi

    printf 'attempt %02d/60: waiting...\n' "$attempt"
    sleep 2
done

if [ -z "$PHONE_MOUNT" ]; then
    echo "FATAL: MTP mount did not appear."
    exit 20
fi

echo "MTP_MOUNT=$PHONE_MOUNT"

echo
echo "=== INITIAL INVENTORY ==="

find "$PHONE_MOUNT" \
    -mindepth 1 \
    -maxdepth 2 \
    -printf '%y\t%P\n' 2>&1 \
    | LC_ALL=C sort \
    | tee "$INV"

echo
echo "=== CRITICAL SOURCE DISCOVERY ==="

mapfile -d '' SOURCES < <(
    find "$PHONE_MOUNT" \
        -mindepth 1 \
        -maxdepth 3 \
        -type d \
        \( \
            -iname 'DifferenceEngine' \
            -o -iname 'FILE_LIBRARY_UPLOADS' \
            -o -iname 'ADE' \
            -o -iname 'ADE_DIFFERENCE_ENGINE' \
            -o -iname 'ADE_UPLOAD' \
            -o -iname 'Download' \
            -o -iname 'Downloads' \
        \) \
        -print0 2>/dev/null
)

if [ "${#SOURCES[@]}" -eq 0 ]; then
    echo "FATAL: no critical source directories found."
    exit 30
fi

printf 'FOUND=%d\n' "${#SOURCES[@]}"

for src in "${SOURCES[@]}"; do
    printf 'SOURCE=%s\n' "$src"
done

echo
echo "=== COPYING ==="

FAILURES=0

for src in "${SOURCES[@]}"; do
    rel="${src#$PHONE_MOUNT/}"
    dst="$DEST/$rel"

    mkdir -p "$dst"

    echo
    echo "SOURCE=$src"
    echo "DEST=$dst"

    rsync \
        -r \
        --partial \
        --human-readable \
        --info=progress2 \
        "$src/" "$dst/"

    RC=$?

    echo "RSYNC_RC=$RC"

    if [ "$RC" -ne 0 ]; then
        FAILURES=$((FAILURES + 1))
    fi
done

echo
echo "=== DESTINATION MANIFEST ==="

find "$DEST" \
    -type f \
    -printf '%P\t%s\n' \
    | LC_ALL=C sort \
    > "$MANIFEST"

wc -l "$MANIFEST"
sha256sum "$MANIFEST"

echo
echo "=== EVACUATION RESULT ==="
echo "COPY_FAILURES=$FAILURES"
echo "LOG=$LOG"
echo "INVENTORY=$INV"
echo "MANIFEST=$MANIFEST"
echo "DEST=$DEST"

if [ "$FAILURES" -ne 0 ]; then
    exit 40
fi

echo "CRITICAL_SHARED_EVAC=PASS"
