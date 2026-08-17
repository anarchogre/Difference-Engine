#!/usr/bin/env bash
# DE_QWEN_SMOKE_MONITOR.sh
# Read-only live monitor for Difference Engine Qwen smoke runs.
# Watches process state, CPU/RAM, timeout wrapper, evidence files, and output growth.
# Does NOT start, stop, continue, kill, or modify Qwen processes.

set -u

INTERVAL="${DE_MONITOR_INTERVAL:-5}"
STATE_ROOT="$HOME/.local/state/Difference-Engine/qwen"
LOG_ROOT="$STATE_ROOT/diagnostics"
mkdir -p "$LOG_ROOT"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$LOG_ROOT/${TS}-qwen-live-monitor.log"

human_state() {
    case "$1" in
        R*) echo "RUNNING" ;;
        S*) echo "SLEEPING/WAITING" ;;
        D*) echo "UNINTERRUPTIBLE_IO_WAIT" ;;
        T*|t*) echo "STOPPED_BY_SIGNAL_OR_JOB_CONTROL" ;;
        Z*) echo "ZOMBIE" ;;
        I*) echo "IDLE_KERNEL_THREAD" ;;
        *) echo "UNKNOWN" ;;
    esac
}

latest_run() {
    find "$STATE_ROOT" -mindepth 1 -maxdepth 1 -type d \
        ! -name diagnostics \
        -printf '%T@ %p\n' 2>/dev/null \
      | sort -nr \
      | head -1 \
      | cut -d' ' -f2-
}

clear
echo "DE QWEN LIVE MONITOR"
echo "HOST=$(hostname)"
echo "INTERVAL=${INTERVAL}s"
echo "LOG=$LOG"
echo
echo "Ctrl-C stops MONITORING ONLY. It does not affect Qwen."
sleep 1

while true; do
    NOW_LOCAL="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    NOW_UTC="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

    PIDS="$(pgrep -x llama-cli 2>/dev/null || true)"
    TIMEOUTS="$(pgrep -a timeout 2>/dev/null | grep 'llama-cli' || true)"
    SMOKES="$(ps -eo pid,ppid,stat,etime,args 2>/dev/null | grep -E '[Q]WEN_SMOKE|[s]moke-only' || true)"
    RUN_DIR="$(latest_run)"

    clear
    echo "======================================================================"
    echo " DE QWEN LIVE MONITOR"
    echo " $NOW_LOCAL | $NOW_UTC"
    echo "======================================================================"

    if [ -z "$PIDS" ]; then
        echo
        echo "LLAMA-CLI: NOT RUNNING"
    else
        echo
        echo "LLAMA-CLI:"
        for PID in $PIDS; do
            ROW="$(ps -p "$PID" -o pid=,ppid=,stat=,etime=,%cpu=,%mem=,rss=,wchan:24= 2>/dev/null || true)"
            if [ -n "$ROW" ]; then
                STAT="$(ps -p "$PID" -o stat= 2>/dev/null | xargs)"
                CLASS="$(human_state "$STAT")"
                echo "$ROW"
                echo "  CLASSIFICATION=$CLASS"

                THREADS="$(ps -L -p "$PID" --no-headers 2>/dev/null | wc -l)"
                FDS="$(find "/proc/$PID/fd" -maxdepth 1 -type l 2>/dev/null | wc -l)"
                echo "  THREADS=$THREADS FD_COUNT=$FDS"

                if [[ "$STAT" == T* || "$STAT" == t* ]]; then
                    echo "  ALERT: PROCESS IS STOPPED — CPU WORK CANNOT PROGRESS"
                elif [[ "$STAT" == D* ]]; then
                    echo "  ALERT: PROCESS IS IN UNINTERRUPTIBLE I/O WAIT"
                fi
            fi
        done
    fi

    echo
    echo "TIMEOUT WRAPPER:"
    if [ -n "$TIMEOUTS" ]; then
        echo "$TIMEOUTS"
        while read -r TPID _; do
            [ -n "${TPID:-}" ] || continue
            ps -p "$TPID" -o pid,ppid,stat,etime,wchan:24,cmd 2>/dev/null || true
        done <<< "$TIMEOUTS"
    else
        echo "NONE"
    fi

    echo
    echo "SMOKE SHELL:"
    if [ -n "$SMOKES" ]; then
        echo "$SMOKES"
    else
        echo "NONE"
    fi

    echo
    echo "LATEST EVIDENCE:"
    if [ -n "$RUN_DIR" ] && [ -d "$RUN_DIR" ]; then
        echo "RUN_DIR=$RUN_DIR"
        for F in smoke-output.txt smoke.stderr.txt run.log SUMMARY.txt; do
            if [ -f "$RUN_DIR/$F" ]; then
                SIZE="$(stat -c '%s' "$RUN_DIR/$F" 2>/dev/null || echo '?')"
                MTIME="$(stat -c '%y' "$RUN_DIR/$F" 2>/dev/null | cut -d'.' -f1 || true)"
                echo "  $F bytes=$SIZE modified=$MTIME"
            else
                echo "  $F ABSENT"
            fi
        done

        if [ -s "$RUN_DIR/smoke-output.txt" ]; then
            echo
            echo "--- LAST OUTPUT ---"
            tail -8 "$RUN_DIR/smoke-output.txt" 2>/dev/null || true
        fi

        if [ -s "$RUN_DIR/smoke.stderr.txt" ]; then
            echo
            echo "--- LAST STDERR ---"
            tail -8 "$RUN_DIR/smoke.stderr.txt" 2>/dev/null || true
        fi
    else
        echo "NO RUN DIRECTORY FOUND"
    fi

    echo
    echo "SYSTEM:"
    free -h | sed -n '1,3p'
    echo
    uptime

    {
        echo "===== $NOW_LOCAL ====="
        if [ -n "$PIDS" ]; then
            ps -p "$(echo "$PIDS" | head -1)" \
                -o pid,ppid,stat,etime,%cpu,%mem,rss,wchan:24,cmd 2>/dev/null || true
        else
            echo "LLAMA_CLI=NONE"
        fi
        [ -n "$TIMEOUTS" ] && echo "$TIMEOUTS" || echo "TIMEOUT=NONE"
        echo "RUN_DIR=${RUN_DIR:-NONE}"
        if [ -n "$RUN_DIR" ] && [ -d "$RUN_DIR" ]; then
            for F in smoke-output.txt smoke.stderr.txt run.log SUMMARY.txt; do
                if [ -e "$RUN_DIR/$F" ]; then
                    stat -c "$F BYTES=%s MTIME=%y" "$RUN_DIR/$F" 2>/dev/null || true
                fi
            done
        fi
        echo
    } >> "$LOG"

    echo
    echo "Monitor log: $LOG"
    echo "Refresh: ${INTERVAL}s | Ctrl-C exits monitor only"

    sleep "$INTERVAL"
done
