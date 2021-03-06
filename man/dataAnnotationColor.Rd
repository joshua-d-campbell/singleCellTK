% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plotSCEHeatmap.R
\name{dataAnnotationColor}
\alias{dataAnnotationColor}
\title{Generate distinct colors for all categorical col/rowData entries.
Character columns will be considered as well as all-integer columns. Any
column with all-distinct values will be excluded.}
\usage{
dataAnnotationColor(inSCE, axis = NULL, colorGen = distinctColors)
}
\arguments{
\item{inSCE}{\linkS4class{SingleCellExperiment} inherited object.}

\item{axis}{Choose from \code{"col"} or \code{"row"}.}

\item{colorGen}{A function that generates color code vector by giving an
integer for the number of colors. Alternatively,
\code{\link[grDevices]{rainbow}}. Default \code{\link{distinctColors}}.}
}
\value{
A \code{list} object containing distinct colors mapped to all
possible categorical entries in \code{rowData(inSCE)} or
\code{colData(inSCE)}.
}
\description{
Generate distinct colors for all categorical col/rowData entries.
Character columns will be considered as well as all-integer columns. Any
column with all-distinct values will be excluded.
}
\author{
Yichen Wang
}
