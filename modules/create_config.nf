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
    
    # You can add custom logic here to modify the config based on Nextflow parameters
    """
}
