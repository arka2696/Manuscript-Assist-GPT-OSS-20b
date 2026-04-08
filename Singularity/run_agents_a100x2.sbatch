#!/bin/bash
#SBATCH --job-name=manuscript_ai_a100
#SBATCH --partition=gpu
#SBATCH --gres=gpu:a100:2              # Request 2x A100 SXM4 80GB GPUs
#SBATCH --cpus-per-task=64             # 64 CPU Cores
#SBATCH --mem=256G                     # 256GB RAM
#SBATCH --time=24:00:00                # 24 hour runtime
#SBATCH --output=slurm_logs/hpc_a100_%j.log

# Ensure output directory exists (run from project root)
mkdir -p slurm_logs

echo "==========================================================="
echo "Starting Multi-Agent System on HPC Node: $HOSTNAME"
echo "GPU Configuration: 2x A100 SXM4 80GB (160 GB Total VRAM)"
echo "==========================================================="

# Define paths (Change these to match your HPC workspace)
PROJECT_DIR="$VSC_SCRATCH/Manuscript-Assist-GPT-OSS-20b"
MODELS_DIR="$VSC_SCRATCH/models"
CONTAINER="$PROJECT_DIR/Singularity/manuscript_hpc.sif"

# Verify GPUs
nvidia-smi --list-gpus

# ============================================================
# 1. DRAFTER (Port 8001) — GPU 0 (A100 80GB)
#    31B model fully in VRAM + 65K context window
#    This gives ~50,000 words of generation capacity
# ============================================================
echo "[*] Booting Drafter AI Engine (Port 8001) on GPU 0 — 65K context..."
CUDA_VISIBLE_DEVICES=0 singularity exec --nv \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    $CONTAINER \
    llama-server -m /models/gemma-4-31B-it-Q4_K_M.gguf \
    --port 8001 -c 65536 -ngl 99 -t 16 --flash-attn > slurm_logs/drafter.log 2>&1 &

# ============================================================
# 2. REVIEWER (Port 8002) — GPU 1 (A100 80GB)
#    14B model fully in VRAM + 16K context
# ============================================================
echo "[*] Booting Reviewer AI Engine (Port 8002) on GPU 1..."
CUDA_VISIBLE_DEVICES=1 singularity exec --nv \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    $CONTAINER \
    llama-server -m /models/Ministral-3-14B-Reasoning-2512-Q8_0.gguf \
    --port 8002 -c 16384 -ngl 99 -t 16 --flash-attn > slurm_logs/reviewer.log 2>&1 &

# ============================================================
# 3. ROUTER (Port 8003) — GPU 1 (shares with Reviewer)
#    8B model is tiny, easily fits alongside the 14B
# ============================================================
echo "[*] Booting Router Engine (Port 8003) on GPU 1..."
CUDA_VISIBLE_DEVICES=1 singularity exec --nv \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    $CONTAINER \
    llama-server -m /models/gemma-4-e4b-it-Q4_K_M.gguf \
    --port 8003 -c 8192 -ngl 99 -t 8 --flash-attn > slurm_logs/router.log 2>&1 &

echo "[*] Waiting 90 seconds for full VRAM allocation across all models..."
sleep 90

# ============================================================
# 4. BACKEND (Port 8000) — FastAPI + LangGraph
# ============================================================
echo "[*] Booting Python LangGraph Backend (Port 8000)..."
export JWT_SECRET="password123"
export MAX_TOKENS="50000"
singularity exec \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    --pwd /app \
    $CONTAINER \
    bash -c "cd /app && python3 -m uvicorn backend.main:app --host 0.0.0.0 --port 8000" > slurm_logs/backend.log 2>&1 &

# ============================================================
# 5. FRONTEND (Port 5173) — React UI
# ============================================================
echo "[*] Booting React User Interface (Port 5173)..."
singularity exec \
    --bind $PROJECT_DIR:/app \
    --pwd /app \
    $CONTAINER \
    bash -c "cd frontend && npm install && npm run dev -- --host 0.0.0.0" > slurm_logs/frontend.log 2>&1 &

echo "==========================================================="
echo " 2x A100 SYSTEM ONLINE — 160 GB VRAM ACTIVE"
echo " Drafter: 65K context (GPU 0) | Reviewer: 16K (GPU 1)"
echo ""
echo " To access the UI from your laptop:"
echo " ssh -N -L 5173:$HOSTNAME:5173 -L 8000:$HOSTNAME:8000 $USER@your.hpc.login.node"
echo " Then open http://localhost:5173"
echo "==========================================================="

wait
