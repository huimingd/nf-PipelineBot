include { DOWNLOAD_PIPELINEBOT } from '../modules/download_pipelinebot'
include { SETUP_UV_ENVIRONMENT } from '../modules/setup_uv_environment'
include { RUN_PIPELINEBOT } from '../modules/run_pipelinebot'

workflow PIPELINEBOT {
    // Download the PipelineBot repository
    DOWNLOAD_PIPELINEBOT()
    
    // Set up the uv environment with locked dependencies
    SETUP_UV_ENVIRONMENT(DOWNLOAD_PIPELINEBOT.out.repo_dir)
    
    // Handle config file properly
    if (params.config_file) {
        config_ch = Channel.fromPath(params.config_file, checkIfExists: true)
    } else {
        config_ch = Channel.value(file('NO_FILE'))
    }
    
    // Run the PipelineBot main.py using uv
    RUN_PIPELINEBOT(
        SETUP_UV_ENVIRONMENT.out.setup_repo,
        config_ch
    )
    
    emit:
    results = RUN_PIPELINEBOT.out.results
    log = RUN_PIPELINEBOT.out.log
}