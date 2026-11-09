process create_quant_inputs {
    publishDir "${params.final_output_dir}/manifests", mode: 'copy', pattern: '*.csv'
    input: tuple val(records), path(validationDir), path(mzmlCsv)
    output:
        tuple val(records), path(validationDir), path('quant-idxml.csv'), path('quant-mzml.csv'), path('protein-unfiltered.csv'), emit: input
    script:
        def sampleNames = records.collect { it[0] }.unique()
        def engines = params.search_ProteomicMSMS.search_engines
        def idRows = sampleNames.collect { s ->
            def idName = params.validate_ProteomicPSM.run_protloom ? "${s}_ProtLoom_filter.idXML" :
                (params.validate_ProteomicPSM.merge_consensus ? "${s}_consensus_filter.idXML" : "${s}_${engines[0]}_filter.idXML")
            def unfilteredRows = engines.collect { engine -> """
            unfiltered=\$(find '${validationDir}/${s}' -type f -name '${s}_${engine}_idswitch_pep.idXML' -print -quit)
            if test -n "\$unfiltered"; then printf '%s\\n' "\$(realpath "\$unfiltered")" >> protein-unfiltered.csv; fi
            """ }.join('\n')
            """
            id=\$(find '${validationDir}/${s}' -type f -name '${idName}' -print -quit)
            test -n "\$id" || { echo 'Missing validated idXML for ${s}' >&2; exit 1; }
            printf '%s,%s\\n' '${s}' "\$(realpath "\$id")" >> quant-idxml.csv
            ${unfilteredRows}
            """
        }.join('\n')
        def mzmlColumns = params.experiment_type == 'TMT' && params.quantitate_ProteomicTMT.tmt_workflow != 'feature_based' ?
            '\$1 "," \$3' : '\$1 "," \$2 "," \$3'
        def mzmlHeader = params.experiment_type == 'TMT' ?
            (params.quantitate_ProteomicTMT.tmt_workflow == 'feature_based' ? 'plex_id,fraction_id,mzML' : 'plex_id,mzML') :
            'sample_name,fraction_id,mzML'
        """
        set -euo pipefail
        printf '${params.experiment_type == 'TMT' ? 'plex_id' : 'sample_name'},idXML\\n' > quant-idxml.csv
        printf '${mzmlHeader}\\n' > quant-mzml.csv
        printf 'path\\n' > protein-unfiltered.csv
        ${idRows}
        awk -F, 'NR > 1 { print ${mzmlColumns} }' ${mzmlCsv} >> quant-mzml.csv
        if [ '${params.quantitate_ProteomicProtein.protein_grouping_algorithm}' = 'ProteinProphet' ]; then
            test \$(wc -l < protein-unfiltered.csv) -eq \$((${sampleNames.size()} * ${engines.size()} + 1)) || { echo 'Missing unfiltered PEP idXML for ProteinProphet' >&2; exit 1; }
        fi
        """
}
