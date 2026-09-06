#' Do the judges agree?
#'
#' When the global agreement with the consensus is low, reporting the
#' consensus alone hides the disagreement instead of describing it. Clustering
#' the judges in the space of the Kemeny-Snell distance recovers the
#' sub-populations of methods that see the model differently — marginal
#' against conditional importance measures typically separate here whenever
#' the predictors are correlated, and that separation is itself the finding.
#'
#' The groups are k-medians in ranking space: each group's centre is the Kemeny
#' median of its members, computed by [consensus_rank()], and each judge belongs
#' to the group whose centre it is closest to. The centre of a group is
#' therefore a consensus ranking — the object worth reporting — rather than a
#' point in some embedding.
#'
#' @section Why this returns the same answer twice:
#' Nothing here draws from the RNG. The starting partition is the exactly
#' optimal set of medoids, found by enumerating every one of them while the
#' panel is small enough to allow it, and the refinement is deterministic;
#' ties are broken on the lowest index. A panel of judges is small, so the
#' usual reason for random restarts — an initialisation too expensive to
#' optimise — does not apply, and an inference function that answered
#' differently on every call would be worth less than the answer it gives.
#'
#' Above `medoid_limit` candidate sets the enumeration is replaced by a greedy
#' choice, which is still deterministic but no longer certified optimal; the
#' returned object says which was used.
#'
#' @section Whether to split at all:
#' The panel is left whole unless it groups more sharply than a single
#' population of judges would. That test is not decoration. The average
#' silhouette width on its own divides a homogeneous panel far too readily,
#' because two judges who happen to rank alike sit at distance zero and score a
#' silhouette of exactly 1: on eight variables and six judges one transposition
#' apart, the silhouette alone split a single population 62% of the time. Those
#' same zero distances are what makes a real division obvious, so the statistic
#' cannot tell the two cases apart by itself — it has to be told what one
#' population looks like.
#'
#' So the panel's best split in two is compared against the best split in two
#' of `n_null` panels drawn from one population, spread to match the mean
#' distance between the judges actually supplied. The panel is divided only
#' when fewer than `alpha` of those reference panels split as sharply. What the
#' test costs in divisions missed, and what it buys in divisions not invented,
#' is measured in `inst/simulations/cluster-recovery.R`.
#'
#' @section What it is measured to do:
#' From that script, 300 panels per cell of eight variables. A panel drawn from
#' **one population** is divided anyway 2.0% of the time at six judges (4.0%
#' when those judges are noisier), 5.3% at ten and 8.3% at sixteen, against a
#' nominal `alpha` of 5%. Two well-separated
#' populations are recovered exactly 0.877 of the time at six judges, 0.873 at
#' ten and 0.943 at sixteen; on groups that are close, or judges that are noisy,
#' it falls a long way — 0.360 at six judges with the group centres four
#' transpositions apart, and 0.073 when the judges stray three.
#'
#' On real panels of permutation against LOCO judges over correlated
#' predictors, 100 datasets per cell, the panel divides in two 23 times in 100
#' at a correlation of 0.9 with six judges and 82 times in 100 with sixteen.
#' All 23 of the six-judge divisions fell exactly on the method families; 69 of
#' the 82 at sixteen judges did. Panel size is what buys sensitivity here, and
#' six judges — two methods by three seeds — has little of it.
#' `vignette("method-disagreement")` works through one of the panels that does
#' not divide.
#'
#' The hypothesis is "one population", so the statistic is the best division in
#' two, not the best over every `k`. Testing the maximum over `k` sounds more
#' general and is worse: the reference pays a multiplicity that grows with the
#' panel, and power falls away as judges are added. Measured on two clearly
#' separated groups at the same level: 0.233 at six judges down to 0.067 at
#' twelve for the maximum, against 0.633 up to 0.917 for the two-group
#' statistic.
#'
#' A panel the test rejects is therefore reported as divided **in two**, which
#' is the division the evidence is about. Reading `k` off the largest
#' silhouette instead attaches an uncalibrated number to a calibrated decision,
#' and it measures worse: on two separated groups the partition is recovered
#' exactly 0.943 of the time at sixteen judges against 0.690 for the largest
#' silhouette, at the same false division rate. It is also what made larger
#' panels perform worse — recovery fell from 0.877 at six judges to 0.690 at
#' sixteen, and now rises to 0.943. Pass `k` explicitly to fit any other
#' number; a panel that genuinely holds three groups is reported as two.
#'
#' All of it is read off the distances alone, through the exactly optimal
#' medoid partitions — which is what makes hundreds of reference panels
#' affordable. Which judge goes where, and what each group ranks, is the
#' k-medians refinement of that partition.
#'
#' @section Reproducibility:
#' The reference panels are drawn from `seed`, and the session's random stream
#' is put back where it was found: a call neither depends on the stream nor
#' disturbs it, and two calls on the same panel agree down to the p-value.
#'
#' @param judges A `judges` object or a ranking matrix.
#' @param k Number of clusters, or `NULL` to select it automatically.
#' @param weights Optional per-judge weights, one per row. Taken from a
#'   `judges` panel when it carries them. They weigh each group's consensus,
#'   not the distances.
#' @param algorithm Solver used for each group's consensus, passed to
#'   [consensus_rank()].
#' @param n_null Panels drawn from a single population to judge the observed
#'   grouping against. `0` skips the test, and the largest silhouette then wins
#'   outright. Ignored when `k` is given.
#' @param alpha How rarely a single population must group as sharply as this
#'   panel does before the panel is called divided.
#' @param seed Seed for the reference panels. The caller's random stream is
#'   restored afterwards.
#' @param medoid_limit Largest number of candidate medoid sets to enumerate
#'   before falling back on a greedy start.
#' @return An object of class `judge_clusters`, a list with elements
#'   `clustering` (a tibble of judge, cluster and silhouette width), `cluster`
#'   (the same assignment as a named integer vector), `k`, `centres` (the group
#'   consensus rankings, one per row), `consensus` (the `consensus_rank` object
#'   behind each centre), `distances` (the Kemeny-Snell distances between
#'   judges), `criterion` (the silhouette at every `k` the search could have
#'   used, reported so the shape of the panel can be inspected — the automatic
#'   choice is the test's, not this column's maximum), `test` (the observed
#'   statistic, its p-value against one population, and the spread the
#'   reference panels were given), and the settings used.
#' @examples
#' # Three judges who rank by one logic, three by another. Four variables would
#' # not be enough for the test to call it: with 24 possible rankings a panel
#' # groups this sharply by chance often enough to matter.
#' judges <- rbind(
#'   permutation_1 = c(1, 2, 3, 4, 5, 6), permutation_2 = c(1, 2, 3, 4, 6, 5),
#'   permutation_3 = c(2, 1, 3, 4, 5, 6), impurity_1    = c(6, 5, 4, 3, 2, 1),
#'   impurity_2    = c(5, 6, 4, 3, 2, 1), impurity_3    = c(6, 5, 4, 3, 1, 2)
#' )
#' colnames(judges) <- c("income", "age", "balance", "region", "tenure", "arrears")
#'
#' het <- judge_clusters(judges)
#' het
#' split(rownames(judges), het$cluster)
#'
#' @seealso [item_consensus()] for the same question asked one judge at a time,
#'   [autoplot.judge_clusters()] to see the panel in Kemeny-Snell space.
#' @export
judge_clusters <- function(judges, k = NULL, weights = NULL,
                           algorithm = c("auto", "exact", "quick", "fast", "decor"),
                           n_null = 199L, alpha = 0.05, seed = 1L,
                           medoid_limit = 20000L) {
  algorithm <- match.arg(algorithm)
  if (is.null(weights) && inherits(judges, "judges")) {
    weights <- attr(judges, "weights")
  }
  x <- validate_rankings(judges)
  m <- nrow(x)
  if (m < 2L) {
    stop("`judges` needs at least two judges to be grouped.", call. = FALSE)
  }
  if (!is.null(weights) && length(weights) != m) {
    stop("`weights` must have one entry per judge: expected ", m,
         ", got ", length(weights), ".", call. = FALSE)
  }
  if (!is.null(k)) {
    k <- as.integer(k)
    if (is.na(k) || k < 1L || k > m) {
      stop("`k` must lie between 1 and the number of judges (", m, ").",
           call. = FALSE)
    }
  }

  labels <- rownames(x)
  if (is.null(labels)) labels <- paste0("judge_", seq_len(m))

  d <- kemeny_distances(x)

  # Selecting `k` means fitting every `k` worth considering; being handed one
  # means fitting that one. A panel of judges is small, but not so small that
  # twenty discarded fits are free.
  # Judges with identical rankings cannot be told apart, so they cannot be put
  # in different groups: the panel supports at most as many groups as it has
  # distinct rankings. Asking for more leaves a group empty, which is how the
  # silhouette ends up taking a minimum over nothing.
  distinct <- sum(!duplicated(x))
  if (!is.null(k) && k > distinct) {
    stop("`k` cannot exceed the ", distinct, " distinct rankings in the panel ",
         "(", m, " judges, some ranking alike).", call. = FALSE)
  }

  selected <- if (is.null(k)) "test" else "given"
  # A group holding one judge is not a sub-population, it is an outlier, and
  # `item_consensus()` is what reports those. Restricting the search to
  # partitions that could give every group two judges also halves the number of
  # partitions each reference panel has to be scored on.
  k_max <- min(m %/% 2L, distinct)
  candidates <- if (k_max >= 2L) 2:k_max else integer(0)

  widths <- medoid_silhouettes(d, candidates, medoid_limit)
  test <- NULL
  if (is.null(k)) {
    if (length(candidates) == 0L) {
      k <- 1L
    } else if (n_null > 0L) {
      # The question put to the reference is whether the panel is one
      # population, and the statistic that asks it is the best split in two.
      # Taking the sharpest grouping over every `k` instead makes the reference
      # pay a multiplicity that grows with the panel, and the test then loses
      # power exactly where more judges should have bought it: measured on two
      # well-separated groups, 0.233 at six judges falling to 0.067 at twelve,
      # against 0.633 rising to 0.917 for the two-group statistic at the same
      # level. How many groups there are is an estimate afterwards, not a
      # second hypothesis.
      test <- split_test(d, m, ncol(x), 2L, n_null, seed, medoid_limit,
                         observed = widths[[1L]])
      # The evidence is about a division in two, so a division in two is what
      # gets reported. Taking `which.max(widths)` here instead would attach an
      # uncalibrated number to a calibrated decision: the raw silhouette is the
      # statistic that splits a homogeneous panel 62% of the time, and its
      # maximum is taken over a candidate set that widens with the panel. It
      # chose k >= 4 on every homogeneous panel of ten judges or more that the
      # test rejected, and never k = 2. Measured on two separated groups, the
      # partition is recovered exactly 0.943 of the time at sixteen judges
      # against 0.690 for the maximum, at an identical false division rate --
      # identical because the test is the same. A panel that really holds three
      # groups is reported as two; `k` given explicitly still fits any number.
      k <- if (test$p_value < alpha) 2L else 1L
    } else {
      k <- candidates[which.max(widths)]
    }
  }

  criterion <- tibble::tibble(
    k = c(1L, candidates),
    silhouette = c(NA_real_, widths)
  )

  fit <- if (k == 1L) {
    whole_panel_fit(x, weights, algorithm)
  } else {
    kemeny_kmedians(x, d, k, weights, algorithm, medoid_limit)
  }

  assignment <- stats::setNames(fit$cluster, labels)
  structure(
    list(
      clustering = tibble::tibble(
        judge = labels,
        cluster = fit$cluster,
        silhouette = if (k == 1L) rep(NA_real_, m) else silhouette_widths(d, fit$cluster)
      )[order(fit$cluster, labels), ],
      cluster = assignment,
      k = k,
      centres = fit$centres,
      consensus = fit$consensus,
      distances = d,
      criterion = criterion,
      test = test,
      within = fit$within,
      judges = x,
      weights = weights,
      algorithm = algorithm,
      exact_start = fit$exact_start,
      alpha = alpha,
      selected = selected
    ),
    class = "judge_clusters"
  )
}

