#!/bin/bash
echo "==========================================================="
echo "Starting NumaScribe TURBOQUANT + OPEN-WEBUI (Local PC)"
echo "==========================================================="

PROJECT_DIR="$(pwd)"
MODELS_DIR="$PROJECT_DIR/models"
CONTAINER="Singularity/turboquant.sif"

if [ ! -f "$CONTAINER" ]; then
    echo "[!] ERROR: turboquant.sif not found! You must build it first."
    echo "[!] Run: sudo apptainer build Singularity/turboquant.sif Singularity/turboquant.def"
    exit 1
fi

# Stop previous instances if running
pkill -f llama-server
pkill -f uvicorn
pkill -f open-webui

# 1. AI Engine
echo "[*] Booting TurboQuant Engine (Port 8001)..."
apptainer exec --nv \
    --bind $MODELS_DIR:/models \
    --bind $PROJECT_DIR:/app \
    $CONTAINER \
    llama-server -m /models/gemma-4-e4b-it-Q4_K_M.gguf \
    --port 8001 \
    -c 8192 \
    -ngl 99 \
    --flash-attn on \
    --cache-type-k turbo3 \
    --cache-type-v turbo3 > local_turbo_llama.log 2>&1 &

sleep 5

# 2. Open-WebUI
echo "[*] Booting Open-WebUI (Port 8080)..."
export OPENAI_API_BASE_URL="http://127.0.0.1:8001/v1"
export OPENAI_API_KEY="sk-dummy"
export WEBUI_AUTH="False"
export DO_NOT_TRACK="True"

apptainer exec \
    --bind $PROJECT_DIR:/app \
    --pwd /app \
    $CONTAINER \
    bash -c "open-webui serve --host 0.0.0.0 --port 8080" > local_turbo_openwebui.log 2>&1 &

# 3. NumaScribe Backend
echo "[*] Booting NumaScribe Backend (Port 8000)..."
apptainer exec \
    --bind $PROJECT_DIR:/app \
    --pwd /app \
    $CONTAINER \
    bash -c "python3 -m uvicorn backend.main:app --host 0.0.0.0 --port 8000" > local_turbo_backend.log 2>&1 &

# 4. Frontend
echo "[*] Booting NumaScribe Interface (Port 5173)..."
apptainer exec \
    --bind $PROJECT_DIR:/app \
    --pwd /app \
    $CONTAINER \
    bash -c "cd frontend && npm run dev -- --host 0.0.0.0" > local_turbo_frontend.log 2>&1 &

echo "==========================================================="
echo " SYSTEMS STARTING IN BACKGROUND!"
echo " Monitor logs in local_turbo_*.log"
echo ""
echo " -> OpenWebUI Chat: http://localhost:8080"
echo " -> NumaScribe Pipeline: http://localhost:5173"
echo "==========================================================="
