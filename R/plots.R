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
#' What the picture is for: whether the panel is one cloud or several, and
#' which judges sit between them. The Kemeny-Snell distance is integer-valued
#' and rarely Euclidean, so two dimensions are a projection and not the thing
#' itself — the subtitle reports how much of the distance survives the
#' projection, and a low figure means the plot is a sketch of the grouping
#' rather than evidence for it.
#'
#' @param object A `judge_clusters` object.
#' @param ... Reserved for future use.
#' @return A `ggplot` object.
#' @examples
#' judges <- rbind(
#'   permutation_1 = c(1, 2, 3, 4, 5, 6), permutation_2 = c(1, 2, 3, 4, 6, 5),
#'   permutation_3 = c(2, 1, 3, 4, 5, 6), impurity_1    = c(6, 5, 4, 3, 2, 1),
#'   impurity_2    = c(5, 6, 4, 3, 2, 1), impurity_3    = c(6, 5, 4, 3, 1, 2)
#' )
#' colnames(judges) <- c("income", "age", "balance", "region", "tenure", "arrears")
#' autoplot(judge_clusters(judges))
#' @seealso [judge_clusters()]
#' @export
autoplot.judge_clusters <- function(object, ...) {
  fit <- stats::cmdscale(object$distances, k = 2L, eig = TRUE)
  points <- fit$points
  if (ncol(points) < 2L) {
    points <- cbind(points, 0)[, 1:2, drop = FALSE]
  }
  eig <- fit$eig[fit$eig > 0]
  explained <- if (length(eig)) sum(fit$eig[1:2][fit$eig[1:2] > 0]) / sum(eig) else 0

  # `cluster` keeps the panel's own row order, and so does `cmdscale()`, so the
  # two line up positionally.
  df <- data.frame(
    judge = names(object$cluster),
    cluster = factor(as.integer(object$cluster)),
    dim1 = points[, 1L],
    dim2 = points[, 2L],
    stringsAsFactors = FALSE
  )

  ggplot2::ggplot(
    df, ggplot2::aes(x = .data$dim1, y = .data$dim2, colour = .data$cluster)
  ) +
    ggplot2::geom_point(size = 3) +
    ggplot2::geom_text(
      ggplot2::aes(label = .data$judge),
      vjust = -0.9, size = 3, show.legend = FALSE
    ) +
    ggplot2::labs(
      x = NULL, y = NULL, colour = "cluster",
      title = "The panel in Kemeny-Snell space",
      subtitle = paste0(
        object$k, if (object$k == 1L) " group of " else " groups of ",
        length(object$cluster), " judges; ",
        format(round(100 * explained)), "% of the distance shown in two dimensions"
      )
    ) +
    ggplot2::theme_minimal()
}
