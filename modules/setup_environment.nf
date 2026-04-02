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
