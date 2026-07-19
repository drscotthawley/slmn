#!/bin/bash
# Run a quick, blocking command on a remote host (e.g. a smoke test) and show its output.
# Usage: remote_smoke.sh <host> <repo> <cmd>
#   <cmd> is a single argument -- the whole remote command line, exactly as the caller wrote it.
#   env: ENV_PATH (optional, venv root to activate)
set -euo pipefail
HOST="$1"; REPO="$2"; CMD="$3"
SSH="ssh -o ClearAllForwardings=yes"

ENV_PREFIX=""
[[ -n "${ENV_PATH:-}" ]] && ENV_PREFIX="source '$ENV_PATH/bin/activate' && "

$SSH "$HOST" "cd '$REPO' && ${ENV_PREFIX}${CMD}"
