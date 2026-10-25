process create_search_csv {
    publishDir "${params.final_output_dir}/manifests", mode: 'copy', pattern: 'search.csv'
    input: val records
    output: tuple path('search.csv'), val(records), emit: input
    exec:
        file("${task.workDir}/search.csv").text = 'sample_name,path\n' + records.collect { s, f, m, a -> "${s},${m}" }.join('\n') + '\n'
}
