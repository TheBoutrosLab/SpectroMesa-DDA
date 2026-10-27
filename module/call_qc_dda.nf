process call_qc_dda {
    publishDir "${params.final_output_dir}", mode: 'copy', pattern: 'qc-ProteomicDDA-*'

    input:
        tuple path(mzmlCsv), path(searchCsv), path(filteredCsv), path(featuresCsv),
            path(proteinGroups), path(proteinQuant), path(peptideQuant),
            path(configJson), path(resourceConfig)

    output:
        path('qc-ProteomicDDA-*'), emit: result

    script:
        """
        set -euo pipefail
        NXF_WORK=\$(pwd)/child-work nextflow run ${projectDir}/external/qc-ProteomicDDA/main.nf \\
            -c ${projectDir}/config/child-qc-ProteomicDDA.config \\
            -c ${resourceConfig} -profile ${params.child_profile} -params-file ${configJson} \\
            --dataset_id ${params.dataset_id} \\
            --inference_route ${params.quantitate_ProteomicProtein.protein_grouping_algorithm} \\
            --mzml_csv \$(realpath ${mzmlCsv}) \\
            --search_idxml_csv \$(realpath ${searchCsv}) \\
            --filtered_idxml_csv \$(realpath ${filteredCsv}) \\
            --psm_features_csv \$(realpath ${featuresCsv}) \\
            --protein_groups \$(realpath ${proteinGroups}) \\
            --protein_quant_csv \$(realpath ${proteinQuant}) \\
            --peptide_quant_csv \$(realpath ${peptideQuant}) \\
            --output_dir \$(pwd)
        """
}
