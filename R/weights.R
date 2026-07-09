#' Weights for the panel of judges
#'
#' Not every judge deserves an equal say. Impurity-based importance is known
#' to favour high-cardinality predictors, so a panel that mixes it with
#' out-of-bag permutation importance should down-weight it rather than let
#' the two cancel out.
#'
#' Not implemented yet: scheduled for phase F1.
#'
#' @param judges A `judges` object.
#' @param by Weighting scheme: `"equal"`, `"method"` (a weight per importance
#'   method) or `"reliability"` (weights proportional to a judge's agreement
#'   with the rest of the panel).
#' @param values Named numeric vector of weights, when `by = "method"`.
#' @return A numeric vector of weights, one per judge.
#' @export
judge_weights <- function(judges, by = c("equal", "method", "reliability"), values = NULL) {
  not_implemented("judge_weights", "F1")
}