#' @param x A `judge_clusters` object.
#' @param ... Unused.
#' @rdname judge_clusters
#' @export
print.judge_clusters <- function(x, ...) {
  cat("<judge_clusters>\n")
  cat("  judges    :", nrow(x$judges),
      if (!is.null(x$weights)) "(weighted)" else "", "\n")
  cat("  variables :", ncol(x$judges), "\n")
  cat("  clusters  :", x$k,
      if (x$selected == "given") {
        "(given)"
      } else if (is.null(x$test)) {
        "(nothing to test)"
      } else {
        paste0("(silhouette ", round(x$test$statistic, 3), ", p = ",
               format.pval(x$test$p_value, digits = 2), " against one population)")
      }, "\n")
  cat("  start     :", if (x$exact_start) "enumerated medoids" else "greedy medoids", "\n")
  cat("\n")
  print(x$clustering, n = Inf)
  if (x$k > 1L) {
    cat("\nGroup consensus:\n")
    print(x$centres)
  }
  invisible(x)
}

#' Kemeny-Snell distances between the judges of a panel
#'
#' `ConsRank::kemenyd()` wants a plain matrix; a `judges` object carries
#' provenance, scores and a recipe, which it does not want. Stripped the same
#' way `judge_weights()` strips it before `tau_x()`.
#'
#' @param x A validated ranking matrix.
#' @return A `dist` of Kemeny-Snell distances.
#' @noRd
kemeny_distances <- function(x) {
  plain <- x
  attributes(plain) <- attributes(plain)[c("dim", "dimnames")]
  d <- ConsRank::kemenyd(plain)
  labels <- rownames(x)
  if (is.null(labels)) labels <- paste0("judge_", seq_len(nrow(x)))
  attr(d, "Labels") <- labels
  d
}

