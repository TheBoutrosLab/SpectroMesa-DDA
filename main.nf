#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { create_config_json } from './module/create_config_json.nf'
include { create_protloom_project } from './module/create_protloom_project.nf'
include { create_search_csv } from './module/create_search_csv.nf'
include { call_search_msms } from './module/call_search_msms.nf'
include { create_validation_csv } from './module/create_validation_csv.nf'
include { call_validate_psm } from './module/call_validate_psm.nf'
include { create_quant_inputs } from './module/create_quant_inputs.nf'
include { call_quantitate_tmt } from './module/call_quantitate_tmt.nf'
include { call_quantitate_lfq } from './module/call_quantitate_lfq.nf'
include { create_protein_inputs } from './module/create_protein_inputs.nf'
include { call_quantitate_protein } from './module/call_quantitate_protein.nf'
include { create_qc_inputs } from './module/create_qc_inputs.nf'
include { call_qc_dda } from './module/call_qc_dda.nf'

// Search and quantitation accept multiple mzML fractions per sample or plex.
def readMzMLCsv(String inputCsv) {
    def csv = file(inputCsv)
    if (!csv.isFile()) error "Input CSV does not exist: ${csv}"
    if (csv.readLines().findAll { it.trim() }.size() < 2) {
        error "Input CSV has no data rows: ${csv}"
    }

    return Channel.fromPath(csv).splitCsv(header: true).toList().map { records ->
        def headers = records ? records[0].keySet() as Set : [] as Set
        def requiredHeaders = ['sample_name', 'fraction_id', 'path'] as Set
        def allowedHeaders = requiredHeaders + ['annotation_id']
        if (!records || !(headers == requiredHeaders || headers == allowedHeaders)) {
            error 'Input CSV needs sample_name,fraction_id,path, with optional annotation_id'
        }
        if (params.validate_ProteomicPSM.run_protloom && !headers.contains('annotation_id')) {
            error 'ProtLoom requires annotation_id in the input CSV'
        }
        def seenSampleFractions = [] as Set
        def seenNames = [] as Set
        def seenPaths = [] as Set
        def parsed = records.collect { row ->
            def sample = row.sample_name?.trim()
            def fraction = row.fraction_id?.trim()
            def annotation = row.annotation_id?.trim() ?: ''
            if (!(sample ==~ /[A-Za-z0-9][A-Za-z0-9._-]*/) ||
                !(fraction ==~ /[A-Za-z0-9][A-Za-z0-9._-]*/) ||
                (params.validate_ProteomicPSM.run_protloom &&
                 !(annotation ==~ /[A-Za-z0-9][A-Za-z0-9._-]*/))) {
                error "Invalid sample_name, fraction_id, or ProtLoom annotation_id: ${row}"
            }
            if (!seenSampleFractions.add([sample, fraction])) {
                error "Duplicate fraction '${fraction}' for sample '${sample}'"
            }
            def raw = row.path?.trim()
            if (!raw) error "Missing mzML path for ${sample}"
            def mzml = file(raw.startsWith('/') ? raw : "${csv.parent}/${raw}")
            if (!mzml.isFile() || !mzml.name.toLowerCase().endsWith('.mzml')) {
                error "Missing or invalid mzML for ${sample}: ${mzml}"
            }
            if (mzml.baseName.contains('.') || !seenNames.add(mzml.name.toLowerCase()) ||
                !seenPaths.add(mzml.toRealPath().toString())) {
                error "mzML basenames and paths must be unique, with no dots before .mzML: ${mzml}"
            }
            tuple(sample, fraction, mzml.toRealPath().toString(), annotation)
        }
        if (params.validate_ProteomicPSM.run_protloom) {
            def annotations = parsed.groupBy { it[0] }.collectEntries { sample, rows ->
                [(sample): rows.collect { it[3] }.toSet()]
            }
            if (annotations.values().any { it.size() != 1 }) {
                error "ProtLoom fractions of a sample need the same annotation_id: ${annotations}"
            }
        }
        if (params.experiment_type == 'LFQ') {
            def fractionSets = parsed.groupBy { it[0] }.collectEntries { sample, rows ->
                [(sample): rows.collect { it[1] }.toSet()]
            }
            if (fractionSets.values().toSet().size() > 1) {
                error "LFQ samples must have the same fraction IDs: ${fractionSets}"
            }
            if (fractionSets.values().first().size() > 1 && !params.quantitate_ProteomicLFQ.fractionated) {
                error 'Multiple LFQ fractions require quantitate_ProteomicLFQ.fractionated = true'
            }
        }
        parsed
    }
}

