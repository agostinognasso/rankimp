test_that("item_consensus reports one tau_x per judge", {
  J <- rbind(
    permutation = c(1, 2, 3, 4),
    shap        = c(1, 3, 2, 4),
    impurity    = c(4, 3, 2, 1)
  )
  colnames(J) <- c("income", "age", "balance", "region")
  ic <- item_consensus(consensus_rank(J))

  expect_s3_class(ic, "tbl_df")
  expect_identical(nrow(ic), 3L)
  expect_setequal(ic$judge, rownames(J))
  expect_true(all(ic$tau_x >= -1 & ic$tau_x <= 1))
})

test_that("the mean of item_consensus is the consensus tau", {
  J <- rbind(c(1, 2, 3, 4), c(1, 2, 4, 3), c(2, 1, 3, 4), c(1, 3, 2, 4))
  colnames(J) <- letters[1:4]
  cr <- consensus_rank(J)

  expect_equal(mean(item_consensus(cr)$tau_x), cr$tau)
})

test_that("a judge in perfect agreement scores one", {
  J <- rbind(c(1, 2, 3), c(1, 2, 3), c(1, 2, 3))
  colnames(J) <- letters[1:3]
  ic <- item_consensus(consensus_rank(J))

  expect_equal(ic$tau_x, rep(1, 3))
})

test_that("judges are ordered from least to most agreeable", {
  J <- rbind(
    agrees    = c(1, 2, 3, 4),
    agrees2   = c(1, 2, 3, 4),
    dissents  = c(4, 3, 2, 1)
  )
  colnames(J) <- letters[1:4]
  ic <- item_consensus(consensus_rank(J))

  expect_identical(ic$judge[1], "dissents")
  expect_true(!is.unsorted(ic$tau_x))
})

test_that("unnamed judges get an index label, and weights are reported", {
  J <- rbind(c(1, 2, 3), c(3, 2, 1))
  colnames(J) <- letters[1:3]
  ic <- item_consensus(consensus_rank(J, weights = c(2, 1)))

  expect_setequal(ic$judge, c("judge_1", "judge_2"))
  expect_setequal(ic$weight, c(2, 1))
})

test_that("item_consensus rejects the wrong class", {
  expect_error(item_consensus(1), "must be a `consensus_rank` object")
})

# --- judge_clusters() -------------------------------------------------------

# Two logics, three judges each: the first three order the variables one way,
# the last three the reverse.
#
# Six variables and not four. On four the test declines to call this a division,
# and it is right to: 24 rankings exist, and six judges land this sharply by
# chance in about a tenth of panels drawn from one population. Measured, at p =
# 4: silhouette 0.737, p = 0.095. From five variables up the same panel gives p
# = 0.005.
split_panel <- function() {
  m <- rbind(
    permutation_1 = c(1, 2, 3, 4, 5, 6), permutation_2 = c(1, 2, 3, 4, 6, 5),
    permutation_3 = c(2, 1, 3, 4, 5, 6), impurity_1    = c(6, 5, 4, 3, 2, 1),
    impurity_2    = c(5, 6, 4, 3, 2, 1), impurity_3    = c(6, 5, 4, 3, 1, 2)
  )
  colnames(m) <- c("income", "age", "balance", "region", "tenure", "arrears")
  m
}

test_that("a panel built from two logics is split along them", {
  het <- judge_clusters(split_panel())

  expect_s3_class(het, "judge_clusters")
  expect_identical(het$k, 2L)
  expect_identical(
    unname(split(names(het$cluster), het$cluster)),
    list(paste0("permutation_", 1:3), paste0("impurity_", 1:3))
  )
})

test_that("a panel that does not split is left whole", {
  # The half of the problem that automatic selection usually gets wrong: five
  # judges who agree except on adjacent pairs are one population, and saying so
  # is the answer.
  m <- rbind(a = c(1, 2, 3, 4, 5, 6), b = c(1, 2, 3, 4, 5, 6),
             c = c(1, 2, 3, 4, 6, 5), d = c(2, 1, 3, 4, 5, 6),
             e = c(1, 3, 2, 4, 5, 6))
  colnames(m) <- c("income", "age", "balance", "region", "tenure", "arrears")

  het <- judge_clusters(m)

  expect_identical(het$k, 1L)
  expect_gt(het$test$p_value, 0.05)
  expect_true(all(het$cluster == 1L))
  expect_identical(nrow(het$centres), 1L)
})

test_that("the clustering is the same on every call", {
  # The reference panels are drawn from `seed` and the caller's stream is put
  # back, so neither the groups nor the p-value depend on when the function was
  # called.
  panel <- split_panel()
  set.seed(1)
  first <- judge_clusters(panel)
  set.seed(999)
  second <- judge_clusters(panel)
  runif(10)
  third <- judge_clusters(panel)

  expect_identical(first$cluster, second$cluster)
  expect_identical(first$cluster, third$cluster)
  expect_identical(first$centres, third$centres)
  expect_identical(first$test$p_value, third$test$p_value)
})

