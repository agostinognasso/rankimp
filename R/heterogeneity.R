#' Do the judges agree?
#'
#' When the global agreement with the consensus is low, reporting the
#' consensus alone hides the disagreement instead of describing it. Clustering
#' the judges in the space of the Kemeny-Snell distance recovers the
#' sub-populations of methods that see the model differently — marginal
#' against conditional importance measures typically separate here whenever
#' the predictors are correlated, and that separation is itself the finding.
#'
#' Not implemented yet: scheduled for phase F4.
#'
#' @param judges A `judges` object or a ranking matrix.
#' @param k Number of clusters, or `NULL` to select it automatically.
#' @return An object of class `judge_clusters`.
#' @export
judge_clusters <- function(judges, k = NULL) {
  not_implemented("judge_clusters", "F4")
}

#' Agreement of each judge with the consensus
#'
#' Not implemented yet: scheduled for phase F4.
#'
#' @param cr A `consensus_rank` object.
#' @return A tibble with one row per judge and its `tau_x` against the
#'   consensus.
#' @export
item_consensus <- function(cr) {
  not_implemented("item_consensus", "F4")
}
