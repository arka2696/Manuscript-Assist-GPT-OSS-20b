#!/usr/bin/env bash
#SBATCH --job-name=vllm-gptoss20b
#SBATCH --partition=gpu
#SBATCH --gpus=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --time=24:00:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err

set -euo pipefail
source $(dirname $0)/env_setup.sh

PORT=${VLLM_PORT:-8001}
MODEL_NAME=${MODEL_NAME:-openai/gpt-oss-20b}

python -m venv .venv_vllm || true
source .venv_vllm/bin/activate
python -m pip install --upgrade pip uv
uv pip install --pre vllm==0.10.1+gptoss       --extra-index-url https://wheels.vllm.ai/gpt-oss/       --extra-index-url https://download.pytorch.org/whl/nightly/cu128       --index-strategy unsafe-best-match

vllm serve "$MODEL_NAME"       --host 0.0.0.0       --port ${PORT}       --max-model-len 16384       --tensor-parallel-size 1       --gpu-memory-utilization 0.92
