#!/usr/bin/env bash
set -euo pipefail

# Load modules or activate Conda here (edit for your cluster)
module purge || true
module load CUDA/12.2 || true
module load cuDNN || true

# Conda env (optional)
if [ -z "${CONDA_DEFAULT_ENV:-}" ]; then
  if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
    conda activate manuscript || true
  fi
fi
