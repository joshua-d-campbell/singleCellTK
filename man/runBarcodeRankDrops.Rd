% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/dropletUtils_barcodeRank.R
\name{runBarcodeRankDrops}
\alias{runBarcodeRankDrops}
\title{Identify empty droplets using \link[DropletUtils]{barcodeRanks}.}
\usage{
runBarcodeRankDrops(
  inSCE,
  sample = NULL,
  useAssay = "counts",
  lower = 100,
  fitBounds = NULL,
  df = 20
)
}
\arguments{
\item{inSCE}{A \link[SingleCellExperiment]{SingleCellExperiment} object.
Must contain a raw counts matrix before empty droplets have been removed.}

\item{sample}{Character vector. Indicates which sample each cell belongs to
\link[DropletUtils]{emptyDrops} will be run on cells from each sample separately.
If NULL, then all cells will be processed together. Default \code{NULL}.}

\item{useAssay}{A string specifying which assay in the SCE to use.}

\item{lower}{See \link[DropletUtils]{emptyDrops} for more information. Default \code{100}.}

\item{fitBounds}{See \link[DropletUtils]{emptyDrops} for more information. Default \code{NULL}.}

\item{df}{See \link[DropletUtils]{emptyDrops} for more information. Default \code{20}.}
}
\value{
A \link[SingleCellExperiment]{SingleCellExperiment} object with the
 \link[DropletUtils]{barcodeRanks} output table appended to the
 \link[SummarizedExperiment]{colData} slot. The columns include
 \emph{dropletUtils_BarcodeRank_Knee} and \emph{dropletUtils_BarcodeRank_Knee}
 Please refer to the documentation of \link[DropletUtils]{barcodeRanks} for
 details.
}
\description{
Run \link[DropletUtils]{barcodeRanks} on a count matrix
 provided in a \link[SingleCellExperiment]{SingleCellExperiment} object.
 Distinguish between droplets containing cells and ambient RNA in a
 droplet-based single-cell RNA sequencing experiment.
}
\examples{
# The following unfiltered PBMC_1k_v3 data were downloaded from
# https://support.10xgenomics.com/single-cell-gene-expression/datasets/3.0.0
# /pbmc_1k_v3
# Only the top 10 cells with most counts and the last 10 cells with non-zero
# counts are included in this example.
# This example only serves as an proof of concept and a tutoriol on how to
# run the function. The results should not be
# used for drawing scientific conclusions.
data(scExample, package = "singleCellTK")
sce <- runBarcodeRankDrops(inSCE = sce)
}
