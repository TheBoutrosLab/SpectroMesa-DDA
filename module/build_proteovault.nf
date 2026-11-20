process build_proteovault {
    container params.docker_image_proteovault
    publishDir "${params.metapipeline_output_dir}",
        mode: 'copy', pattern: '*.proteovault.duckdb'

    input:
        path searchDir
        path validationDir
        path quantDir
        path proteinDir
        path qcDir
        path qcMzmlCsv
        path databaseFasta
        path channelCsv

    output:
        path("${params.dataset_id}.proteovault.duckdb"), emit: database

    script:
        def versionDirectory = new File(params.output_dir_base.toString()).parentFile.name
        def channelArgument = params.experiment_type == 'TMT' ?
            "--tmt-channel-csv \"\$(realpath '${channelCsv}')\"" : ''
        def resolvedSettings = groovy.json.JsonOutput.toJson(
            [quantitate_ProteomicTMT: [plex_type: params.quantitate_ProteomicTMT.plex_type]]
        )
        def settingsCommand = params.experiment_type == 'TMT' ?
            "cat > \"\$PWD/source/run.resolved.yaml\" <<'PROTEOVAULT_SETTINGS'\n${resolvedSettings}\nPROTEOVAULT_SETTINGS" : ''
        """
        set -euo pipefail
        source_root="\$PWD/source/${versionDirectory}"
        workflow_root="\$source_root/${params.dataset_id}/main_workflow"
        mkdir -p "\$workflow_root/manifests"
        for input_dir in '${searchDir}' '${validationDir}' '${quantDir}' '${proteinDir}' '${qcDir}'; do
            ln -s "\$(realpath "\$input_dir")" "\$workflow_root/\$(basename "\$input_dir")"
        done
        ln -s "\$(realpath '${qcMzmlCsv}')" "\$workflow_root/manifests/qc-mzml.csv"
        ${settingsCommand}
        vault="\$PWD/${params.dataset_id}.proteovault.duckdb"
        proteovault build --workflow-type DDA --pipeline-output "\$source_root" --fasta "\$(realpath '${databaseFasta}')" ${channelArgument} --output "\$vault"
        proteovault validate "\$vault"
        """
}
