#!/bin/bash
#SBATCH --job-name=manuscript_turbo
#SBATCH --partition=hopper_gpu         # Adjust layout as needed
#SBATCH --nodes=1
#SBATCH --gres=gpu:1                   # Using 1 GPU to test compression
#SBATCH --ntasks-per-gpu=1             
#SBATCH --cpus-per-task=16             
#SBATCH --mem=128G                     
#SBATCH --time=12:00:00                
#SBATCH --output=slurm_logs/hpc_turbo_%j.log

# Ensure output directory exists
mkdir -p slurm_logs

echo "==========================================================="
echo "Starting NumaScribe TURBOQUANT + OPEN-WEBUI on HPC"
echo "==========================================================="

# Update with your correct actual project path
PROJECT_DIR="$(pwd)"
MODELS_DIR="$PROJECT_DIR/models"
CONTAINER="$PROJECT_DIR/Singularity/turboquant.sif"

# Check if the custom container exists
if [ ! -f "$CONTAINER" ]; then
    echo "[!] ERROR: turboquant.sif not found! You must build it first."
    echo "[!] Run: apptainer build Singularity/turboquant.sif Singularity/turboquant.def"
    exit 1
fi

# ============================================================
# 1. AI Engine (Port 8001) - With TURBO3 Compression
# ============================================================
echo "[*] Booting TurboQuant Engine (Port 8001)..."
singularity exec --nv \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    $CONTAINER \
    llama-server -m /models/gemma-4-e4b-it-Q4_K_M.gguf \
    --port 8001 \
    -c 32768 \
    -ngl 99 \
    --flash-attn on \
    --cache-type-k turbo3 \
    --cache-type-v turbo3 > slurm_logs/turbo_llama.log 2>&1 &

echo "[*] Waiting 30s for the Engine..."
sleep 30

# ============================================================
# 2. Open-WebUI (Port 8080) - ChatGPT Interface
# ============================================================
echo "[*] Booting Open-WebUI (Port 8080)..."
export OPENAI_API_BASE_URL="http://127.0.0.1:8001/v1"
export OPENAI_API_KEY="sk-dummy"
export WEBUI_AUTH="False"
export DO_NOT_TRACK="True"

singularity exec \
    --bind $PROJECT_DIR:/app \
    --pwd /app \
    $CONTAINER \
    bash -c "open-webui serve --host 0.0.0.0 --port 8080" > slurm_logs/turbo_openwebui.log 2>&1 &

# ============================================================
# 3. NumaScribe Backend (Port 8000)
# ============================================================
echo "[*] Booting NumaScribe AI Graph (Port 8000)..."
singularity exec \
    --bind $PROJECT_DIR:/app \
    --pwd /app \
    $CONTAINER \
    bash -c "python3 -m uvicorn backend.main:app --host 0.0.0.0 --port 8000" > slurm_logs/turbo_backend.log 2>&1 &

# ============================================================
# 4. NumaScribe Frontend (Port 5173)
# ============================================================
echo "[*] Booting Interactive Pipeline Dashboard (Port 5173)..."
singularity exec \
    --bind $PROJECT_DIR:/app \
    --pwd /app \
    $CONTAINER \
    bash -c "cd frontend && npm run dev -- --host 0.0.0.0" > slurm_logs/turbo_frontend.log 2>&1 &

echo "==========================================================="
echo " ALL SYSTEMS GO!"
echo " Tunnel into the node using your SSH command."
echo " Choose your UI:"
echo " -> http://localhost:5173  (NumaScribe Draft/Review Pipeline)"
echo " -> http://localhost:8080  (Open-WebUI Fast Chat Interface)"
echo "==========================================================="

wait
