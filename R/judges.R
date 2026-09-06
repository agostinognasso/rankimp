#' Turn importance scores into rankings
#'
#' Each row of `x` holds the importance that one judge assigns to each variable;
#' the result holds the rank that judge gives each variable, with `1` for the
#' most important. Variables a judge scores equally receive the same rank,
#' because pretending to separate them would invent information the judge never
#' supplied.
#'
#' @param x Numeric matrix or data frame of importance scores, judges in
#'   rows and variables in columns. Higher is more important.
#' @param ties_method Passed to [base::rank()]. The default, `"min"`,
#'   produces the weak orderings that the Kemeny framework expects.
#' @return An integer matrix of rankings with the same dimensions and
#'   dimnames as `x`, suitable for [consensus_rank()].
#' @examples
#' imp <- rbind(
#'   permutation = c(income = 0.31, age = 0.12, balance = 0.12),
#'   impurity    = c(income = 0.44, age = 0.20, balance = 0.05)
#' )
#' importance_to_rank(imp)
#' @export
importance_to_rank <- function(x, ties_method = c("min", "average", "first")) {
  ties_method <- match.arg(ties_method)
  if (is.data.frame(x)) x <- as.matrix(x)
  if (!is.matrix(x) || !is.numeric(x)) {
    stop("`x` must be a numeric matrix of importance scores.", call. = FALSE)
  }
  if (anyNA(x)) {
    stop("`x` must not contain missing values.", call. = FALSE)
  }
  out <- t(apply(x, 1L, function(row) rank(-row, ties.method = ties_method)))
  dimnames(out) <- dimnames(x)
  storage.mode(out) <- "integer"
  out
}

