#' Do the judges agree?
#'
#' When the global agreement with the consensus is low, reporting the
#' consensus alone hides the disagreement instead of describing it. Clustering
#' the judges in the space of the Kemeny-Snell distance recovers the
#' sub-populations of methods that see the model differently — marginal
#' against conditional importance measures typically separate here whenever
#' the predictors are correlated, and that separation is itself the finding.
#'
#' Not implemented yet: scheduled for phase F4.
#'
#' @param judges A `judges` object or a ranking matrix.
#' @param k Number of clusters, or `NULL` to select it automatically.
#' @return An object of class `judge_clusters`.
#' @export
judge_clusters <- function(judges, k = NULL) {
  not_implemented("judge_clusters", "F4")
}

#' Agreement of each judge with the consensus
#'
#' The Emond-Mason `tau_x` between each judge's ranking and the consensus.
#' `cr$tau` is the (weighted) mean of this column; the column itself says
#' whether that mean summarises a panel that agrees or averages a panel that is
#' split, which are different situations reported by the same number.
#'
#' A judge with a `tau_x` near zero is not necessarily wrong. Marginal and
#' conditional importance measures disagree by construction when the predictors
#' are correlated, and one of them will look like an outlier against a panel
#' dominated by the other.
#'
#' @param cr A `consensus_rank` object.
#' @return A tibble with one row per judge: its name (or index), its weight, and
#'   its `tau_x` against the consensus, in increasing order of agreement.
#' @examples
#' judges <- rbind(
#'   permutation = c(1, 2, 3, 4),
#'   shap        = c(1, 3, 2, 4),
#'   impurity    = c(4, 3, 2, 1)
#' )
#' colnames(judges) <- c("income", "age", "balance", "region")
#' item_consensus(consensus_rank(judges))
#' @seealso [judge_clusters()] for what to do when the agreement is low.
#' @export
item_consensus <- function(cr) {
  if (!inherits(cr, "consensus_rank")) {
    stop("`cr` must be a `consensus_rank` object.", call. = FALSE)
  }
  judges <- cr$judges
  consensus <- matrix(cr$consensus_all[1L, ], nrow = 1L)

  taus <- vapply(
    seq_len(nrow(judges)),
    function(i) as.numeric(ConsRank::tau_x(judges[i, , drop = FALSE], consensus)),
    numeric(1L)
  )

  labels <- rownames(judges)
  if (is.null(labels)) labels <- paste0("judge_", seq_len(nrow(judges)))

  out <- tibble::tibble(
    judge = labels,
    weight = if (is.null(cr$weights)) rep(1, nrow(judges)) else cr$weights,
    tau_x = taus
  )
  out[order(out$tau_x, out$judge), ]
}
