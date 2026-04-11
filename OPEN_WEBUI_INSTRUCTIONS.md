# 🚀 TurboQuant & Open-WebUI Survival Guide

This document explains exactly how to build, run, and completely manage the **Dual-UI Architecture** we built on the experimental `Numascribe-Turboquant` branch.

---

## 1. Core Architecture
Normally, NumaScribe only runs the automated Drafter/Reviewer pipeline. In this branch, you have **three incredible tools fully interconnected**:

1. **The Brain (`llama-server`)**: Runs the massive LLM models securely, but utilizes experimental `turbo3` KV cache compression so you can run 128K context window models on basic hardware without crashing!
2. **The Langgraph Pipeline (`localhost:5173`)**: Your custom automated Drafting Engine.
3. **Open-WebUI (`localhost:8080`)**: A sleek, beautifully polished ChatGPT replacement for instantly talking with your models without starting an automated "Drafting" system.

> [!TIP]
> Both Interfaces are fully functional at the same time! You never have to pick just one.

---

## 2. Setup & Building the Container

Because TurboQuant relies on brand-new, customized C++ code that modifies how NVIDIA handles context databases, you **must build** the `.sif` file the first time you set it up.

### Building on Local PC
Ensure Apptainer/Singularity is installed. Open your terminal in the `Manuscript-Assist-GPT-OSS-20b` folder and run:
```bash
sudo apptainer build Singularity/turboquant.sif Singularity/turboquant.def
```

### Building on Windows (Docker)
Ensure Docker Desktop is installed with the WSL2 backend enabled. Open **PowerShell** in the `Manuscript-Assist-GPT-OSS-20b` repository folder and run:
```powershell
docker build -t numascribe_turbo -f Singularity/Dockerfile.turbo_local .
```

### Building on VSC HPC (Cluster)
Upload the `.def` file to your cluster Scratch node where you have space, and use the VUB fakeroot command:
```bash
apptainer build --fakeroot turboquant.sif Singularity/turboquant.def
```

---

## 3. How to Start Everything 🟢

### On your Local PC
We created an automated master script that boots all 4 background processes completely silently. 
Simply double click or run:
```bash
./run_turbo_local.sh
```
*Wait ~3 minutes. Open-WebUI will silently download its RAG databases during this time in the background. Once it finishes, you can instantly connect via Safari/Chrome!*

### On your Windows PC (Docker)
1. Open PowerShell in the project directory.
2. Run this Docker command to start the container and share your GPUs to it:
```powershell
docker run --rm -it `
    --gpus all `
    -v "${PWD}:/app" `
    -v "${PWD}/models:/models" `
    -p 8001:8001 `
    -p 8080:8080 `
    -p 8000:8000 `
    -p 5173:5173 `
    numascribe_turbo /bin/bash
```
3. Once the Docker terminal loads, you are effectively running Linux! Simply execute:
```bash
./run_turbo_local.sh
```

### On the HPC
To submit the 12-hour job that allocates 1 GPU and boots both APIs behind the scenes, just submit the specialized slurm script:
```bash
sbatch Singularity/run_agents_turboquant.sbatch
```

---

## 4. How to Kill Everything 🔴

Because `./run_turbo_local.sh` spawns the servers silently as **Background Tasks**, doing a `CTRL+C` keyboard command will NOT kill them!

> [!WARNING]
> If you close the terminal without killing them, the AI will stay hidden in the background permanently eating your VRAM!

### The Automated Kill
The easiest way to kill everything is actually just to run `./run_turbo_local.sh` again! The very first thing the script does is aggressively hunt down and kill any old instances of the server before starting new ones. 

### The Manual Kill
To surgically close all 3 processes yourself and shut down the software for the day, highlight and paste this into your terminal:
```bash
pkill -f llama-server && pkill -f uvicorn && pkill -f open-webui
```
*If it prints nothing, it successfully killed them all!*
