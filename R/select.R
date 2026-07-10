#' Select variables with a rank guarantee
#'
#' Keeps the variables whose whole rank confidence set lies at or above
#' `threshold`, that is, whose upper (worst) end is no worse than `threshold`.
#'
#' Selecting on the point estimate of the rank ignores that the ranking was
#' estimated in the first place. Selecting on the confidence set makes the claim
#' "this variable really is among the most important" one that the data can
#' refuse: a variable whose interval straddles the threshold is not selected,
#' and the reason is visible.
#'
#' The rule is deliberately conservative. It answers "which variables am I sure
#' about", not "which variables should I keep": a variable excluded here may
#' still carry signal, and [prob_topk()] quantifies how much doubt there is.
#'
#' @param cb A `rank_confsets` object.
#' @param threshold Worst rank a selected variable may plausibly occupy.
#' @return A character vector of selected variable names, in consensus order.
#' @examples
#' judges <- rbind(c(1, 2, 3, 4), c(1, 2, 3, 4), c(1, 2, 4, 3))
#' colnames(judges) <- c("income", "age", "balance", "region")
#' cb <- rank_confsets(consensus_rank(judges), n_boot = 50)
#'
#' rank_select(cb, threshold = 2)
#' prob_topk(cb, k = 2)
#' @seealso [rank_confsets()], [prob_topk()]
#' @export
rank_select <- function(cb, threshold = 10L) {
  if (!inherits(cb, "rank_confsets")) {
    stop("`cb` must be a `rank_confsets` object.", call. = FALSE)
  }
  if (length(threshold) != 1L || is.na(threshold) || threshold < 1) {
    stop("`threshold` must be a single rank, at least 1.", call. = FALSE)
  }
  cb$confsets$variable[cb$confsets$upper <= threshold]
}
