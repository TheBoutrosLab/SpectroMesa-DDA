process create_validation_csv {
    publishDir "${params.final_output_dir}/manifests", mode: 'copy', pattern: '*.csv'
    input: tuple val(records), path(searchDir)
    output: tuple val(records), path('validation.csv'), path('validation-mzml.csv'), emit: input
    script:
        def idRows = records.collect { it[0] }.unique().collectMany { s ->
            params.search_ProteomicMSMS.search_engines.collect { engine ->
            """
            id=\$(find '${searchDir}/${s}' -type f -name '${s}_${engine}.idXML' -print -quit)
            test -n "\$id" || { echo 'Missing search idXML for ${s}' >&2; exit 1; }
            printf '%s,%s,%s\\n' '${s}' '${engine}' "\$(realpath "\$id")" >> validation.csv
            """
            }
        }.join('\n')
        // The search child numbers reindexed files in search.csv order within each sample.
        def fractionIndex = [:].withDefault { 0 }
        def mzmlRows = records.collect { s, f, m, a ->
            if (!params.search_ProteomicMSMS.reindex_mzml) {
                return "printf '%s,%s,%s\\n' '${s}' '${f}' '${m}' >> validation-mzml.csv"
            }
            def index = ++fractionIndex[s]
            """
            mzml=\$(find '${searchDir}/${s}' -type f -path '*/output/reindex_mzml/${s}_reindex_${index}.mzML' -print -quit)
            test -n "\$mzml" || { echo 'Missing reindexed mzML for ${s} fraction ${f} (input ${index})' >&2; exit 1; }
            printf '%s,%s,%s\\n' '${s}' '${f}' "\$(realpath "\$mzml")" >> validation-mzml.csv
            """
        }.join('\n')
        """
        set -euo pipefail
        printf 'sample_name,search_engine,idXML\\n' > validation.csv
        printf 'sample_name,fraction,mzML\\n' > validation-mzml.csv
        ${idRows}
        ${mzmlRows}
        """
}
