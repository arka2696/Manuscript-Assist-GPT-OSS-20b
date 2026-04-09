#!/bin/bash
#PBS -N mt_batch_test
#PBS -l nodes=1:gpus=1:ppn=16
#PBS -l walltime=01:00:00
#PBS -o slurm_logs/batch_test_gemma.log
#PBS -e slurm_logs/batch_test_gemma.err
#PBS -A [YOUR_PROJECT_CODE]

# Ensure output directory exists
mkdir -p slurm_logs

echo "==========================================================="
echo "Testing Batch Pipeline with Small Gemma Model (8B)"
echo "==========================================================="

PROJECT_DIR="$VSC_SCRATCH/Manuscript-Assist-GPT-OSS-20b"
MODELS_DIR="$VSC_SCRATCH/models"
CONTAINER="$PROJECT_DIR/Singularity/manuscript_hpc.sif"

# Start the small model 
echo "[*] Booting Gemma 8B..."
singularity exec --nv \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    $CONTAINER \
    llama-server -m /models/gemma-4-e4b-it-Q4_K_M.gguf \
    --port 8001 -c 8192 -ngl 99 -t 8 --flash-attn on > slurm_logs/batch_test_llama.log 2>&1 &
    
LLAMA_PID=$!

echo "[*] Waiting 30 seconds for small model to load..."
sleep 30

echo "[*] Running batch generator..."
singularity exec \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    --pwd /app \
    $CONTAINER \
    bash -c "cd /app && python3 backend/batch_generator.py"

echo "[*] Done. Shutting down AI."
kill $LLAMA_PID
