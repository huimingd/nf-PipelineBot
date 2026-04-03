include { DOWNLOAD_PIPELINEBOT } from '../modules/download_pipelinebot'
include { SETUP_UV_ENVIRONMENT } from '../modules/setup_uv_environment'
include { RUN_PIPELINEBOT } from '../modules/run_pipelinebot'

workflow PIPELINEBOT {
    // Download the PipelineBot repository
    DOWNLOAD_PIPELINEBOT()
    
    // Set up the uv environment with locked dependencies
    SETUP_UV_ENVIRONMENT(DOWNLOAD_PIPELINEBOT.out.repo_dir)
    
    // Run the PipelineBot main.py using uv (no config file input needed)
    RUN_PIPELINEBOT(SETUP_UV_ENVIRONMENT.out.setup_repo)
    
    emit:
    results = RUN_PIPELINEBOT.out.results
    log_file = RUN_PIPELINEBOT.out.log_file
}
