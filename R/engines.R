# Internal adapters that isolate the package from how each supported engine
# spells prediction, refitting and metadata. Everything a backend needs from a
# fitted model goes through these functions, so supporting a new engine means
# extending them and nothing else.

#' Name the engine behind a fitted model
#'
#' The returned string doubles as the package name, which is what the
#' conditional `requireNamespace()` checks rely on.
#'
#' @param fit A fitted model.
#' @return `"randomForest"` or `"ranger"`.
#' @noRd
engine_of <- function(fit) {
  if (inherits(fit, "randomForest")) return("randomForest")
  if (inherits(fit, "ranger")) return("ranger")
  stop(
    "Unsupported model class '", paste(class(fit), collapse = "/"),
    "'. Supported engines: randomForest, ranger.",
    call. = FALSE
  )
}

#' Fail if the engine behind a fit is not installed
#' @noRd
require_engine <- function(engine) {
  if (!requireNamespace(engine, quietly = TRUE)) {
    stop(
      "Package `", engine, "` is needed to work with this fit. ",
      "Install it with install.packages(\"", engine, "\").",
      call. = FALSE
    )
  }
}

#' Predictors a model was trained on
#' @noRd
predictors_of <- function(fit) {
  out <- switch(engine_of(fit),
    randomForest = rownames(fit$importance),
    ranger = fit$forest$independent.variable.names
  )
  if (is.null(out)) {
    stop(
      "Cannot recover the predictors from this fit. ",
      "For ranger, refit with `write.forest = TRUE` (the default).",
      call. = FALSE
    )
  }
  out
}

#' Is the model a classifier?
#' @noRd
is_classifier <- function(fit) {
  switch(engine_of(fit),
    randomForest = {
      if (fit$type == "unsupervised") {
        stop("Unsupervised forests have no response to rank importance against.",
             call. = FALSE)
      }
      fit$type == "classification"
    },
    ranger = fit$treetype %in% c("Classification", "Probability estimation")
  )
}

#' Predict on the response scale
#'
#' Numbers for regression, class labels for classification. Probability
#' forests are collapsed to the modal class with deterministic tie breaking,
#' so that the misclassification loss applies unchanged.
#'
#' @noRd
predict_response <- function(fit, newdata) {
  engine <- engine_of(fit)
  require_engine(engine)
  switch(engine,
    randomForest = stats::predict(fit, newdata = newdata),
    ranger = {
      pred <- stats::predict(fit, data = newdata)$predictions
      if (fit$treetype == "Probability estimation") {
        factor(colnames(pred)[max.col(pred, ties.method = "first")],
               levels = colnames(pred))
      } else {
        pred
      }
    }
  )
}

#' Predict class probabilities
#' @noRd
predict_prob <- function(fit, newdata) {
  engine <- engine_of(fit)
  require_engine(engine)
  switch(engine,
    randomForest = stats::predict(fit, newdata = newdata, type = "prob"),
    ranger = {
      if (fit$treetype != "Probability estimation") {
        stop(
          "SHAP on a ranger classifier needs class probabilities: ",
          "refit with `probability = TRUE`.",
          call. = FALSE
        )
      }
      stats::predict(fit, data = newdata)$predictions
    }
  )
}

#' Refit a model on new data, preserving its size parameters
#'
#' The number of trees and `mtry` are carried over (capped at the number of
#' available predictors, for the leave-one-covariate-out refits); everything
#' else uses the engine defaults. Ranger refits always compute impurity
#' importance so that a refitted judge can still answer an MDI query.
#'
#' @noRd
refit <- function(fit, x, y) {
  engine <- engine_of(fit)
  require_engine(engine)
  switch(engine,
    randomForest = randomForest::randomForest(
      x = x, y = y,
      ntree = fit$ntree,
      mtry = min(fit$mtry, ncol(x))
    ),
    ranger = ranger::ranger(
      x = x, y = y,
      num.trees = fit$num.trees,
      mtry = min(fit$mtry, ncol(x)),
      importance = "impurity",
      probability = fit$treetype == "Probability estimation"
    )
  )
}

#' Loss of a prediction against the observed response
#'
#' Root mean squared error for a numeric response, misclassification rate for
#' a factor. What matters for permutation and LOCO importance is not the loss
#' itself but its increase, so any strictly proper choice works; these two are
#' the conventional ones.
#'
#' @noRd
prediction_loss <- function(y, pred) {
  if (is.factor(y)) {
    mean(pred != y)
  } else {
    sqrt(mean((y - pred)^2))
  }
}

#' Validate the data a backend was handed
#'
#' Checks that `data` holds the response and every predictor the model was
#' trained on, and that the response type matches the fit. Character responses
#' are promoted to factors, since that is what every modelling function in R
#' does on its own.
#'
#' @return A list with `predictors` (in the fit's order) and `y` (the
#'   validated response).
#' @noRd
check_data <- function(fit, data, target) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }
  if (!is.character(target) || length(target) != 1L || is.na(target)) {
    stop("`target` must be a single column name.", call. = FALSE)
  }
  if (!target %in% names(data)) {
    stop("`data` has no column called '", target, "'.", call. = FALSE)
  }
  predictors <- predictors_of(fit)
  absent <- setdiff(predictors, names(data))
  if (length(absent)) {
    stop(
      "`data` is missing predictors the model was trained on: ",
      toString(absent), ".",
      call. = FALSE
    )
  }
  y <- data[[target]]
  if (is.character(y)) y <- factor(y)
  if (is_classifier(fit) && !is.factor(y)) {
    stop("The model is a classifier but `data$", target, "` is not a factor.",
         call. = FALSE)
  }
  if (!is_classifier(fit) && !is.numeric(y)) {
    stop("The model is a regression but `data$", target, "` is not numeric.",
         call. = FALSE)
  }
  list(predictors = predictors, y = y)
}