#' Distance from every judge to one ranking
#' @noRd
distance_to_centre <- function(x, centre) {
  plain <- x
  attributes(plain) <- attributes(plain)[c("dim", "dimnames")]
  as.numeric(ConsRank::kemenyd(plain, centre))
}

#' The Kemeny median of a group of judges, as a one-row matrix
#'
#' Reuses [consensus_rank()] rather than calling the solver directly, so that a
#' group's centre is the same object, computed the same way and with the same
#' handling of several equally optimal medians, as the consensus of a whole
#' panel.
#'
#' @noRd
group_centre <- function(x, rows, weights, algorithm) {
  cr <- consensus_rank(
    x[rows, , drop = FALSE],
    weights = if (is.null(weights)) NULL else weights[rows],
    algorithm = algorithm
  )
  centre <- matrix(
    cr$ranking$rank[match(colnames(x), cr$ranking$variable)],
    nrow = 1L, dimnames = list(NULL, colnames(x))
  )
  list(centre = centre, consensus = cr)
}

#' k-medians in Kemeny space, from an exactly optimal start
#'
#' Lloyd's algorithm with the Kemeny median as the centre of a group. The start
#' is the best set of `k` medoids, which is enumerated exactly while the number
#' of candidate sets stays under `medoid_limit`.
#'
#' An iteration that would empty a group is discarded and the previous
#' partition kept: `k` groups were asked for, and the alternative — moving a
#' judge in to refill the group — has no non-arbitrary choice of which judge.
#'
#' @return A list with `cluster`, `centres`, `consensus`, `within` and
#'   `exact_start`.
#' @noRd
kemeny_kmedians <- function(x, d, k, weights, algorithm, medoid_limit = 20000L,
                            max_iter = 50L) {
  start <- initial_medoids(d, k, medoid_limit)
  assignment <- start$cluster

  for (iter in seq_len(max_iter)) {
    centres <- lapply(sort(unique(assignment)), function(g)
      group_centre(x, which(assignment == g), weights, algorithm))
    to_centre <- vapply(centres, function(cc) distance_to_centre(x, cc$centre),
                        numeric(nrow(x)))
    if (!is.matrix(to_centre)) to_centre <- matrix(to_centre, nrow = nrow(x))
    # Nearest centre, ties to the lowest index: the whole function is
    # deterministic or it is not.
    proposed <- max.col(-to_centre, ties.method = "first")
    if (length(unique(proposed)) < k) break
    if (identical(proposed, assignment)) break
    assignment <- proposed
  }

  centres <- lapply(sort(unique(assignment)), function(g)
    group_centre(x, which(assignment == g), weights, algorithm))
  centre_matrix <- do.call(rbind, lapply(centres, `[[`, "centre"))
  rownames(centre_matrix) <- paste0("cluster_", sort(unique(assignment)))
  to_centre <- vapply(centres, function(cc) distance_to_centre(x, cc$centre),
                      numeric(nrow(x)))
  if (!is.matrix(to_centre)) to_centre <- matrix(to_centre, nrow = nrow(x))

  list(
    cluster = as.integer(assignment),
    centres = centre_matrix,
    consensus = stats::setNames(lapply(centres, `[[`, "consensus"),
                                rownames(centre_matrix)),
    within = sum(to_centre[cbind(seq_len(nrow(x)), assignment)]),
    exact_start = start$exact
  )
}

