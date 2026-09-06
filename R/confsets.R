#' Bootstrap confidence sets for the consensus ranking
#'
#' A single consensus ranking is a point estimate. Resampling gives the sampling
#' distribution of each variable's position, from which follow the interval of
#' plausible ranks for each variable and the probability that a variable belongs
#' to the top `k`.
#'
#' This is the inferential layer. It is what distinguishes the package from a
#' rank-averaging exercise, and it is what lets a claim about variable
#' importance be falsified: "`income` is the third most important variable"
#' cannot be checked, while "`income` is in the top five with probability 0.97"
#' can.
#'
#' @section What is resampled:
#' Two questions, two answers, and they are not the same question.
#'
#' `type = "judges"` draws the judges with replacement from `cr$judges`. It
#' measures how much the consensus depends on *which sources of importance
#' happened to be in the panel* — a panel of ten permutation replicates and one
#' SHAP judge will show it. Resampling is done by drawing multinomial counts and
#' passing them as judge weights rather than by materialising the resampled
#' panel. The two are equivalent — `ConsRank` treats a weight of 3 exactly as
#' three copies of the judge — and the weighted form avoids rebuilding a
#' `K x p` matrix per replicate. Judge weights supplied to [consensus_rank()]
#' are carried through by multiplying them into the bootstrap counts.
#'
#' `type = "data"` draws the *rows* with replacement, refits every model on the
#' resampled data and rebuilds the whole panel from scratch, once per replicate.
#' It measures how much the consensus depends on the sample the models were
#' fitted to — the question a reader asks when they wonder whether the ranking
#' would survive another dataset. It needs a panel built by
#' [importance_judges()], whose recipe carries the fits, the data and the
#' settings; a plain ranking matrix has no models to refit.
#'
#' @section How a data replicate is built:
#' Each replicate draws `n` rows with replacement, refits every model on them
#' with [importance_judges()]'s own machinery, and measures importance the way
#' the recipe did: on the rows the bootstrap left out when the original panel
#' judged out of sample (the `resamples` axis), on the resampled rows themselves
#' when it judged in sample. Mirroring the recipe is what keeps the bootstrap
#' distribution centred on the point estimate, without which a percentile
#' interval means nothing.
#'
#' Two consequences worth stating plainly:
#'
#' * A `resamples` axis is **replaced** by the bootstrap's own in-bag/out-of-bag
#'   split, so a panel of `models x methods x V` judges is rebuilt with
#'   `models x methods` of them. Each replicate votes with fewer judges than the
#'   point estimate did, which makes its consensus noisier and the intervals, if
#'   anything, wider.
#' * Refits preserve the number of trees and `mtry` and nothing else. A forest
#'   fitted with a hand-tuned `nodesize` is refitted at the engine's default,
#'   here as on the `seeds` and `resamples` axes.
#'
#' One consequence to expect rather than to debug: the interval need not contain
#' the consensus rank. `n` rows drawn with replacement hold about 0.632`n`
#' distinct ones, and a weak-but-real predictor is harder to place on that much
#' less information, so its bootstrap ranks drift towards worse positions.
#' Measured on eight predictors with close effects and eighty rows, the second
#' variable of the consensus had a median bootstrap rank of three. Hand a
#' replicate all the distinct rows instead and it returns the point estimate
#' exactly — which is how this was told apart from a panel rebuilt wrongly.
#'
#' A replicate that fails is dropped rather than allowed to kill the run, and
#' the count of dropped replicates is warned about and kept in `failed`. The
#' failure that actually happens is a response class too rare to survive a
#' bootstrap draw: `randomForest` refuses to refit on a sample that lost one
#' (`ranger` drops the level and carries on). A rare *predictor* level is
#' harmless, because subsetting a factor keeps its levels.
#'
#' @section What the level actually buys:
#' The two bootstraps miss the nominal level in opposite directions, and by
#' enough that the choice between them is the choice that matters. The
#' simulation is `inst/simulations/rank-coverage.R`: eight predictors, five of
#' them real, 300 replicates per cell, nominal 0.95, coverage of the true rank
#' of the signal variables.
#'
#' * `type = "data"` — 0.966, 0.969 and 0.978 at `n` of 80, 200 and 500 with
#'   effects close enough that the middle of the ranking is barely
#'   identifiable; 0.993 and 0.998 at `n` of 80 and 200 with effects that
#'   separate cleanly.
#' * `type = "judges"` — 0.582, 0.655 and 0.711 on those same close cells;
#'   0.801 and 0.929 on the separated ones.
#'
#' The data bootstrap covers, and it covers by being wide. On the hardest cell
#' its interval spans 5.1 of the 8 available ranks — it reports that this
#' sample does not order these variables, which is the truth: the point
#' estimate recovers the true order of the five signal variables in 5% of
#' replicates there. An interval that admitted less would be claiming more than
#' the data holds.
#'
#' The judge bootstrap is narrow on the same cell — 2.0 ranks — and misses the
#' true rank two times in five. Resampling a panel measures how much the
#' methods disagree with each other, and that is not how far the ranking would
#' move on another sample. It is the cheap answer to a different question, and
#' the gap it leaves is the reason `type = "data"` exists: 0.966 against 0.582
#' where the ordering is hardest.
#'
#' Fifty replicates are enough for the data bootstrap. The same cell at
#' `n_boot = 200` covers 0.970 against 0.966, a difference inside the Monte
#' Carlo error of either — which is worth stating because it was not always
#' true of this package: a defect that made the bootstrap repeat its resamples
#' once made `n_boot` look decisive (see `NEWS.md`).
#'
#' Read a rank confidence set as a statement about what the evidence rules out,
#' not as a calibrated guarantee. The rank is a discrete, non-smooth functional
#' and a percentile bootstrap is not automatically valid for such functionals;
#' the figures above are measured on those designs, not promised in general.
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
#' A data replicate additionally refits every model and recomputes every
#' importance, which is orders of magnitude dearer than reweighting a panel that
#' already exists. Hence the smaller default for `n_boot`, and a message
#' reporting the projected cost when the run looks like a long one.
#'
#' @param cr A `consensus_rank` object.
#' @param n_boot Number of bootstrap replicates. Defaults to 500 for
#'   `type = "judges"` and 50 for `type = "data"`, which refits every model on
#'   every replicate.
#' @param level Coverage of the rank confidence sets.
#' @param type What to resample: the `"judges"` in the panel, or the `"data"`
#'   the models were fitted to.
#' @param algorithm Solver used for the replicates. `"quick"` by default;
#'   `"exact"`, `"fast"` and `"decor"` are also accepted, as in
#'   [consensus_rank()].
#'
#' @return An object of class `rank_confsets`, a list with elements
#'   `confsets` (a tibble of variable, consensus rank, and the lower and upper
#'   ends of the rank interval), `ranks` (the `n_boot x p` matrix of bootstrap
#'   ranks), `level`, `n_boot`, `type`, `n_units` (how many judges or rows were
#'   resampled), `failed` (replicates dropped) and `consensus` (the `cr` it came
#'   from).
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
#' @examplesIf requireNamespace("randomForest", quietly = TRUE)
#' # Resampling the data instead: every replicate refits the forest.
#' set.seed(1)
#' fit <- randomForest::randomForest(mpg ~ ., data = mtcars, ntree = 50)
#' J <- importance_judges(fit, methods = c("permutation", "mdi"),
#'                        data = mtcars, target = "mpg", n_perm = 2)
#' rank_confsets(consensus_rank(J), n_boot = 10, type = "data")
#'
#' @seealso [prob_topk()], [rank_select()], [autoplot.rank_confsets()]
#' @export
rank_confsets <- function(cr,
                          n_boot = NULL,
                          level = 0.95,
                          type = c("judges", "data"),
                          algorithm = c("quick", "exact", "fast", "decor")) {
  if (!inherits(cr, "consensus_rank")) {
    stop("`cr` must be a `consensus_rank` object.", call. = FALSE)
  }
  type <- match.arg(type)
  algorithm <- match.arg(algorithm)
  n_boot <- resolve_n_boot(n_boot, type)
  if (is.na(n_boot) || n_boot < 2L) {
    stop("`n_boot` must be at least 2.", call. = FALSE)
  }
  if (level <= 0 || level >= 1) {
    stop("`level` must lie strictly between 0 and 1.", call. = FALSE)
  }

  judges <- cr$judges
  engine <- resolve_algorithm(algorithm, ncol(judges))

  boot <- switch(type,
    judges = boot_judges(cr, n_boot, engine),
    data = boot_data(cr, n_boot, engine)
  )
  ranks <- boot$ranks

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
      type = type,
      n_units = boot$n_units,
      failed = boot$failed,
      algorithm = engine,
      consensus = cr
    ),
    class = "rank_confsets"
  )
}

