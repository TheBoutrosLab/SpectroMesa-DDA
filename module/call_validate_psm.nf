process call_validate_psm {
    publishDir "${params.final_output_dir}", mode: 'copy', pattern: 'validate-ProteomicPSM-*'

    input:
        tuple val(records), path(inputCsv), path(mzmlCsv), path(configJson), path(resourceConfig), path(projectYaml)
        path database

    output:
        tuple val(records), path('validate-ProteomicPSM-*'), path('validation-mzml.csv'), emit: result

    script:
        def projectArgument = params.validate_ProteomicPSM.run_protloom ?
            "--protloom_project_yaml \$(realpath ${projectYaml})" : ''
        """
        set -euo pipefail
        NXF_WORK=\$(pwd)/child-work \\
        nextflow run ${projectDir}/external/validate-ProteomicPSM/main.nf \\
            -c ${projectDir}/external/validate-ProteomicPSM/config/template.config \\
            -c ${resourceConfig} \\
            -profile ${params.child_profile} \\
            -params-file ${configJson} \\
            --input_csv \$(realpath ${inputCsv}) \\
            --input_mzml_csv \$(realpath ${mzmlCsv}) \\
            --decoy_database \$(realpath ${database}) \\
            --dataset_id ${params.dataset_id} \\
            ${projectArgument} \\
            --output_dir \$(pwd)
        """
}