#' Assemble the panel of judges
#'
#' Builds the ranking matrix consumed by [consensus_rank()] from any combination
#' of the four axes along which a variable importance ranking can vary: the
#' *method* used, the *model* it interrogates, the *seed* of the ensemble, and
#' the *resample* of the data. Every combination of the active axes becomes one
#' judge, one row of the panel, whose importance scores are computed by the
#' matching backend and turned into a ranking with [importance_to_rank()].
#'
#' @section The four axes:
#' * **Methods** (`methods`): each importance method is one voice; see
#'   [importance_backends].
#' * **Models** (`fit_list`): several fitted models, so that a cross-model
#'   consensus asks which variables matter regardless of the learner. All
#'   models must be trained on the same predictors.
#' * **Seeds** (`seeds`): each seed refits every model on `data` after
#'   `set.seed(seed)`, measuring the stability of the ranking under the
#'   ensemble's own randomness. Refits keep the original number of trees and
#'   `mtry`.
#' * **Resamples** (`resamples`): an `rset` from the rsample package (v-fold
#'   CV or bootstrap). Every split refits the models on its analysis set;
#'   permutation and SHAP importance are then computed on the assessment set,
#'   and LOCO refits on the analysis set and evaluates on the assessment set,
#'   giving the out-of-sample versions of those importances. MDI, which has no
#'   data argument, is read off the refit.
#'
#' Without `seeds` or `resamples` the supplied fits are used as they are, and
#' data-dependent importances are in-sample. Axes combine as a full grid: models
#' × methods × seeds × resamples.
#'
#' @section The recipe:
#' The panel keeps the arguments that built it: the fits, the data, the target,
#' the methods, the axes and the backend settings. That is what lets
#' [rank_confsets()] rebuild it on a bootstrap sample of the rows without being
#' handed them all again. That makes the panel as large as the objects it refers
#' to.
#'
#' @section Reproducibility:
#' Permutation shuffles, SHAP row subsampling and refits draw from the session
#' RNG; call `set.seed()` before this function for a reproducible panel.
#'
#' The `seeds` axis sets seeds of its own, and puts the stream back where it
#' found it, so building a panel does not move the caller's RNG. That is more
#' than politeness: [rank_confsets()] with `type = "data"` rebuilds the panel
#' once per bootstrap replicate and draws the next resample from this same
#' stream, and a panel that parked it made every replicate resample the same
#' rows.
#'
#' @param fit_list A fitted model, or a (preferably named) list of them.
#'   Supported engines: randomForest, ranger. Unnamed models are called
#'   `model1`, `model2`, ...
#' @param methods Character vector of importance methods, among
#'   `"permutation"`, `"mdi"`, `"shap"`, `"loco"`.
#' @param data Data frame holding the response and the predictors. Required
#'   unless `methods` is only `"mdi"` and no `seeds` or `resamples` are given.
#' @param target Name of the response column in `data`.
#' @param resamples Optional `rset` (from [rsample::vfold_cv()] or
#'   [rsample::bootstraps()]) giving the resampling axis.
#' @param seeds Optional integer vector of seeds for the refitting axis.
#' @param weights Optional named numeric vector of method weights, e.g.
#'   `c(permutation = 1, mdi = 0.5)`. Every method in `methods` must be named.
#'   The expanded per-judge weights travel with the panel and are picked up by
#'   [consensus_rank()].
#' @param ties_method Passed to [importance_to_rank()].
#' @param ... Passed to every backend, e.g. `n_perm` for
#'   [importance_permutation()]; each backend ignores what it does not use.
#' @return An object of class `judges`: an integer ranking matrix with one row
#'   per judge, carrying as attributes the `provenance` of each row (a tibble
#'   with the judge's model, engine, method, seed and resample), the raw
#'   `scores` behind the ranks, the per-judge `weights` (or `NULL`), and the
#'   `recipe` that built it.
#' @examplesIf requireNamespace("randomForest", quietly = TRUE)
#' set.seed(1)
#' fit <- randomForest::randomForest(mpg ~ ., data = mtcars, ntree = 50)
#' judges <- importance_judges(fit, methods = c("permutation", "mdi"),
#'                             data = mtcars, target = "mpg", n_perm = 2)
#' judges
#' consensus_rank(judges)
#' @seealso [importance_backends], [judge_weights()], [consensus_rank()]
#' @export
importance_judges <- function(fit_list,
                              methods = c("permutation", "mdi"),
                              data = NULL,
                              target = NULL,
                              resamples = NULL,
                              seeds = NULL,
                              weights = NULL,
                              ties_method = c("min", "average", "first"),
                              ...) {
  ties_method <- match.arg(ties_method)
  methods <- unique(match.arg(methods,
                              c("permutation", "mdi", "shap", "loco"),
                              several.ok = TRUE))

  # Ensemble fits are themselves lists, so `is.list()` cannot tell one model
  # from a list of models: any classed object counts as a single model.
  if (is.object(fit_list) || !is.list(fit_list)) fit_list <- list(fit_list)
  if (!length(fit_list)) {
    stop("`fit_list` must hold at least one fitted model.", call. = FALSE)
  }
  model_names <- names(fit_list)
  if (is.null(model_names)) model_names <- rep("", length(fit_list))
  unnamed <- !nzchar(model_names)
  model_names[unnamed] <- paste0("model", seq_along(fit_list))[unnamed]
  if (anyDuplicated(model_names)) {
    stop("`fit_list` names must be unique.", call. = FALSE)
  }
  names(fit_list) <- model_names
  engines <- vapply(fit_list, engine_of, character(1))

  predictors <- predictors_of(fit_list[[1L]])
  for (m in model_names[-1L]) {
    other <- predictors_of(fit_list[[m]])
    if (!setequal(predictors, other)) {
      stop(
        "All models must be trained on the same predictors. '", model_names[1L],
        "' and '", m, "' differ on: ",
        toString(union(setdiff(predictors, other), setdiff(other, predictors))),
        ".",
        call. = FALSE
      )
    }
  }

  refitting <- !is.null(seeds) || !is.null(resamples)
  needs_data <- refitting || any(methods != "mdi")
  if (needs_data && (is.null(data) || is.null(target))) {
    stop(
      "`data` and `target` are required ",
      if (refitting) "to refit the models along the seed or resample axis."
      else "by every method except \"mdi\".",
      call. = FALSE
    )
  }
  if (needs_data) {
    for (m in model_names) check_data(fit_list[[m]], data, target)
  }

  if (!is.null(seeds)) {
    seeds <- as.integer(seeds)
    if (anyNA(seeds) || anyDuplicated(seeds)) {
      stop("`seeds` must be distinct integers.", call. = FALSE)
    }
  }

  splits <- NULL
  if (!is.null(resamples)) {
    if (!inherits(resamples, "rset")) {
      stop("`resamples` must be an `rset`, e.g. from rsample::vfold_cv().",
           call. = FALSE)
    }
    if (!requireNamespace("rsample", quietly = TRUE)) {
      stop("The `resamples` axis needs the rsample package.", call. = FALSE)
    }
    id_cols <- setdiff(names(resamples), "splits")
    labels <- do.call(paste, c(resamples[id_cols], list(sep = ".")))
    splits <- Map(function(label, split) list(label = label, split = split),
                  labels, resamples$splits)
  }

  if (!is.null(weights)) {
    if (!is.numeric(weights) || is.null(names(weights))) {
      stop("`weights` must be a named numeric vector, one entry per method.",
           call. = FALSE)
    }
    unweighted <- setdiff(methods, names(weights))
    if (length(unweighted)) {
      stop("`weights` names no weight for: ", toString(unweighted), ".",
           call. = FALSE)
    }
    unknown <- setdiff(names(weights), methods)
    if (length(unknown)) {
      stop("`weights` names methods not in `methods`: ", toString(unknown), ".",
           call. = FALSE)
    }
    if (anyNA(weights) || any(weights <= 0)) {
      stop("`weights` must be positive and non-missing.", call. = FALSE)
    }
  }

  panel <- panel_scores(
    fit_list, engines = engines, predictors = predictors, methods = methods,
    target = target, data = data,
    splits = if (is.null(splits)) whole_data_split() else splits,
    seeds = seeds, refitting = refitting, ...
  )

  ranks <- importance_to_rank(panel$scores, ties_method = ties_method)

  judge_w <- NULL
  if (!is.null(weights)) {
    judge_w <- stats::setNames(unname(weights[panel$provenance$method]),
                               panel$provenance$judge)
  }

  recipe <- list(
    fit_list = fit_list, engines = engines, predictors = predictors,
    methods = methods, data = data, target = target, seeds = seeds,
    weights = weights, ties_method = ties_method,
    out_of_sample = !is.null(splits), dots = list(...)
  )

  new_judges(ranks, provenance = panel$provenance, scores = panel$scores,
             weights = judge_w, recipe = recipe)
}

