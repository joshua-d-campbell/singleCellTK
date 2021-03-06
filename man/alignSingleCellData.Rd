% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/alignSingleCellData.R
\name{alignSingleCellData}
\alias{alignSingleCellData}
\title{Align Single Cell RNA-Seq Data and Create a SingleCellExperiment Object}
\usage{
alignSingleCellData(
  inputfile1,
  inputfile2 = NULL,
  indexPath,
  gtfAnnotation,
  outputDir = NULL,
  sampleAnnotations = NULL,
  featureAnnotations = NULL,
  threads = 1,
  saveBam = FALSE,
  saveCountFiles = FALSE,
  isPairedEnd = FALSE
)
}
\arguments{
\item{inputfile1}{An input file or list of files. Files can be fastq,
fastq.gz, or bam, but must all be of the same type. Sample names will be the
full file name, without _1.fastq.gz, .fastq.gz, _1.fastq, .fastq or .bam
endings.}

\item{inputfile2}{If fastq files are provided in input list, a list of
corresponding paired fastq files, if applicable.}

\item{indexPath}{Path to the Rsubread genome index.}

\item{gtfAnnotation}{Path to the GTF gene annotation to use. This must
correspond to the genome specified in indexPath.}

\item{outputDir}{If saveBam or saveCountFiles is TRUE, specify a
directory in which to save the output files.}

\item{sampleAnnotations}{A data.frame of sample annotations, with samples
as rows and annotations in columns. The sample names must be identical to
and in the same order as the list of files in inputfile1. Alignment
statistics will be added to the annotation data frame.}

\item{featureAnnotations}{An optional data.frame of probe annotations, with
probes as rows and probe annotations in columns.}

\item{threads}{Number of threads to use during alignment. The default is 1.}

\item{saveBam}{If TRUE, bam alignment files will be saved in the outputDir.
The default is FALSE.}

\item{saveCountFiles}{If TRUE, per sample gene count files will be saved in
the outputDir. The default is FALSE.}

\item{isPairedEnd}{If input files are .bam, indicate whether the input bam
files are paired end.}
}
\value{
Object to import into the shiny app.
}
\description{
Align Single Cell RNA-Seq Data and Create a SingleCellExperiment Object
}
\examples{
\dontrun{
singlecellobject <- alignSingleCellData(
  inputfile1 = c("/path/to/sample1_1.fastq.gz",
                 "/path/to/sample2_1.fastq.gz"),
  inputfile2 = c("/path/to/sample1_2.fastq.gz",
                 "/path/to/sample2_2.fastq.gz"),
  indexPath = "/path/to/genome/index",
  gtfAnnotation = "/path/to/gene/annotations.gtf",
  sampleAnnotations = sample.annotation.df,
  threads=4)}
}
