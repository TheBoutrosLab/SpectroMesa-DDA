process create_qc_inputs {
    publishDir "${params.final_output_dir}/manifests", mode: 'copy', pattern: 'qc-*.csv'

    input:
        tuple val(records), path(searchCsv), path(mzmlCsv), path(filteredCsv), path(validationDir), path(proteinDir)

    output:
        tuple path('qc-mzml.csv'), path(searchCsv), path(filteredCsv), path('qc-psm-features.csv'),
            path('protein-groups.input'), path('protein-quant.input'),
            path('peptide-quant.input'), emit: input

    script:
        def featureRows = records.collect { it[0] }.unique().collect { sample ->
            def fractions = records.findAll { it[0] == sample }.collect { it[1] }
            params.search_ProteomicMSMS.search_engines.collect { engine ->
                def pinRows = fractions.collect { fraction -> """
                    pin=\$(find '${validationDir}/${sample}' -type f \\
                        -path '*/MSBooster/output/engine_${engine}/run_*-fraction_${fraction}_edited.pin' -print -quit)
                    if test -n "\$pin"; then
                        printf '%s,%s,MSBooster,%s,%s\\n' '${sample}' '${engine}' '${fraction}' "\$(realpath "\$pin")" >> qc-psm-features.csv
                    fi
                """.stripIndent() }.join('\n')
                """
                    feature=\$(find '${validationDir}/${sample}' -type f \\
                        -name '${sample}_${engine}_featureExtracted.idXML' -print -quit)
                    if test -n "\$feature"; then
                        printf '%s,%s,PSMFeatureExtractor,,%s\\n' '${sample}' '${engine}' "\$(realpath "\$feature")" >> qc-psm-features.csv
                    fi
                    ${pinRows}
                """.stripIndent()
            }.join('\n')
        }.join('\n')
        def grouping = params.quantitate_ProteomicProtein.protein_grouping_algorithm
        def groupName = grouping == 'ProteinProphet' ?
            "${params.dataset_id}_ProteinProphet_filtered.idXML" :
            "${params.dataset_id}_IDConflictResolver.consensusXML"
        """
        set -euo pipefail
        printf 'sample_name,fraction_id,path\\n' > qc-mzml.csv
        printf 'sample_name,search_engine,route,fraction_id,path\\n' > qc-psm-features.csv
        tail -n +2 ${mzmlCsv} >> qc-mzml.csv
        ${featureRows}
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
