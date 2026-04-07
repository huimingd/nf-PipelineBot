# nf-PipelineBot

A Nextflow wrapper for [PipelineBot](https://github.com/huimingd/PipelineBot) — a Python framework for executing tasks with comprehensive resource monitoring and management.

This workflow automatically clones PipelineBot, sets up its `uv` environment, and runs it via Nextflow, giving you reproducibility, resource handling, and optional SLURM integration with no changes to PipelineBot itself.

## Features

- **Automatic Repository Cloning** — Clones PipelineBot at a specified branch or tag at runtime
- **Reproducible Environment** — Sets up the locked `uv` environment from PipelineBot's `uv.lock`
- **Flexible Configuration** — Accepts a custom YAML config or falls back to the default bioinformatics pipeline config
- **SLURM Pass-through** — Forwards all SLURM parameters to PipelineBot's `main.py --slurm` flags
- **GPU Acceleration** — Supports `ParabricksAlignmentTask` for GPU-accelerated alignment via `aligner: parabricks` in the YAML config
- **Output Management** — Publishes `pipeline_results.json` and `pipeline.log` to the specified output directory
- **Modular Design** — Core steps are split into reusable modules under `modules/`

## Requirements

- [Nextflow](https://www.nextflow.io/) ≥ 23.04
- [uv](https://github.com/astral-sh/uv) available on `$PATH` (or via conda)
- Git

## Usage

### Basic (local execution, default config)

```bash
nextflow run main.nf
```

### With a custom config file

```bash
nextflow run main.nf --config_file /path/to/your/config.yaml
```

### With a specific PipelineBot branch or tag

```bash
nextflow run main.nf --pipelinebot_revision develop
```

### SLURM execution

```bash
nextflow run main.nf \
    --use_slurm true \
    --slurm_partition compute \
    --slurm_account myproject \
    --slurm_time_limit "08:00:00" \
    --slurm_mem_gb 32
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `pipelinebot_repo` | `https://github.com/huimingd/PipelineBot.git` | PipelineBot repository URL |
| `pipelinebot_revision` | `main` | Branch, tag, or commit to check out |
| `config_file` | `null` | Path to a YAML pipeline config; uses PipelineBot's default if not set |
| `output_dir` | `results` | Directory for published outputs |
| `log_level` | `INFO` | Logging level passed to `main.py` |
| `use_slurm` | `false` | Enable SLURM execution inside PipelineBot |
| `slurm_partition` | `null` | SLURM partition/queue |
| `slurm_account` | `null` | SLURM project account |
| `slurm_time_limit` | `04:00:00` | Wall-clock limit per job |
| `slurm_mem_gb` | `null` | Memory per job (GB) |
| `slurm_nodes` | `null` | Nodes per job |
| `slurm_ntasks_per_node` | `null` | MPI tasks per node |
| `slurm_work_dir` | `/tmp/pipeline_slurm` | Shared directory for SLURM job scripts and logs |
| `slurm_python` | `python` | Python binary on compute nodes |
| `slurm_poll_interval` | `10` | Seconds between `squeue` polls |

## Pipeline Config YAML

When `--config_file` is not provided, the workflow uses PipelineBot's built-in `src/resource_executor/examples/pipeline_bioinformatics.yaml`. To customize the pipeline, copy and edit that file:

```yaml
tasks:
  - alignment
  - variant_calling
  - rna_seq

executor:
  reference_genome: reference_genome.fa
  annotation_file: annotations.gtf
  output_dir: bioinformatics_results

alignment:
  resource_config:
    cpus: 4
    memory_gb: 8.0
    max_processes: 2
    timeout_seconds: 1800
  fastq_files:
    - sample1.fastq
    - sample2.fastq
  fastq_r2_files:           # omit or leave empty for single-end
    - sample1_R2.fastq
    - sample2_R2.fastq
  aligner: bwa              # options: bwa, bowtie2, star, minimap2, parabricks
  threads_per_sample: 4

  # Parabricks (GPU) fields — required when aligner: parabricks
  # container_path: /path/to/clara-parabricks.sif
  # scratch_dir: /host/path/mounted/as/scratch  # bound to /scratch inside container

  # Optional: submit each alignment job to SLURM instead of running locally.
  # slurm_config:
  #   partition: compute
  #   nodes: 1
  #   ntasks_per_node: 1
  #   mem_gb: 8.0
  #   time_limit: "02:00:00"
  #   account: myproject
  #   work_dir: /scratch/pipeline_jobs
  #   gpu: h200:1            # GPU type:count, e.g. h200:1, h100:2, l40s:1
  #   modules: ["cuda/13.0", "apptainer/1.1.9"]
  #   extra_directives: ["--requeue"]

variant_calling:
  resource_config:
    cpus: 8
    memory_gb: 16.0
    max_processes: 4
    timeout_seconds: 3600
  caller: gatk              # options: gatk, freebayes, samtools
  bam_files: []             # leave empty to use BAM files from the alignment task

  # slurm_config:
  #   partition: compute
  #   mem_gb: 16.0
  #   time_limit: "04:00:00"

rna_seq:
  resource_config:
    cpus: 6
    memory_gb: 12.0
    max_processes: 3
    timeout_seconds: 2400
  quantification_method: salmon   # options: salmon, kallisto, featurecounts

  # slurm_config:
  #   partition: compute
  #   mem_gb: 12.0
  #   time_limit: "03:00:00"
```

Tasks listed under `tasks:` are executed in order. Remove or reorder entries to run only a subset. When `variant_calling` follows `alignment`, BAM files are passed automatically.

> **Note:** `slurm_config` blocks in the YAML are overridden when `--slurm` flags are passed on the command line.

See the [PipelineBot README](https://github.com/huimingd/PipelineBot) for the full YAML reference and all supported tasks.

## GPU-accelerated alignment with Parabricks

Set `aligner: parabricks` in the YAML config to run `pbrun fq2bam` inside a Singularity container on a GPU node. The container is launched via `singularity exec --nv` with `scratch_dir` bound to `/scratch` inside the container. All input/output paths should be expressed relative to `/scratch`.

```yaml
executor:
  reference_genome: /scratch/Genomes/hg38.fa   # path visible inside container
  output_dir: /RUN/alignment                    # written inside container

alignment:
  aligner: parabricks
  fastq_files:
    - /scratch/sample_R1.fastq
  fastq_r2_files:
    - /scratch/sample_R2.fastq
  container_path: /host/path/clara-parabricks.sif
  scratch_dir: /host/path/to/scratch           # mounted as /scratch in container
  slurm_config:
    partition: gpu_partition
    mem_gb: 64.0
    time_limit: "06:00:00"
    gpu: h200:1                                # or l40s:1, h100:2, etc.
    modules: ["cuda/13.0.1", "apptainer/1.1.9"]
    work_dir: /host/path/slurm_jobs
```

Pass this config via `--config_file`:

```bash
nextflow run main.nf --config_file /path/to/alignment_gpu.yaml
```

## Workflow Structure

```
DOWNLOAD_PIPELINEBOT
        │
        ▼
SETUP_UV_ENVIRONMENT   (uv sync --locked)
        │
        ▼
RUN_PIPELINEBOT        (uv run python main.py ...)
        │
        ▼
  results/
  ├── pipeline_results.json
  └── pipeline.log
```

### Modules

| Module | Description |
|--------|-------------|
| `modules/download_pipelinebot.nf` | Clones the PipelineBot repo at the specified revision |
| `modules/setup_uv_environment.nf` | Runs `uv sync --locked` to install locked dependencies |
| `modules/run_pipelinebot.nf` | Executes `uv run python main.py` with all parameters |

## Entry Points

| File | Description |
|------|-------------|
| `main.nf` | Modular entry point using `include` from `modules/` and `workflows/` |
| `main_single.nf` | Self-contained single-file workflow |

Both entry points produce identical results. `main.nf` is the recommended entry point — its split module structure makes individual steps easier to reuse and maintain. `main_single.nf` is available as a self-contained alternative with no module dependencies.

## License

MIT License — see [LICENSE](LICENSE) for details.
