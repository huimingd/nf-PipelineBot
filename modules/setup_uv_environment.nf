process SETUP_UV_ENVIRONMENT {
    conda "conda-forge::uv=0.4.18"
    
    input:
    path repo_dir
    
    output:
    path repo_dir, emit: setup_repo
    
    script:
    """
    cd ${repo_dir}
    
    # Install dependencies using uv with the lock file
    uv sync --locked
    
    # Verify the installation
    uv run python --version
    uv run python -c "import psutil, yaml; print('Dependencies installed successfully')"
    """
}
