% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/miscFunctions.R
\name{summarizeSCE}
\alias{summarizeSCE}
\title{Summarize an assay in a \linkS4class{SingleCellExperiment}}
\usage{
summarizeSCE(inSCE, useAssay = NULL, sampleVariableName = NULL)
}
\arguments{
\item{inSCE}{Input SingleCellExperiment object.}

\item{useAssay}{Indicate which assay to summarize. If \code{NULL}, then the first
assay in \code{inSCE} will be used. Default \code{NULL}.}

\item{sampleVariableName}{Variable name in \code{colData} denoting which
sample each cell belongs to. If \code{NULL}, all cells will be assumed
to come from the same sample. Default \code{"sample"}.}
}
\value{
A data.frame object of summary metrics.
}
\description{
Creates a table of summary metrics from an input
\linkS4class{SingleCellExperiment}
}
\examples{
data("mouseBrainSubsetSCE")
summarizeSCE(mouseBrainSubsetSCE, sample = NULL)
}
