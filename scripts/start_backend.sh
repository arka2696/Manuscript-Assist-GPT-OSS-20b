#!/usr/bin/env bash
# Start the Local FastAPI Backend

set -euo pipefail

# Fallback to current directory
cd "$(dirname "$0")/.."

# Load environment variables if .env exists
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Ensure storage directories exist
mkdir -p "$INDEX_DIR" "$UPLOAD_DIR"

if [ ! -d "venv" ]; then
    echo "Creating virtual environment 'venv' to prevent polluting conda base..."
    python3 -m venv venv
fi

echo "Activating virtual environment..."
source venv/bin/activate

echo "Checking Python dependencies..."
python -m pip install --upgrade pip
pip install -r backend/requirements.txt

echo "Starting Manuscript Assistant Backend..."
python -m uvicorn backend.main:app --host ${BACKEND_HOST:-0.0.0.0} --port ${BACKEND_PORT:-8000}
