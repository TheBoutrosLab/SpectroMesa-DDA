process create_converted_input {
    publishDir "${params.final_output_dir}/manifests", mode: 'copy', pattern: 'converted-input.csv'

    input: tuple val(records), path(convertDir)
    output: path('converted-input.csv'), emit: input

    script:
        def rows = records.collect { s, f, m, a, scan ->
            """
            matches=( '${convertDir}/${s}'/*/output/${f}_*.mzML )
            test \${#matches[@]} -eq 1 || { echo 'Expected one converted mzML for ${s}/${f}; found '\${#matches[@]} >&2; exit 1; }
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
