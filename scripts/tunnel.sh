#!/usr/bin/env bash
# Usage: ./tunnel.sh USER LOGIN_NODE LOCAL_FRONTEND_PORT LOCAL_BACKEND_PORT
# Example: ./tunnel.sh vsc11013 login.hpc.edu 7001 8000
set -euo pipefail
USER=${1:?user}
HOST=${2:?login_node}
LFRONT=${3:-7001}
LBACK=${4:-8000}

# Core ports (Frontend and Backend)
ssh_cmd="ssh -N \
  -L ${LBACK}:127.0.0.1:8000 \
  -L ${LFRONT}:127.0.0.1:5173 \
  -L 8001:127.0.0.1:8001 \
  -L 8002:127.0.0.1:8002 \
  -L 8003:127.0.0.1:8003 \
  -L 8004:127.0.0.1:8004 \
  ${USER}@${HOST}"

echo "Starting tunnel... (Ctrl+C to stop)"
echo "=> Frontend UI: http://localhost:${LFRONT}"
echo "=> Backend API: http://localhost:${LBACK}"
echo "=> Agent Models (Raw API): ports 8001, 8002, 8003, 8004"
eval $ssh_cmd
