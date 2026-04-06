#!/bin/bash
# =========================================================================
# HPC Build Script for Singularity Container
# =========================================================================
# You MUST run this on a Linux machine where you have `sudo` privileges 
# (e.g. your local workstation). You cannot run `singularity build` on the HPC!

echo "[*] Building Singularity 'Empty Shell' Container..."
echo "[*] This will install CUDA 12.1, GCC-10, Python 3.12, Node 20, and compile llama.cpp."
echo "[*] This takes approximately 10-15 minutes."

# Build the .sif image natively
sudo singularity build manuscript_hpc.sif manuscript_hpc.def

echo "[*] Complete! You now have a standalone container file: manuscript_hpc.sif"
echo "[*] Transfer this file to your HPC cluster via rsync or scp."
