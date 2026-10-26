process create_qc_inputs {
    publishDir "${params.final_output_dir}/manifests", mode: 'copy', pattern: 'qc-mzml.csv'

    input:
        tuple val(records), path(searchCsv), path(filteredCsv), path(proteinDir)

    output:
        tuple path('qc-mzml.csv'), path(searchCsv), path(filteredCsv),
            path('protein-groups.input'), path('protein-quant.input'),
            path('peptide-quant.input'), emit: input

    script:
        def mzmlRows = records.collect { sample, fraction, mzml, annotation ->
            "printf '%s,%s,%s\\n' '${sample}' '${fraction}' '${mzml}' >> qc-mzml.csv"
        }.join('\n')
        def grouping = params.quantitate_ProteomicProtein.protein_grouping_algorithm
        def groupName = grouping == 'ProteinProphet' ?
            "${params.dataset_id}_ProteinProphet_filtered.idXML" :
            "${params.dataset_id}_IDConflictResolver.consensusXML"
        """
        set -euo pipefail
        printf 'sample_name,fraction_id,path\\n' > qc-mzml.csv
        ${mzmlRows}
        for kind in groups protein_quant peptide_quant; do
            case "\$kind" in
                groups) filename='${groupName}'; destination=protein-groups.input ;;
                protein_quant) filename='${params.dataset_id}_ProteinQuantifier_protein.csv'; destination=protein-quant.input ;;
                peptide_quant) filename='${params.dataset_id}_ProteinQuantifier_peptide.csv'; destination=peptide-quant.input ;;
            esac
            source=\$(find "\$(realpath '${proteinDir}')" -type f -path '*/output/*' -name "\$filename" -print -quit)
            test -n "\$source" || { echo "Missing QC input: \$filename" >&2; exit 1; }
            ln -s "\$(realpath "\$source")" "\$destination"
        done
        """
}
