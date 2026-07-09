#' Bootstrap confidence sets for the consensus ranking
#'
#' A single consensus ranking is a point estimate. Resampling the judges (or
#' the data underneath them) gives the sampling distribution of each
#' variable's position, from which follow the interval of plausible ranks for
#' each variable and the probability that a variable belongs to the top `k`.
#'
#' This is the inferential layer that distinguishes the package from a
#' rank-averaging exercise, and it is the piece the methodological paper
#' rests on.
#'
#' Not implemented yet: scheduled for phase F3.
#'
#' @param cr A `consensus_rank` object.
#' @param n_boot Number of bootstrap replicates.
#' @param level Coverage of the rank confidence sets.
#' @return An object of class `rank_confsets`.
#' @export
rank_confsets <- function(cr, n_boot = 500L, level = 0.95) {
  not_implemented("rank_confsets", "F3")
}

#' Probability that a variable lands in the top k
#'
#' Not implemented yet: scheduled for phase F3.
#'
#' @param cb A `rank_confsets` object.
#' @param k Size of the top set.
#' @return A tibble of variables and probabilities, in decreasing order.
#' @export
prob_topk <- function(cb, k = 5L) {
  not_implemented("prob_topk", "F3")
}
