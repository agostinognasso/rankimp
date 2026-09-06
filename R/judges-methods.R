#' Importance backends
#'
#' Each backend asks a fitted model for one named numeric vector of importance
#' scores over its predictors, higher meaning more important. They are the
#' judges' voices: [importance_judges()] calls them once per judge, and they can
#' equally be called directly when a single score vector is all that is needed.
#'
#' Permutation, MDI and LOCO are implemented natively against the supported
#' engines (randomForest, ranger); SHAP delegates to the kernelshap package.
#' Scores are computed on the data supplied, so permutation and LOCO are
#' in-sample unless `data` is a holdout set. [importance_judges()] with a
#' `resamples` axis is the out-of-sample version.
#'
#' Backends that randomise (permutation shuffles, SHAP row subsampling, LOCO
#' refits) draw from the session RNG: call `set.seed()` first for
#' reproducibility.
#'
#' @param fit A fitted model (randomForest or ranger).
#' @param data A data frame holding the response and every predictor the model
#'   was trained on. For `importance_mdi()` the scores are read off the fit,
#'   so `data` and `target` are accepted but unused.
#' @param target Name of the response column in `data`.
#' @param ... Ignored. It absorbs the arguments meant for the other backends
#'   when the call comes from [importance_judges()], which forwards its own
#'   `...` to every backend it invokes.
#' @return A named numeric vector of importance scores, one per predictor.
#' @seealso [importance_judges()], [importance_to_rank()]
#' @name importance_backends
NULL

#' @describeIn importance_backends Permutation importance: the mean increase
#'   in loss (RMSE for regression, misclassification rate for classification)
#'   when one predictor's column is shuffled, over `n_perm` shuffles.
#' @param n_perm Number of independent shuffles per predictor.
#' @examplesIf requireNamespace("randomForest", quietly = TRUE)
#' set.seed(1)
#' fit <- randomForest::randomForest(mpg ~ ., data = mtcars, ntree = 50)
#' importance_permutation(fit, mtcars, "mpg", n_perm = 2)
#' @export
importance_permutation <- function(fit, data, target, n_perm = 5L, ...) {
  info <- check_data(fit, data, target)
  n_perm <- as.integer(n_perm)
  if (is.na(n_perm) || n_perm < 1L) {
    stop("`n_perm` must be a positive integer.", call. = FALSE)
  }
  baseline <- prediction_loss(info$y, predict_response(fit, data))
  vapply(info$predictors, function(v) {
    shuffled <- data
    losses <- vapply(seq_len(n_perm), function(r) {
      shuffled[[v]] <- sample(shuffled[[v]])
      prediction_loss(info$y, predict_response(fit, shuffled))
    }, numeric(1))
    mean(losses) - baseline
  }, numeric(1))
}

#' @describeIn importance_backends Mean decrease in impurity, read off the
#'   fit: `IncNodePurity` (regression) or `MeanDecreaseGini` (classification)
#'   for randomForest, `variable.importance` for a ranger model fitted with
#'   `importance = "impurity"`.
#' @examplesIf requireNamespace("randomForest", quietly = TRUE)
#' set.seed(1)
#' fit <- randomForest::randomForest(mpg ~ ., data = mtcars, ntree = 50)
#' importance_mdi(fit)
#' @export
importance_mdi <- function(fit, data = NULL, target = NULL, ...) {
  switch(engine_of(fit),
    randomForest = {
      column <- if (fit$type == "classification") "MeanDecreaseGini" else "IncNodePurity"
      if (!column %in% colnames(fit$importance)) {
        stop("This randomForest fit carries no '", column, "' column.",
             call. = FALSE)
      }
      fit$importance[, column]
    },
    ranger = {
      mode <- fit$importance.mode
      if (is.null(mode) || !mode %in% c("impurity", "impurity_corrected")) {
        stop(
          "This ranger fit stores no impurity importance. ",
          "Refit with `importance = \"impurity\"`.",
          call. = FALSE
        )
      }
      fit$variable.importance
    }
  )
}

#' @describeIn importance_backends Mean absolute SHAP value, via
#'   [kernelshap::kernelshap()]. For classifiers the mean is also taken across
#'   classes; ranger classifiers must be fitted with `probability = TRUE`.
#'   At most `n_explain` rows of `data` are explained (sampled without
#'   replacement when there are more), against a background sample of `bg_n`
#'   rows drawn by kernelshap.
#' @param n_explain Maximum number of rows to explain.
#' @param bg_n Size of the background sample, passed to
#'   [kernelshap::kernelshap()].
#' @export
importance_shap <- function(fit, data, target, n_explain = 100L, bg_n = 200L, ...) {
  if (!requireNamespace("kernelshap", quietly = TRUE)) {
    stop(
      "SHAP importance needs the kernelshap package. ",
      "Install it with install.packages(\"kernelshap\").",
      call. = FALSE
    )
  }
  info <- check_data(fit, data, target)
  x <- data[info$predictors]
  n_explain <- as.integer(n_explain)
  if (is.na(n_explain) || n_explain < 1L) {
    stop("`n_explain` must be a positive integer.", call. = FALSE)
  }
  explained <- if (nrow(x) > n_explain) {
    x[sample(nrow(x), n_explain), , drop = FALSE]
  } else {
    x
  }
  pred_fun <- if (is_classifier(fit)) {
    function(object, newdata) predict_prob(object, newdata)
  } else {
    function(object, newdata) predict_response(object, newdata)
  }
  shap <- kernelshap::kernelshap(
    fit,
    X = explained, bg_X = x, bg_n = bg_n,
    pred_fun = pred_fun, verbose = FALSE
  )
  if (is.list(shap$S)) {
    # One SHAP matrix per class: a variable's importance is its mean absolute
    # contribution, averaged over classes.
    rowMeans(vapply(shap$S, function(s) colMeans(abs(s)),
                    numeric(length(info$predictors))))
  } else {
    colMeans(abs(shap$S))
  }
}

#' @describeIn importance_backends Leave-one-covariate-out: the increase in
#'   loss when the model is refitted on `data` without one predictor
#'   (preserving the original number of trees and `mtry`, capped) and compared
#'   with `fit`. Losses are evaluated on `newdata` when supplied, on `data`
#'   otherwise; `data` should be the data `fit` was trained on, or the
#'   comparison mixes training sets. The most expensive backend: one refit per
#'   predictor.
#' @param newdata Optional data frame on which the losses are evaluated.
#' @examplesIf requireNamespace("randomForest", quietly = TRUE)
#' set.seed(1)
#' small <- mtcars[c("mpg", "wt", "hp", "qsec")]
#' fit <- randomForest::randomForest(mpg ~ ., data = small, ntree = 30)
#' importance_loco(fit, small, "mpg")
#' @export
importance_loco <- function(fit, data, target, newdata = NULL, ...) {
  info <- check_data(fit, data, target)
  if (is.null(newdata)) newdata <- data
  eval_info <- check_data(fit, newdata, target)
  baseline <- prediction_loss(eval_info$y, predict_response(fit, newdata))
  vapply(info$predictors, function(v) {
    kept <- setdiff(info$predictors, v)
    if (!length(kept)) {
      stop("LOCO needs at least two predictors.", call. = FALSE)
    }
    reduced <- refit(fit, x = data[kept], y = info$y)
    prediction_loss(eval_info$y, predict_response(reduced, newdata)) - baseline
  }, numeric(1))
}
