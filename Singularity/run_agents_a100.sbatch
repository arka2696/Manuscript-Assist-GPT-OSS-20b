#!/bin/bash
#SBATCH --job-name=manuscript_ai_a100
#SBATCH --partition=gpu
#SBATCH --gres=gpu:a100:1              # Request 1x A100 SXM4 80GB
#SBATCH --cpus-per-task=32             # 32 CPU Cores
#SBATCH --mem=128G                     # 128GB RAM
#SBATCH --time=24:00:00                # 24 hour runtime
#SBATCH --output=slurm_logs/hpc_a100_%j.log

# Ensure output directory exists
mkdir -p slurm_logs

echo "================================================================"
echo "Starting Multi-Agent System on HPC Node: $HOSTNAME"
echo "GPU: 1x A100 SXM4 80GB — MAX CONTEXT MODE"
echo "================================================================"

# Define paths (Change these to match your HPC workspace)
PROJECT_DIR="$VSC_SCRATCH/Manuscript-Assist-GPT-OSS-20b"
MODELS_DIR="$VSC_SCRATCH/models"
CONTAINER="$PROJECT_DIR/Singularity/manuscript_hpc.sif"

nvidia-smi --list-gpus

# ================================================================
#  VRAM BUDGET (80 GB total):
#  ┌──────────────────────────────────────────────────┐
#  │ Drafter   31B Q4_K_M  = 17.4 GB  (model)        │
#  │           128K context = ~13 GB   (KV cache)     │
#  │ Reviewer  14B Q8_0    = 14.0 GB  (model)         │
#  │           16K context  = ~2 GB    (KV cache)     │
#  │ Router    8B  Q4_K_M  = 4.5 GB   (model)         │
#  │           4K context   = ~0.5 GB  (KV cache)     │
#  │ Compute buffers        = ~3 GB                   │
#  ├──────────────────────────────────────────────────┤
#  │ TOTAL                 ≈ 55 GB / 80 GB available  │
#  │ Headroom              ≈ 25 GB FREE               │
#  └──────────────────────────────────────────────────┘
# ================================================================

# 1. DRAFTER — 128K Context (generates up to ~100,000 words)
echo "[*] Booting Drafter (Port 8001) — 128K context, full GPU offload..."
singularity exec --nv \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    $CONTAINER \
    llama-server -m /models/gemma-4-31B-it-Q4_K_M.gguf \
    --port 8001 \
    -c 131072 \
    -ngl 99 \
    -t 16 \
    --flash-attn \
    > slurm_logs/drafter.log 2>&1 &

# 2. REVIEWER — 16K Context (enough for full review passes)
echo "[*] Booting Reviewer (Port 8002) — 16K context, full GPU offload..."
singularity exec --nv \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    $CONTAINER \
    llama-server -m /models/Ministral-3-14B-Reasoning-2512-Q8_0.gguf \
    --port 8002 \
    -c 16384 \
    -ngl 99 \
    -t 16 \
    --flash-attn \
    > slurm_logs/reviewer.log 2>&1 &

# 3. ROUTER — 4K Context (fast classification, doesn't need more)
echo "[*] Booting Router (Port 8003) — 4K context, full GPU offload..."
singularity exec --nv \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    $CONTAINER \
    llama-server -m /models/gemma-4-e4b-it-Q4_K_M.gguf \
    --port 8003 \
    -c 4096 \
    -ngl 99 \
    -t 4 \
    --flash-attn \
    > slurm_logs/router.log 2>&1 &

echo "[*] Waiting 120 seconds for full 128K VRAM allocation..."
sleep 120

# 4. BACKEND — FastAPI + LangGraph
echo "[*] Booting Python LangGraph Backend (Port 8000)..."
export JWT_SECRET="password123"
export MAX_TOKENS="100000"
singularity exec \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    --pwd /app \
    $CONTAINER \
    bash -c "cd /app && python3 -m uvicorn backend.main:app --host 0.0.0.0 --port 8000" > slurm_logs/backend.log 2>&1 &

# 5. FRONTEND — React UI
echo "[*] Booting React User Interface (Port 5173)..."
singularity exec \
    --bind $PROJECT_DIR:/app \
    --pwd /app \
    $CONTAINER \
    bash -c "cd frontend && npm install && npm run dev -- --host 0.0.0.0" > slurm_logs/frontend.log 2>&1 &

echo "================================================================"
echo " A100 80GB — MAX CONTEXT SYSTEM ONLINE"
echo " Drafter: 128K context | Reviewer: 16K | Router: 4K"
echo " All 3 models fully loaded in GPU VRAM (~55/80 GB used)"
echo ""
echo " MAX_TOKENS = 100,000 (~75,000 words per generation)"
echo ""
echo " SSH tunnel from your laptop:"
echo " ssh -N -L 5173:$HOSTNAME:5173 -L 8000:$HOSTNAME:8000 $USER@login.hpc.vub.be"
echo " Then open http://localhost:5173"
echo "================================================================"

wait
