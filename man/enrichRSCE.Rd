% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/enrichRSCE.R
\name{enrichRSCE}
\alias{enrichRSCE}
\title{enrichR
Given a list of genes this function runs the enrichR() to perform Gene
enrichment}
\usage{
enrichRSCE(inSCE, glist, db = NULL)
}
\arguments{
\item{inSCE}{Input \linkS4class{SingleCellExperiment} object.}

\item{glist}{selected genes for enrichment analysis using enrichR(). Required}

\item{db}{selected database name from the enrichR database list. if NULL then
enrichR will be run on all the available databases on the enrichR database.}
}
\value{
enrichRSCE(): returns a data.frame of enrichment terms overlapping in
the respective databases along with p-values, z-scores etc.,
}
\description{
enrichR
Given a list of genes this function runs the enrichR() to perform Gene
enrichment
}
\examples{
\dontrun{
enrichRSCE(mouseBrainSubsetSCE, "Cmtm5", "GO_Cellular_Component_2017")
}
}
