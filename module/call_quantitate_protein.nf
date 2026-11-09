process call_quantitate_protein {
    publishDir "${params.final_output_dir}", mode: 'copy', pattern: 'quantitate-ProteomicProtein-*'

    input:
        tuple path(consensusCsv), path(unfilteredCsv), path(configJson), path(resourceConfig)
        path database

    output: path('quantitate-ProteomicProtein-*'), emit: result

    script:
        """
        set -euo pipefail
        NXF_WORK=\$(pwd)/child-work \\
        nextflow run ${projectDir}/external/quantitate-ProteomicProtein/main.nf \\
            -c ${projectDir}/config/child-quantitate-ProteomicProtein.config \\
            -c ${resourceConfig} \\
            -profile ${params.child_profile} \\
            -params-file ${configJson} \\
            --input_consensusXML \$(realpath ${consensusCsv}) \\
            --unfiltered_idXML \$(realpath ${unfilteredCsv}) \\
            --decoy_database \$(realpath ${database}) \\
            --project_name ${params.dataset_id} \\
            --protein_fdr_cutoff ${params.quantitate_ProteomicProtein.protein_fdr_cutoff} \\
            --output_dir \$(pwd)
        """
}
