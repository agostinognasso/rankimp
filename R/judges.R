#' Turn importance scores into rankings
#'
#' Each row of `x` holds the importance that one judge assigns to each
#' variable; the result holds the rank that judge gives each variable, with
#' `1` for the most important. Variables a judge scores equally receive the
#' same rank, because pretending to separate them would invent information
#' the judge never supplied.
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
#' Builds the ranking matrix consumed by [consensus_rank()] from any
#' combination of the four axes along which a variable importance ranking can
#' vary: the *method* used, the *model* it interrogates, the *seed* of the
#' ensemble, and the *resample* of the data. Every combination of the active
#' axes becomes one judge — one row of the panel — whose importance scores are
#' computed by the matching backend and turned into a ranking with
#' [importance_to_rank()].
#'
#' @section The four axes:
#' * **Methods** (`methods`): each importance method is one voice; see
#'   [importance_backends].
#' * **Models** (`fit_list`): several fitted models — a cross-model consensus
#'   asks which variables matter regardless of the learner. All models must be
#'   trained on the same predictors.
#' * **Seeds** (`seeds`): each seed refits every model on `data` after
#'   `set.seed(seed)`, measuring the stability of the ranking under the
#'   ensemble's own randomness. Refits keep the original number of trees and
#'   `mtry`.
#' * **Resamples** (`resamples`): an `rset` from the rsample package (v-fold
#'   CV or bootstrap). Every split refits the models on its analysis set;
#'   permutation and SHAP importance are then computed on the assessment set,
#'   and LOCO refits on the analysis set and evaluates on the assessment set —
#'   the out-of-sample versions of those importances. MDI, which has no data
#'   argument, is read off the refit.
#'
#' Without `seeds` or `resamples` the supplied fits are used as they are, and
#' data-dependent importances are in-sample. Axes combine as a full grid:
#' models × methods × seeds × resamples.
#'
#' @section Reproducibility:
#' Permutation shuffles, SHAP row subsampling and refits draw from the session
#' RNG; call `set.seed()` before this function for a reproducible panel.
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
#'   `scores` behind the ranks, and the per-judge `weights` (or `NULL`).
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
    splits <- resamples$splits
    names(splits) <- do.call(paste, c(resamples[id_cols], list(sep = ".")))
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

  combos <- expand.grid(
    resample = if (is.null(splits)) NA_character_ else names(splits),
    seed = if (is.null(seeds)) NA_integer_ else seeds,
    model = model_names,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )

  backend_of <- list(
    permutation = importance_permutation,
    mdi = importance_mdi,
    shap = importance_shap,
    loco = importance_loco
  )

  rows <- vector("list", nrow(combos) * length(methods))
  provenance <- vector("list", length(rows))
  row <- 0L
  for (i in seq_len(nrow(combos))) {
    model <- combos$model[i]
    seed <- combos$seed[i]
    resample <- combos$resample[i]

    train <- if (!is.na(resample)) rsample::analysis(splits[[resample]]) else data
    eval_data <- if (!is.na(resample)) rsample::assessment(splits[[resample]]) else data

    fit <- fit_list[[model]]
    if (refitting) {
      if (!is.na(seed)) set.seed(seed)
      fit <- refit(fit, x = train[predictors], y = train[[target]])
    }

    for (method in methods) {
      score <- switch(method,
        mdi = importance_mdi(fit),
        loco = importance_loco(fit, data = train, target = target,
                               newdata = eval_data, ...),
        backend_of[[method]](fit, data = eval_data, target = target, ...)
      )
      score <- score[predictors]

      row <- row + 1L
      label <- paste0(
        model, ":", method,
        if (!is.na(seed)) paste0(":s", seed),
        if (!is.na(resample)) paste0(":", resample)
      )
      rows[[row]] <- score
      provenance[[row]] <- tibble::tibble(
        judge = label, model = model, engine = engines[[model]],
        method = method, seed = seed, resample = resample
      )
    }
  }

  scores <- do.call(rbind, rows)
  provenance <- do.call(rbind, provenance)
  rownames(scores) <- provenance$judge
  colnames(scores) <- predictors

  ranks <- importance_to_rank(scores, ties_method = ties_method)

  judge_w <- NULL
  if (!is.null(weights)) {
    judge_w <- stats::setNames(unname(weights[provenance$method]), provenance$judge)
  }

  new_judges(ranks, provenance = provenance, scores = scores, weights = judge_w)
}

#' Construct a judges object
#' @noRd
new_judges <- function(ranks, provenance, scores, weights = NULL) {
  structure(
    ranks,
    provenance = provenance,
    scores = scores,
    weights = weights,
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
      if (is.null(attr(x, "weights"))) "none (equal)" else "by method", "\n\n")
  m <- x
  attributes(m) <- attributes(m)[c("dim", "dimnames")]
  print(utils::head(m, 10L))
  if (nrow(x) > 10L) {
    cat("... and", nrow(x) - 10L, "more judges\n")
  }
  invisible(x)
}
