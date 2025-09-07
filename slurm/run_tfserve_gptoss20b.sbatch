#!/usr/bin/env bash
#SBATCH --job-name=tfserve-gptoss20b
#SBATCH --partition=gpu
#SBATCH --gpus=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --time=24:00:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err

set -euo pipefail
source $(dirname $0)/env_setup.sh

python -m pip install --upgrade pip
pip install -U transformers kernels torch --extra-index-url https://download.pytorch.org/whl/cu121

# OpenAI-compatible server on 8001
transformers serve --model openai/gpt-oss-20b --host 0.0.0.0 --port 8001
