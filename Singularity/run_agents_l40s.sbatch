#!/bin/bash
#SBATCH --job-name=manuscript_ai_l40s
#SBATCH --partition=gpu
#SBATCH --gres=gpu:l40s:1              # Request 1 L40S GPU (48GB VRAM)
#SBATCH --cpus-per-task=32             # 32 CPU Cores
#SBATCH --mem=128G                     # 128GB RAM
#SBATCH --time=24:00:00                # 24 hour runtime
#SBATCH --output=slurm_logs/hpc_l40s_%j.log

# Ensure output directory exists (run from project root)
mkdir -p slurm_logs

echo "=========================================================="
echo "Starting Multi-Agent System on HPC Node: $HOSTNAME (L40S Configuration)"
echo "=========================================================="

# Define paths (Change these to match your HPC workspace)
PROJECT_DIR="/scratch/$USER/Manuscript-Assist-GPT-OSS-20b"
MODELS_DIR="/scratch/$USER/models"
CONTAINER="$PROJECT_DIR/Singularity/manuscript_hpc.sif"

# 1. Start the Llama.cpp Drafter Agent on GPU
echo "[*] Booting Drafter AI Engine (Port 8001) onto L40S VRAM..."
singularity exec --nv \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    $CONTAINER \
    llama-server -m /models/gemma-4-31B-it-Q4_K_M.gguf \
    --port 8001 -c 4096 -ngl 99 -t 14 > slurm_logs/drafter.log 2>&1 &

# 2. Start the Llama.cpp Reviewer Agent on GPU
echo "[*] Booting Reviewer AI Engine (Port 8002) onto L40S VRAM..."
singularity exec --nv \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    $CONTAINER \
    llama-server -m /models/Ministral-3-14B-Reasoning-2512-Q8_0.gguf \
    --port 8002 -c 4096 -ngl 99 -t 14 > slurm_logs/reviewer.log 2>&1 &

# 3. Start the Router Agent on GPU
echo "[*] Booting Router Engine (Port 8003) onto L40S VRAM..."
singularity exec --nv \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    $CONTAINER \
    llama-server -m /models/gemma-4-e4b-it-Q4_K_M.gguf \
    --port 8003 -c 4096 -ngl 99 -t 4 > slurm_logs/router.log 2>&1 &

echo "[*] Waiting 60 seconds for full massive VRAM allocation across all 3 models..."
sleep 60

# 4. Start the Python FastAPI Backend
echo "[*] Booting Python LangGraph Backend (Port 8000)..."
export JWT_SECRET="password123" # Must match your frontend environment expectation
singularity exec \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    --pwd /app \
    $CONTAINER \
    bash -c "cd /app && python3 -m uvicorn backend.main:app --host 0.0.0.0 --port 8000" > slurm_logs/backend.log 2>&1 &

# 5. Start the React Frontend UI
echo "[*] Booting React User Interface (Port 5173)..."
singularity exec \
    --bind $PROJECT_DIR:/app \
    --pwd /app \
    $CONTAINER \
    bash -c "cd frontend && npm install && npm run dev -- --host 0.0.0.0" > slurm_logs/frontend.log 2>&1 &

echo "=========================================================="
echo " L40S TRIPLE-GPU SYSTEM ONLINE."
echo " To access the UI from your laptop, open a terminal on your laptop and run:"
echo " ssh -N -L 5173:$HOSTNAME:5173 -L 8000:$HOSTNAME:8000 $USER@your.hpc.login.node"
echo " Then open http://localhost:5173 in your desktop browser!"
echo "=========================================================="

wait
