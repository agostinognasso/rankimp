#' Visualise a consensus ranking against the panel it came from
#'
#' The consensus rank of each variable, drawn on top of every rank the judges
#' actually gave it. Point area is the number of judges at that rank, so the
#' picture is exact rather than jittered.
#'
#' What it is for: a consensus ranking reports one number per variable, and
#' that number is equally consistent with a panel that agreed and a panel that
#' was split down the middle. The spread behind each point is the difference,
#' and it is per variable — `tau_x` and [item_consensus()] measure agreement
#' per *judge*, which is a different question and will not tell you *which*
#' variables the panel could not place.
#'
#' Variables the consensus could not separate come out at the same rank and are
#' drawn at the same height; that is a finding, not a drawing artefact. Where
#' the Kemeny median is not unique the plot plots the combined ranking, the one
#' [consensus_rank()] reports, and says so in the subtitle.
#'
#' The rank axis is reversed, so rank 1 — the most important variable — sits at
#' the top.
#'
#' @param object A `consensus_rank` object.
#' @param ... Reserved for future use.
#' @return A `ggplot` object.
#' @examples
#' judges <- rbind(
#'   permutation = c(1, 2, 3, 4), impurity = c(1, 3, 2, 4), loco = c(2, 1, 3, 4)
#' )
#' colnames(judges) <- c("income", "age", "balance", "region")
#' autoplot(consensus_rank(judges))
#' @seealso [consensus_rank()], [item_consensus()], [autoplot.rank_confsets()]
#' @export
autoplot.consensus_rank <- function(object, ...) {
  ranking <- object$ranking
  judges <- object$judges
  # Ties put several variables on one rank, so the drawing order is the
  # consensus order and not the rank itself. `rev()` because `coord_flip()`
  # builds the discrete axis from the bottom.
  levels_by_rank <- rev(ranking$variable)

  # `judges` is judges x variables and `as.vector()` reads it down the columns,
  # which is the order `each = nrow(judges)` repeats the names in.
  panel <- data.frame(
    variable = factor(rep(colnames(judges), each = nrow(judges)),
                      levels = levels_by_rank),
    rank = as.vector(judges)
  )
  consensus <- data.frame(
    variable = factor(ranking$variable, levels = levels_by_rank),
    rank = ranking$rank
  )

  ggplot2::ggplot(panel, ggplot2::aes(x = .data$variable, y = .data$rank)) +
    ggplot2::geom_count(colour = "grey60") +
    ggplot2::geom_point(
      data = consensus, ggplot2::aes(colour = "consensus"), size = 2.6
    ) +
    ggplot2::scale_y_reverse(breaks = seq_len(object$n_items)) +
    # A count of judges has no half. The default continuous breaks offer them.
    ggplot2::scale_size_continuous(breaks = integer_breaks) +
    ggplot2::scale_colour_manual(values = c(consensus = "firebrick")) +
    ggplot2::coord_flip() +
    ggplot2::labs(
      x = NULL,
      y = "rank",
      size = "judges",
      colour = NULL,
      title = "Consensus ranking over the panel that produced it",
      subtitle = paste0(
        object$n_judges, " judges", if (object$weighted) ", weighted" else "",
        "; tau_x = ", format(round(object$tau, 3)),
        if (object$multiple) {
          paste0("; ", nrow(object$consensus_all),
                 " equally optimal consensus rankings combined")
        } else {
          ""
        }
      )
    ) +
    ggplot2::theme_minimal()
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

#' Whole-numbered breaks for an axis or legend counting things
#'
#' @param limits Range ggplot2 asks the breaks for.
#' @return An integer vector inside `limits`.
#' @noRd
integer_breaks <- function(limits) {
  candidates <- unique(round(pretty(limits)))
  keep <- candidates >= max(1, floor(min(limits))) & candidates <= ceiling(max(limits))
  candidates[keep]
}
