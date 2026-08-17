#!/usr/bin/env bash
# DE_QWEN_SMOKE_DIAG_01.sh
# Read-only diagnostic for the current Qwen smoke-test hang on Forge.
# Does NOT run Qwen, kill processes, hash the model, benchmark, install, or modify the repository.

set -u

ROOT="$HOME/.local/state/Difference-Engine/qwen"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUTDIR="$ROOT/diagnostics"
REPORT="$OUTDIR/${TS}-qwen-smoke-diag.txt"

mkdir -p "$OUTDIR"
exec > >(tee "$REPORT") 2>&1

section() {
    printf '\n===== %s =====\n' "$1"
}

echo "DE QWEN SMOKE DIAGNOSTIC"
echo "UTC=$TS"
echo "HOST=$(hostname)"
echo "REPORT=$REPORT"

# REQUIRED FIRST OBSERVATION FROM CURRENT HANDOFF.
section "EXACT REQUIRED PROCESS CHECK"
ps -o pid,ppid,stat,etime,wchan:24,cmd -C llama-cli || true

section "RELATED LIVE PROCESSES"
ps -eo pid,ppid,sid,stat,etime,wchan:24,comm,args \
  | grep -E '[l]lama-cli|[t]imeout .*llama-cli|[Q]WEN_SMOKE|[Q]WEN_NAP_RUN' \
  || true

section "LLAMA-CLI PER-PROCESS DETAIL"
PIDS="$(pgrep -x llama-cli 2>/dev/null || true)"
if [ -z "$PIDS" ]; then
    echo "LLAMA_CLI_LIVE=NO"
else
    echo "LLAMA_CLI_LIVE=YES"
    for PID in $PIDS; do
        echo "--- PID=$PID ---"
        ps -p "$PID" -o pid,ppid,sid,stat,etime,lstart,wchan:32,%cpu,%mem,rss,vsz,cmd || true
        echo "[status]"
        sed -n '1,120p' "/proc/$PID/status" 2>/dev/null || true
        echo "[threads]"
        ps -L -p "$PID" -o pid,tid,psr,stat,etime,wchan:24,%cpu,comm 2>/dev/null || true
        echo "[cgroup]"
        cat "/proc/$PID/cgroup" 2>/dev/null || true
        echo "[fd-count]"
        if [ -d "/proc/$PID/fd" ]; then
            find "/proc/$PID/fd" -maxdepth 1 -type l 2>/dev/null | wc -l
        fi
    done
fi

section "TIMEOUT PROCESS DETAIL"
pgrep -a timeout 2>/dev/null || echo "NO_TIMEOUT_PROCESS"

section "QWEN EVIDENCE ROOT"
if [ -d "$ROOT" ]; then
    ls -ld "$ROOT"
    echo "-- newest entries --"
    ls -lat "$ROOT" 2>/dev/null | sed -n '1,30p'
else
    echo "MISSING=$ROOT"
fi

section "NEWEST NON-DIAGNOSTIC QWEN RUN"
LATEST=""
if [ -d "$ROOT" ]; then
    LATEST="$(
        find "$ROOT" -mindepth 1 -maxdepth 1 -type d \
          ! -name diagnostics -printf '%T@ %p\n' 2>/dev/null \
        | sort -nr \
        | head -1 \
        | cut -d' ' -f2-
    )"
fi

if [ -z "$LATEST" ]; then
    echo "LATEST_RUN=NONE"
else
    echo "LATEST_RUN=$LATEST"
    stat "$LATEST" 2>/dev/null || true

    echo "-- files --"
    find "$LATEST" -maxdepth 1 -type f -printf '%TY-%Tm-%TdT%TH:%TM:%TS %10s %f\n' \
      2>/dev/null | sort || true

    for F in SUMMARY.txt run.log smoke-output.txt smoke.stderr.txt; do
        if [ -f "$LATEST/$F" ]; then
            echo
            echo "----- $LATEST/$F -----"
            case "$F" in
                smoke.stderr.txt|run.log)
                    tail -120 "$LATEST/$F" 2>/dev/null || true
                    ;;
                *)
                    sed -n '1,160p' "$LATEST/$F" 2>/dev/null || true
                    ;;
            esac
        else
            echo "ABSENT=$LATEST/$F"
        fi
    done
fi

section "BOOT / UPTIME / CLOCK"
date
date -u
uptime
uptime -s 2>/dev/null || true
who -b 2>/dev/null || true
cat /proc/uptime 2>/dev/null || true

section "SUSPEND / SLEEP EVIDENCE CURRENT BOOT"
echo "-- targeted journal scan, last 12 hours --"
journalctl -b --since "12 hours ago" --no-pager -o short-iso 2>&1 \
  | grep -Ei \
    'suspend|suspending|resume|resumed|sleep|systemd-sleep|PM: suspend|PM: resume|freeze|hibernat|lid' \
  | tail -240 \
  || true

section "SYSTEMD SLEEP TARGET STATE"
systemctl status sleep.target suspend.target hibernate.target hybrid-sleep.target \
  --no-pager 2>&1 | sed -n '1,220p' || true

section "CURRENT INHIBITORS"
systemd-inhibit --list 2>&1 || true

section "PATH CASE CHECK"
for P in \
    "$HOME/.local/share/Difference-Engine" \
    "$HOME/.local/share/difference-engine" \
    "$HOME/.local/libexec/Difference-Engine" \
    "$HOME/.local/libexec/difference-engine"
do
    if [ -e "$P" ]; then
        echo "PRESENT=$P"
        ls -ld "$P"
    else
        echo "ABSENT=$P"
    fi
done

section "RUNTIME BINARY CHECK — NO EXECUTION"
for P in \
    "$HOME/.local/libexec/Difference-Engine/llama.cpp/llama-cli" \
    "$HOME/.local/libexec/difference-engine/llama.cpp/llama-cli"
do
    if [ -e "$P" ]; then
        echo "PRESENT=$P"
        ls -l "$P"
        file "$P" 2>/dev/null || true
    else
        echo "ABSENT=$P"
    fi
done

section "KERNEL OOM / HANG-ADJACENT EVIDENCE"
journalctl -k -b --since "12 hours ago" --no-pager -o short-iso 2>&1 \
  | grep -Ei 'oom|out of memory|killed process|blocked for more than|hung task|i/o error|nvme|segfault' \
  | tail -200 \
  || true

section "DIAGNOSTIC COMPLETE"
echo "REPORT=$REPORT"
echo "NEXT=TRANSFER_THIS_REPORT_BACK_FOR_ANALYSIS"