#' How many replicates when the caller did not say
#'
#' A data replicate refits every model, so the constant that is generous for a
#' panel bootstrap would launch an hours-long job here without warning.
#'
#' @noRd
resolve_n_boot <- function(n_boot, type) {
  if (is.null(n_boot)) {
    return(if (type == "data") 50L else 500L)
  }
  suppressWarnings(as.integer(n_boot))
}

#' Bootstrap the judges, by multinomial reweighting
#' @noRd
boot_judges <- function(cr, n_boot, engine) {
  judges <- cr$judges
  k <- nrow(judges)
  base_weights <- if (is.null(cr$weights)) rep(1, k) else cr$weights

  ranks <- matrix(NA_integer_, nrow = n_boot, ncol = ncol(judges),
                  dimnames = list(NULL, colnames(judges)))

  for (b in seq_len(n_boot)) {
    counts <- stats::rmultinom(1L, size = k, prob = rep(1 / k, k))[, 1L]
    w <- counts * base_weights
    drawn <- w > 0
    if (sum(drawn) < 1L) next # cannot happen with size = k, but be explicit

    # As in `boot_data()`: a replicate consumes its own draw from the caller's
    # stream and nothing else, so that what the solver does with the RNG cannot
    # correlate one replicate with the next.
    state <- capture_seed()
    fit <- quiet_consrank(
      X = judges[drawn, , drop = FALSE],
      wk = matrix(w[drawn], ncol = 1L),
      algorithm = engine,
      full = !cr$ties
    )
    restore_seed(state)
    ranks[b, ] <- as.integer(combine_optima(as.matrix(fit$Consensus)))
  }

  list(ranks = ranks, n_units = k, failed = 0L)
}

