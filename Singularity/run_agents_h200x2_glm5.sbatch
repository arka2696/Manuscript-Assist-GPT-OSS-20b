#!/bin/bash
#PBS -N manuscript_ai_glm5
#PBS -l nodes=1:gpus=2:ppn=64
#PBS -l walltime=24:00:00
#PBS -o slurm_logs/hpc_glm5.log
#PBS -e slurm_logs/hpc_glm5.err
#PBS -A [YOUR_PROJECT_CODE]        # IMPORTANT: Replace with your actual project code

# IMPORTANT: You may need to swap to the specific H200 module for your cluster
# module swap cluster/dodrio/gpu_h200_rhel9  <-- Modify for your specific H200 module path

# Ensure output directory exists (run from project root)
mkdir -p slurm_logs

echo "==========================================================="
echo "Starting NumaScribe Single-Shot on HPC Node: $HOSTNAME"
echo "GPU Configuration: 2x H200 141GB (282 GB Total VRAM)"
echo "Mode: GLM-5 744B (1-bit Quantized) — Reviewer Bypassed"
echo "==========================================================="

# Define paths (Change these to match your HPC workspace)
PROJECT_DIR="$VSC_SCRATCH/Manuscript-Assist-GPT-OSS-20b"
MODELS_DIR="$VSC_SCRATCH/models"
CONTAINER="$PROJECT_DIR/Singularity/manuscript_hpc.sif"

# Verify GPUs
nvidia-smi --list-gpus

# ============================================================
# 1. DRAFTER (Port 8001) — 2x H200 GPUs
#    744B GLM-5 Model (176 GB) + 128K context window
#    Spans across GPUs 0 and 1 automatically.
# ============================================================
echo "[*] Booting GLM-5 AI Engine (Port 8001) across 2x H200 GPUs..."
CUDA_VISIBLE_DEVICES=0,1 singularity exec --nv \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    $CONTAINER \
    llama-server -m /models/GLM-5-UD-TQ1_0.gguf \
    --port 8001 \
    -c 131072 \
    -ngl 99 \
    -t 32 \
    --np 1 \
    --batch-size 4096 \
    --ubatch-size 1024 \
    --flash-attn on > slurm_logs/drafter_glm5.log 2>&1 &

echo "[*] Waiting 180 seconds for massive 176GB VRAM allocation..."
sleep 180

# ============================================================
# 4. BACKEND (Port 8000) — FastAPI + LangGraph
# ============================================================
echo "[*] Booting Python LangGraph Backend (Port 8000)..."
export JWT_SECRET="password123"
export MAX_TOKENS="100000"
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
echo " 2x H200 SYSTEM ONLINE — GLM-5 744B READY"
echo " Context: 128K tokens"
echo " Mode: SINGLE-SHOT (Reviewer bypassed)"
echo ""
echo " To access the UI from your laptop:"
echo " ssh -N -L 5173:$HOSTNAME:5173 -L 8000:$HOSTNAME:8000 $USER@your.hpc.login.node"
echo " Then open http://localhost:5173"
echo "==========================================================="

wait
