process create_converted_input {
    publishDir "${params.final_output_dir}/manifests", mode: 'copy', pattern: 'converted-input.csv'

    input: tuple val(records), path(convertDir)
    output: path('converted-input.csv'), emit: input

    script:
        // convert-MSData suffixes every fraction only when a sample has
        // duplicate input basenames; otherwise it preserves each basename.
        def basenameCounts = records.countBy { row -> [row[0], file(row[2]).baseName] }
        def suffixFractions = basenameCounts.values().any { it > 1 }
        def rows = records.collect { s, f, m, a, scan ->
            def basename = file(m).baseName
            def outputName = "${basename}${suffixFractions ? "_${f}" : ''}.mzML"
            """
            matches=( '${convertDir}/${s}'/*/output/'${outputName}' )
            test \${#matches[@]} -eq 1 || { echo 'Expected ${outputName} for ${s}/${f}; found '\${#matches[@]} >&2; exit 1; }
            printf '%s,%s,%s,%s\\n' '${s}' '${f}' "\$(realpath "\${matches[0]}")" '${a}' >> converted-input.csv
            """
        }.join('\n')
        """
        set -euo pipefail
        shopt -s nullglob
        printf 'sample_name,fraction_id,path,annotation_id\\n' > converted-input.csv
        ${rows}
        """
}
