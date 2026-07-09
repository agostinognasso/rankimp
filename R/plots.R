#' Visualise a consensus ranking
#'
#' Not implemented yet: scheduled for phase F4.
#'
#' @param object A `consensus_rank` object.
#' @param ... Reserved for future use.
#' @return A `ggplot` object.
#' @export
autoplot.consensus_rank <- function(object, ...) {
  not_implemented("autoplot.consensus_rank", "F4")
}

#' Visualise the rank confidence sets
#'
#' Variables ordered by consensus rank, each with the interval of ranks it
#' plausibly occupies. Overlapping intervals are the honest way to say that
#' two variables cannot be ordered.
#'
#' Not implemented yet: scheduled for phase F4.
#'
#' @param object A `rank_confsets` object.
#' @param ... Reserved for future use.
#' @return A `ggplot` object.
#' @export
autoplot.rank_confsets <- function(object, ...) {
  not_implemented("autoplot.rank_confsets", "F4")
}

#' Visualise the disagreement between judges
#'
#' Multidimensional scaling of the judges in the space of the Kemeny-Snell
#' distance, coloured by cluster.
#'
#' Not implemented yet: scheduled for phase F4.
#'
#' @param object A `judge_clusters` object.
#' @param ... Reserved for future use.
#' @return A `ggplot` object.
#' @export
autoplot.judge_clusters <- function(object, ...) {
  not_implemented("autoplot.judge_clusters", "F4")
}
