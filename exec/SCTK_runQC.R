#!/usr/bin/env Rscript --vanilla

##Check to see if necessary packages are installed
#CRAN packages
cran.packages <- c("optparse", "yaml", "igraph", "Rtsne", "spam", "MCMCprecision")

cran.package.check <- lapply(cran.packages, FUN = function(x) {
    if (!require(x, character.only = TRUE)) {
        install.packages(x, dependencies = TRUE)
    }
})

#Bioconductor packages
bioc.packages <- c("singleCellTK", "celda", "BiocParallel")

bioc.package.check <- lapply(bioc.packages, FUN = function(x) {
    if (!require(x, character.only = TRUE)) {
        BiocManager::install(x)
    }
})

# check for optparse (possibly redundant)
if(!require("optparse")) {
    install.packages("optparse")
}

## Function to parse arguments from yaml file
.parseConfig <- function(sctkConfig, arguments) {
  for (i in seq_along(arguments)) {
    arg <- arguments[i]
    assign(arg, sctkConfig[[arg]], envir = parent.frame())
  }
}

## tmp function to check the output of QC before generate HTAN meta
.check_QC <- function(directory, samplename) {
    absFilterDir <- file.path(directory, samplename, "FlatFile", "Cells")
    print('The layout of the output folder after QC is done')
    print(list.files(absFilterDir, recursive = TRUE))

    decontx_AbsFileName <- file.path(absFilterDir, 'assays', paste0(samplename, '_decontXcounts.mtx.gz'))
    mat_AbsFileName <- file.path(absFilterDir, 'assays', paste0(samplename, '_counts.mtx.gz'))

    AbsColData <- file.path(absFilterDir, paste0(samplename, '_cellData.txt.gz'))
    AbsDecontXUMAP <- file.path(absFilterDir, 'reducedDims', paste0(samplename, '_decontX_UMAP.txt.gz'))
    AbsScrubletTSNE <- file.path(absFilterDir, 'reducedDims', paste0(samplename, '_scrublet_TSNE.txt.gz'))
    AbsScrubletUMAP <- file.path(absFilterDir, 'reducedDims', paste0(samplename, '_scrublet_UMAP.txt.gz'))
    
    for (file in c(decontx_AbsFileName, mat_AbsFileName, AbsColData, AbsDecontXUMAP, AbsScrubletTSNE, AbsScrubletUMAP)) {
        if (!file.exists(file)) {print(paste('The following file cannot be accessed', file))}
    }
}

### helper function for importing Mito gene set
.importMito <- function(MitoImport, MitoType) {
    reference <- NULL
    id <- NULL

    if (isTRUE(MitoImport)) {
        mito_info <- strsplit(MitoType, split = "-")
        if (length(mito_info[[1]]) != 2) {
            stop("The --MitoType ", MitoType, " is not correct or supported. Please double check the documentation.")
        }

        reference <- mito_info[[1]][1]
        id <- mito_info[[1]][2]

        if ((!reference %in% c("human", "mouse")) || (!id %in% c("symbol", "entrez", "ensembl", "ensemblTranscriptID"))) {
            stop("The --MitoType ", MitoType, " is not correct or supported. Please double check the documentation.")
        }
    }
    return(list('reference' = reference, 'id' = id))
}

## Check whether python module is available
if (!reticulate::py_module_available(module = "scrublet")) {
    stop("Cannot find python module 'scrublet'. ",
            "Scrublet can be installed on the local machine",
            "with pip (e.g. pip install --user scanpy) and then the 'use_python()'",
            " function from the 'reticulate' package can be used to select the",
            " correct Python environment.")
}

