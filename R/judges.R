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
#' vary: the method used, the seed of the ensemble, the resample of the data,
#' and the model family.
#'
#' Not implemented yet: scheduled for phase F1.
#'
#' @param fit_list A named list of fitted models.
#' @param methods Character vector of importance methods, among
#'   `"permutation"`, `"shap"`, `"mdi"`, `"loco"`, `"drop_column"`.
#' @param resamples Optional `rsample` object giving the folds or bootstrap
#'   samples over which importance is recomputed.
#' @param seeds Optional integer vector of seeds for refitting each model.
#' @param weights Optional named numeric vector of method weights.
#' @return An object of class `judges`: a ranking matrix with one row per
#'   judge, carrying the provenance of each row as attributes.
#' @export
importance_judges <- function(fit_list,
                              methods = c("permutation", "mdi"),
                              resamples = NULL,
                              seeds = NULL,
                              weights = NULL) {
  not_implemented("importance_judges", "F1")
}