test_that("testing the panel leaves the caller's random stream alone", {
  panel <- split_panel()
  set.seed(7)
  expected <- runif(3)

  set.seed(7)
  invisible(judge_clusters(panel, n_null = 49))

  expect_identical(runif(3), expected)
})

test_that("a different seed is a different reference, not a different panel", {
  panel <- split_panel()

  a <- judge_clusters(panel, seed = 1L)
  b <- judge_clusters(panel, seed = 2L)

  expect_identical(a$cluster, b$cluster)
  expect_identical(a$test$statistic, b$test$statistic)
})

test_that("n_null = 0 asks for no reference and gets none", {
  # Without a reference the largest silhouette wins outright, which is the
  # behaviour that splits a homogeneous panel; it stays available and stays
  # off by default.
  homogeneous <- rbind(a = c(1, 2, 3, 4, 5, 6), b = c(1, 2, 3, 4, 5, 6),
                       c = c(1, 2, 3, 4, 6, 5), d = c(2, 1, 3, 4, 5, 6),
                       e = c(1, 3, 2, 4, 5, 6))
  colnames(homogeneous) <- paste0("x", 1:6)

  tested <- judge_clusters(homogeneous)
  untested <- judge_clusters(homogeneous, n_null = 0L)

  expect_identical(tested$k, 1L)
  expect_null(untested$test)
  expect_gt(untested$k, 1L)
})

test_that("the p-value is a Monte Carlo one and never zero", {
  het <- judge_clusters(split_panel(), n_null = 199L)

  expect_identical(het$test$p_value, 1 / 200)
  expect_identical(het$test$n_null, 199L)
  expect_gt(het$test$steps, 0L)
})

test_that("each group's centre is the consensus of its own members", {
  het <- judge_clusters(split_panel())
  panel <- split_panel()

  for (g in seq_len(het$k)) {
    members <- panel[het$cluster == g, , drop = FALSE]
    own <- consensus_rank(members)
    expect_identical(
      as.integer(het$centres[g, ]),
      as.integer(own$ranking$rank[match(colnames(panel), own$ranking$variable)])
    )
  }
})

test_that("the silhouette is the one cluster::silhouette computes", {
  # Written out in the package rather than depended on for a single number,
  # so it is checked against the reference implementation instead.
  skip_if_not_installed("cluster")
  panel <- split_panel()
  d <- kemeny_distances(panel)

  for (k in 2:5) {
    fit <- kemeny_kmedians(panel, d, k, NULL, "auto")
    reference <- cluster::silhouette(fit$cluster, d)
    expect_equal(
      silhouette_widths(d, fit$cluster),
      as.numeric(reference[, "sil_width"])
    )
  }
})

test_that("a given k is used as given, and a bad one is refused", {
  het <- judge_clusters(split_panel(), k = 3)

  expect_identical(het$k, 3L)
  expect_identical(length(unique(het$cluster)), 3L)
  expect_identical(het$selected, "given")
  expect_error(judge_clusters(split_panel(), k = 99), "between 1 and the number")
  expect_error(judge_clusters(split_panel(), k = 0), "between 1 and the number")
})

test_that("judge_clusters takes a panel and its weights", {
  skip_if_not_installed("randomForest")
  set.seed(50)
  J <- importance_judges(rf_reg, methods = c("permutation", "mdi"),
                         data = reg_data, target = "y", seeds = 1:2, n_perm = 2,
                         weights = c(permutation = 1, mdi = 0.5))

  het <- judge_clusters(J)

  expect_identical(length(het$cluster), nrow(J))
  expect_identical(names(het$cluster), rownames(J))
  expect_identical(het$weights, attr(J, "weights"))
})

test_that("judge_clusters refuses what it cannot group", {
  one <- matrix(c(1, 2, 3), nrow = 1)
  expect_error(judge_clusters(one), "at least two judges")
  expect_error(judge_clusters(split_panel(), weights = c(1, 2)),
               "one entry per judge")
})

test_that("judges who rank alike cannot be pulled into different groups", {
  # A real panel repeats itself: two methods often agree exactly. Medoids drawn
  # from identical rankings leave a group empty, and the silhouette then takes a
  # minimum over no other group at all. The panel supports as many groups as it
  # has distinct rankings, and no more.
  m <- rbind(a = c(1, 2, 3, 4), b = c(1, 2, 3, 4), c = c(1, 2, 3, 4),
             d = c(4, 3, 2, 1), e = c(4, 3, 2, 1))
  colnames(m) <- c("income", "age", "balance", "region")

  expect_no_warning(het <- judge_clusters(m))
  expect_identical(het$k, 2L)
  expect_identical(length(unique(het$cluster)), 2L)
  expect_error(judge_clusters(m, k = 3), "distinct rankings")
})

