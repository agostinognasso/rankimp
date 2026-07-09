#' Kemeny consensus ranking of variable importance
#'
#' Given `K` judges, each expressing a ranking over the same `p` variables,
#' returns the median ranking in the sense of Kemeny: the ranking that
#' minimises the total Kemeny-Snell distance to the judges,
#' \deqn{\pi^{*} = \arg\min_{\pi} \sum_{k=1}^{K} w_k \, d_{KS}(\pi, \pi_k).}
#'
#' Ties in the consensus are meaningful and are kept by default. Variables
#' that the judges genuinely cannot separate *should* come out equal, which
#' is what distinguishes a Kemeny median from an average of Borda scores.
#' Set `ties = FALSE` to force a linear order.
#'
#' @section Choice of algorithm:
#' Finding the Kemeny median is NP-hard, so `algorithm = "auto"` picks by
#' problem size:
#'
#' * `p <= 12` — `"exact"`, branch-and-bound. (`ConsRank` refuses
#'   branch-and-bound above 15 items with ties allowed; 12 leaves a margin.)
#' * `13 <= p <= 50` — `"quick"`.
#' * `p > 50` — `"fast"`, with a message. The integer-programming route of
#'   the roadmap, which would restore optimality guarantees at this size, is
#'   a phase F2 deliverable.
#'
#' @param x A numeric matrix of rankings, judges in rows and variables in
#'   columns, where `1` denotes the most important variable. Ties are
#'   encoded by repeating a rank. Column names are used as variable names.
#'   See [importance_to_rank()] to build `x` from importance scores.
#' @param weights Optional numeric vector of length `nrow(x)` giving the
#'   weight of each judge. Weights let a permutation importance computed
#'   out-of-bag count for more than an impurity-based one.
#' @param algorithm One of `"auto"`, `"exact"`, `"quick"`, `"fast"`,
#'   `"decor"`.
#' @param ties Keep ties in the consensus ranking.
#'
#' @return An object of class `consensus_rank`, a list with elements
#'   `ranking` (a tibble of variable and consensus rank), `tau` (the average
#'   `tau_x` agreement between the consensus and the judges), `consensus_all`
#'   (every optimal consensus found, one per row), and the settings used.
#'
#' @examples
#' judges <- rbind(
#'   c(1, 2, 3, 4),
#'   c(1, 2, 4, 3),
#'   c(2, 1, 3, 4)
#' )
#' colnames(judges) <- c("income", "age", "balance", "region")
#' consensus_rank(judges)
#'
#' @seealso [importance_to_rank()], [rank_confsets()]
#' @export
consensus_rank <- function(x,
                           weights = NULL,
                           algorithm = c("auto", "exact", "quick", "fast", "decor"),
                           ties = TRUE) {
  algorithm <- match.arg(algorithm)
  x <- validate_rankings(x)

  p <- ncol(x)
  k <- nrow(x)

  if (!is.null(weights)) {
    if (length(weights) != k) {
      stop("`weights` must have one entry per judge: expected ", k,
           ", got ", length(weights), ".", call. = FALSE)
    }
    if (anyNA(weights) || any(weights <= 0)) {
      stop("`weights` must be positive and non-missing.", call. = FALSE)
    }
  }

  engine <- resolve_algorithm(algorithm, p)

  fit <- withCallingHandlers(
    ConsRank::consrank(
      X = x,
      wk = if (is.null(weights)) NULL else matrix(weights, ncol = 1L),
      ps = FALSE,
      algorithm = engine,
      full = !ties
    ),
    message = function(m) invisible(NULL)
  )

  consensus_all <- as.matrix(fit$Consensus)
  colnames(consensus_all) <- colnames(x)
  best <- consensus_all[1L, ]

  structure(
    list(
      ranking = tibble::tibble(
        variable = colnames(x),
        rank = as.integer(best)
      )[order(best), ],
      tau = as.numeric(fit$Tau)[1L],
      consensus_all = consensus_all,
      n_judges = k,
      n_items = p,
      algorithm = engine,
      ties = ties,
      weighted = !is.null(weights),
      multiple = nrow(consensus_all) > 1L
    ),
    class = "consensus_rank"
  )
}

#' Pick the solver for a problem of `p` items
#'
#' @param algorithm User request.
#' @param p Number of items.
#' @return A string accepted by `ConsRank::consrank()`.
#' @noRd
resolve_algorithm <- function(algorithm, p) {
  if (algorithm != "auto") {
    return(switch(algorithm, exact = "BB", quick = "quick", fast = "fast", decor = "decor"))
  }
  if (p <= 12L) {
    "BB"
  } else if (p <= 50L) {
    "quick"
  } else {
    message(
      "p = ", p, " items: falling back on the `fast` heuristic. ",
      "The consensus is no longer guaranteed to be optimal."
    )
    "fast"
  }
}

#' Check that a ranking matrix is well formed
#'
#' @param x Candidate ranking matrix.
#' @return `x`, as a numeric matrix with column names.
#' @noRd
validate_rankings <- function(x) {
  if (is.data.frame(x)) x <- as.matrix(x)
  if (!is.matrix(x) || !is.numeric(x)) {
    stop("`x` must be a numeric matrix of rankings (judges in rows).", call. = FALSE)
  }
  if (anyNA(x)) {
    stop("`x` must not contain missing values.", call. = FALSE)
  }
  if (nrow(x) < 1L || ncol(x) < 2L) {
    stop("`x` needs at least one judge and two variables.", call. = FALSE)
  }
  if (any(x < 1)) {
    stop("Ranks must start at 1, where 1 is the most important variable.", call. = FALSE)
  }
  if (is.null(colnames(x))) {
    colnames(x) <- paste0("V", seq_len(ncol(x)))
  }
  x
}

#' @param x A `consensus_rank` object.
#' @param ... Unused.
#' @rdname consensus_rank
#' @export
print.consensus_rank <- function(x, ...) {
  cat("<consensus_rank>\n")
  cat("  judges    :", x$n_judges, if (x$weighted) "(weighted)" else "", "\n")
  cat("  variables :", x$n_items, "\n")
  cat("  algorithm :", x$algorithm, if (x$ties) "(ties allowed)" else "(linear order)", "\n")
  cat("  tau_x     :", round(x$tau, 4), "\n")
  if (x$multiple) {
    cat("  note      :", nrow(x$consensus_all), "equally optimal consensus rankings;",
        "the first is shown\n")
  }
  cat("\n")
  print(x$ranking, n = Inf)
  invisible(x)
}
