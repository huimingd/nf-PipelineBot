#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIPELINEBOT } from './workflows/pipelinebot'

workflow {
    PIPELINEBOT()
}
