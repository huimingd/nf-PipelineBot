#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

params.pipelinebot_repo = "https://github.com/huimingd/PipelineBot.git"
params.pipelinebot_revision = "main"
params.config_file = null
params.output_dir = "results"
params.log_level = "INFO"
params.use_slurm = false
params.slurm_partition = null
params.slurm_account = null
params.slurm_time_limit = "04:00:00"
params.slurm_mem_gb = null
params.slurm_nodes = null
params.slurm_ntasks_per_node = null
params.slurm_work_dir = "/tmp/pipeline_slurm"
params.slurm_python = "python"
params.slurm_poll_interval = 10

process CLONE_PIPELINEBOT {
    conda "conda-forge::git=2.40.1"
    
    output:
    path "PipelineBot", emit: repo_dir
    
    script:
    """
    git clone ${params.pipelinebot_repo} PipelineBot
    cd PipelineBot
    git checkout ${params.pipelinebot_revision}
    """
}

process SETUP_ENVIRONMENT {
    conda "conda-forge::python=3.12 conda-forge::pip=23.1.2"
    
    input:
    path repo_dir
    
    output:
    path repo_dir, emit: setup_repo
    
    script:
    """
    cd ${repo_dir}
    
    # Install Python dependencies
    pip install psutil>=7.2.2 pyyaml>=6.0.3
    
    # Install the package in development mode if setup.py exists
    if [ -f setup.py ]; then
        pip install -e .
    fi
    """
}

process CREATE_CONFIG {
    input:
    path repo_dir
    path config_file
    
    output:
    path "pipeline_config.yaml", emit: config
    
    script:
    def config_source = config_file.name != 'NO_FILE' ? config_file : "${repo_dir}/src/resource_executor/examples/pipeline_bioinformatics.yaml"
    """
    # Use provided config file or default from repository
    cp ${config_source} pipeline_config.yaml
    
    # Optionally modify config based on parameters
    # This is where you could add logic to customize the YAML config
    # based on Nextflow parameters
    """
}

process RUN_PIPELINEBOT {
    conda "conda-forge::python=3.12 conda-forge::pip=23.1.2"
    
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
    
    # Set up Python path
    export PYTHONPATH="\${PWD}/src:\${PWD}/src/resource_executor/examples:\${PWD}/src/tasks:\${PYTHONPATH:-}"
    
    # Install dependencies
    pip install psutil>=7.2.2 pyyaml>=6.0.3
    
    # Run the pipeline
    python main.py \\
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
    // Clone the PipelineBot repository
    CLONE_PIPELINEBOT()
    
    // Set up the Python environment
    SETUP_ENVIRONMENT(CLONE_PIPELINEBOT.out.repo_dir)
    
    // Create or use provided config file
    config_ch = params.config_file ? 
        Channel.fromPath(params.config_file, checkIfExists: true) : 
        Channel.fromPath("NO_FILE")
    
    CREATE_CONFIG(SETUP_ENVIRONMENT.out.setup_repo, config_ch)
    
    // Run the PipelineBot main.py
    RUN_PIPELINEBOT(
        SETUP_ENVIRONMENT.out.setup_repo,
        CREATE_CONFIG.out.config
    )
}