#' Score every judge in one grid
#'
#' The loop shared by [importance_judges()] and the data bootstrap of
#' [rank_confsets()]: each combination of split, seed, model and method becomes
#' one row of scores and one row of provenance. It is the only place an
#' importance backend is invoked, so a new method is added here and nowhere
#' else.
#'
#' @param splits A list of split specifications, resolved by `resolve_split()`.
#' @param refitting Refit each model on the split's training rows before
#'   measuring importance. Always `TRUE` for the data bootstrap, and for the
#'   seed and resample axes.
#' @return A list with `scores` (a `K x p` matrix, judges in rows) and
#'   `provenance` (a `K`-row tibble).
#' @noRd
panel_scores <- function(fit_list, engines, predictors, methods, target,
                         data, splits, seeds = NULL, refitting = FALSE, ...) {
  # The seed axis calls `set.seed()`, which parks the session stream at a state
  # the last seed fixes. Harmless for a single panel; fatal for the data
  # bootstrap, which asks for one panel per replicate and draws the next
  # resample in between, so every replicate would set out from the same state
  # and the resamples fall into a cycle a handful of draws long. Hand the
  # stream back where it was found.
  if (refitting && !is.null(seeds)) {
    entry_state <- capture_seed()
    on.exit(restore_seed(entry_state), add = TRUE)
  }
  model_names <- names(fit_list)
  combos <- expand.grid(
    split = seq_along(splits),
    seed = if (is.null(seeds)) NA_integer_ else seeds,
    model = model_names,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )

  rows <- vector("list", nrow(combos) * length(methods))
  provenance <- vector("list", length(rows))
  row <- 0L
  for (i in seq_len(nrow(combos))) {
    model <- combos$model[i]
    seed <- combos$seed[i]
    spec <- splits[[combos$split[i]]]
    parts <- resolve_split(spec, data)

    fit <- fit_list[[model]]
    if (refitting) {
      if (!is.na(seed)) set.seed(seed)
      fit <- refit(fit, x = parts$train[predictors], y = parts$train[[target]])
    }

    for (method in methods) {
      score <- switch(method,
        mdi = importance_mdi(fit),
        loco = importance_loco(fit, data = parts$train, target = target,
                               newdata = parts$eval, ...),
        permutation = importance_permutation(fit, data = parts$eval,
                                             target = target, ...),
        shap = importance_shap(fit, data = parts$eval, target = target, ...)
      )
      score <- score[predictors]

      row <- row + 1L
      label <- paste0(
        model, ":", method,
        if (!is.na(seed)) paste0(":s", seed),
        if (!is.na(spec$label)) paste0(":", spec$label)
      )
      rows[[row]] <- score
      provenance[[row]] <- tibble::tibble(
        judge = label, model = model, engine = engines[[model]],
        method = method, seed = seed, resample = spec$label
      )
    }
  }

  scores <- do.call(rbind, rows)
  provenance <- do.call(rbind, provenance)
  rownames(scores) <- provenance$judge
  colnames(scores) <- predictors
  list(scores = scores, provenance = provenance)
}

