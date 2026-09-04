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
#' plausibly occupies. Overlapping intervals are the honest way of saying that
#' two variables cannot be ordered on this evidence, which is the statement most
#' importance plots decline to make.
#'
#' The rank axis is reversed, so that rank 1 — the most important variable —
#' sits at the top.
#'
#' @param object A `rank_confsets` object.
#' @param ... Reserved for future use.
#' @return A `ggplot` object.
#' @examples
#' judges <- rbind(c(1, 2, 3, 4), c(1, 3, 2, 4), c(2, 1, 3, 4))
#' colnames(judges) <- c("income", "age", "balance", "region")
#' autoplot(rank_confsets(consensus_rank(judges), n_boot = 50))
#' @seealso [rank_confsets()]
#' @export
autoplot.rank_confsets <- function(object, ...) {
  df <- object$confsets
  df$variable <- factor(df$variable, levels = rev(df$variable))

  ggplot2::ggplot(
    df,
    ggplot2::aes(x = .data$variable, y = .data$rank, ymin = .data$lower, ymax = .data$upper)
  ) +
    ggplot2::geom_linerange() +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_y_reverse(breaks = seq_len(nrow(df))) +
    ggplot2::coord_flip() +
    ggplot2::labs(
      x = NULL,
      y = "consensus rank",
      title = "Consensus ranking with bootstrap rank confidence sets",
      subtitle = paste0(
        format(100 * object$level), "% intervals over ", object$n_boot,
        switch(object$type,
          judges = paste0(" resamples of the ", object$n_units, " judges"),
          data = paste0(" bootstrap samples of the ", object$n_units, " rows")
        )
      )
    ) +
    ggplot2::theme_minimal()
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
