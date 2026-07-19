#!/bin/bash
# Launch a command in the background on a remote host via ssh+nohup; print its PID.
# This is the genuinely ssh-heavy part of remote_launch() -- kept in bash rather than
# reimplemented in Python, since building ssh remote-command strings by hand in Python
# turns into a quoting nightmare fast. See slmn/remote.py for the thin Python wrapper
# (which handles rsync'ing sync_paths first, in plain Python -- that part isn't bash-heavy).
#
# Usage: remote_launch.sh <host> <repo> <log> <cmd>
#   <cmd> is a single argument -- the whole remote command line, exactly as the caller wrote it
#   (quoting and all). Do not split it into multiple argv words before calling this script.
#   env: ENV_PATH (optional, venv root to activate), GPU (optional, sets CUDA_VISIBLE_DEVICES)
set -euo pipefail
HOST="$1"; REPO="$2"; LOG="$3"; CMD="$4"

SSH="ssh -o ClearAllForwardings=yes"

$SSH "$HOST" "mkdir -p '$REPO/logs'"

ENV_PREFIX=""
[[ -n "${ENV_PATH:-}" ]] && ENV_PREFIX="source '$ENV_PATH/bin/activate' && "
GPU_PREFIX=""
[[ -n "${GPU:-}" ]] && GPU_PREFIX="CUDA_VISIBLE_DEVICES=$GPU "

$SSH "$HOST" "cd '$REPO' && ${ENV_PREFIX}${GPU_PREFIX}nohup $CMD > '$LOG' 2>&1 & echo \$!"