workflow {
    samples = readMzMLCsv(params.input_csv)
    configs = Channel.of(
        ['search_ProteomicMSMS', params.search_ProteomicMSMS, []],
        ['validate_ProteomicPSM', params.validate_ProteomicPSM, []],
        ['quantitate_ProteomicTMT', params.quantitate_ProteomicTMT, []],
        ['quantitate_ProteomicLFQ', params.quantitate_ProteomicLFQ, []],
        ['quantitate_ProteomicProtein', params.quantitate_ProteomicProtein, []],
        ['qc_ProteomicDDA', params.qc_ProteomicDDA, []]
    )
    create_config_json(configs)
    searchConfig = create_config_json.out.config.filter { n, c, r -> n == 'search_ProteomicMSMS' }.map { n, c, r -> [c, r] }
    validationConfig = create_config_json.out.config.filter { n, c, r -> n == 'validate_ProteomicPSM' }.map { n, c, r -> [c, r] }
    tmtConfig = create_config_json.out.config.filter { n, c, r -> n == 'quantitate_ProteomicTMT' }.map { n, c, r -> [c, r] }
    lfqConfig = create_config_json.out.config.filter { n, c, r -> n == 'quantitate_ProteomicLFQ' }.map { n, c, r -> [c, r] }
    proteinConfig = create_config_json.out.config.filter { n, c, r -> n == 'quantitate_ProteomicProtein' }.map { n, c, r -> [c, r] }
    qcConfig = create_config_json.out.config.filter { n, c, r -> n == 'qc_ProteomicDDA' }.map { n, c, r -> [c, r] }

    create_search_csv(samples)
    searchInput = create_search_csv.out.input.combine(searchConfig)
    call_search_msms(searchInput, file(params.decoy_database), file(params.msfragger_executable ?: "${projectDir}/external/search-ProteomicMSMS/input/NO_FILE"))
    create_validation_csv(call_search_msms.out.result)
    validationBase = create_validation_csv.out.input.combine(validationConfig)
    if (params.validate_ProteomicPSM.run_protloom) {
        create_protloom_project(samples, params.validate_ProteomicPSM.protloom_project_yaml)
        validationInput = validationBase.combine(create_protloom_project.out.project)
            .map { records, inputCsv, mzmlCsv, config, resources, projectYaml ->
                [records, inputCsv, mzmlCsv, config, resources, projectYaml]
            }
    } else {
        validationInput = validationBase.map { records, inputCsv, mzmlCsv, config, resources ->
            [records, inputCsv, mzmlCsv, config, resources, []]
        }
    }
    call_validate_psm(validationInput, file(params.decoy_database))
    create_quant_inputs(call_validate_psm.out.result)

    if (params.experiment_type == 'TMT') {
        tmtInput = create_quant_inputs.out.input.combine(tmtConfig)
        call_quantitate_tmt(tmtInput, file(params.channel_csv))
        quantResult = call_quantitate_tmt.out.result
    } else {
        lfqInput = create_quant_inputs.out.input.combine(lfqConfig)
        call_quantitate_lfq(lfqInput)
        quantResult = call_quantitate_lfq.out.result
    }
    create_protein_inputs(quantResult)
    proteinInput = create_protein_inputs.out.input.combine(proteinConfig)
    call_quantitate_protein(proteinInput, file(params.decoy_database))

    qcSearch = create_validation_csv.out.input.map { records, searchCsv, mzmlCsv -> [records, searchCsv] }
    qcFiltered = create_quant_inputs.out.input.map { records, validationDir, filteredCsv, mzmlCsv, unfilteredCsv -> filteredCsv }
    qcInput = qcSearch.combine(qcFiltered).combine(call_quantitate_protein.out.result)
        .map { records, searchCsv, filteredCsv, proteinDir ->
            tuple(records, searchCsv, filteredCsv, proteinDir)
        }
    create_qc_inputs(qcInput)
    call_qc_dda(create_qc_inputs.out.input.combine(qcConfig))
}
