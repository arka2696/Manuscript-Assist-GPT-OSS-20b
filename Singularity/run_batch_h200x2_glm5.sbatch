#!/bin/bash
#PBS -N manuscript_ai_batch
#PBS -l nodes=1:gpus=2:ppn=64
#PBS -l walltime=24:00:00
#PBS -o slurm_logs/hpc_batch_glm5.log
#PBS -e slurm_logs/hpc_batch_glm5.err
#PBS -A [YOUR_PROJECT_CODE]        # IMPORTANT: Replace with your actual project code

# Ensure output directory exists (run from project root)
mkdir -p slurm_logs

echo "==========================================================="
echo "Starting NumaScribe BATCH MODE on HPC Node: $HOSTNAME"
echo "GPU Configuration: 2x H200 141GB (282 GB Total VRAM)"
echo "Mode: GLM-5 744B (1-bit Quantized) — Headless Batch Processor"
echo "==========================================================="

# Define paths
PROJECT_DIR="$VSC_SCRATCH/Manuscript-Assist-GPT-OSS-20b"
MODELS_DIR="$VSC_SCRATCH/models"
CONTAINER="$PROJECT_DIR/Singularity/manuscript_hpc.sif"

# Verify GPUs
nvidia-smi --list-gpus

# ============================================================
# 1. Start the GLM-5 Engine in the Background
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
    --flash-attn on > slurm_logs/batch_llama.log 2>&1 &

# Capture the Process ID so we can kill it later
LLAMA_PID=$!

echo "[*] Waiting 180 seconds for massive 176GB VRAM allocation..."
sleep 180

# ============================================================
# 2. Execute the Headless Batch Python Script
# ============================================================
echo "[*] Launching Batch Generator Python Script..."

# We don't run uvicorn or the frontend. We just run the local python script.
singularity exec \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    --pwd /app \
    $CONTAINER \
    bash -c "cd /app && python3 backend/batch_generator.py"

echo "[*] Batch Generator Script Completed. Shutting down."

# ============================================================
# 3. Clean up and Exit
# ============================================================
kill $LLAMA_PID
echo "==========================================================="
echo " JOB COMPLETE. Check your batch_workspace/output/ folder!"
echo "==========================================================="
