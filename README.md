# Multi-Agent Manuscript Assistant

A highly optimized, privacy-first, locally hosted scientific writing assistant. 

This repository has been rebuilt specifically for high-end **Dual-Xeon Workstations with GPU support**, entirely sidestepping commercial APIs to maintain absolute data security over unreleased research. 

It utilizes a **LangGraph** backend to orchestrate a team of specialized AI agents running concurrently via `llama.cpp`. By using exact `numactl` CPU-socket pinning across dual processors, the system prevents interconnect latency and allows the agents (a Drafter, a Reviewer, and a Tool Router) to think parallel to one another.

---

## Step 1: Install and Compile `llama.cpp`

Yes, **you do need to install `llama.cpp`** on your workstation first. This is the ultra-fast execution engine that will run your AI models. Because you have an Nvidia GPU and AVX2-capable Xeons, you must compile it with CUDA support to enable layer offloading.

1. Clone the `llama.cpp` repository into your home directory (or somewhere accessible):
   ```bash
   cd ~
   git clone https://github.com/ggml-org/llama.cpp.git
   cd llama.cpp
   ```
2. Resolve NVCC compiler incompatibilities (for CUDA 11.5) by installing a highly stable legacy compiler:
   ```bash
   sudo apt-get update
   sudo apt-get install gcc-10 g++-10
   ```
3. Compile the engine to support your CUDA GPU (`GGML_CUDA=ON`). We will strictly bind the compiler to GCC-10 to bypass errors, and utilize 40 processor threads (`-j 40`) for an ultra-fast build:
   ```bash
   cmake -B build -DGGML_CUDA=ON -DCMAKE_C_COMPILER=gcc-10 -DCMAKE_CXX_COMPILER=g++-10 -DCMAKE_CUDA_HOST_COMPILER=g++-10
   cmake --build build --config Release -j 40
   ```
4. Once compiled, you need to make the `llama-server` binary accessible globally so our scripts can use it. Copy it into your local binaries path:
   ```bash
   sudo cp build/bin/llama-server /usr/local/bin/
   ```

---

## Step 2: Download the GGUF Models

The architecture expects multiple distinct agent models to fit inside your 128GB of RAM. You will need to download compressed `.gguf` weights from HuggingFace and place them inside a `models/` directory in this project.

1. Open a terminal in the root of this project and create the directory:
   ```bash
   mkdir -p models
   cd models
   ```
2. Download the recommended models (using `wget`):

   **The Drafter (Main Writer - Runs on GPU + CPU Socket 0):**
   ```bash
   # Using Gemma 4 31B (Advanced reasoning, dense architecture)
   wget https://huggingface.co/ggml-org/gemma-4-31B-it-GGUF/resolve/main/gemma-4-31B-it-Q4_K_M.gguf -O drafter-model.gguf
   ```

   **The Reviewer (Critique Agent - Runs purely on CPU Socket 1):**
   ```bash
   # Using Ministral 3 14B Reasoning (Highly precise, optimized for logic)
   wget https://huggingface.co/ggml-org/Ministral-3-14B-Reasoning-2512-GGUF/resolve/main/Ministral-3-14B-Reasoning-2512-Q8_0.gguf -O reviewer-model.gguf
   ```

   **The Router/RAG Extractor (Runs on CPU Socket 0):**
   ```bash
   # Using Gemma 4 8B (Extremely fast, intelligent contextual routing)
   wget https://huggingface.co/ggml-org/gemma-4-E4B-it-GGUF/resolve/main/gemma-4-e4b-it-Q4_K_M.gguf -O coordinator-model.gguf
   ```

---

## Step 3: Configure the Core Environment

1. Rename the environment template to activate it:
   ```bash
   cp .env.example .env
   ```
2. Open `.env` and change the `JWT_SECRET` to a random, secure password. This is what you will type into the Web UI to log into your laboratory assistant.

---

## Step 4: Launching the System

You must start the system in layers (Agents -> Backend API -> User Interface).

### A. Turn on the Agent Engines
This script utilizes `numactl` to map the models perfectly to your Dual-Xeon 14-core topology.
```bash
./scripts/start_agents.sh
```
*(Leave this terminal running. It will state "Multi-Agent servers are running.")*

