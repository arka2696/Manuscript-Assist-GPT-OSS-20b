# HPC Singularity Deployment Pipeline

This guide outlines exactly how to deploy the Multi-Agent Manuscript system from your workstation to an HPC cluster using Singularity containers securely.

## Phase 1: Build the Container Locally
You usually cannot run `sudo singularity build` on HPC login nodes due to root security locks. You must build the `.sif` file on your personal workstation first.
1. On your personal Linux workstation, navigate to the Singularity folder:
   ```bash
   cd ~/Desktop/Manuscript-Assist-GPT-OSS-20b/Singularity
   chmod +x hpc_build.sh
   ./hpc_build.sh
   ```
2. Wait 10–15 minutes. It will download CUDA, Python 3.12, Node 20, and compile `llama.cpp` using GCC-10. You will now have an encapsulated binary called `manuscript_hpc.sif`.

## Phase 2: Transfer to HPC
Push your code and the container to the HPC's high-speed parallel storage (e.g. `/scratch` or `/work`).
```bash
rsync -avzP ~/Desktop/Manuscript-Assist-GPT-OSS-20b/ your_username@hpc.domain.edu:/scratch/your_username/Manuscript-Assist-GPT-OSS-20b/
```

## Phase 3: Download Models Directly to HPC Scratch
SSH into your HPC. Go to your scratch directory and download the models directly from HuggingFace to your remote scratch disk. **Do not upload them from your laptop** (uploading 60GB will take hours).
```bash
ssh your_username@hpc.domain.edu
mkdir -p /scratch/your_username/models
cd /scratch/your_username/models

wget https://huggingface.co/ggml-org/gemma-4-31B-it-GGUF/resolve/main/gemma-4-31B-it-Q4_K_M.gguf
wget https://huggingface.co/ggml-org/Ministral-3-14B-Reasoning-2512-GGUF/resolve/main/Ministral-3-14B-Reasoning-2512-Q8_0.gguf
wget https://huggingface.co/ggml-org/gemma-4-E4B-it-GGUF/resolve/main/gemma-4-e4b-it-Q4_K_M.gguf
```

## Phase 4: Launching on SLURM
1. Open the `/scratch/your_username/Manuscript-Assist-GPT-OSS-20b/Singularity/run_agents.sbatch` file on the HPC.
2. Update the `PROJECT_DIR` and `MODELS_DIR` paths at the top of the file to match your actual HPC directories!
3. Ensure you are in the project root directory when submitting, so the logs route correctly:
   ```bash
   cd /scratch/your_username/Manuscript-Assist-GPT-OSS-20b
   sbatch Singularity/run_agents.sbatch
   ```
4. Find out which compute node your job is running on:
   ```bash
   squeue -u your_username
   ```
   *(Look under the `NODELIST` column. For example, it might say `gpu-node-40`)*.

## Phase 5: Connecting from your Laptop
Because the compute node (`gpu-node-40`) is firewalled behind the cluster, you must tunnel the ports backward to your laptop securely.
Open a new terminal on your **LOCAL LAPTOP** and run:
```bash
# Replace gpu-node-40 with the actual node from step 4
# Replace your_username@hpc.domain.edu with your real login node credentials
ssh -N -L 5173:gpu-node-40:5173 -L 8000:gpu-node-40:8000 your_username@hpc.domain.edu
```

Keep that terminal open! Now open Chrome on your laptop and type:
`http://localhost:5173`

You are now successfully interacting with the A100 GPU cluster through the Singularity container as if it were running natively on your laptop!
