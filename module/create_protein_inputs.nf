process create_protein_inputs {
    publishDir "${params.final_output_dir}/manifests", mode: 'copy',
        pattern: 'protein-cohort.consensusXML',
        enabled: params.experiment_type == 'LFQ'

    input:
        tuple val(records), path(quantDir), path(unfilteredCsv)

    output:
        tuple path('protein-cohort.consensusXML'), path(unfilteredCsv), emit: input

    script:
        """
        set -euo pipefail
        consensus_files=()
        while IFS= read -r consensus; do
            consensus_files+=("\$consensus")
        done < <(find "\$(realpath '${quantDir}')" \\
            -type f -path '*/output/*_IDConflictResolver.consensusXML' -print | sort)
        test \${#consensus_files[@]} -eq 1 || {
            echo 'Expected one final ${params.experiment_type} IDConflictResolver consensusXML; found '"\${#consensus_files[@]}" >&2
            exit 1
        }
        ln -s "\$(realpath "\${consensus_files[0]}")" protein-cohort.consensusXML
        """
}