#' Bootstrap the data, by rebuilding the panel on every replicate
#' @noRd
boot_data <- function(cr, n_boot, engine) {
  judges <- cr$judges
  recipe <- attr(judges, "recipe")
  if (is.null(recipe)) {
    stop(
      "`type = \"data\"` has to refit the models, and this consensus came from ",
      "a plain ranking matrix, which carries none. Build the panel with ",
      "`importance_judges()` and the recipe travels with it.",
      call. = FALSE
    )
  }
  if (is.null(recipe$data)) {
    stop(
      "`type = \"data\"` needs the data the models were fitted to, and this ",
      "panel was built from \"mdi\" scores alone, which are read off the fits ",
      "without ever seeing the data. Rebuild the panel with `data` and ",
      "`target`.",
      call. = FALSE
    )
  }

  data <- recipe$data
  n <- nrow(data)
  variables <- colnames(judges)
  ranks <- matrix(NA_integer_, nrow = n_boot, ncol = length(variables),
                  dimnames = list(NULL, variables))

  rebuilt_k <- length(recipe$fit_list) * length(recipe$methods) *
    max(1L, length(recipe$seeds))
  keep_weights <- !is.null(cr$weights) && length(cr$weights) == rebuilt_k
  if (!is.null(cr$weights) && !keep_weights) {
    warning(
      "The panel rebuilt on a bootstrap sample has ", rebuilt_k, " judges and ",
      "the consensus was weighted over ", length(cr$weights), ", because the ",
      "resample axis is replaced by the bootstrap's own split. Falling back on ",
      "the method weights the panel was built with.",
      call. = FALSE
    )
  }

  failed <- 0L
  first_error <- NULL
  started <- proc.time()[["elapsed"]]

  for (b in seq_len(n_boot)) {
    in_bag <- sample.int(n, n, replace = TRUE)
    out_of_bag <- setdiff(seq_len(n), in_bag)
    # Mirror the recipe: a panel that judged out of sample keeps judging out of
    # sample, on the rows this replicate left behind. `out_of_bag` is empty only
    # for absurdly small `n`, and then there is nowhere else to look.
    eval_rows <- if (recipe$out_of_sample && length(out_of_bag)) {
      out_of_bag
    } else {
      in_bag
    }

    # The replicates are independent draws only for as long as nothing between
    # them moves the stream to a fixed place, and rebuilding the panel runs
    # whatever a backend does with the RNG — this is where a `set.seed()` in
    # `panel_scores()` once made every replicate resample the same rows. The
    # state that draws the next resample is put back by hand rather than
    # trusted.
    state <- capture_seed()
    outcome <- tryCatch(
      data_replicate(recipe, in_bag, eval_rows, variables, engine,
                     weights = if (keep_weights) cr$weights else NULL,
                     ties = cr$ties),
      error = function(e) e
    )
    restore_seed(state)

    if (inherits(outcome, "error")) {
      failed <- failed + 1L
      if (is.null(first_error)) first_error <- conditionMessage(outcome)
    } else {
      ranks[b, ] <- outcome
    }

    if (b == 1L) {
      announce_cost(proc.time()[["elapsed"]] - started, n_boot)
    }
  }

  if (failed == n_boot) {
    stop("Every bootstrap replicate failed. The first error was: ", first_error,
         call. = FALSE)
  }
  if (failed > 0L) {
    warning(
      failed, " of ", n_boot, " bootstrap replicates failed and were dropped. ",
      "The first error was: ", first_error,
      call. = FALSE
    )
  }

  list(ranks = ranks, n_units = n, failed = failed)
}

