# NumaScribe — HPC Quick Connect Guide

A quick-reference card for connecting to the VUB HPC cluster and accessing NumaScribe.

---

## 1. SSH into the HPC Login Node

Open a terminal on your workstation and run:

```bash
ssh -i ~/.ssh/id_rsa_vsc vsc11013@login.hpc.vub.be
```

You will be prompted for your SSH key passphrase. After entering it, you will land on the VUB login node.

---

## 2. Submit the SLURM Job

On the HPC login node, navigate to the project and launch the job:

```bash
cd $VSC_SCRATCH/Manuscript-Assist-GPT-OSS-20b
sbatch Singularity/run_agents_l40s.sbatch
```

Check which compute node your job landed on:

```bash
squeue -u vsc11013
```

Look at the **NODELIST** column (e.g., `node511`).

---

## 3. Open the SSH Tunnel from Your Workstation

Open a **new terminal** on your workstation (keep the HPC session in the other one) and run:

```bash
ssh -N -L 5173:node511:5173 -L 8000:node511:8000 -i ~/.ssh/id_rsa_vsc vsc11013@login.hpc.vub.be
```

> **Note:** Replace `node511` with whatever node name appeared in `squeue`.

The terminal will appear to hang — **that is correct**. The tunnel is active.

---

## 4. Access NumaScribe in Your Browser

Open your web browser and navigate to:

```
http://localhost:5173
```

Log in with:
- **Username:** `andrew`
- **Password:** `password123`

You are now connected to NumaScribe running on the HPC GPU node! 🎉

---

## 5. Example Prompt to Test

Paste the following into the chat to verify the system produces a full scientific output:

> Write a detailed Materials and Methods section for a study investigating the biomechanical properties of hepatic stellate cells (HSCs) during fibrotic activation using atomic force microscopy (AFM) combined with single-cell RNA sequencing (scRNA-seq). The study uses a carbon tetrachloride (CCl₄)-induced murine liver fibrosis model with C57BL/6J mice at 2-week, 4-week, and 8-week timepoints versus oil-injected controls. Include: (1) the AFM force spectroscopy protocol using a JPK NanoWizard 4 with MLCT-BIO cantilevers for measuring Young's modulus via the Hertz contact model, (2) the scRNA-seq library preparation using 10x Genomics Chromium v3.1, (3) the bioinformatic pipeline for integrating mechanical phenotyping data with transcriptomic clusters using Seurat v5 and a custom correlation analysis between cell stiffness quartiles and differentially expressed genes, and (4) the statistical framework including mixed-effects models accounting for biological replicates (n=6 per group) and multiple comparison corrections using Benjamini-Hochberg FDR at q<0.05. Use proper LaTeX formatting for all equations and units.

**Expected output:** A complete ~1200-word Materials & Methods section with 6 subsections, Hertz model equations in LaTeX, and a linear mixed-effects model definition.

---

## Useful Commands

| Task | Command |
|------|---------|
| Check job status | `squeue -u vsc11013` |
| View main job log | `tail -f $VSC_SCRATCH/Manuscript-Assist-GPT-OSS-20b/slurm_logs/hpc_l40s_*.log` |
| View drafter log | `tail -f $VSC_SCRATCH/Manuscript-Assist-GPT-OSS-20b/slurm_logs/drafter.log` |
| View backend log | `tail -f $VSC_SCRATCH/Manuscript-Assist-GPT-OSS-20b/slurm_logs/backend.log` |
| Cancel a job | `scancel <job_id>` |
| Check GPU usage | `ssh node511 nvidia-smi` |
