process CLONE_PIPELINEBOT {
    // No conda directive needed - use system git
    
    output:
    path "PipelineBot", emit: repo_dir
    
    script:
    """
    git clone ${params.pipelinebot_repo} PipelineBot
    cd PipelineBot
    git checkout ${params.pipelinebot_revision}
    """
}

