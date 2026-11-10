#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { create_config_json } from './module/create_config_json.nf'
include { create_conversion_csv } from './module/create_conversion_csv.nf'
include { call_convert_msdata } from './module/call_convert_msdata.nf'
include { create_converted_input } from './module/create_converted_input.nf'
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
include { build_proteovault } from './module/build_proteovault.nf'

// Search and quantitation accept multiple mzML fractions per sample or plex.
def needsMSDataConversion(String inputCsv) {
    def csv = file(inputCsv)
    if (!csv.isFile()) error "Input CSV does not exist: ${csv}"
    def lines = csv.readLines().findAll { it.trim() }
    if (lines.size() < 2) error "Input CSV has no data rows: ${csv}"
    def headers = lines[0].split(',', -1).collect { it.trim() }
    def pathColumn = headers.indexOf('path')
    if (pathColumn < 0) error 'Input CSV needs a path column'
    def formats = lines.drop(1).collect { row ->
        def fields = row.split(',', -1)
        if (fields.size() <= pathColumn || !fields[pathColumn].trim()) error "Missing MS data path: ${row}"
        def path = fields[pathColumn].trim()
        def name = file(path).name
        def extension = name.lastIndexOf('.') >= 0 ? name.substring(name.lastIndexOf('.') + 1).toLowerCase() : ''
        if (!extension) error "Input MS data path has no extension: ${path}"
        extension
    }.toSet()
    if (formats.size() != 1) error "Input CSV mixes MS data formats: ${formats.sort().join(', ')}"
    return formats.first() != 'mzml'
}

