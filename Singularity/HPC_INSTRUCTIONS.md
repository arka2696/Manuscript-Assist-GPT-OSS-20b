# HPC Singularity Deployment on VSC (Vlaams Supercomputer Centrum)

Complete guide to deploy the Multi-Agent Manuscript system on a VSC cluster (KU Leuven, UGent, UAntwerpen, or VUB) using Singularity containers.

---

## Phase 0: SSH Key Setup (One-Time Only)

Before anything else, you need an SSH key pair registered with your VSC account.

### Step 0.1: Generate your SSH key
If you do NOT already have a VSC SSH key, generate one on your Linux workstation:
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_vsc
```
When prompted for a passphrase, type a strong password (you will be asked for this every time you connect).

### Step 0.2: Upload the PUBLIC key to your VSC Account
1. Go to https://account.vscentrum.be/
2. Log in with your institutional credentials.
3. Navigate to **"Edit Account"** → **"SSH Keys"**.
4. Paste the contents of your PUBLIC key file:
   ```bash
   cat ~/.ssh/id_rsa_vsc.pub
   ```
   Copy the entire output and paste it into the web form. Click **Save**.
5. Wait ~30 minutes for the key to be synchronized with all VSC login nodes.

---

## Phase 1: Build the Container Locally

You CANNOT run `sudo singularity build` on the VSC login nodes. Build the `.sif` on your personal workstation first.

```bash
cd ~/Desktop/Manuscript-Assist-GPT-OSS-20b/Singularity
chmod +x hpc_build.sh
./hpc_build.sh
```
Wait 10–15 minutes. You will now have `manuscript_hpc.sif` (~3 GB).

---

## Phase 2: Connect to the VSC Cluster via SSH

Open a terminal on your workstation and connect to the VSC login node.

**Replace `vscXXXXX` with your actual VSC username** (e.g., `vsc35000`).
**Replace the login node** with the one matching your institution:

| Institution | Login Node |
|---|---|
| KU Leuven (wICE) | `login.hpc.kuleuven.be` |
| KU Leuven (Genius) | `login.hpc.kuleuven.be` |
| UGent (Hortense) | `login.hpc.ugent.be` |
| UAntwerpen (Vaughan) | `login.hpc.uantwerpen.be` |
| VUB (Hydra) | `login.hpc.vub.be` |

```bash
ssh -i ~/.ssh/id_rsa_vsc vscXXXXX@login.hpc.kuleuven.be
```

The first time you connect, you will be asked to verify the host authenticity. Type `yes` and press Enter.

### Tip: Avoid retyping the passphrase every time
Use the SSH agent to cache your key in memory:
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa_vsc
```

### Tip: Create an SSH config shortcut
Add this to `~/.ssh/config` on your local workstation:
```
Host vsc
    HostName login.hpc.kuleuven.be
    User vscXXXXX
    IdentityFile ~/.ssh/id_rsa_vsc
    ForwardX11 yes
```
After this, you can simply type `ssh vsc` to connect!

---

## Phase 3: Transfer Code and Container to the Cluster

From your **local workstation** terminal (NOT the VSC terminal), push your entire project:

```bash
rsync -avzP --exclude='*.gguf' --exclude='venv/' --exclude='node_modules/' \
    ~/Desktop/Manuscript-Assist-GPT-OSS-20b/ \
    vscXXXXX@login.hpc.kuleuven.be:/scratch/leuven/XXX/vscXXXXX/Manuscript-Assist-GPT-OSS-20b/
```

> **Important:** Replace `/scratch/leuven/XXX/vscXXXXX/` with your actual scratch path.
> You can find your scratch path by running `echo $VSC_SCRATCH` on the login node.

Then transfer the container separately (it's ~3 GB):
```bash
rsync -avzP ~/Desktop/Manuscript-Assist-GPT-OSS-20b/Singularity/manuscript_hpc.sif \
    vscXXXXX@login.hpc.kuleuven.be:$VSC_SCRATCH/Manuscript-Assist-GPT-OSS-20b/Singularity/
```

---

## Phase 4: Download Models Directly on the HPC

SSH into the cluster and download the models directly to the high-speed scratch disk.
**Do NOT upload them from your workstation** (60 GB over SSH will take hours).

```bash
ssh vsc   # or: ssh -i ~/.ssh/id_rsa_vsc vscXXXXX@login.hpc.kuleuven.be

mkdir -p $VSC_SCRATCH/models
cd $VSC_SCRATCH/models

wget https://huggingface.co/ggml-org/gemma-4-31B-it-GGUF/resolve/main/gemma-4-31B-it-Q4_K_M.gguf
wget https://huggingface.co/ggml-org/Ministral-3-14B-Reasoning-2512-GGUF/resolve/main/Ministral-3-14B-Reasoning-2512-Q8_0.gguf
wget https://huggingface.co/ggml-org/gemma-4-E4B-it-GGUF/resolve/main/gemma-4-e4b-it-Q4_K_M.gguf
```

---

## Phase 5: Edit the SLURM Script Paths

While still connected to the VSC cluster, open the sbatch file and update the paths:

```bash
cd $VSC_SCRATCH/Manuscript-Assist-GPT-OSS-20b
nano Singularity/run_agents_l40s.sbatch
```

Change these two lines at the top to match YOUR cluster paths:
```bash
PROJECT_DIR="$VSC_SCRATCH/Manuscript-Assist-GPT-OSS-20b"
MODELS_DIR="$VSC_SCRATCH/models"
```

Also update the `#SBATCH --partition=` line to match your cluster's GPU partition name. Common VSC partition names:
- KU Leuven wICE: `gpu` or `gpu_a100`
- UGent: `gpu`

Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X` in nano).

---

## Phase 6: Submit the Job to SLURM

```bash
cd $VSC_SCRATCH/Manuscript-Assist-GPT-OSS-20b
sbatch Singularity/run_agents_l40s.sbatch
```

You will see: `Submitted batch job 12345678`

Check which compute node your job landed on:
```bash
squeue -u $USER
```

Look at the `NODELIST` column (e.g., `r23g36`). You will need this node name for the tunnel.

---

## Phase 7: Open an SSH Tunnel from Your Workstation

Go back to your **local workstation terminal** (NOT the VSC session).

You need to tunnel Port 5173 (React UI) and Port 8000 (FastAPI) through the login node to the compute node:

```bash
# Replace r23g36 with the actual NODELIST from squeue
# Replace vscXXXXX with your VSC username
ssh -N \
    -L 5173:r23g36:5173 \
    -L 8000:r23g36:8000 \
    -i ~/.ssh/id_rsa_vsc \
    vscXXXXX@login.hpc.kuleuven.be
```

**Keep this terminal open!** It is the live bridge between your browser and the GPU node.

Now open your web browser and visit:
```
http://localhost:5173
```

You are now interacting with the AI agents running on the L40S / H100 GPU node through the Singularity container! 🎉

---

## Monitoring and Debugging

### Check job output in real-time:
```bash
# On the VSC login node:
tail -f $VSC_SCRATCH/Manuscript-Assist-GPT-OSS-20b/slurm_logs/hpc_l40s_*.log
```

### Check individual agent logs:
```bash
tail -f $VSC_SCRATCH/Manuscript-Assist-GPT-OSS-20b/slurm_logs/drafter.log
tail -f $VSC_SCRATCH/Manuscript-Assist-GPT-OSS-20b/slurm_logs/reviewer.log
```

### Cancel a running job:
```bash
scancel <job_id>
```

### Check GPU utilization on the compute node:
```bash
# First SSH to the compute node from the login node:
ssh r23g36
nvidia-smi
```