test_that("a panel of judges who all agree is one group", {
  m <- rbind(a = c(1, 2, 3), b = c(1, 2, 3), c = c(1, 2, 3))
  colnames(m) <- c("x", "y", "z")

  expect_no_warning(het <- judge_clusters(m))
  expect_identical(het$k, 1L)
})

test_that("autoplot builds a ggplot from the clusters", {
  skip_if_not_installed("ggplot2")
  het <- judge_clusters(split_panel())

  p <- autoplot(het)

  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))
  expect_match(p$labels$subtitle, "2 groups of 6 judges")
})

test_that("a judge_clusters object prints its groups", {
  het <- judge_clusters(split_panel())
  expect_output(print(het), "<judge_clusters>")
  expect_output(print(het), "enumerated medoids")
  expect_output(print(het), "Group consensus")
})

test_that("a rejected panel is divided in two, not into as many groups as the silhouette likes", {
  # Sixteen judges drawn from ONE population, a few adjacent transpositions
  # apart. The test rejects here (p = 0.025, which at alpha = 0.05 is the type I
  # error it is entitled to), and the question is what `k` comes back with that
  # rejection. The silhouette rises monotonically with `k` on a panel like this,
  # because judges who rank alike sit at distance zero and score 1 -- so reading
  # `k` off its maximum returned 8, eight groups for sixteen judges out of a
  # single population. The evidence is about a division in two.
  panel <- structure(c(
    1L, 2L, 2L, 1L, 2L, 2L, 1L, 2L, 2L, 1L, 1L, 2L, 1L, 1L, 1L, 1L,
    2L, 1L, 1L, 2L, 1L, 1L, 2L, 1L, 1L, 3L, 3L, 1L, 2L, 3L, 2L, 2L,
    3L, 3L, 3L, 3L, 4L, 3L, 3L, 3L, 4L, 2L, 2L, 3L, 4L, 2L, 3L, 3L,
    4L, 4L, 4L, 4L, 3L, 4L, 4L, 5L, 3L, 4L, 4L, 4L, 3L, 4L, 4L, 4L,
    5L, 6L, 5L, 5L, 5L, 5L, 5L, 4L, 5L, 5L, 5L, 6L, 5L, 5L, 5L, 5L,
    6L, 5L, 7L, 6L, 6L, 6L, 6L, 6L, 6L, 6L, 6L, 5L, 6L, 6L, 6L, 8L,
    7L, 7L, 6L, 7L, 7L, 8L, 7L, 7L, 7L, 8L, 8L, 7L, 8L, 8L, 7L, 6L,
    8L, 8L, 8L, 8L, 8L, 7L, 8L, 8L, 8L, 7L, 7L, 8L, 7L, 7L, 8L, 7L),
    dim = c(16L, 8L))
  dimnames(panel) <- list(paste0("j", 1:16), paste0("x", 1:8))

  het <- judge_clusters(panel)

  expect_lt(het$test$p_value, het$alpha)
  expect_identical(het$k, 2L)
  # The old rule's answer, so the test fails if the rule is put back.
  expect_gt(which.max(het$criterion$silhouette[-1]) + 1L, 2L)
})

test_that("the automatic k is two on panels that do divide, at every panel size", {
  # The contract on the branch that matters: when the test rejects, the answer
  # is two. Well-separated panels reject reliably, so this exercises the
  # rejecting path at each size rather than hoping a homogeneous panel trips it.
  # The silhouette keeps climbing past k = 2 on the larger panels, which is
  # exactly where the old rule went wrong.
  set.seed(11)
  step <- function(r, n) {
    for (s in seq_len(n)) { j <- sample.int(7L, 1L); r[c(j, j + 1L)] <- r[c(j + 1L, j)] }
    r
  }
  for (m in c(6L, 10L, 16L)) {
    far <- step(1:8, 16L)
    rows <- lapply(rep(1:2, each = m / 2L),
                   function(g) step(if (g == 1L) 1:8 else far, 1L))
    panel <- do.call(rbind, rows)
    dimnames(panel) <- list(paste0("j", seq_len(m)), paste0("x", 1:8))

    het <- judge_clusters(panel)
    expect_lt(het$test$p_value, het$alpha)
    expect_identical(het$k, 2L)
    expect_identical(length(unique(het$cluster)), 2L)
  }
  # An explicit k still fits what it is asked for.
  expect_identical(judge_clusters(panel, k = 4L)$k, 4L)
})
