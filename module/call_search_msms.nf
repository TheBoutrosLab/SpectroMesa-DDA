process call_search_msms {
    publishDir "${params.final_output_dir}", mode: 'copy', pattern: 'search-ProteomicMSMS-*'

    input:
        tuple path(inputCsv), val(records), path(configJson), path(resourceConfig)
        path database
        path msfraggerJar

    output:
        tuple val(records), path('search-ProteomicMSMS-*'), emit: result

    script:
        """
        set -euo pipefail
        NXF_WORK=\$(pwd)/child-work \\
        nextflow run ${projectDir}/external/search-ProteomicMSMS/main.nf \\
            -c ${projectDir}/external/search-ProteomicMSMS/config/template.config \\
            -c ${resourceConfig} \\
            -profile ${params.child_profile} \\
            -params-file ${configJson} \\
            --input_csv \$(realpath ${inputCsv}) \\
            --decoy_database \$(realpath ${database}) \\
            --msfragger_executable \$(realpath ${msfraggerJar}) \\
            --output_dir \$(pwd)
        """
}
