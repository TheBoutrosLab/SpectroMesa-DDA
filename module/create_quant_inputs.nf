process create_quant_inputs {
    publishDir "${params.final_output_dir}/manifests", mode: 'copy', pattern: '*.csv'
    input: tuple val(records), path(validationDir)
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
        def mzmlRows = records.collect { s, f, m, a ->
            params.experiment_type == 'TMT' ?
                "printf '%s,%s\\n' '${s}' '${m}' >> quant-mzml.csv" :
                "printf '%s,%s,%s\\n' '${s}' '${f}' '${m}' >> quant-mzml.csv"
        }.join('\n')
        """
        set -euo pipefail
        printf '${params.experiment_type == 'TMT' ? 'plex_id' : 'sample_name'},idXML\\n' > quant-idxml.csv
        printf '${params.experiment_type == 'TMT' ? 'plex_id' : 'sample_name,fraction_id'},mzML\\n' > quant-mzml.csv
        printf 'path\\n' > protein-unfiltered.csv
        ${idRows}
        ${mzmlRows}
        if [ '${params.quantitate_ProteomicProtein.protein_grouping_algorithm}' = 'ProteinProphet' ]; then
            test \$(wc -l < protein-unfiltered.csv) -eq \$((${sampleNames.size()} * ${engines.size()} + 1)) || { echo 'Missing unfiltered PEP idXML for ProteinProphet' >&2; exit 1; }
        fi
        """
}
