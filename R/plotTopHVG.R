#' Plot highly variable genes
#'
#' @param inSCE Input \code{SingleCellExperiment} object containing the
#' computations.
#' @param method Select either \code{"vst"}, \code{"mean.var.plot"},
#' \code{"dispersion"} or \code{"modelGeneVar"}.
#' @param useFeatureSubset A character string for the \code{rowData} variable
#' name to store a logical index of selected features. Default \code{NULL}. See
#' details.
#' @param hvgNumber Specify the number of top genes to highlight in red. Default
#' \code{2000}. See details.
#' @param labelsCount Specify the number of data points/genes to label. Should
#' be less than \code{hvgNumber}. Default \code{10}. See details.
#' @param featureDisplay A character string for the \code{rowData} variable name
#' to indicate what type of feature ID should be displayed. If set by
#' \code{\link{setSCTKDisplayRow}}, will by default use it. If \code{NULL}, will
#' use \code{rownames(inSCE)}.
#' @param labelSize Numeric, size of the text label on top HVGs. Default 
#' \code{2}.
#' @param dotSize Numeric, size of the dots of the features. Default \code{2}.
#' @param textSize Numeric, size of the text of axis title, axis label, etc.
#' Default \code{12}.
#' @return ggplot of HVG metrics and top HVG labels
#' @details When \code{hvgNumber = NULL} and \code{useFeature = NULL}, only plot
#' the mean VS variance/dispersion scatter plot. When only \code{hvgNumber} set,
#' label the top \code{hvgNumber} HVGs ranked by the metrics calculated by
#' \code{method}. When \code{useFeatureSubset} set, label the features in
#' the subset on the scatter plot created with \code{method} and ignore
#' \code{hvgNumber}.
#' @export
#' @examples
#' data("mouseBrainSubsetSCE", package = "singleCellTK")
#' mouseBrainSubsetSCE <- runModelGeneVar(mouseBrainSubsetSCE)
#' plotTopHVG(mouseBrainSubsetSCE, method = "modelGeneVar")
#' @seealso \code{\link{runFeatureSelection}}, \code{\link{runSeuratFindHVG}},
#' \code{\link{runModelGeneVar}}, \code{\link{getTopHVG}}
#' @importFrom SummarizedExperiment rowData
#' @importFrom S4Vectors metadata
plotTopHVG <- function(inSCE,
                       method = "modelGeneVar",
                       hvgNumber = 2000,
                       useFeatureSubset = NULL,
                       labelsCount = 10,
                       featureDisplay = metadata(inSCE)$featureDisplay,
                       labelSize = 2, dotSize = 2, textSize = 12
                       )
{
  method <- match.arg(method, choices = c("vst", "mean.var.plot", "dispersion",
                                          "modelGeneVar"))
  metric <- .dfFromHVGMetric(inSCE, method)
  yLabelChoice <- list(vst = "Standardized Variance",
                       mean.var.plot = "Dispersion", dispersion = "Dispersion",
                       modelGeneVar = "Variance")
  x <- metric[,"mean"]
  y <- metric[,"v_plot"]
  if (method == "vst") x <- log(x)
  yAxisLabel <- yLabelChoice[[method]]
  hvgList <- character()
  if (!is.null(useFeatureSubset)) {
    hvgList <- .parseUseFeatureSubset(inSCE, useFeatureSubset,
                                      returnType = "character")
    hvgNumber <- length(hvgList)
  } else if (!is.null(hvgNumber)) {
    hvgList <- getTopHVG(inSCE = inSCE, method = method, hvgNumber = hvgNumber,
                         featureDisplay = NULL, useFeatureSubset = NULL)
  }
  if (is.null(hvgNumber) || hvgNumber == 0) {
    redIdx <- logical()
  } else {
    redIdx <- rownames(inSCE) %in% hvgList[seq(hvgNumber)]
  }
  if (is.null(hvgNumber) || labelsCount == 0) {
    labelIdx <- logical()
  } else {
    labelIdx <- rownames(inSCE) %in% hvgList[seq(labelsCount)]
  }
  if (!is.null(featureDisplay)) {
    labelTxt <- rowData(inSCE)[[featureDisplay]][labelIdx]
  } else {
    labelTxt <- rownames(inSCE)[labelIdx]
  }
  vfplot <- ggplot2::ggplot() +
    ggplot2::geom_point(ggplot2::aes(x = x, y = y), size = dotSize) +
    ggplot2::geom_point(ggplot2::aes(x = subset(x, redIdx),
                                     y = subset(y, redIdx)),
                        colour = "red", size = dotSize) +
    ggplot2::geom_label(ggplot2::aes(x = subset(x, labelIdx),
                                     y = subset(y, labelIdx),
                                     label = labelTxt),
                        colour = "red",
                        size = labelSize) +
    ggplot2::labs(x = "Mean", y = yAxisLabel)
  vfplot <- .ggSCTKTheme(vfplot) +
      ggplot2::theme(text = ggplot2::element_text(size = textSize))
  return(vfplot)
}
