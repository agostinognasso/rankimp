#' Select variables with a rank guarantee
#'
#' Keeps the variables whose rank confidence set lies entirely above
#' `threshold`. Selecting on the point estimate of the rank would ignore the
#' fact that the ranking is estimated; selecting on the confidence set makes
#' the claim "this variable really is among the most important" testable.
#'
#' Not implemented yet: scheduled for phase F3.
#'
#' @param cb A `rank_confsets` object.
#' @param threshold Rank above which a variable is retained.
#' @return A character vector of selected variable names.
#' @export
rank_select <- function(cb, threshold = 10L) {
  not_implemented("rank_select", "F3")
}
