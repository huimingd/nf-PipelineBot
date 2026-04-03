process RUN_PIPELINEBOT {
    //conda "conda-forge::uv=0.4.18"
    
    publishDir "${params.output_dir}", mode: 'copy'
    
    input:
    path repo_dir
    
    output:
    path "pipeline_results.json", emit: results
    path "pipeline.log", emit: log_file
    path "*.json", optional: true
    path "*.log", optional: true
    
    script:
    def slurm_args = params.use_slurm ? buildSlurmArgs() : ""
    def config_file_cmd = params.config_file ? 
        "cp '${params.config_file}' ./pipeline_config.yaml && config_file='./pipeline_config.yaml'" : 
        "config_file='src/resource_executor/examples/pipeline_bioinformatics.yaml'"
    """
    WORK_DIR=\$(pwd)
    cd ${repo_dir}

    # Ensure uv environment is synced
    uv sync --locked

    # Handle config file (logic moved to Groovy above)
    ${config_file_cmd}

    # Debug: Show what config file we're using
    echo "Using config file: \$config_file"
    ls -la \$config_file || echo "Config file not found at \$config_file"
    
    # Run the pipeline using uv
    uv run python main.py \\
        --config \$config_file \\
        --output \${WORK_DIR}/pipeline_results.json \\
        --log \${WORK_DIR}/pipeline.log \\
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