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
        def mzmlRows = records.collect { s, f, m, a ->
            "printf '%s,%s,%s\\n' '${s}' '${f}' '${m}' >> validation-mzml.csv"
        }.join('\n')
        """
        set -euo pipefail
        printf 'sample_name,search_engine,idXML\\n' > validation.csv
        printf 'sample_name,fraction,mzML\\n' > validation-mzml.csv
        ${idRows}
        ${mzmlRows}
        """
}
