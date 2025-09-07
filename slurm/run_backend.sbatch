#!/usr/bin/env bash
#SBATCH --job-name=backend
#SBATCH --partition=cpu
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=24:00:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err

set -euo pipefail
source $(dirname $0)/env_setup.sh

cd "$SLURM_SUBMIT_DIR/.." || cd ..
export $(grep -v '^#' .env | xargs)

mkdir -p "$INDEX_DIR" "$UPLOAD_DIR"

python -m pip install --upgrade pip
pip install -r backend/requirements.txt

python -m uvicorn backend.main:app --host ${BACKEND_HOST:-0.0.0.0} --port ${BACKEND_PORT:-8000}
