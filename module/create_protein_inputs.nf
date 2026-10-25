process create_protein_inputs {
    publishDir "${params.final_output_dir}/manifests", mode: 'copy',
        pattern: 'protein-consensus.csv'

    input:
        tuple val(records), path(quantDir), path(unfilteredCsv)

    output:
        tuple path('protein-consensus.csv'), path(unfilteredCsv), emit: input

    script:
        def tmtRows = records.collect { it[0] }.unique().collect { sample ->
            """
            consensus=\$(find "\$(realpath '${quantDir}')" -type f \
                -path '*/output/*/${sample}_IDConflictResolver.consensusXML' -print -quit)
            test -n "\$consensus" || { echo 'Missing final consensusXML for ${sample}' >&2; exit 1; }
            printf '%s\\n' "\$(realpath "\$consensus")" >> protein-consensus.csv
            """.stripIndent()
        }.join('\n')
        def lfqPattern = params.quantitate_ProteomicLFQ.fractionated ?
            '*/output/FileMerger/*_FileMerger.consensusXML' :
            '*/output/MSPtools_ConsensusXML_setColumnHeaders/*_setColumnHeaders.consensusXML'
        def lfqRows = """
            consensus_files=\$(find "\$(realpath '${quantDir}')" -type f \
                -path '${lfqPattern}' \
                -print | sort)
            test -n "\$consensus_files" || { echo 'Missing final LFQ consensusXML files' >&2; exit 1; }
            while IFS= read -r consensus; do
                printf '%s\\n' "\$(realpath "\$consensus")" >> protein-consensus.csv
            done <<< "\$consensus_files"
        """.stripIndent()
        """
        set -euo pipefail
        printf 'path\\n' > protein-consensus.csv
        ${params.experiment_type == 'TMT' ? tmtRows : lfqRows}
        """
}
