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
