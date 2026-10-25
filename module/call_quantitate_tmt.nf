process call_quantitate_tmt {
    publishDir "${params.final_output_dir}", mode: 'copy', pattern: 'quantitate-ProteomicTMT-*'
    input:
        tuple val(records), path(validationDir), path(idCsv), path(mzmlCsv), path(unfilteredCsv), path(configJson), path(resourceConfig)
        path channelCsv
    output:
        tuple val(records), path('quantitate-ProteomicTMT-*'), path(unfilteredCsv), emit: result
    script:
        """
        set -euo pipefail
        NXF_WORK=\$(pwd)/child-work nextflow run ${projectDir}/external/quantitate-ProteomicTMT/main.nf \
            -c ${projectDir}/config/child-quantitate-ProteomicTMT.config \
            -c ${resourceConfig} -profile ${params.child_profile} -params-file ${configJson} \
            --idXML_csv \$(realpath ${idCsv}) --mzML_csv \$(realpath ${mzmlCsv}) \
            --channel_csv \$(realpath ${channelCsv}) --output_dir \$(pwd)
        """
}