### B. Turn on the Logic Backend (FastAPI / LangGraph)
Open a **new terminal tab** in the project root:
```bash
./scripts/start_backend.sh
```
*(This automatically installs necessary pip packages like `langgraph`, generates your FAISS directories, and starts the API on port 8000).*

### C. Build and Run the Web UI
Open a **third terminal tab**. The frontend requires Node.js (v18+) to run.
```bash
cd frontend
npm install
npm run dev
```
*(This will start the local React development server on port 5173).*

---

## Performance Tuning & Resolved Architecture Errors

The shift from the original HPC cluster baseline to a dedicated **Dual-Socket Xeon Workstation (with 8GB Quadro M4000 GPU)** revealed several edge-cases that have been successfully engineered and bypassed:

1. **NUMA Binding & Overlapping VRAM Conflicts** 
   - *Error:* `llama.cpp` instances were violently colliding and crashing with `Out Of Memory` errors when trying to aggressively allocate buffers to the GPU. Both the Drafter and the Router attempted to seize 3+ GB of VRAM simultaneously.
   - *Resolution:* Adjusted `start_agents.sh` to strictly segregate the GPU. We explicitly injected `CUDA_VISIBLE_DEVICES=""` for the Reviewer and Router agents, forcing them to remain purely in the CPU/RAM space. We allocated `-ngl 5` (5 layers) strictly to the Drafter to comfortably fit the Quadro M4000's strict 8GB limit.
   - *Scaling Note:* We bound the Drafter engine strictly to `-t 14` (the absolute maximum physical FPUs on Socket 0) to avoid hyper-threading bottlenecks and NUMA cross-bridge latency.
2. **Node.js Engine Conflicts**
   - *Error:* The frontend threw `EBADENGINE` warnings owing to legacy Node.js v12.
   - *Resolution:* Upgraded the workstation to Node v20 via `apt`, stabilizing `Vite` and `Rollup` compilation.
3. **Ghost Process Port-Locking**
   - *Error:* `start: couldn't bind HTTP server socket, hostname: 127.0.0.1, port: 8001`
   - *Resolution:* Force-crashing the `start_agents.sh` bash script left zombie instances of `llama-server` alive, permanently hogging the ports. Solved by running `pkill -9 -f llama-server` before attempting fresh initializations.
4. **Gemma-4 "Thinking" Prefill Bugs (`400 Bad Request`)**
   - *Error:* `Assistant response prefill is incompatible with enable_thinking.` The LangGraph state array was injecting previous assistant iterations that crashed Gemma's `<think>` token boundaries.
   - *Resolution:* Rewrote `backend/agents.py` to intercept the LangGraph feedback loop, squashing all Reviewer critiques into a single contiguous `User` message, entirely preventing the Llama format validation crash.
5. **Real-Time Log Streamer (UI)**
   - *Feature Added:* The transition to 14-thread CPU restraints meant that a single draft generation could pause the UI for 2–3 minutes. We built a live terminal-emulator in `React` (`App.tsx`) attached to a `/logs/stream` FastAPI endpoint that continuously tails the hardware outputs in real-time, providing immediate visual feedback of the models executing.
6. **Scientific Markdown Rendering (UI)**
   - *Feature Added:* The frontend was originally outputting raw, unformatted AI text blocks. We integrated `react-markdown` along with `remark-math` and `rehype-katex` to beautifully render structured scientific formatting, bold elements, headers, and complex LaTeX equations natively in the browser.

---

## Step 5: Connecting from your Laptop

If you are working from a laptop and want to access the assistant running on the workstation, use the included SSH tunnel script.

On your **LAPTOP terminal**, run:
```bash
./scripts/tunnel.sh YOUR_LINUX_USERNAME WORKSTATION_IP_ADDRESS
```
*(Example: `./scripts/tunnel.sh arka 192.168.1.50`)*

Once connected, simply open your laptop's web browser and go to:
**http://localhost:7001**

You will be greeted by the secure login screen. Enter any username alongside the `JWT_SECRET` password you set in your `.env` file, and you are ready to write!