#' The panel left whole, in the shape `kemeny_kmedians()` returns
#' @noRd
whole_panel_fit <- function(x, weights, algorithm) {
  one <- group_centre(x, seq_len(nrow(x)), weights, algorithm)
  centre_matrix <- one$centre
  rownames(centre_matrix) <- "cluster_1"
  list(
    cluster = rep(1L, nrow(x)),
    centres = centre_matrix,
    consensus = list(cluster_1 = one$consensus),
    within = sum(distance_to_centre(x, one$centre)),
    exact_start = TRUE
  )
}

#' Average silhouette width of the optimal medoid partition, at every `k`
#'
#' The statistic both the choice of `k` and the test against one population are
#' read from. It touches nothing but the distance matrix, which is what makes
#' hundreds of reference panels affordable: the k-medians refinement costs a
#' Kemeny solve per group per iteration, and this costs none.
#'
#' A panel supports as many groups as it has distinct rankings, and a reference
#' panel drawn from one population often has fewer than the observed one: `NA`
#' marks a `k` that panel cannot reach, rather than an error from asking for
#' more medoids than there are places to put them.
#'
#' @return One mean width per entry of `candidates`; `numeric(0)` when there is
#'   no candidate to score.
#' @noRd
medoid_silhouettes <- function(d, candidates, medoid_limit = 20000L) {
  reachable <- sum(!duplicated(as.matrix(d)))
  vapply(candidates, function(k) {
    if (k > reachable) return(NA_real_)
    mean(silhouette_widths(d, initial_medoids(d, k, medoid_limit)$cluster))
  }, numeric(1))
}

