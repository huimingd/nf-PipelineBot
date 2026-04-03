Usage Examples
Basic Usage (Local Execution)

nextflow run main.nf

With Custom Config File

nextflow run main.nf --config_file /path/to/your/config.yaml

With SLURM Execution

nextflow run main.nf \
    --use_slurm true \
    --slurm_partition compute \
    --slurm_account myproject \
    --slurm_time_limit "08:00:00" \
    --slurm_mem_gb 32
	
With Custom Repository Branch

nextflow run main.nf --pipelinebot_revision develop

Usage:
# With your custom config file
nextflow run main_single.nf --config_file "/home/cloud/myhome/sourcecode/PipelineBot_test/alignment_bwa.yaml"

# With default config
nextflow run main_single.nf

# Using modular version
nextflow run main.nf --config_file "/path/to/your/config.yaml"

The main issue was the channel creation for the dummy file and the hard-coded config path. These fixes should resolve the parameter passing problem you were experiencing.

Key Features

    Automatic Repository Cloning: The workflow clones your PipelineBot repository automatically
    Environment Setup: Installs all required Python dependencies using conda
    Flexible Configuration: Supports custom YAML config files or uses the default
    SLURM Support: Passes through all SLURM parameters to your main.py script
    Output Management: Publishes results and logs to the specified output directory
    Wave Integration: Uses Wave for environment caching and reproducibility

This Nextflow wrapper provides a clean interface to run your PipelineBot while leveraging Nextflow's workflow management capabilities, resource handling, and reproducibility features.

