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
#' @section When the median is not unique:
#' Several rankings can attain the same minimum, and `ConsRank` returns them all.
#' Reporting one of them would be arbitrary in a way that is not neutral: which
#' comes first depends on the order of the columns, so a variable can gain a
#' position by sitting to the left. That was measured — on a symmetric panel,
#' permuting the columns changed the winner; in a simulation with three
#' exchangeable noise predictors the leftmost took the best rank systematically,
#' and the situation is not rare, arising in 57% to 98% of replicates there.
#'
#' The consensus reported is therefore the optimal set combined: each variable
#' takes its average position over the optima, and those that come out equal are
#' tied. Variables the objective genuinely cannot separate are reported as
#' equal, which is the point of taking a median over weak orderings. The whole
#' set remains in `consensus_all`.
#'
#' @section Choice of algorithm:
#' Finding the Kemeny median is NP-hard, so `algorithm = "auto"` picks by
#' problem size:
#'
#' * `p <= 10` — `"exact"`, branch-and-bound.
#' * `11 <= p <= 50` — `"quick"`.
#' * `p > 50` — `"fast"`, with a message. The integer-programming route of the
#'   roadmap, which would restore optimality guarantees at this size, is a phase
#'   F2 deliverable.
#'
#' The exact threshold is ten rather than the fifteen `ConsRank` permits,
#' because the cost of branch-and-bound is not a smooth function of `p` and the
#' panels this package produces are the hard ones. Importance scores tie: the
#' unimportant variables all sit near zero and rank equal. On tied panels of
#' thirty judges the same solver took 0.010 s at `p = 10`, 0.78 s at `p = 11`
#' and 280 s at `p = 12`. Meanwhile `"quick"` returned the identical consensus
#' and the identical `tau_x` on twenty out of twenty tied panels at `p = 10`.
#' Exactness above ten variables buys little and can cost minutes, so ask for it
#' deliberately with `algorithm = "exact"`.
#'
#' @param x A numeric matrix of rankings, judges in rows and variables in
#'   columns, where `1` denotes the most important variable. Ties are
#'   encoded by repeating a rank. Column names are used as variable names.
#'   See [importance_to_rank()] to build `x` from importance scores.
#' @param weights Optional numeric vector of length `nrow(x)` giving the
#'   weight of each judge. Weights let a permutation importance computed
#'   out-of-bag count for more than an impurity-based one. When `x` is a
#'   `judges` object carrying method weights (see [importance_judges()] and
#'   [judge_weights()]), those are used unless `weights` overrides them.
#' @param algorithm One of `"auto"`, `"exact"`, `"quick"`, `"fast"`,
#'   `"decor"`.
#' @param ties Keep ties in the consensus ranking.
#'
#' @return An object of class `consensus_rank`, a list with elements `ranking`
#'   (a tibble of variable and consensus rank), `tau` (the average `tau_x`
#'   agreement between the consensus and the judges), `consensus_all` (every
#'   optimal consensus found, one per row), `judges` and `weights` (the panel
#'   as supplied), and the settings used.
#'
#'   When several rankings attain the minimum, `ranking` holds their combination
#'   rather than an arbitrary one of them: see the section below.
#'
#'   The panel is kept because the consensus alone is a point estimate:
#'   [rank_confsets()] resamples the judges to put an interval around it, and it
#'   cannot do that from a ranking.
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
  if (is.null(weights) && inherits(x, "judges")) {
    weights <- attr(x, "weights")
  }
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

  fit <- quiet_consrank(
    X = x,
    wk = if (is.null(weights)) NULL else matrix(weights, ncol = 1L),
    algorithm = engine,
    full = !ties
  )

  consensus_all <- as.matrix(fit$Consensus)
  colnames(consensus_all) <- colnames(x)
  best <- combine_optima(consensus_all)

  structure(
    list(
      ranking = tibble::tibble(
        variable = colnames(x),
        rank = as.integer(best)
      )[order(best), ],
      tau = as.numeric(fit$Tau)[1L],
      consensus_all = consensus_all,
      judges = x,
      weights = weights,
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

#' Combine several equally optimal consensus rankings into one
#'
#' The Kemeny median need not be unique, and `ConsRank` returns every ranking
#' that attains the minimum. Taking the first is not neutral: which one comes
#' first depends on the order of the columns. On a symmetric panel of three
#' indistinguishable variables, permuting the columns changed which variable won,
#' and in a simulation with three exchangeable noise predictors the leftmost took
#' the best rank systematically — across designs where several optima arose in
#' 57% to 98% of replicates.
#'
#' Averaging each variable's position over the optimal set and re-ranking with
#' ties lets the variables the objective cannot separate come out equal, which is
#' what a Kemeny median over weak orderings is for. The full set stays available
#' as `consensus_all`.
#'
#' @param consensus_all Matrix of optimal consensus rankings, one per row.
#' @return A named integer vector of ranks, one per variable.
#' @noRd
combine_optima <- function(consensus_all) {
  if (nrow(consensus_all) == 1L) {
    return(consensus_all[1L, ])
  }
  rank(colMeans(consensus_all), ties.method = "min")
}

#' Call ConsRank without its running commentary
#'
#' `ConsRank::consrank()` reports progress in two different ways. Branch counts
#' are printed when `ps = TRUE`, and are silenced by `ps = FALSE`. Degenerate
#' panels — a combined input matrix of zeros, for instance, where every ranking
#' is a median — announce themselves with `print()` regardless. `print()` writes
#' to stdout and no condition handler can intercept it, so the output has to be
#' captured; `suppressMessages()` covers the conditions the package does raise.
#'
#' An earlier version of this function used
#' `withCallingHandlers(message = function(m) invisible(NULL))`, which suppresses
#' nothing at all: a calling handler that does not invoke `muffleMessage` lets
#' the message through untouched.
#'
#' @param ... Passed to `ConsRank::consrank()`.
#' @return The list returned by `ConsRank::consrank()`.
#' @noRd
quiet_consrank <- function(...) {
  fit <- NULL
  utils::capture.output(
    fit <- suppressMessages(ConsRank::consrank(..., ps = FALSE))
  )
  fit
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
  if (p <= 10L) {
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
  # Every judge must rank *something* first. Checking `any(x < 1)` would let a
  # matrix of importance scores through, which is the mistake this catches: a
  # judge whose best rank is 2 has either mis-encoded the ranking or handed us
  # scores instead of ranks.
  best_rank <- apply(x, 1L, min)
  if (any(best_rank != 1)) {
    bad <- which(best_rank != 1)
    stop(
      "Ranks must start at 1, where 1 is the most important variable. ",
      "Judge ", toString(utils::head(bad, 5L)),
      if (length(bad) > 5L) ", ..." else "",
      " has a best rank of ", toString(utils::head(best_rank[bad], 5L)), ". ",
      "If these are importance scores, convert them with `importance_to_rank()`.",
      call. = FALSE
    )
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
        "combined, so variables they order differently are tied\n")
  }
  cat("\n")
  print(x$ranking, n = Inf)
  invisible(x)
}
