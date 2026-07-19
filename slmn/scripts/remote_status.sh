#!/bin/bash
# Check whether a background job on a remote host is still running, and show its log tail.
# Usage: remote_status.sh <host> <log_path_or_dir> [proc_match]
#   If <log_path_or_dir> ends in .log, treated as an exact log path.
#   Otherwise treated as a directory to search for the most recently modified *.log in.
set -euo pipefail
HOST="$1"; TARGET="$2"; PROC_MATCH="${3:-python}"
SSH="ssh -o ClearAllForwardings=yes"

$SSH "$HOST" bash -s -- "$TARGET" "$PROC_MATCH" << 'ENDSSH'
TARGET="$1"; PROC_MATCH="$2"
if [[ "$TARGET" == *.log ]]; then
    LOG="$TARGET"
else
    LOG=$(ls -t "$TARGET"/*.log 2>/dev/null | head -1)
fi
if [ -z "$LOG" ] || [ ! -f "$LOG" ]; then
    echo "No log found"
    exit 1
fi
echo "Log: $LOG"
SIZE1=$(wc -c < "$LOG"); sleep 2; SIZE2=$(wc -c < "$LOG")
GROWING=0; [ "$SIZE2" -gt "$SIZE1" ] && GROWING=1
PID=$(ps aux | grep "[${PROC_MATCH:0:1}]${PROC_MATCH:1}" | awk '{print $2}' | sort -n | head -1)
if [ "$GROWING" -eq 1 ]; then
    echo "Status: RUNNING (log growing$([ -n "$PID" ] && echo ", PID $PID"))"
elif [ -n "$PID" ]; then
    echo "Status: RUNNING (PID $PID, log not growing)"
else
    echo "Status: NOT RUNNING"
fi
echo "--- last 5 lines ---"
tr '\r' '\n' < "$LOG" | grep -vE '[0-9]+it/s|%\|' | grep -v '^\s*$' | tail -5
ENDSSH
