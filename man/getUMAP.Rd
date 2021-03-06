% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/getUMAP.R
\name{getUMAP}
\alias{getUMAP}
\title{Uniform Manifold Approximation and Projection(UMAP) algorithm for
dimension reduction.}
\usage{
getUMAP(
  inSCE,
  useAssay = "counts",
  sample = NULL,
  reducedDimName = "UMAP",
  logNorm = TRUE,
  nNeighbors = 30,
  nIterations = 200,
  alpha = 1,
  minDist = 0.01,
  spread = 1,
  pca = TRUE,
  initialDims = 50
)
}
\arguments{
\item{inSCE}{Input \linkS4class{SingleCellExperiment} object.}

\item{useAssay}{Indicate which assay to use. The default is "counts".}

\item{sample}{Character vector. Indicates which sample each cell belongs to.}

\item{reducedDimName}{a name to store the results of the dimension reduction
coordinates obtained from this method. This is stored in the SingleCellExperiment
object in the reducedDims slot. Default "UMAP".}

\item{logNorm}{Whether the counts will need to be log-normalized prior to
generating the UMAP via scater::logNormCounts. Default TRUE.}

\item{nNeighbors}{The size of local neighborhood used for
manifold approximation. Larger values result in more global
views of the manifold, while smaller values result in more
local data being preserved. Default 30.
 See `?uwot::umap` for more information.}

\item{nIterations}{number of iterations performed during layout optimization.
Default is 200.}

\item{alpha}{initial value of "learning rate" of layout optimization. Default is 1.}

\item{minDist}{The effective minimum distance between embedded points.
Smaller values will result in a more clustered/clumped
embedding where nearby points on the manifold are drawn
closer together, while larger values will result on a more
even dispersal of points. Default 0.01.
See `?uwot::umap` for more information.}

\item{spread}{The effective scale of embedded points. In combination with
‘min_dist’, this determines how clustered/clumped the
embedded points are. Default 1.
See `?uwot::umap` for more information.}

\item{pca}{Logical. Whether to perform dimensionality reduction with PCA
before UMAP.}

\item{initialDims}{Number of dimensions from PCA to use as
input in UMAP. Default 50.}
}
\value{
A \linkS4class{SingleCellExperiment} object with the reduced
dimensions updated under reducedDimName specified.
}
\description{
Uniform Manifold Approximation and Projection(UMAP) algorithm for
dimension reduction.
}
\examples{
data(scExample, package = "singleCellTK")
sce <- sce[, colData(sce)$type != 'EmptyDroplet']
umap_res <- getUMAP(inSCE = sce, useAssay = "counts",
                    reducedDimName = "UMAP", logNorm = TRUE,
                    nNeighbors = 30, alpha = 1,
                    nIterations = 200, spread = 1, pca = TRUE,
                    initialDims = 50)
reducedDims(umap_res)
}
