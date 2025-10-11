# Manuscript Assistant (Cluster Ready) — gpt-oss-20b

This repository provides an **end-to-end manuscript writing assistant** powered by the **gpt-oss-20b** open-weight model. It integrates:
- **LLM backend (gpt-oss-20b via vLLM or Transformers)** for reasoning, editing, outlining, and reviewer responses.
- **RAG pipeline**: Upload PDFs, chunk & embed text, search with FAISS, and answer queries with citations.
- **Reference management**: Upload BibTeX files, format citations with CSL styles (e.g., Nature).
- **Web-based UI**: Simple chat interface with tools to upload papers, manage references, and interact with the model.
- **Cluster-ready scripts**: SLURM job files, Dockerfiles, and SSH tunnel helpers to run on HPC clusters.

---
Here’s your extremely detailed setup guide for the manuscript assistant along with a conceptual interface mock‑up.

**Mock‑up of the interface layout**

Everything—from hardware requirements to Slurm scripts, RAG indexing, citation handling, port forwarding, and advanced options—is covered step by step in this comprehensive guide:

This should give you everything you need to get up and running. If you need any tweaks for your specific cluster (partition names, GPU counts) or further customization, just let me know!
<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/ddfc0bf0-f238-422a-a70c-bf0b665dbcf4" />


## About gpt-oss-20b

The **gpt-oss** family (by OpenAI) is a series of **open-weight models** designed for:
- **Powerful reasoning and agentic tasks**
- **Function calling & tool use**
- **Native support for Harmony response format**
- **Configurable reasoning effort (low, medium, high)**

**gpt-oss-20b**:
- ~21B parameters (3.6B active parameters in MoE)
- Runs within ~16GB GPU memory (works on A100 40/80GB easily)
- Licensed under **Apache 2.0** (free for research & commercial use)
- Supports **fine-tuning, quantization, and adapters**

We integrate gpt-oss-20b with **Harmony chat format** and **reasoning levels** so you can adjust between *fast answers* and *deep detailed reasoning*.

---

## About This Tool

This tool is built for researchers, students, and writers who want:
- To **draft manuscripts faster** with outlines, structured rewrites, and reviewer-response drafting.
- To **query scientific PDFs** (RAG pipeline) and get cited answers.
- To **manage references** inside the same assistant.
- To run all of this **securely on your HPC cluster** and access it from your laptop.

It consists of:
- **Backend (FastAPI)**: Authentication, RAG, references, and LLM calls.
- **Frontend (React/Vite)**: Browser-based interface for chat and tools.
- **SLURM scripts**: To start vLLM server (GPU) and backend (CPU).
- **Dockerfiles**: Optional containerized deployment.
- **SSH tunnel script**: Securely connect to cluster from your laptop.

---

## Step-by-Step Setup

These instructions are written to be understandable for **people with diverse backgrounds**. Even if you are not an HPC or ML expert, you can follow along.

### 1. Download the Project
- Copy the ZIP file to your cluster and extract:
```bash
unzip manuscript-assistant-gptoss20b.zip
cd manuscript-assistant
```

### 2. Prepare Environment
- Copy environment template:
```bash
cp .env.example .env
```
- Open `.env` and set a strong password for `JWT_SECRET`.  
This secret secures your login.

Example:
```
JWT_SECRET=my_super_secret_password
```

### 3. Run the Model (GPU job)
- Submit the vLLM server job on a GPU node:
```bash
sbatch slurm/run_vllm_gptoss20b.sbatch
```
This will:
- Create a virtual environment
- Install vLLM with special GPT-OSS support
- Launch `openai/gpt-oss-20b` on port 8001

Check the job log file (e.g. `vllm-gptoss20b-12345.out`) for confirmation.

### 4. Run the Backend (CPU job)
- Submit backend on a CPU node (or login node if allowed):
```bash
sbatch slurm/run_backend.sbatch
```
This starts the FastAPI server on port 8000.

### 5. Tunnel from Your Laptop
Since cluster nodes are not public, you must **tunnel**:
```bash
./scripts/tunnel.sh USER LOGIN_NODE 7001 8000
```
Replace:
- `USER` = your cluster username
- `LOGIN_NODE` = cluster login node (e.g. `login.hpc.edu`)

