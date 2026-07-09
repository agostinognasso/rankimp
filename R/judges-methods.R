#' Importance backends
#'
#' Thin adapters that ask each supported package for a vector of importance
#' scores, so that [importance_judges()] does not have to know how `vip`,
#' `DALEX` or `fastshap` spell their arguments. Every backend returns a named
#' numeric vector over the predictors, higher meaning more important.
#'
#' Not implemented yet: scheduled for phase F1.
#'
#' @param fit A fitted model.
#' @param data The data on which importance is computed.
#' @param target Name of the response column in `data`.
#' @param ... Passed to the underlying backend.
#' @return A named numeric vector of importance scores.
#' @name importance_backends
NULL

#' @describeIn importance_backends Permutation importance.
#' @export
importance_permutation <- function(fit, data, target, ...) {
  not_implemented("importance_permutation", "F1")
}

#' @describeIn importance_backends Mean decrease in impurity.
#' @export
importance_mdi <- function(fit, data, target, ...) {
  not_implemented("importance_mdi", "F1")
}

#' @describeIn importance_backends Mean absolute SHAP value.
#' @export
importance_shap <- function(fit, data, target, ...) {
  not_implemented("importance_shap", "F1")
}

#' @describeIn importance_backends Leave-one-covariate-out.
#' @export
importance_loco <- function(fit, data, target, ...) {
  not_implemented("importance_loco", "F1")
}
