process call_quantitate_lfq {
    publishDir "${params.final_output_dir}", mode: 'copy', pattern: 'quantitate-ProteomicLFQ-*'
    input:
        tuple val(records), path(validationDir), path(idCsv), path(mzmlCsv), path(unfilteredCsv), path(configJson), path(resourceConfig)
    output:
        tuple val(records), path('quantitate-ProteomicLFQ-*'), path(unfilteredCsv), emit: result
    script:
        """
        set -euo pipefail
        NXF_WORK=\$(pwd)/child-work nextflow run ${projectDir}/external/quantitate-ProteomicLFQ/main.nf \
            -c ${projectDir}/config/child-quantitate-ProteomicLFQ.config \
            -c ${resourceConfig} -profile ${params.child_profile} -params-file ${configJson} \
            --idXML_csv \$(realpath ${idCsv}) --mzML_csv \$(realpath ${mzmlCsv}) \
            --project_name ${params.dataset_id} --output_dir \$(pwd)
        """
}
