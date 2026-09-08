#' Weights for the panel of judges
#'
#' Not every judge deserves an equal say. Impurity-based importance is known to
#' favour high-cardinality predictors, so a panel that mixes it with permutation
#' importance may want to down-weight it rather than let the two cancel out. The
#' returned vector plugs straight into [consensus_rank()]'s `weights` argument.
#'
#' @section Schemes:
#' * `"equal"`: every judge weighs 1.
#' * `"method"`: one weight per importance method, supplied through `values`
#'   and expanded over the judges. Needs the provenance that
#'   [importance_judges()] records, so it only works on a `judges` object.
#' * `"reliability"`: a judge's weight grows with its agreement with the rest
#'   of the panel: \eqn{w_k = (1 + \bar\tau_k)/2}, where \eqn{\bar\tau_k} is
#'   the mean Emond-Mason \eqn{\tau_x} correlation between judge \eqn{k} and
#'   every other judge, computed with [ConsRank::tau_x()]. Weights are
#'   normalised to mean 1, and floored at machine epsilon so that a judge in
#'   perfect disagreement with everyone is effectively, though not numerically,
#'   excluded. Down-weighting the dissenters sharpens the consensus around the
#'   majority view; when dissent is the interesting signal, look at
#'   `judge_clusters()` instead of weighting it away.
#'
#' @param judges A `judges` object from [importance_judges()], or a plain
#'   ranking matrix (judges in rows) for the schemes that need no provenance.
#' @param by Weighting scheme: `"equal"`, `"method"` or `"reliability"`.
#' @param values Named numeric vector of method weights, when `by = "method"`:
#'   every method present in the panel must be named.
#' @return A named numeric vector of positive weights, one per judge.
#' @examples
#' judges <- rbind(
#'   c(1, 2, 3, 4), c(1, 2, 4, 3), c(2, 1, 3, 4), c(4, 3, 2, 1)
#' )
#' colnames(judges) <- c("income", "age", "balance", "region")
#' judge_weights(judges, by = "reliability")
#' @seealso [importance_judges()], [consensus_rank()]
#' @export
judge_weights <- function(judges, by = c("equal", "method", "reliability"),
                          values = NULL) {
  by <- match.arg(by)
  x <- validate_rankings(judges)
  k <- nrow(x)
  labels <- rownames(x)
  if (is.null(labels)) labels <- paste0("judge", seq_len(k))

  if (by == "equal") {
    return(stats::setNames(rep(1, k), labels))
  }

  if (by == "method") {
    provenance <- attr(judges, "provenance")
    if (is.null(provenance)) {
      stop(
        "`by = \"method\"` needs the provenance that `importance_judges()` ",
        "records; this panel has none.",
        call. = FALSE
      )
    }
    if (!is.numeric(values) || is.null(names(values))) {
      stop("`values` must be a named numeric vector of method weights.",
           call. = FALSE)
    }
    unweighted <- setdiff(unique(provenance$method), names(values))
    if (length(unweighted)) {
      stop("`values` names no weight for: ", toString(unweighted), ".",
           call. = FALSE)
    }
    if (anyNA(values) || any(values <= 0)) {
      stop("`values` must be positive and non-missing.", call. = FALSE)
    }
    return(stats::setNames(unname(values[provenance$method]), labels))
  }

  # reliability
  if (k < 2L) {
    stop("Reliability weights need at least two judges.", call. = FALSE)
  }
  plain <- x
  attributes(plain) <- attributes(plain)[c("dim", "dimnames")]
  agreement <- as.matrix(ConsRank::tau_x(plain))
  # as.matrix() on a dist puts 0 on the diagonal, so the row sums already
  # exclude self-agreement.
  mean_tau <- rowSums(agreement) / (k - 1)
  w <- pmax((1 + mean_tau) / 2, .Machine$double.eps)
  stats::setNames(unname(w / mean(w)), labels)
}
