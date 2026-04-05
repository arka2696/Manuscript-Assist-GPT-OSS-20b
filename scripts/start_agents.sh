#!/bin/bash

# Multi-Agent Local Deployment Script
# Designed for dual Xeon E5-2683 v3 (14 physical cores per socket) with GPU

echo "Starting llama.cpp agent servers..."
mkdir -p slurm_logs

# Agent 1: Drafter/Writer (Port 8001 | GPU + NUMA Node 0)
# Uses the physical GPU for max speed on the largest model
numactl --cpunodebind=0 --localalloc llama-server \
  --model models/drafter-model.gguf \
  --port 8001 \
  --n-gpu-layers 5 \
  -c 4096 \
  -t 14 \
  > slurm_logs/drafter.log 2>&1 &

# Agent 2: Reviewer/Critic (Port 8002 | CPU NUMA Node 1)
# Pinned completely to the second physical CPU socket
CUDA_VISIBLE_DEVICES="" numactl --cpunodebind=1 --localalloc llama-server \
  --model models/reviewer-model.gguf \
  --port 8002 \
  -c 4096 \
  -t 14 \
  > slurm_logs/reviewer.log 2>&1 &

# Agent 3: Tool Router / RAG Extractor (Port 8003 | CPU NUMA Node 0)
CUDA_VISIBLE_DEVICES="" numactl --cpunodebind=0 --localalloc llama-server \
  --model models/coordinator-model.gguf \
  --port 8003 \
  -c 4096 \
  -t 4 \
  > slurm_logs/router.log 2>&1 &

# Agent 4: Vision Model (Port 8004 | Shared CPU fallback)
# Only starts if the vision model exists, otherwise backend will fallback to Nanobana API
if [ -f "models/vision-model.gguf" ]; then
    numactl --interleave=all llama-server \
      --model models/vision-model.gguf \
      --mmproj models/vision-projector.gguf \
      --port 8004 \
      -c 2048 \
      > slurm_logs/vision.log 2>&1 &
fi

echo "Multi-Agent servers are running. Press Ctrl+C to terminate."
wait
