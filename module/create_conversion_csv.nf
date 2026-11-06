process create_conversion_csv {
    publishDir "${params.final_output_dir}/manifests", mode: 'copy', pattern: 'conversion.csv'

    input: val records
    output: tuple val(records), path('conversion.csv'), emit: input

    exec:
        file("${task.workDir}/conversion.csv").text =
            'sample_name,fraction_id,path,scan\n' + records.collect { s, f, m, a, scan ->
                "${s},${f},${m},${scan ?: ''}"
            }.join('\n') + '\n'
}
