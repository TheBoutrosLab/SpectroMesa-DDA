process create_protein_inputs {
    container(params.quantitate_ProteomicProtein.docker_image_openms ?:
        "ghcr.io/theboutroslab/openms-thirdparty:${params.quantitate_ProteomicProtein.openms_version ?: '3.5.0'}")

    publishDir "${params.final_output_dir}/manifests", mode: 'copy',
        pattern: 'protein-cohort.consensusXML',
        enabled: params.experiment_type == 'LFQ'

    input:
        tuple val(records), path(quantDir), path(unfilteredCsv)

    output:
        tuple path('protein-cohort.consensusXML'), path(unfilteredCsv), emit: input

    script:
        def pattern = params.experiment_type == 'TMT' ?
            "*/output/${params.dataset_id}_IDConflictResolver.consensusXML" :
            (params.quantitate_ProteomicLFQ.fractionated ?
                '*/output/FileMerger/*_FileMerger.consensusXML' :
                '*/output/MSPtools_ConsensusXML_setColumnHeaders/*_setColumnHeaders.consensusXML')
        """
        set -euo pipefail
        consensus_files=()
        while IFS= read -r consensus; do
            consensus_files+=("\$consensus")
        done < <(find "\$(realpath '${quantDir}')" \\
            -type f -path '${pattern}' -print | sort)
        test \${#consensus_files[@]} -gt 0 || { echo 'Missing final ${params.experiment_type} consensusXML' >&2; exit 1; }
        if [ '${params.experiment_type}' = 'TMT' ]; then
            test \${#consensus_files[@]} -eq 1 || { echo 'Expected one final TMT consensusXML' >&2; exit 1; }
        fi
        if [ \${#consensus_files[@]} -eq 1 ]; then
            ln -s "\$(realpath "\${consensus_files[0]}")" protein-cohort.consensusXML
        else
            FileMerger \\
                -in "\${consensus_files[@]}" \\
                -in_type consensusXML \\
                -append_method append_cols \\
                -out protein-cohort.consensusXML \\
                -threads ${task.cpus}
        fi
        """
}
