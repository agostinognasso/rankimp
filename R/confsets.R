#' Bootstrap confidence sets for the consensus ranking
#'
#' A single consensus ranking is a point estimate. Resampling the judges gives
#' the sampling distribution of each variable's position, from which follow the
#' interval of plausible ranks for each variable and the probability that a
#' variable belongs to the top `k`.
#'
#' This is the inferential layer. It is what distinguishes the package from a
#' rank-averaging exercise, and it is what lets a claim about variable
#' importance be falsified: "`income` is the third most important variable"
#' cannot be checked, while "`income` is in the top five with probability 0.97"
#' can.
#'
#' @section What is resampled:
#' The judges, drawn with replacement from `cr$judges`. This measures how much
#' the consensus depends on *which sources of importance happened to be in the
#' panel* — a panel of ten permutation replicates and one SHAP judge will show
#' it. It does not measure how much the consensus depends on the sample the
#' models were fitted to: that requires refitting, and cannot be done from a
#' `consensus_rank` object.
#'
#' Resampling is done by drawing multinomial counts and passing them as judge
#' weights rather than by materialising the resampled panel. The two are
#' equivalent — `ConsRank` treats a weight of 3 exactly as three copies of the
#' judge — and the weighted form avoids rebuilding a `K x p` matrix per
#' replicate. Judge weights supplied to [consensus_rank()] are carried through
#' by multiplying them into the bootstrap counts.
#'
#' @section On the cost:
#' Every replicate solves a Kemeny problem, which is NP-hard. Branch-and-bound
#' is fast on panels that agree and pathological on panels that do not: with
#' twelve variables and many ties — the normal case for importance scores, where
#' unimportant variables all tie near zero — a single exact solve has been
#' measured at over four minutes, which is a day and a half for five hundred
#' replicates.
#'
#' The default is therefore to resample with the `"quick"` heuristic regardless
#' of the algorithm used for the point estimate, and to say so. Pass
#' `algorithm = "exact"` if the panel is small and you want optimality
#' guarantees inside the bootstrap too.
#'
#' @param cr A `consensus_rank` object.
#' @param n_boot Number of bootstrap replicates.
#' @param level Coverage of the rank confidence sets.
#' @param algorithm Solver used for the replicates. `"quick"` by default;
#'   `"exact"`, `"fast"` and `"decor"` are also accepted, as in
#'   [consensus_rank()].
#'
#' @return An object of class `rank_confsets`, a list with elements
#'   `confsets` (a tibble of variable, consensus rank, and the lower and upper
#'   ends of the rank interval), `ranks` (the `n_boot x p` matrix of bootstrap
#'   ranks), `level`, `n_boot`, and `consensus` (the `cr` it came from).
#'
#' @examples
#' judges <- rbind(
#'   c(1, 2, 3, 4), c(1, 2, 3, 4), c(1, 3, 2, 4),
#'   c(2, 1, 3, 4), c(1, 2, 4, 3), c(2, 1, 4, 3)
#' )
#' colnames(judges) <- c("income", "age", "balance", "region")
#' cb <- rank_confsets(consensus_rank(judges), n_boot = 50)
#' cb
#'
#' @seealso [prob_topk()], [rank_select()], [autoplot.rank_confsets()]
#' @export
rank_confsets <- function(cr,
                          n_boot = 500L,
                          level = 0.95,
                          algorithm = c("quick", "exact", "fast", "decor")) {
  if (!inherits(cr, "consensus_rank")) {
    stop("`cr` must be a `consensus_rank` object.", call. = FALSE)
  }
  algorithm <- match.arg(algorithm)
  n_boot <- as.integer(n_boot)
  if (n_boot < 2L) {
    stop("`n_boot` must be at least 2.", call. = FALSE)
  }
  if (level <= 0 || level >= 1) {
    stop("`level` must lie strictly between 0 and 1.", call. = FALSE)
  }

  judges <- cr$judges
  k <- nrow(judges)
  p <- ncol(judges)
  base_weights <- if (is.null(cr$weights)) rep(1, k) else cr$weights
  engine <- resolve_algorithm(algorithm, p)

  ranks <- matrix(NA_integer_, nrow = n_boot, ncol = p, dimnames = list(NULL, colnames(judges)))

  for (b in seq_len(n_boot)) {
    counts <- stats::rmultinom(1L, size = k, prob = rep(1 / k, k))[, 1L]
    w <- counts * base_weights
    drawn <- w > 0
    if (sum(drawn) < 1L) next # cannot happen with size = k, but be explicit

    fit <- quiet_consrank(
      X = judges[drawn, , drop = FALSE],
      wk = matrix(w[drawn], ncol = 1L),
      algorithm = engine,
      full = !cr$ties
    )
    ranks[b, ] <- as.integer(as.matrix(fit$Consensus)[1L, ])
  }

  alpha <- (1 - level) / 2
  lower <- apply(ranks, 2L, stats::quantile, probs = alpha, na.rm = TRUE, type = 1L)
  upper <- apply(ranks, 2L, stats::quantile, probs = 1 - alpha, na.rm = TRUE, type = 1L)

  confsets <- tibble::tibble(
    variable = colnames(judges),
    rank = cr$ranking$rank[match(colnames(judges), cr$ranking$variable)],
    lower = as.integer(lower),
    upper = as.integer(upper)
  )
  confsets <- confsets[order(confsets$rank, confsets$variable), ]

  structure(
    list(
      confsets = confsets,
      ranks = ranks,
      level = level,
      n_boot = n_boot,
      algorithm = engine,
      consensus = cr
    ),
    class = "rank_confsets"
  )
}

#' @param x A `rank_confsets` object.
#' @param ... Unused.
#' @rdname rank_confsets
#' @export
print.rank_confsets <- function(x, ...) {
  cat("<rank_confsets>\n")
  cat("  replicates :", x$n_boot, "(", x$algorithm, ")\n")
  cat("  level      :", x$level, "\n")
  cat("  judges     :", x$consensus$n_judges, "resampled with replacement\n\n")
  print(x$confsets, n = Inf)
  invisible(x)
}

#' Probability that a variable lands in the top k
#'
#' The proportion of bootstrap replicates in which the variable's consensus rank
#' is at most `k`. Ties are counted as membership: a variable tied at rank `k`
#' with another is in the top `k`.
#'
#' @param cb A `rank_confsets` object.
#' @param k Size of the top set.
#' @return A tibble of variables and probabilities, in decreasing order of
#'   probability.
#' @examples
#' judges <- rbind(c(1, 2, 3, 4), c(1, 3, 2, 4), c(2, 1, 3, 4))
#' colnames(judges) <- c("income", "age", "balance", "region")
#' prob_topk(rank_confsets(consensus_rank(judges), n_boot = 50), k = 2)
#' @seealso [rank_confsets()]
#' @export
prob_topk <- function(cb, k = 5L) {
  if (!inherits(cb, "rank_confsets")) {
    stop("`cb` must be a `rank_confsets` object.", call. = FALSE)
  }
  k <- as.integer(k)
  if (k < 1L || k > ncol(cb$ranks)) {
    stop("`k` must lie between 1 and the number of variables (",
         ncol(cb$ranks), ").", call. = FALSE)
  }

  probs <- colMeans(cb$ranks <= k, na.rm = TRUE)
  out <- tibble::tibble(variable = names(probs), probability = unname(probs))
  out[order(-out$probability, out$variable), ]
}