#' The sharpest grouping a panel admits, or zero when it admits none
#' @noRd
sharpest_grouping <- function(widths) {
  if (!length(widths) || all(is.na(widths))) 0 else max(widths, na.rm = TRUE)
}

#' One ranking, `steps` adjacent transpositions away from the identity
#'
#' A random walk on adjacent transpositions, which is how far a judge strays
#' from its population's centre. Zero steps returns the centre and enough steps
#' forget it, so `steps` is the dial that sets a population's spread. Only the
#' distances between the sampled rankings matter downstream, and the Kemeny
#' distance is unchanged by relabelling the variables of both rankings at once,
#' so walking from the identity is as general as walking from any centre.
#'
#' @noRd
random_walk_ranking <- function(p, steps) {
  order_of <- seq_len(p)
  for (s in seq_len(steps)) {
    i <- sample.int(p - 1L, 1L)
    order_of[c(i, i + 1L)] <- order_of[c(i + 1L, i)]
  }
  out <- integer(p)
  out[order_of] <- seq_len(p)
  out
}

#' A panel of `m` judges drawn from one population
#' @noRd
null_panel <- function(m, p, steps) {
  out <- t(vapply(seq_len(m), function(i) random_walk_ranking(p, steps),
                  integer(p)))
  colnames(out) <- paste0("V", seq_len(p))
  out
}

#' How far a single population has to spread to look like this panel
#'
#' Matched on distances between judges rather than on distances to a centre: it
#' is what the silhouette reads, and it needs no centre, which spares the
#' question of what a tied consensus means for a sampler producing linear
#' orders.
#'
#' Matched on their mean. A low quantile was tried, on the argument that the
#' mean is inflated by the very structure being tested for and should cost
#' power; measured, it cost far more. Matching the 25th percentile of a split
#' panel targets a within-group distance, which makes the reference population
#' tight, and a tight population repeats itself: its panels fill with identical
#' rankings, identical rankings sit at distance zero, and a reference panel
#' full of zero distances scores a silhouette near 1. The reference then
#' becomes almost impossible to beat. On two groups sixteen transpositions
#' apart the split was found 0.805 of the time with the mean and 0.173 with the
#' quantile, at the same level. The mean it is.
#'
#' The walk saturates — past a certain length the rankings are uniform and the
#' distances stop growing — so a panel more scattered than uniform is matched
#' by the longest walk on the grid, which is as close as one population comes.
#'
#' @param target The observed panel's mean pairwise distance.
#' @return The number of transpositions, one of the values on the grid.
#' @noRd
calibrate_spread <- function(target, m, p, panels = 30L) {
  grid <- unique(round(exp(seq(0, log(4 * p * p), length.out = 16L))))
  reached <- vapply(grid, function(steps) {
    mean(vapply(seq_len(panels),
                function(b) mean(ConsRank::kemenyd(null_panel(m, p, steps))),
                numeric(1)))
  }, numeric(1))
  grid[which.min(abs(reached - target))]
}