After this:
- Open [http://localhost:7001](http://localhost:7001) → Frontend
- API is at [http://localhost:8000](http://localhost:8000)

### 6. Run the Frontend
#### Option A: Run locally on your laptop
- Install Node.js (v18+).
- From `frontend/`:
```bash
npm install
npm run dev
```
This starts the frontend on `http://localhost:5173`.

If running on the cluster, use SSH tunneling to forward port 5173 to your laptop.

---

## Features in Detail

### A. Chat
- Ask questions or draft text
- Choose **reasoning level** (low/medium/high)
- Use “fast” or “reasoned” response

### B. RAG (PDF Query)
- Upload scientific PDFs
- Model ingests and chunks the text
- Query with: “Summarize methods of Smith et al.” → Model responds citing chunks.

### C. References
- Upload a `.bib` BibTeX file
- Request formatted citations with CSL style (Nature, etc.)
- Output can be pasted into manuscripts

### D. Tools
- **Outline**: Generate manuscript outline from title + aims
- **Rewrite**: Rewrite text in styles: *concise*, *formal*, *reviewer-response*, *LaTeX*

---

## Security Notes
- Always keep the assistant behind SSH tunnels.
- Use **strong JWT_SECRET**.
- If deploying publicly, add HTTPS + OAuth (Google/SSO).

---

## Advanced Options
- **Scaling**: For multiple GPUs, increase `--tensor-parallel-size`.
- **Transformers Serve**: Alternate inference backend if vLLM is not available.
- **Fine-tuning**: Point `MODEL_NAME` to a fine-tuned checkpoint.
- **Docker**: Use Dockerfiles to containerize (convert to Singularity for HPC).

---

## Quick Demo Command (for experts)
```bash
curl -s http://localhost:8000/chat   -H 'Authorization: Bearer <TOKEN>'   -H 'Content-Type: application/json'   -d '{
    "messages":[{"role":"user","content":"Write a concise abstract about liver stellate cell activation."}]
  }'
```

---

## Summary
You now have a **cluster-ready manuscript assistant**:
- LLM: gpt-oss-20b with reasoning levels
- Tools: Chat, RAG, References, Outlines, Rewrites
- Frontend: Browser-based UI
- Backend: Secure FastAPI server
- Deployment: SLURM, Docker, SSH tunnel

This tool should greatly improve your **productivity in writing and research**.


Here you go — a GitHub-friendly, copy-paste-ready Markdown guide. It’s structured, scannable, and sticks to short phrases in tables. You can drop this into `README.md` or `docs/SETUP.md`.

---

# Manuscript Assistant (gpt-oss-20b)

**Self-hosted manuscript writing assistant** with:

* **LLM**: `openai/gpt-oss-20b` (Harmony chat format; reasoning levels)
* **Inference**: vLLM (OpenAI-compatible API)
* **Backend**: FastAPI (JWT auth, RAG, citations)
* **Frontend**: React (Vite dev server / static build)
* **RAG**: FAISS vector store + sentence-transformers
* **Citations**: BibTeX → CSL (e.g., Nature)

---

## Table of Contents

* [Why gpt-oss-20b](#why-gpt-oss-20b)
* [Architecture](#architecture)
* [Requirements](#requirements)
* [Quick Start](#quick-start)
* [1) Download & Layout](#1-download--layout)
* [2) Environment & Secrets](#2-environment--secrets)
* [3) GPU Node: vLLM Server](#3-gpu-node-vllm-server)
* [4) CPU Node: Backend](#4-cpu-node-backend)
* [5) Frontend (React)](#5-frontend-react)
* [6) RAG Index (PDF → FAISS)](#6-rag-index-pdf--faiss)
* [7) Citations (BibTeX → CSL)](#7-citations-bibtex--csl)
* [8) Slurm Jobs](#8-slurm-jobs)
* [9) SSH Port Forwarding](#9-ssh-port-forwarding)
* [10) Using the App](#10-using-the-app)
* [Advanced](#advanced)
* [Troubleshooting](#troubleshooting)
* [Security](#security)

---

## Why gpt-oss-20b

* **Open-weight**; Apache-2.0
* **Reasoning levels**: `low | medium | high`
* **Tool-use ready**; function calling
* **MoE**; ~21B params; ~3.6B active per token
* **Fits** on 16–40 GB GPUs (better with ≥40 GB)

---

## Architecture

```
 ┌───────────────────────────────┐
 │ Laptop Browser (React UI)     │  ← chat / tools / uploads
 └───────────────┬───────────────┘
                 │ HTTPS/SSH tunnel
 ┌───────────────▼───────────────┐
 │ FastAPI Backend (JWT, RAG,    │  :8000/8002
 │ citations, OpenAI client)     │
 └───────────────┬───────────────┘
                 │ REST (OpenAI API)
 ┌───────────────▼───────────────┐
 │ vLLM Server (gpt-oss-20b)     │  :8001/v1
 │ GPU node(s), tensor parallel  │
 └───────────────────────────────┘
```

---

## Requirements

| Component | Minimum             | Notes                                                |
| --------- | ------------------- | ---------------------------------------------------- |
| GPU node  | 1× A100/H100 ≥40 GB | 20B can run on 16 GB; more VRAM = better concurrency |
| CPU node  | 4–8 vCPU; 32 GB RAM | Backend + embeddings                                 |
| Frontend  | Node 18+            | Dev: Vite; Prod: static host                         |
| Storage   | ~60 GB              | Weights + FAISS + uploads                            |
| Scheduler | Slurm (example)     | Adapt if PBS/others                                  |
| Network   | SSH + port forward  | Tunnel to laptop                                     |

> If you have multiple GPUs on one node, use tensor parallel (`--tensor-parallel-size N`).

---

## Quick Start

```bash
# 0) unzip repo and cd
unzip manuscript-assistant.zip -d manuscript-assistant
cd manuscript-assistant

# 1) copy env
cp .env.example .env
# edit .env → set a strong JWT_SECRET; check VLLM_ENDPOINT/MODEL_NAME

# 2) start vLLM (GPU node)
sbatch slurm/run_vllm_gptoss20b.sbatch

# 3) start backend (CPU node)
sbatch slurm/run_backend.sbatch

# 4) start frontend (local dev)
cd frontend && npm install && npm run dev

# 5) laptop: SSH tunnel (example)
./scripts/tunnel.sh USER LOGIN_NODE 7001 8000

# open UI
# dev: http://localhost:5173  (or http://localhost:7001 if tunneled)
# api: http://localhost:8000
```

---

## 1) Download & Layout

```bash
wget <ZIP_URL> -O manuscript-assistant.zip
unzip manuscript-assistant.zip -d manuscript-assistant
cd manuscript-assistant
```

**Tree (key parts):**

* `backend/` — FastAPI app, RAG, citations
* `frontend/` — React UI (Vite)
* `slurm/` — batch scripts (vLLM, backend)
* `scripts/` — SSH tunnel, helpers
* `docker/` — optional images
* `.env.example` — config template

---

## 2) Environment & Secrets

```bash
cp .env.example .env
nano .env
```

**Must set:**

* `JWT_SECRET` → long random string
* `VLLM_ENDPOINT` → e.g. `http://gpu-node:8001/v1`
* `MODEL_NAME` → `openai/gpt-oss-20b`
* `REASONING_LEVEL` → `low|medium|high`
* `INDEX_DIR`, `UPLOAD_DIR` → keep defaults or change
* `CSL_STYLE` → `backend/csl_styles/nature.csl` (or your style)

---

## 3) GPU Node: vLLM Server

Install (example with `uv`):

```bash
# on GPU node
uv venv --python 3.12 --seed
source .venv/bin/activate

uv pip install --pre vllm==0.10.1+gptoss \
  --extra-index-url https://wheels.vllm.ai/gpt-oss/ \
  --extra-index-url https://download.pytorch.org/whl/nightly/cu128 \
  --index-strategy unsafe-best-match
```

Run vLLM:

```bash
# single GPU, default port 8000
vllm serve openai/gpt-oss-20b

# multi-GPU (e.g., 4 GPUs; custom port)
vllm serve openai/gpt-oss-20b \
  --tensor-parallel-size 4 \
  --port 8001
```

Check:

* API root: `http://<gpu-node>:8001/v1`
* Keep running (or use Slurm job below).

---

## 4) CPU Node: Backend

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# .env lives one level up; backend reads process env
cd ..
export $(grep -v '^#' .env | xargs)

# run backend (default :8000)
cd backend
python -m uvicorn backend.main:app --host 0.0.0.0 --port ${BACKEND_PORT:-8000}
```

---

## 5) Frontend (React)

**Dev mode:**

```bash
cd frontend
npm install
npm run dev   # http://localhost:5173
```

**Prod build (static):**

```bash
npm run build
npx serve -s dist -l 3000
```

If serving frontend on the cluster, tunnel port `5173` (dev) or `3000` (prod) to your laptop.

---

## 6) RAG Index (PDF → FAISS)

1. Put PDFs in:

```
backend/storage/uploads/
```

2. Start backend once (loads libs and creates dirs).

3. Use the **UI upload** to ingest PDFs
   *or* run your embedding flow (if provided) to populate FAISS:

* Default embedding model: `sentence-transformers/all-MiniLM-L6-v2`
* FAISS index: `backend/storage/faiss_index/index.faiss`
* Metadata: `meta.jsonl`

> The backend exposes `/rag/ingest` and `/rag/query`; the UI calls these for you.

---

## 7) Citations (BibTeX → CSL)

* Put your BibTeX file in `backend/storage/`
* Load via UI (bib upload), or the backend’s `/refs/upload`
* Select CSL style (place CSL file in `backend/csl_styles/` and set `CSL_STYLE` in `.env`)

---

## 8) Slurm Jobs

**vLLM (GPU):** `slurm/run_vllm_gptoss20b.sbatch`

```bash
sbatch slurm/run_vllm_gptoss20b.sbatch
```

**Backend (CPU):** `slurm/run_backend.sbatch`

```bash
sbatch slurm/run_backend.sbatch
```

*Tips:*

* Adapt `--partition`, `--gpus`, `--cpus-per-task`, `--mem`, and module loads
* For multi-GPU, set `--tensor-parallel-size N` in the vLLM command

---

## 9) SSH Port Forwarding

Typical mapping:

| Service        | Node            | Remote Port | Local Port |
| -------------- | --------------- | ----------- | ---------- |
| vLLM           | `gpu-node`      | 8001        | 8001       |
| Backend        | `backend-node`  | 8000        | 8000       |
| Frontend (dev) | `frontend-node` | 5173        | 7001       |

**Example (single login hop):**

```bash
ssh -N \
  -L 8001:gpu-node:8001 \
  -L 8000:backend-node:8000 \
  -L 7001:frontend-node:5173 \
  <user>@<login-node>
```

Open:

* UI: `http://localhost:7001`
* API: `http://localhost:8000`

---

## 10) Using the App

* **Login** (JWT; set `JWT_SECRET` in `.env`)
* **Chat**: free-form Q&A; select **Reasoning level**
* **Outline**: title + aims → structured outline
* **Rewrite**: highlight → `concise`, `formal`, `reviewer-response`, `latex`
* **RAG**: upload PDFs → ask questions → answers with source snippets
* **Citations**: upload `.bib` → format with CSL → insert into text

---

## Advanced

* **Bigger model**: switch to `openai/gpt-oss-120b` in `.env`; update vLLM flags
* **Transformers Serve** (alt to vLLM):

  ```bash
  pip install -U transformers kernels torch
  transformers serve --model openai/gpt-oss-20b --host 0.0.0.0 --port 8001
  ```

  Set `VLLM_ENDPOINT=http://127.0.0.1:8001/v1`
* **Tensor parallel**: `--tensor-parallel-size N` (single node, multi-GPU)
* **Frontend config**: use `VITE_API_URL` if you want to hard-wire the backend URL

---

## Troubleshooting

* **401 Unauthorized**: wrong token; set strong `JWT_SECRET`; re-login
* **CORS errors**: serve frontend and backend on compatible origins; enable CORS in backend
* **OOM on GPU**: reduce sequence length, `--gpu-memory-utilization`, or parallelize across GPUs
* **Timeouts**: check tunnels, ports, node names, firewall rules
* **No RAG hits**: re-ingest PDFs; check FAISS paths; verify embedding model

---

## Security

* Keep services **private** (SSH tunnels or VPN)
* Use long, unique `JWT_SECRET`
* Rotate secrets periodically
* If exposing externally: TLS (reverse proxy) + SSO/OIDC, rate limiting, logs/alerts

---

## License

* Code: your repo’s license
* Models: follow `openai/gpt-oss-20b` terms
* CSL styles: per their licenses

---

### Badges (optional)

```
![GPU](https://img.shields.io/badge/Requires-GPU-blue)
![Python](https://img.shields.io/badge/Python-3.11%2B-blue)
![Node](https://img.shields.io/badge/Node-18%2B-green)
```

---

If you want, I can turn this into `docs/SETUP.md` and update your repo’s `README.md` with a concise overview + links to this guide.