##Read in flags from command line using optparse
option_list <- list(optparse::make_option(c("-b", "--basePath"),
        type = "character",
        default = NULL,
        help = "Base path for the output from the preprocessing algorithm"),
    optparse::make_option(c("-P", "--preproc"),
        type = "character",
        default = NULL,
        help = "Algorithm used for preprocessing. One of 'CellRangerV2', 'CellRangerV3', 'BUStools', 'STARSolo', 'SEQC', 'Optimus', 'DropEst', 'SceRDS', 'CountMatrix', 'AnnData', 'Seurat', 'Alevin', and 'FlatFile'."),
    optparse::make_option(c("-s", "--sample"),
        type = "character",
        help = "Name of the sample. This will be prepended to the cell barcodes."),
    optparse::make_option(c("-o", "--directory"),
        type = "character",
        default = ".",
        help = "Output directory"),
    optparse::make_option(c("-O", "--outputPrefix"),
        type = "character",
        default = "CombinedSamples",
        help = "Prefix of the name of output file when --splitSample=FALSE."),
    optparse::make_option(c("-g", "--gmt"),
        type = "character",
        default = NULL,
        help = "GMT file containing gene sets for quality control. The second column in the GMT file (i.e. the description) should contain the location to look for the IDs in the data. If set to 'rownames', then the gene set IDs will be matched with the row IDs of the data matrix. If another character or integer index is supplied, then gene set IDs will be matched to IDs the that column of feature table."),
    optparse:: make_option(c("-t", "--delim"),
        type = "character",
        default = "\t",
        help = "Delimiter used in GMT file"),
    optparse::make_option(c("-G", "--genome"),
        type = "character",
        default = NULL,
        help = "The name of genome reference. This is only required for CellRangerV2 data."),
    optparse::make_option(c("-C", "--cellPath"),
        type = "character",
        default = NULL,
        help = "The directory contains cell matrix, gene and cell barcodes information. Default is NULL. If 'basePath' is NULL, both 'cellPath' and 'rawPath' should also be specified."),
    optparse::make_option(c("-R", "--rawPath"),
        type = "character",
        default = NULL,
        help = "The directory contains droplet matrix, gene and cell barcodes information. Default is NULL. If 'basePath' is NULL, both 'cellPath' and 'rawPath' should also be specified."),
    optparse::make_option(c("-S", "--splitSample"),
        type = "logical",
        default = TRUE,
        help = "Save SingleCellExperiment object for each sample. Default is FALSE. If TRUE, all samples will be combined and only one combimed SingleCellExperiment object will be saved."),
    optparse::make_option(c("-r", "--rawData"),
        type = "character",
        default = NULL,
        help = "The full path of the RDS file or Matrix file of the raw gene count matrix. This would be provided only when --preproc is SceRDS or CountMatrix."),
    optparse::make_option(c("-c", "--cellData"),
        type = "character",
        default = NULL,
        help = "The full path of the RDS file or Matrix file of the cell count matrix. This would be use only when --preproc is SceRDS or CountMatrix."),
    optparse::make_option(c("-f", "--flatFiles"),
        type = "character",
        default = NULL,
        help = "The full paths of the matrix, barcodes, and features files needed to construct an SCE object from flat files."),
    optparse::make_option(c("-F", "--outputFormat"),
        type = "character",
        default = NULL,
        help = "The output format of this QC pipeline. Currently, it supports SCE, Flatfile, Seurat, AnnData and HTAN."),
    optparse::make_option(c("-y", "--yamlFile"),
        type = "character",
        default = NULL,
        help = "YAML file containing parameters called by singleCellTK QC functions. Please check documentation for details."),
    optparse::make_option(c("-d", "--dataType"),
        type = "character",
        default = "Both",
        help = "Type of data as input. Default is Both, which means taking both droplet and cell matrix as input. If set as 'Droplet', it will only processes droplet data. If set as 'Cell', it will only processes cell data."),
    optparse::make_option(c("-n", "--numCores"),
        type = "integer",
        default = 1,
        help = "Number of cores used to run the pipeline. By default is 1. Parallel computing is enabled if -n is greater than 1."),
    optparse::make_option(c("-D", "--detectCells"),
        type = "logical",
        default = FALSE,
        help = "Detect cells from droplet matrix. Default is FALSE. This argument is only evaluated when -d is 'Droplet'. If set as TRUE, cells will be detected and cell matrixed will be subset from the droplet matrix. Also, quality control will be performed on the detected cell matrix."),
    optparse::make_option(c("-m", "--cellDetectMethod"),
        type = "character",
        default = "EmptyDrops",
        help = "Methods to detect cells. Default is 'EmptyDrops'. Other options could be 'Knee' or 'Inflection'. More information is provided in the documentation. "),
    optparse::make_option(c("-i", "--studyDesign"),
        type = "character",
        default = NULL,
        help = "The txt file containing the desrciption of the study design. Default is NULL. This would be shown at the begining the html report of cell and droplet QC."),
    optparse::make_option(c("-L", "--subTitle"),
        type = "character",
        default = NULL,
        help = "The subtitle used in the cell and droplet QC HTML report. Default is None. The subtitle can contain information of the sample, like sample name, etc. The length of subsitle should be the same as the length of samples, if -S is set as TRUE. if -S is set as FALSE, the length of subtitle should be one or NULL"),
    optparse::make_option(c("-T", "--parallelType"),
        type = "character",
        default = "MulticoreParam",
        help = "Type of clusters used for parallel computing. Default is 'MulticoreParam'. It can be 'MulticoreParam' or 'SnowParam'. This argument will be evaluated only when numCores > 1."),
    optparse::make_option(c("-M", "--detectMitoLevel"),
        type = "logical",
        default = TRUE,
        help = "Detect mitochondrial gene expression level. If TRUE, the pipeline will examinate mito gene expression level automatically without the need of importing user defined gmt file. Default is TRUE"),
    optparse::make_option(c("-E", "--mitoType"),
        type = "character",
        default = "human-ensembl",
        help = "Type of mitochondrial gene set to be used when --detectMitoLevel is set to TRUE. Possible choices are: 'human-ensembl', 'human-symbol', 'human-entrez', 'human-ensemblTranscriptID',
        'mouse-ensembl', 'mouse-symbol', 'mouse-entrez', 'mouse-ensemblTranscriptID'. The first part defines the species and second part defines type of gene ID used as the rownames of the count matrix"),
    optparse::make_option(c("-Q", "--QCReport"),
        type = "logical",
        default = FALSE,
        help = "Generates QC report when the SCTK-QC pipeline is finished. Default if TRUE")
    )
## Define arguments
arguments <- optparse::parse_args(optparse::OptionParser(option_list=option_list), positional_arguments=TRUE)
opt <- arguments$options
process <- unlist(strsplit(opt[["preproc"]], ","))
sample <- unlist(strsplit(opt[["sample"]], ","))
directory <- unlist(strsplit(opt[["directory"]], ","))
gmt <- opt[["gmt"]]
sep <- opt[["delim"]]
split <- opt[["splitSample"]]
basepath <- opt[["basePath"]]
FilterDir <- opt[["cellPath"]]
RawDir <- opt[["rawPath"]]
Reference <- opt[["genome"]]
RawFile <- opt[["rawData"]]
flatFiles <- opt[["flatFiles"]]
FilterFile <- opt[["cellData"]]
yamlFile <- opt[["yamlFile"]]
formats <- opt[["outputFormat"]]
dataType <- opt[["dataType"]]
detectCell <- opt[["detectCells"]]
numCores <- opt[["numCores"]]
parallelType <- opt[["parallelType"]]
cellCalling <- opt[["cellDetectMethod"]]
studyDesign <- opt[["studyDesign"]]
subTitles <- opt[["subTitle"]]
CombinedSamplesName <- opt[["outputPrefix"]]
MitoImport <- opt[["detectMitoLevel"]]
MitoType <- opt[["mitoType"]]
QCReport <- opt[["QCReport"]]

message("The output directory is")
print(directory)

if (!is.null(basepath)) { basepath <- unlist(strsplit(opt[["basePath"]], ",")) }

if (!is.null(FilterDir)) { FilterDir <- unlist(strsplit(opt[["cellPath"]], ",")) }

if (!is.null(RawDir)) { RawDir <- unlist(strsplit(opt[["rawPath"]], ",")) }

if (!is.null(Reference)) { Reference <- unlist(strsplit(opt[["genome"]], ",")) }

if (!is.null(RawFile)) { RawFile <- unlist(strsplit(opt[["rawData"]], ",")) }

if (!is.null(FilterFile)) { FilterFile <- unlist(strsplit(opt[["cellData"]], ",")) }

if (!is.null(flatFiles)) { flatFiles <- unlist(strsplit(opt[["flatFiles"]], ",")) }

if (!is.null(formats)) { formats <- unlist(strsplit(opt[["outputFormat"]], ",")) }

if (!is.null(studyDesign)) { studyDesign <- base::readLines(studyDesign, n=-1) }

if (is.null(subTitles)) {
    subTitles <- paste("SCTK QC HTML report for sample", sample)
} else {
    subTitles <- unlist(strsplit(opt[["subTitles"]], ","))
}

if ("HTAN" %in% formats) {
    if (!("FlatFile" %in% formats)) {
        message("Note: HTAN specified as output without FlatFile. Automatically including FlatFile export.")
        formats <- append(formats, "FlatFile")
    }
}

## Parse parameters for QC algorithms
if (!is.null(yamlFile)) {
    arguments <- c('Params')
    qcParams <- yaml::read_yaml(yamlFile)
    .parseConfig(qcParams, arguments)
} else {
    Params <- list()
}

## checking numCores argument
isWindows <- .Platform$OS.type == "windows"

if (numCores > 1) {
    if (numCores > parallel::detectCores()) {
        warning("numCores is greater than number of cores available. Set numCores as maximum number of cores available.")
    }

    numCores <- min(numCores, parallel::detectCores())
    message(as.character(numCores), " cores are used for parallel computation.")

    if (parallelType == "MulticoreParam") {
        parallelParam <- MulticoreParam(workers = numCores)

        if (isTRUE(isWindows)) {
            warning("'MulticoreParam' is not supported for Windows system. Setting 'parallelType' as 'SnowParam'. ")
            parallelParam <- SnowParam(workers = numCores)
        }

    } else if (parallelType == "SnowParam") {
        parallelParam <- SnowParam(workers = numCores)
    } else {
        stop("'--parallelType' should be 'MulticoreParam' or 'SnowParam'.")
    }

    Params$QCMetrics$BPPARAM <- parallelParam
    Params$emptyDrops$BPPARAM <- parallelParam
    #Params$doubletCells$BPPARAM <- parallelParam
    Params$doubletFinder$nCores <- numCores
}

### checking output formats
if (!all(formats %in% c("SCE", "AnnData", "FlatFile", "HTAN", "Seurat"))) {
    warning("Output format must be 'SCE', 'AnnData', 'HTAN', 'Seurat' or 'FlatFile'. Format ",
         paste(formats[!formats %in% c("SCE", "AnnData", "FlatFile", "HTAN", "Seurat")], collapse = ","),
         " is not supported now. ")
}

formats <- formats[formats %in% c("SCE", "AnnData", "FlatFile", "HTAN", "Seurat")]
message("The output format is [",
        paste(formats, collapse = ","), "]. ")

if (length(formats) == 0) {
    warning("None of the provided format is supported now. Therefore, the output ",
        "will be SCE, AnnData, Seurat, FlatFile and HTAN. ")
    formats <- c("SCE", "AnnData", "FlatFile", "HTAN", "Seurat")
}

if (!(dataType %in% c("Both", "Droplet", "Cell"))) {
    stop("-d / -dataType must be one of the following: 'Both', 'Droplet' or 'Cell'. ")
}

# Checking argument
check <- switch(dataType,
         "cell" = .checkCell(FilterFile, FilterDir, basepath, Reference, process),
         "droplet" = .checkDroplet(RawFile, RawDir, basepath, Reference, process),
         "both" = .checkBoth(RawFile, FilterFile, RawDir, FilterDir, basepath, Reference, process))

if (!cellCalling %in% c("Knee", "Inflection", "EmptyDrops")) {
    stop("The --cellDetectMethod must be 'Knee', 'Inflection' or 'Emptydrops'.")
}

## Prepare for QC
dropletSCE_list <- list()
cellSCE_list <- list()
geneSetCollection <- NULL
if (!is.null(gmt)) {
    geneSetCollection <- GSEABase::getGmt(gmt, sep = sep)
}


level3Meta <- list()
level4Meta <- list()

for(i in seq_along(process)) {

    # pop elements from FlatFile input list
    if ("FlatFile" %in% process[i]) {
        if (dataType %in% c("Droplet", "Cell")) {
            flatFileInput <- flatFiles[c(1, 2, 3)]
            flatFiles <- flatFiles[-c(1, 2, 3)]
        }
        else {
            flatFileInput <- flatFiles[c(1, 2, 3, 4, 5, 6)]
            flatFiles <- flatFiles[-c(1, 2, 3, 4, 5, 6)]
        }
    }

    preproc <- process[i]
    samplename <- sample[i]
    path <- basepath[i]
    raw <- RawDir[i]
    fil <- FilterDir[i]
    ref <- Reference[i]
    rawFile <- RawFile[i]
    filFile <- FilterFile[i]
    subTitle <- subTitles[i]
    INPUT <- qcInputProcess(preproc,
                            samplename,
                            path,
                            raw,
                            fil,
                            ref,
                            rawFile,
                            filFile,
                            flatFileInput,
                            dataType)
    dropletSCE <- INPUT[[1]]
    cellSCE <- INPUT[[2]]

    mitoInfo <- .importMito(MitoImport = MitoImport, MitoType = MitoType)

    cellQCAlgos <- c("QCMetrics", "scDblFinder", "cxds", "bcds", "scrublet", "doubletFinder",
    "cxds_bcds_hybrid", "decontX", "decontX_bg", "soupX", "soupX_bg") #scrublet
    

    # Checking to see if the input is a file instead of a directory, for RDS and H5AD reading
    # also check to see if the sample name is specified, and if so, set it
    if (!is.null(rawFile) || !is.null(filFile)) {
        if (!dir.exists(path)) {
            if (is.null(samplename)) {
                stop("In Seurat/SCE/AnnData input mode, a sample name must be provided using the -s/--sample flag.")
            } else {
                if (dataType == "Cell" || dataType == "Both") {
                    if (is.null(filFile)) {
                        stop("You must provide a file with cell counts.")
                    }
                }
                if (dataType == "Droplet" || dataType == "Both") {
                    if (is.null(rawFile)) {
                        stop("You must provide a file with raw counts.")
                    }
                }
            samplesname <- sample
            }
        }
    }

    if (dataType == "Cell") {
        if (is.null(cellSCE) && (preproc %in% c("BUStools", "SEQC"))) {
            dropletSCE <- runDropletQC(inSCE = dropletSCE, paramsList=Params)
            ix <- !is.na(dropletSCE$dropletUtils_emptyDrops_fdr) & (dropletSCE$dropletUtils_emptyDrops_fdr < 0.01)
            cellSCE <- dropletSCE[,ix]
        }

        message(paste0(date(), " .. Running cell QC"))
        cellSCE <- runCellQC(inSCE = cellSCE, geneSetCollection = geneSetCollection, 
            paramsList=Params, algorithms = cellQCAlgos, background = dropletSCE,
            mitoRef = mitoInfo[['reference']], mitoIDType = mitoInfo[['id']],
            mitoGeneLocation = "rownames")
    }

    if (dataType == "Droplet") {
        message(paste0(date(), " .. Running droplet QC"))
        dropletSCE <- runDropletQC(inSCE = dropletSCE, paramsList=Params)
        if (isTRUE(detectCell)) {
            if (cellCalling == "EmptyDrops") {
                ix <- !is.na(dropletSCE$dropletUtils_emptyDrops_fdr) & dropletSCE$dropletUtils_emptyDrops_fdr < 0.01
            } else if (cellCalling == "Knee") {
                ix <- dropletSCE$dropletUtils_BarcodeRank_Knee == 1
            } else {
                ix <- dropletSCE$dropletUtils_BarcodeRank_Inflection == 1
            }
            cellSCE <- dropletSCE[,ix]
            message(paste0(date(), " .. Running cell QC"))
            cellSCE <- runCellQC(inSCE = cellSCE, geneSetCollection = geneSetCollection, 
                paramsList=Params, algorithms = cellQCAlgos, background = dropletSCE,
                mitoRef = mitoInfo[['reference']], mitoIDType = mitoInfo[['id']],
                mitoGeneLocation = "rownames")
        }
    }

    if (dataType == "Both") {
        if (!is.null(dropletSCE)) {
            message(paste0(date(), " .. Running droplet QC"))
            dropletSCE <- runDropletQC(inSCE = dropletSCE, paramsList=Params)

            if (is.null(cellSCE)) {
                if (cellCalling == "EmptyDrops") {
                    ix <- !is.na(dropletSCE$dropletUtils_emptyDrops_fdr) & dropletSCE$dropletUtils_emptyDrops_fdr < 0.01
                } else if (cellCalling == "Knee") {
                    ix <- dropletSCE$dropletUtils_BarcodeRank_Knee == 1
                } else {
                    ix <- dropletSCE$dropletUtils_BarcodeRank_Inflection == 1
                }
                cellSCE <- dropletSCE[,ix]
            } else {
                ### add indicator which barcodes are in the user-provided cellSCE
                cbInCellMat <- colnames(dropletSCE) %in% colnames(cellSCE)
                SummarizedExperiment::colData(dropletSCE)$barcodeInCellMatrix <- cbInCellMat
            }
        }

        if (!is.null(cellSCE)) {
            message(paste0(date(), " .. Running cell QC"))

            cellSCE <- runCellQC(inSCE = cellSCE, geneSetCollection = geneSetCollection, 
                paramsList=Params, algorithms = cellQCAlgos, background = dropletSCE,
                mitoRef = mitoInfo[['reference']], mitoIDType = mitoInfo[['id']],
                mitoGeneLocation = "rownames")
        }
    }
    ## merge colData of dropletSCE and FilteredSCE
    mergedDropletSCE <- NULL
    mergedFilteredSCE <- NULL

    if (dataType == "Both") {
        mergedDropletSCE <- mergeSCEColData(dropletSCE, cellSCE)
        mergedFilteredSCE <- mergeSCEColData(cellSCE, dropletSCE)
        #mergedDropletSCE <- dropletSCE
        #mergedCellSCE <- cellSCE
    }

    if (dataType == "Cell") {
        mergedFilteredSCE <- cellSCE
    }

    if (dataType == "Droplet") {
        if (isTRUE(detectCell)) {
            mergedDropletSCE <- mergeSCEColData(dropletSCE, cellSCE)
            mergedFilteredSCE <- mergeSCEColData(cellSCE, dropletSCE)
        } else {
            mergedDropletSCE <- dropletSCE
        }
    }


    if (isTRUE(split)) {
        ### assign sample to every runBarcodeRanksMetaOutput metadata slot
        if (!is.null(mergedDropletSCE)) {
            names(metadata(mergedDropletSCE)$sctk$runBarcodeRankDrops) <- samplename
        }

        if (!is.null(mergedFilteredSCE)) {
            for (name in names(metadata(mergedFilteredSCE))) {
                if (!name %in% c("assayType", "sctk")) {
                    metadata(mergedFilteredSCE)[[name]] <- list(metadata(mergedFilteredSCE)[[name]])
                    names(metadata(mergedFilteredSCE)[[name]]) <- samplename
                }
            }
        }

        if ((dataType == "Both") || (dataType == "Droplet" && isTRUE(detectCell))) {
            exportSCE(inSCE = mergedDropletSCE, samplename = samplename, directory = directory, type = "Droplets", format=formats)
            exportSCE(inSCE = mergedFilteredSCE, samplename = samplename, directory = directory, type = "Cells", format=formats)


            ## Get parameters of QC functions
            getSceParams(inSCE = mergedFilteredSCE, directory = directory,
                         samplename = samplename, writeYAML = TRUE,
                         skip = c("runScrublet","runDecontX","runBarcodeRanksMetaOutput","genesets","runSoupX"))

            ## generate meta data
            if ("FlatFile" %in% formats) {
                if ("HTAN" %in% formats) {
                    meta <- generateHTANMeta(dropletSCE = mergedDropletSCE, cellSCE = mergedFilteredSCE, samplename = samplename,
                                        dir = directory, htan_biospecimen_id=samplename, dataType = "Both")
                } else {
                    meta <- generateMeta(dropletSCE = mergedDropletSCE, cellSCE = mergedFilteredSCE, samplename = samplename,
                                        dir = directory, HTAN=FALSE, dataType = "Both")
                }

                level3Meta[[i]] <- meta[[1]]
                level4Meta[[i]] <- meta[[2]]

            } else {
                warning("'FlatFile' is not in output format. Skip exporting the manifest file.")
            }

            ## generate html report
            if (QCReport) {
                reportDropletQC(inSCE = mergedDropletSCE, output_dir = directory, output_file = paste0("SCTK_", samplename,'_dropletQC.html'), subTitle = subTitle, studyDesign = studyDesign)
                reportCellQC(inSCE = mergedFilteredSCE, output_dir = directory, output_file = paste0("SCTK_", samplename,'_cellQC.html'), subTitle = subTitle, studyDesign = studyDesign)                
            }

            ## generate QC metrics table for mergedFilteredSCE
            mergedFilteredSCE <- sampleSummaryStats(mergedFilteredSCE, simple=FALSE, sample = colData(mergedFilteredSCE)$sample) #colData(cellSCE)$Study_ID
            QCsummary <- getSampleSummaryStatsTable(mergedFilteredSCE, statsName = "qc_table")
            write.csv(QCsummary, file.path(directory,
                                           samplename,
                                           paste0("SCTK_", samplename,'_cellQC_summary.csv')))
        }

        if ((dataType == "Droplet") && (!isTRUE(detectCell))) {
            exportSCE(inSCE = mergedDropletSCE, samplename = samplename, directory = directory, type = "Droplets", format=formats)
            if ("FlatFile" %in% formats) {
                if ("HTAN" %in% formats) {
                    meta <- generateHTANMeta(dropletSCE = mergedDropletSCE, cellSCE = NULL, samplename = samplename,
                                        dir = directory, htan_biospecimen_id=samplename, dataType = "Droplet")
                } else {
                    meta <- generateMeta(dropletSCE = mergedDropletSCE, cellSCE = NULL, samplename = samplename,
                                        dir = directory, HTAN=FALSE, dataType = "Droplet")
                }

                level3Meta[[i]] <- meta[[1]]
                level4Meta[[i]] <- meta[[2]]

            } else {
                warning("'FlatFile' is not in output format. Skip exporting the manifest file.")
            }

            if (QCReport) {
                reportDropletQC(inSCE = mergedDropletSCE, output_dir = directory, output_file = paste0("SCTK_", samplename,'_dropletQC.html'), subTitle = subTitle, studyDesign = studyDesign)
            }
        }

        if (dataType == "Cell") {
            exportSCE(inSCE = mergedFilteredSCE, samplename = samplename, directory = directory, type = "Cells", format=formats)
            if ("FlatFile" %in% formats) {
                if ("HTAN" %in% formats) {
                    .check_QC(directory = directory, samplename = samplename)
                    meta <- generateHTANMeta(dropletSCE = NULL, cellSCE = mergedFilteredSCE, samplename = samplename,
                                        dir = directory, htan_biospecimen_id=samplename, dataType = "Cell")
                } else {
                    meta <- generateMeta(dropletSCE = NULL, cellSCE = mergedFilteredSCE, samplename = samplename,
                                        dir = directory, HTAN=FALSE, dataType = "Cell")
                }

                level3Meta[[i]] <- meta[[1]]
                level4Meta[[i]] <- meta[[2]]

            } else {
                warning("'FlatFile' is not in output format. Skip exporting the manifest file.")
            }

            if (QCReport) {
                reportCellQC(inSCE = mergedFilteredSCE, output_dir = directory, output_file = paste0("SCTK_", samplename,'_cellQC.html'), subTitle = subTitle, studyDesign = studyDesign)
            }
            getSceParams(inSCE = mergedFilteredSCE, directory = directory,
                         samplename = samplename, writeYAML = TRUE,
                         skip = c("runScrublet","runDecontX","runBarcodeRanksMetaOutput","genesets","runSoupX"))

            mergedFilteredSCE <- sampleSummaryStats(mergedFilteredSCE, simple=FALSE, sample = colData(mergedFilteredSCE)$sample) #colData(cellSCE)$Study_ID
            QCsummary <- getSampleSummaryStatsTable(mergedFilteredSCE, statsName = "qc_table")
            write.csv(QCsummary, file.path(directory,
                                           samplename,
                                           paste0("SCTK_", samplename,'_cellQC_summary.csv')))
        }

    }
    dropletSCE_list[[samplename]] <- mergedDropletSCE
    cellSCE_list[[samplename]] <- mergedFilteredSCE
}

if (!isTRUE(split)) {

    if (length(sample) > 1) {
        samplename <- CombinedSamplesName #paste(sample, collapse="-")
        subTitle <- paste("SCTK QC HTML report for sample", samplename)
    }

    if ((dataType == "Both") || (dataType == "Droplet" && isTRUE(detectCell))) {

        by.r <- NULL
        by.c <- Reduce(intersect, lapply(dropletSCE_list, function(x) { colnames(colData(x))}))
        dropletSCE <- combineSCE(dropletSCE_list, by.r, by.c, combined = TRUE)
        names(metadata(dropletSCE)$sctk$runBarcodeRankDrops) <- sample  

        if (length(sample) == 1) {
            ### one sample. Treat it like split == TRUE
            cellSCE <- cellSCE_list[[1]]
            for (name in names(metadata(cellSCE))) {
              if (!name %in% c("assayType", "sctk")) {
                metadata(mergedFilteredSCE)[[name]] <- list(metadata(mergedFilteredSCE)[[name]])
                names(metadata(mergedFilteredSCE)[[name]]) <- samplename
              }
            }
        } else {
            by.c <- Reduce(intersect, lapply(cellSCE_list, function(x) { colnames(colData(x))}))
            cellSCE <- combineSCE(cellSCE_list, by.r, by.c, combined = TRUE)
            for (name in names(metadata(cellSCE))) {
                if (!name %in% c("assayType", "sctk")) {
                    names(metadata(cellSCE)[[name]]) <- sample
                }
            }
        }

        exportSCE(inSCE = dropletSCE, samplename = samplename, directory = directory, type = "Droplets", format=formats)
        exportSCE(inSCE = cellSCE, samplename = samplename, directory = directory, type = "Cells", format=formats)

        ## html report
        if (QCReport) {
            reportDropletQC(inSCE = dropletSCE, output_dir = directory, output_file = paste0("SCTK_", samplename,'_dropletQC.html'), subTitle = subTitle, studyDesign = studyDesign)
            reportCellQC(inSCE = cellSCE, output_dir = directory, output_file = paste0("SCTK_", samplename,'_cellQC.html'), subTitle = subTitle, studyDesign = studyDesign)
        }
        ## Get parameters of QC functions
        getSceParams(inSCE = cellSCE, directory = directory, samplename = samplename, writeYAML = TRUE)

        ## generate meta data
        # generate HTAN level3/level4 output
        if ("FlatFile" %in% formats) {
            if ("HTAN" %in% formats) {
                meta <- generateHTANMeta(dropletSCE = dropletSCE, cellSCE = cellSCE, samplename = samplename,
                                    dir = directory, htan_biospecimen_id=samplename, dataType = "Both")
            } else {
                meta <- generateMeta(dropletSCE = dropletSCE, cellSCE = cellSCE, samplename = samplename,
                                    dir = directory, HTAN=FALSE, dataType = "Both")
            }

            level3Meta <- list(meta[[1]])
            level4Meta <- list(meta[[2]])

        } else {
            warning("'FlatFile' is not in output format. Skip exporting the manifest file.")
        }

        ## generate QC summary
        cellSCE <- sampleSummaryStats(cellSCE, simple=FALSE, sample = colData(cellSCE)$sample)
        QCsummary <- getSampleSummaryStatsTable(cellSCE, statsName = "qc_table")
        write.csv(QCsummary, file.path(directory,
                                       samplename,
                                       paste0("SCTK_", samplename,'_cellQC_summary.csv')))
    }

    if (dataType == "Cell") {

        if (length(sample) == 1) {
            ### one sample. Treat it like split == TRUE
            cellSCE <- cellSCE_list[[1]]
            for (name in names(metadata(cellSCE))) {
              if (!name %in% c("assayType", "sctk")) {
                  metadata(cellSCE)[[name]] <- list(metadata(cellSCE)[[name]])
                  names(metadata(cellSCE)[[name]]) <- samplename
              }
            }
        } else {
            by.r <- NULL
            by.c <- Reduce(intersect, lapply(cellSCE_list, function(x) { colnames(colData(x))}))
            cellSCE <- combineSCE(cellSCE_list, by.r, by.c, combined = TRUE)
            for (name in names(metadata(cellSCE))) {
                if (!name %in% c("assayType", "sctk")) { ### not important and hard to force name. Skipped
                    names(metadata(cellSCE)[[name]]) <- sample
                }
            }
        }

        exportSCE(inSCE = cellSCE, samplename = samplename, directory = directory, type = "Cells", format=formats)
        # generate HTAN level3/level4 output
        if ("FlatFile" %in% formats) {
            if ("HTAN" %in% formats) {
                meta <- generateHTANMeta(dropletSCE = NULL, cellSCE = cellSCE, samplename = samplename,
                                    dir = directory, htan_biospecimen_id=samplename, dataType = "Cell")
            } else {
                meta <- generateMeta(dropletSCE = NULL, cellSCE = cellSCE, samplename = samplename,
                                    dir = directory, HTAN=FALSE, dataType = "Cell")
            }

            level3Meta[[i]] <- meta[[1]]
            level4Meta[[i]] <- meta[[2]]

        } else {
            warning("'FlatFile' is not in output format. Skip exporting the manifest file.")
        }
        if (QCReport) {
            reportCellQC(inSCE = cellSCE, output_dir = directory, output_file = paste0("SCTK_", samplename,'_cellQC.html'), subTitle = subTitle, studyDesign = studyDesign)
        }
        getSceParams(inSCE = cellSCE, directory = directory, samplename = samplename, writeYAML = TRUE)

        cellSCE <- sampleSummaryStats(cellSCE, simple=FALSE, sample = colData(cellSCE)$sample)
        QCsummary <- getSampleSummaryStatsTable(cellSCE, statsName = "qc_table")
        write.csv(QCsummary, file.path(directory,
                                       samplename,
                                       paste0("SCTK_", samplename,'_cellQC_summary.csv')))
    }

    if ((dataType == "Droplet") && (!isTRUE(detectCell))) {
        by.r <- NULL
        by.c <- Reduce(intersect, lapply(dropletSCE_list, function(x) { colnames(colData(x))}))
        dropletSCE <- combineSCE(dropletSCE_list, by.r, by.c, combined = TRUE)
        names(metadata(dropletSCE)$sctk$runBarcodeRankDrops) <- sample

        exportSCE(inSCE = dropletSCE, samplename = samplename, directory = directory, type = "Droplets", format=formats)
        # generate HTAN level3/level4 output
        if ("FlatFile" %in% formats) {
            if ("HTAN" %in% formats) {
                meta <- generateHTANMeta(dropletSCE = dropletSCE, cellSCE = NULL, samplename = samplename,
                                    dir = directory, htan_biospecimen_id=samplename, dataType = "Droplet")
            } else {
                meta <- generateMeta(dropletSCE = dropletSCE, cellSCE = NULL, samplename = samplename,
                                    dir = directory, HTAN=FALSE, dataType = "Droplet")
            }

            level3Meta[[i]] <- meta[[1]]
            level4Meta[[i]] <- meta[[2]]

        } else {
            warning("'FlatFile' is not in output format. Skip exporting the manifest file.")
        }
        if (QCReport) {
            reportDropletQC(inSCE = dropletSCE, output_dir = directory, output_file = paste0("SCTK_", samplename,'_dropletQC.html'), subTitle = subTitle, studyDesign = studyDesign)
        }
    }
}

if (("FlatFile" %in% formats)) {
    HTANLevel3 <- do.call(base::rbind, level3Meta)
    HTANLevel4 <- do.call(base::rbind, level4Meta)
    write.csv(HTANLevel3, file = file.path(directory, "level3Meta.csv"))
    if ( !(dataType == "Droplet" && !isTRUE(detectCell)) ) {
        write.csv(HTANLevel4, file = file.path(directory, "level4Meta.csv"))
    }
}

# output session info
sessionInfo()