#' Does this panel divide more sharply than one population would?
#'
#' The observed statistic is the panel's sharpest division in two. The
#' reference is the same quantity on panels of the same shape drawn from a
#' single population spread to match, and the p-value is the usual Monte Carlo
#' one, never zero. `candidates` is `2L` for the test itself; the argument is
#' kept general because the same machinery scores the reference panels.
#'
#' The reference panels come from `seed` and the caller's stream is put back
#' afterwards, so the p-value is a property of the panel and not of when the
#' function happened to be called.
#'
#' @return A list with `statistic`, `p_value`, `steps`, `n_null`, `null_mean`.
#' @noRd
split_test <- function(d, m, p, candidates, n_null, seed, medoid_limit,
                       observed) {
  entry_state <- capture_seed()
  on.exit(restore_seed(entry_state), add = TRUE)
  set.seed(seed)

  target <- mean(d)
  if (max(d) == 0) {
    # Every judge ranks alike: there is nothing for a reference to be sharper
    # or blunter than.
    return(list(statistic = observed, p_value = 1, steps = 0L,
                n_null = as.integer(n_null), null_mean = NA_real_))
  }

  steps <- calibrate_spread(target, m, p)
  null_stat <- vapply(seq_len(n_null), function(b) {
    sharpest_grouping(medoid_silhouettes(
      ConsRank::kemenyd(null_panel(m, p, steps)), candidates, medoid_limit))
  }, numeric(1))

  list(
    statistic = observed,
    p_value = (1 + sum(null_stat >= observed)) / (n_null + 1),
    steps = steps,
    n_null = as.integer(n_null),
    null_mean = mean(null_stat)
  )
}

#' The best `k` medoids, exactly when that is affordable
#'
#' Enumeration returns the certified optimum. The greedy fallback is the usual
#' build: the most central judge first, then whichever judge reduces the total
#' distance to the nearest medoid most. Both break ties on the lowest index.
#'
#' @return A list with `cluster` and `exact`.
#' @noRd
initial_medoids <- function(d, k, medoid_limit = 20000L) {
  D <- as.matrix(d)
  m <- nrow(D)
  # Two medoids at distance zero are the same medoid twice, and one of the two
  # groups would be empty from the start. Only one judge per distinct ranking
  # is eligible; the rest join whichever group it lands in.
  eligible <- which(!duplicated(D))
  assign_to <- function(medoids) max.col(-D[, medoids, drop = FALSE], ties.method = "first")
  cost <- function(medoids) sum(apply(D[, medoids, drop = FALSE], 1L, min))

  exact <- choose(length(eligible), k) <= medoid_limit
  if (exact) {
    sets <- utils::combn(eligible, k)
    costs <- apply(sets, 2L, cost)
    medoids <- sets[, which.min(costs)]
  } else {
    medoids <- eligible[which.min(colSums(D)[eligible])]
    while (length(medoids) < k) {
      rest <- setdiff(eligible, medoids)
      gains <- vapply(rest, function(j) cost(c(medoids, j)), numeric(1))
      medoids <- c(medoids, rest[which.min(gains)])
    }
  }
  list(cluster = as.integer(assign_to(sort(medoids))), exact = exact)
}

#' Silhouette width of every judge
#'
#' Written out rather than taken from a dependency used for this one number.
#' `cluster::silhouette()` is the reference, and a test checks the two agree.
#' The conventions are its own: a judge alone in its group scores 0, and so
#' does a judge at distance zero from everything.
#'
#' @return A numeric vector, one width per judge.
#' @noRd
silhouette_widths <- function(d, cluster) {
  D <- as.matrix(d)
  groups <- unique(cluster)
  if (length(groups) < 2L) {
    return(rep(0, length(cluster)))
  }
  vapply(seq_along(cluster), function(i) {
    own <- cluster == cluster[i]
    if (sum(own) == 1L) return(0)
    own[i] <- FALSE
    a <- mean(D[i, own])
    b <- min(vapply(setdiff(groups, cluster[i]),
                    function(g) mean(D[i, cluster == g]), numeric(1)))
    if (max(a, b) == 0) 0 else (b - a) / max(a, b)
  }, numeric(1))
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
  # The reported consensus, not an arbitrary one of the optima: when the median
  # is not unique `consensus_rank()` combines them and ties what they disagree
  # about, and a judge has to be scored against what the user was shown.
  consensus <- matrix(
    cr$ranking$rank[match(colnames(judges), cr$ranking$variable)],
    nrow = 1L
  )

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
