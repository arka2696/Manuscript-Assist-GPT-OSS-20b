#!/usr/bin/env bash
# Usage: ./tunnel.sh USER LOGIN_NODE LOCAL_FRONTEND_PORT LOCAL_BACKEND_PORT
# Example: ./tunnel.sh vsc11013 login.hpc.edu 7001 8000
set -euo pipefail
USER=${1:?user}
HOST=${2:?login_node}
LFRONT=${3:-7001}
LBACK=${4:-8000}

# If frontend runs on cluster port 5173, add another -L accordingly
ssh -N       -L ${LBACK}:127.0.0.1:8000       -L ${LFRONT}:127.0.0.1:5173       ${USER}@${HOST}
