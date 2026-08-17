#!/usr/bin/env bash
set -u

PHONE_URI='mtp://motorola_moto_g_power__2021__ZY22BQZ88B/'

BASE="$HOME/phone-evacuation/moto-g-power-2021"
DEST="$BASE/internal-shared-storage"
EVID="$HOME/migration-evidence"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$EVID/PHONE_SHARED_EVAC_${STAMP}.log"
MANIFEST="$EVID/PHONE_SHARED_DEST_MANIFEST_${STAMP}.tsv"

mkdir -p "$DEST" "$EVID"

exec > >(tee -a "$LOG") 2>&1

echo '=== FULL PHONE SHARED-STORAGE EVACUATION ==='
date --iso-8601=seconds
echo "DEST=$DEST"

echo
echo '=== WAITING FOR FILE-TRANSFER / MTP MODE ==='
echo 'Switch phone USB mode to: File transfer / Android Auto'
echo 'Keep phone unlocked and awake.'

PHONE_MOUNT=''

for attempt in $(seq 1 120); do
    # Ask GVFS to mount once Android exposes MTP.
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

    if (( attempt % 5 == 0 )); then
        printf 'waiting for MTP... %d/120\n' "$attempt"
        lsusb | grep -iE 'motorola|22b8' || true
    fi

    sleep 2
done

if [ -z "$PHONE_MOUNT" ]; then
    echo 'FATAL: MTP mount did not appear.'
    exit 20
fi

SOURCE="$PHONE_MOUNT/Internal shared storage"

if [ ! -d "$SOURCE" ]; then
    echo "FATAL: MTP mounted but shared-storage root was not found."
    echo "PHONE_MOUNT=$PHONE_MOUNT"
    find "$PHONE_MOUNT" -maxdepth 2 -printf '%y\t%p\n' 2>&1 || true
    exit 21
fi

echo
echo '=== MTP ONLINE ==='
echo "PHONE_MOUNT=$PHONE_MOUNT"
echo "SOURCE=$SOURCE"

echo
echo '=== SOURCE TOP LEVEL ==='
find "$SOURCE" \
    -mindepth 1 \
    -maxdepth 1 \
    -printf '%y\t%P\n' 2>&1 \
    | LC_ALL=C sort

echo
echo '=== HOST CAPACITY ==='
df -h "$HOME"

echo
echo '=== COPY ALL SHARED STORAGE ==='

rsync \
    -r \
    --partial \
    --human-readable \
    --info=progress2 \
    "$SOURCE/" "$DEST/"

RC=$?

echo
echo "RSYNC_RC=$RC"

echo
echo '=== DESTINATION MANIFEST ==='

find "$DEST" \
    -type f \
    -printf '%P\t%s\n' \
    | LC_ALL=C sort \
    > "$MANIFEST"

DEST_FILES="$(wc -l < "$MANIFEST")"
DEST_BYTES="$(find "$DEST" -type f -printf '%s\n' | awk '{s+=$1} END {print s+0}')"

echo "DEST_FILES=$DEST_FILES"
echo "DEST_BYTES=$DEST_BYTES"

echo
echo '=== MANIFEST SHA256 ==='
sha256sum "$MANIFEST"

echo
echo '=== ARTIFACTS ==='
echo "LOG=$LOG"
echo "MANIFEST=$MANIFEST"
echo "DEST=$DEST"

if [ "$RC" -ne 0 ]; then
    echo 'PHONE_SHARED_EVAC=INCOMPLETE'
    exit "$RC"
fi

echo 'PHONE_SHARED_EVAC=PASS'