#' One data-bootstrap replicate: rebuild the panel, take the consensus
#'
#' @param in_bag,eval_rows Row indices into the recipe's data.
#' @param variables Column order of the original panel, which the replicate is
#'   aligned to so that the consensus can be read off positionally.
#' @return An integer vector of consensus ranks, one per variable.
#' @noRd
data_replicate <- function(recipe, in_bag, eval_rows, variables, engine,
                           weights, ties) {
  panel <- do.call(panel_scores, c(
    list(
      recipe$fit_list,
      engines = recipe$engines,
      predictors = recipe$predictors,
      methods = recipe$methods,
      target = recipe$target,
      data = recipe$data,
      splits = list(list(
        label = NA_character_,
        rows = list(train = in_bag, eval = eval_rows)
      )),
      seeds = recipe$seeds,
      refitting = TRUE
    ),
    recipe$dots
  ))

  replicate_ranks <- importance_to_rank(panel$scores,
                                        ties_method = recipe$ties_method)
  replicate_ranks <- replicate_ranks[, variables, drop = FALSE]

  w <- if (!is.null(weights)) {
    weights
  } else if (!is.null(recipe$weights)) {
    unname(recipe$weights[panel$provenance$method])
  } else {
    NULL
  }

  fit <- quiet_consrank(
    X = replicate_ranks,
    wk = if (is.null(w)) NULL else matrix(w, ncol = 1L),
    algorithm = engine,
    full = !ties
  )
  as.integer(combine_optima(as.matrix(fit$Consensus)))
}

#' Report what a data bootstrap is about to cost, when it is worth reporting
#'
#' Measured on the first replicate and extrapolated. Silent below half a minute,
#' so that examples and tests say nothing.
#'
#' @noRd
announce_cost <- function(per_replicate, n_boot) {
  total <- per_replicate * n_boot
  if (!is.finite(total) || total <= 30) {
    return(invisible(NULL))
  }
  message(
    "Data bootstrap: ", n_boot, " replicates at about ",
    signif(per_replicate, 2), " s each, roughly ", format_duration(total), "."
  )
}

#' @noRd
format_duration <- function(seconds) {
  if (seconds < 90) {
    paste(round(seconds), "seconds")
  } else if (seconds < 5400) {
    paste(round(seconds / 60), "minutes")
  } else {
    paste(round(seconds / 3600, 1), "hours")
  }
}

#' @param x A `rank_confsets` object.
#' @param ... Unused.
#' @rdname rank_confsets
#' @export
print.rank_confsets <- function(x, ...) {
  cat("<rank_confsets>\n")
  cat("  replicates :", x$n_boot, "(", x$algorithm, ")\n")
  cat("  level      :", x$level, "\n")
  cat("  resampled  :", switch(x$type,
    judges = paste(x$n_units, "judges, with replacement"),
    data = paste(x$n_units, "rows, with replacement; the panel is rebuilt on each")
  ), "\n")
  if (isTRUE(x$failed > 0L)) {
    cat("  dropped    :", x$failed, "replicates that failed\n")
  }
  cat("\n")
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