def readMzMLCsv(inputCsv) {
    def csv = file(params.input_csv)
    if (!csv.isFile()) error "Input CSV does not exist: ${csv}"
    if (csv.readLines().findAll { it.trim() }.size() < 2) {
        error "Input CSV has no data rows: ${csv}"
    }

    return inputCsv.splitCsv(header: true).toList().map { records ->
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
            if (mzml.baseName.contains('.') || !seenNames.add([sample, mzml.name.toLowerCase()]) ||
                !seenPaths.add(mzml.toRealPath().toString())) {
                error "mzML basenames must be unique within each sample, paths must be unique, and basenames cannot contain dots: ${mzml}"
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

def readRawCsv(String inputCsv) {
    def csv = file(inputCsv)
    if (!csv.isFile()) error "Input CSV does not exist: ${csv}"
    if (csv.readLines().findAll { it.trim() }.size() < 2) error "Input CSV has no data rows: ${csv}"
    return Channel.fromPath(csv).splitCsv(header: true).toList().map { rows ->
        def headers = rows ? rows[0].keySet() as Set : [] as Set
        def required = ['sample_name', 'fraction_id', 'path'] as Set
        if (!rows || !headers.containsAll(required) || (headers - required - ['annotation_id', 'scan']).size() > 0) {
            error 'Conversion input CSV needs sample_name,fraction_id,path, with optional annotation_id and scan'
        }
        if (params.validate_ProteomicPSM.run_protloom && !headers.contains('annotation_id')) {
            error 'ProtLoom requires annotation_id in the input CSV'
        }
        def seen = [] as Set
        def seenPaths = [] as Set
        rows.collect { row ->
            def sample = row.sample_name?.trim()
            def fraction = row.fraction_id?.trim()
            def annotation = row.annotation_id?.trim() ?: ''
            if (!(sample ==~ /[A-Za-z0-9][A-Za-z0-9._-]*/) ||
                !(fraction ==~ /[A-Za-z0-9][A-Za-z0-9._-]*/) ||
                (params.validate_ProteomicPSM.run_protloom && !(annotation ==~ /[A-Za-z0-9][A-Za-z0-9._-]*/))) {
                error "Invalid sample_name, fraction_id, or ProtLoom annotation_id: ${row}"
            }
            if (!seen.add([sample, fraction])) error "Duplicate fraction '${fraction}' for sample '${sample}'"
            def raw = row.path?.trim()
            if (!raw) error "Missing MS data path for ${sample}/${fraction}"
            def input = file(raw.startsWith('/') ? raw : "${csv.parent}/${raw}")
            if (!input.isFile() || input.baseName.contains('.') || input.toString().contains(',') ||
                !seenPaths.add(input.toRealPath().toString())) {
                error "Missing or invalid MS data for ${sample}/${fraction}: ${input}"
            }
            def scanRaw = row.scan?.trim()
            def scan = scanRaw ? file(scanRaw.startsWith('/') ? scanRaw : "${csv.parent}/${scanRaw}") : null
            if ((scan && (!scan.isFile() || scan.toString().contains(','))) ||
                (input.name.toLowerCase().endsWith('.wiff') && !scan)) {
                error "WIFF requires an existing scan companion for ${sample}/${fraction}"
            }
            tuple(sample, fraction, input.toRealPath().toString(), annotation,
                scan ? scan.toRealPath().toString() : '')
        }
    }
}

workflow {
    configs = Channel.of(
        ['convert_MSData', params.convert_MSData, []],
        ['search_ProteomicMSMS', params.search_ProteomicMSMS, []],
        ['validate_ProteomicPSM', params.validate_ProteomicPSM, []],
        ['quantitate_ProteomicTMT', params.quantitate_ProteomicTMT, []],
        ['quantitate_ProteomicLFQ', params.quantitate_ProteomicLFQ, []],
        ['quantitate_ProteomicProtein', params.quantitate_ProteomicProtein, []],
        ['qc_ProteomicDDA', params.qc_ProteomicDDA, []]
    )
    create_config_json(configs)
    convertConfig = create_config_json.out.config.filter { n, c, r -> n == 'convert_MSData' }.map { n, c, r -> [c, r] }
    searchConfig = create_config_json.out.config.filter { n, c, r -> n == 'search_ProteomicMSMS' }.map { n, c, r -> [c, r] }
    validationConfig = create_config_json.out.config.filter { n, c, r -> n == 'validate_ProteomicPSM' }.map { n, c, r -> [c, r] }
    tmtConfig = create_config_json.out.config.filter { n, c, r -> n == 'quantitate_ProteomicTMT' }.map { n, c, r -> [c, r] }
    lfqConfig = create_config_json.out.config.filter { n, c, r -> n == 'quantitate_ProteomicLFQ' }.map { n, c, r -> [c, r] }
    proteinConfig = create_config_json.out.config.filter { n, c, r -> n == 'quantitate_ProteomicProtein' }.map { n, c, r -> [c, r] }
    qcConfig = create_config_json.out.config.filter { n, c, r -> n == 'qc_ProteomicDDA' }.map { n, c, r -> [c, r] }

    if (needsMSDataConversion(params.input_csv)) {
        rawSamples = readRawCsv(params.input_csv)
        create_conversion_csv(rawSamples)
        call_convert_msdata(create_conversion_csv.out.input.combine(convertConfig))
        create_converted_input(call_convert_msdata.out.result)
        samples = readMzMLCsv(create_converted_input.out.input)
    } else {
        samples = readMzMLCsv(Channel.fromPath(params.input_csv))
    }

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
    qcFiltered = create_quant_inputs.out.input.map { records, validationDir, filteredCsv, mzmlCsv, unfilteredCsv ->
        [filteredCsv, validationDir]
    }
    qcInput = qcSearch.combine(qcFiltered).combine(call_quantitate_protein.out.result)
        .map { records, searchCsv, filteredCsv, validationDir, proteinDir ->
            tuple(records, searchCsv, filteredCsv, validationDir, proteinDir)
        }
    create_qc_inputs(qcInput)
    call_qc_dda(create_qc_inputs.out.input.combine(qcConfig))

    if (!params.validate_ProteomicPSM.run_protloom) {
        build_proteovault(
            call_search_msms.out.result.map { records, dir -> dir },
            call_validate_psm.out.result.map { records, dir, mzmlCsv -> dir },
            quantResult.map { records, dir, unfilteredCsv -> dir },
            call_quantitate_protein.out.result,
            call_qc_dda.out.result,
            create_qc_inputs.out.input.map { mzmlCsv, searchCsv, filteredCsv, featuresCsv,
                proteinGroups, proteinQuant, peptideQuant -> mzmlCsv },
            file(params.decoy_database),
            file(params.experiment_type == 'TMT' ? params.channel_csv : params.input_csv)
        )
    }
}