#' Snapshot the session's random stream, and put it back
#'
#' Restoring is the only way a function that calls `set.seed()` for its own
#' reproducibility can leave the caller's stream alone; `withr::with_seed()`
#' does the same thing. `.Random.seed` does not exist until something has drawn
#' from the stream, and "not there" is then the state to put back.
#'
#' @noRd
capture_seed <- function() {
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    get(".Random.seed", envir = globalenv(), inherits = FALSE)
  } else {
    NULL
  }
}

#' @rdname capture_seed
#' @noRd
restore_seed <- function(state) {
  if (is.null(state)) {
    if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    }
  } else {
    assign(".Random.seed", state, envir = globalenv())
  }
  invisible(NULL)
}

#' The single split that trains and evaluates on all of the data
#' @noRd
whole_data_split <- function() {
  list(list(label = NA_character_))
}

#' Materialise the training and evaluation frames of one split
#'
#' A split specification carries a `label` and one of: a `split`, an `rsplit`
#' from rsample; `rows`, a pair of integer index vectors into `data`, which is
#' how the data bootstrap passes its in-bag and out-of-bag rows; or neither,
#' meaning the whole of `data` for both. The frames are built here rather than
#' up front so that only one is alive at a time.
#'
#' @noRd
resolve_split <- function(spec, data) {
  if (!is.null(spec$split)) {
    return(list(train = rsample::analysis(spec$split),
                eval = rsample::assessment(spec$split)))
  }
  if (!is.null(spec$rows)) {
    return(list(train = data[spec$rows$train, , drop = FALSE],
                eval = data[spec$rows$eval, , drop = FALSE]))
  }
  list(train = data, eval = data)
}

#' Construct a judges object
#' @noRd
new_judges <- function(ranks, provenance, scores, weights = NULL,
                       recipe = NULL) {
  structure(
    ranks,
    provenance = provenance,
    scores = scores,
    weights = weights,
    recipe = recipe,
    class = c("judges", class(ranks))
  )
}

#' @param x A `judges` object.
#' @param ... Unused.
#' @rdname importance_judges
#' @export
print.judges <- function(x, ...) {
  prov <- attr(x, "provenance")
  cat("<judges> ", nrow(x), " judges x ", ncol(x), " variables\n", sep = "")
  cat("  models  :", toString(unique(prov$model)), "\n")
  cat("  methods :", toString(unique(prov$method)), "\n")
  if (!all(is.na(prov$seed))) {
    cat("  seeds   :", toString(unique(prov$seed)), "\n")
  }
  if (!all(is.na(prov$resample))) {
    cat("  resamples:", toString(unique(prov$resample)), "\n")
  }
  cat("  weights :",
      if (is.null(attr(x, "weights"))) "none (equal)" else "by method", "\n")
  if (!is.null(attr(x, "recipe"))) {
    cat("  recipe  : kept; rank_confsets(type = \"data\") can rebuild this panel\n")
  }
  cat("\n")
  m <- x
  attributes(m) <- attributes(m)[c("dim", "dimnames")]
  print(utils::head(m, 10L))
  if (nrow(x) > 10L) {
    cat("... and", nrow(x) - 10L, "more judges\n")
  }
  invisible(x)
}
