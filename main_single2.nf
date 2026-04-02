#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

params.pipelinebot_repo = "https://github.com/huimingd/PipelineBot.git"
params.pipelinebot_revision = "main"
params.config_file = "/home/cloud/myhome/sourcecode/PipelineBot_test/alignment_bwa.yaml"
params.output_dir = "results"
params.log_level = "INFO"
params.use_slurm = false
params.slurm_partition = null
params.slurm_account = null
params.slurm_time_limit = "04:00:00"
params.slurm_mem_gb = null
params.slurm_nodes = null
params.slurm_ntasks_per_node = null
params.slurm_work_dir = "/home/cloud/myhome/sourcecode/PipelineBot_test/pipeline_slurm"
params.slurm_python = "python"
params.slurm_poll_interval = 10

process DOWNLOAD_PIPELINEBOT {
    // No conda needed - use system tools
    
    output:
    path "PipelineBot", emit: repo_dir
    
    script:
    """
    # Download repository using system curl/tar
    #curl -L https://github.com/huimingd/PipelineBot/archive/${params.pipelinebot_revision}.tar.gz | tar -xz
    #mv PipelineBot-${params.pipelinebot_revision} PipelineBot
    git clone ${params.pipelinebot_repo} PipelineBot
    cd PipelineBot
    git checkout ${params.pipelinebot_revision}
    """
}

process SETUP_UV_ENVIRONMENT {
    // No conda - assumes uv is available on the system
    
    input:
    path repo_dir
    
    output:
    path repo_dir, emit: setup_repo
    
    script:
    """
    cd ${repo_dir}
    
    # Install dependencies using system uv
    uv sync --locked
    
    # Verify the installation
    uv run python --version
    uv run python -c "import psutil, yaml; print('Dependencies installed successfully')"
    """
}

process CREATE_CONFIG {
    input:
    path repo_dir
    path config_file
    
    output:
    path "pipeline_config.yaml", emit: config
    
    script:
    // Fix the logic here
    if (config_file.name != 'NO_FILE') {
        """
        # Use the provided config file
        cp ${config_file} pipeline_config.yaml
        """
    } else {
        """
        # Use default config from repository
        cp ${repo_dir}/src/resource_executor/examples/pipeline_bioinformatics.yaml pipeline_config.yaml
        """
    }
}

process RUN_PIPELINEBOT {
    // No conda - uses system uv
    
    publishDir "${params.output_dir}", mode: 'copy'
    
    input:
    path repo_dir
    path config_file
    
    output:
    path "pipeline_results.json", emit: results
    path "pipeline.log", emit: log
    path "*.json", optional: true
    path "*.log", optional: true
    
    script:
    def slurm_args = params.use_slurm ? buildSlurmArgs() : ""
    """
    cd ${repo_dir}
    
    # Run using system uv
    uv run python main.py \\
        --config ${config_file} \\
        --output pipeline_results.json \\
        --log pipeline.log \\
        --log-level ${params.log_level} \\
        ${slurm_args}
    """
}

def buildSlurmArgs() {
    def args = []
    if (params.use_slurm) {
        args.add("--slurm")
        if (params.slurm_partition) args.add("--slurm-partition ${params.slurm_partition}")
        if (params.slurm_account) args.add("--slurm-account ${params.slurm_account}")
        if (params.slurm_time_limit) args.add("--slurm-time-limit ${params.slurm_time_limit}")
        if (params.slurm_mem_gb) args.add("--slurm-mem-gb ${params.slurm_mem_gb}")
        if (params.slurm_nodes) args.add("--slurm-nodes ${params.slurm_nodes}")
        if (params.slurm_ntasks_per_node) args.add("--slurm-ntasks-per-node ${params.slurm_ntasks_per_node}")
        if (params.slurm_work_dir) args.add("--slurm-work-dir ${params.slurm_work_dir}")
        if (params.slurm_python) args.add("--slurm-python ${params.slurm_python}")
        if (params.slurm_poll_interval) args.add("--slurm-poll-interval ${params.slurm_poll_interval}")
    }
    return args.join(" ")
}

workflow {
    // Download the PipelineBot repository
    DOWNLOAD_PIPELINEBOT()
    
    // Set up the uv environment with locked dependencies
    SETUP_UV_ENVIRONMENT(DOWNLOAD_PIPELINEBOT.out.repo_dir)
    
    // Create or use provided config file
    config_ch = params.config_file ? 
        Channel.fromPath(params.config_file, checkIfExists: true) : 
        Channel.fromPath("NO_FILE")
    
    CREATE_CONFIG(SETUP_UV_ENVIRONMENT.out.setup_repo, config_ch)
    
    // Run the PipelineBot main.py using uv
    RUN_PIPELINEBOT(
        SETUP_UV_ENVIRONMENT.out.setup_repo,
        CREATE_CONFIG.out.config
    )
}
