panel <- function() {
  J <- rbind(
    j1 = c(1, 2, 3, 4, 5),
    j2 = c(1, 2, 3, 5, 4),
    j3 = c(2, 1, 3, 4, 5),
    j4 = c(1, 3, 2, 4, 5),
    j5 = c(1, 2, 4, 3, 5),
    j6 = c(2, 1, 3, 5, 4)
  )
  colnames(J) <- c("income", "age", "balance", "region", "tenure")
  J
}

test_that("rank_confsets returns an interval that contains the point estimate", {
  set.seed(1)
  cb <- rank_confsets(consensus_rank(panel()), n_boot = 200)

  expect_s3_class(cb, "rank_confsets")
  expect_identical(nrow(cb$confsets), 5L)
  expect_true(all(cb$confsets$lower <= cb$confsets$rank))
  expect_true(all(cb$confsets$rank <= cb$confsets$upper))
  expect_identical(dim(cb$ranks), c(200L, 5L))
  expect_false(anyNA(cb$ranks))
})

test_that("a unanimous panel has degenerate confidence sets", {
  # Every resample of identical judges is the same panel, so there is nothing
  # for the bootstrap to find.
  U <- rbind(c(1, 2, 3), c(1, 2, 3), c(1, 2, 3))
  colnames(U) <- c("a", "b", "c")

  set.seed(1)
  cb <- rank_confsets(consensus_rank(U), n_boot = 100)

  expect_equal(cb$confsets$lower, cb$confsets$rank)
  expect_equal(cb$confsets$upper, cb$confsets$rank)
})

test_that("a wider level gives wider or equal intervals", {
  set.seed(1)
  narrow <- rank_confsets(consensus_rank(panel()), n_boot = 300, level = 0.5)
  set.seed(1)
  wide <- rank_confsets(consensus_rank(panel()), n_boot = 300, level = 0.99)

  expect_true(all(wide$confsets$lower <= narrow$confsets$lower))
  expect_true(all(wide$confsets$upper >= narrow$confsets$upper))
})

test_that("judge weights survive the bootstrap", {
  J <- panel()
  set.seed(1)
  cr <- consensus_rank(J, weights = c(1, 1, 1, 1, 1, 5))
  cb <- rank_confsets(cr, n_boot = 200)

  # The heavily weighted judge puts `age` first, and the bootstrap agrees.
  expect_identical(cr$ranking$variable[1], "age")
  expect_identical(cb$confsets$variable[1], "age")
})

test_that("the bootstrap defaults to a heuristic and says which", {
  set.seed(1)
  cb <- rank_confsets(consensus_rank(panel()), n_boot = 20)

  expect_identical(cb$algorithm, "quick")
  expect_output(print(cb), "quick")
})

test_that("rank_confsets validates its arguments", {
  cr <- consensus_rank(panel())

  expect_error(rank_confsets(1), "must be a `consensus_rank` object")
  expect_error(rank_confsets(cr, n_boot = 1), "at least 2")
  expect_error(rank_confsets(cr, level = 1.5), "strictly between 0 and 1")
  expect_error(rank_confsets(cr, level = 0), "strictly between 0 and 1")
})

test_that("prob_topk is a probability, monotone in k", {
  set.seed(1)
  cb <- rank_confsets(consensus_rank(panel()), n_boot = 200)

  p2 <- prob_topk(cb, k = 2)
  p4 <- prob_topk(cb, k = 4)

  expect_true(all(p2$probability >= 0 & p2$probability <= 1))
  expect_identical(p2$variable[1], "income")

  # Same variables, ordered by probability; compare after aligning.
  m2 <- stats::setNames(p2$probability, p2$variable)
  m4 <- stats::setNames(p4$probability, p4$variable)
  expect_true(all(m4[names(m2)] >= m2[names(m2)]))
})

test_that("prob_topk of the full set is one for every variable", {
  set.seed(1)
  cb <- rank_confsets(consensus_rank(panel()), n_boot = 100)

  expect_equal(prob_topk(cb, k = 5)$probability, rep(1, 5))
})

test_that("prob_topk validates k", {
  set.seed(1)
  cb <- rank_confsets(consensus_rank(panel()), n_boot = 20)

  expect_error(prob_topk(cb, k = 0), "between 1 and")
  expect_error(prob_topk(cb, k = 99), "between 1 and")
  expect_error(prob_topk(1), "must be a `rank_confsets` object")
})

test_that("rank_select keeps only variables whose whole interval clears the bar", {
  set.seed(1)
  cb <- rank_confsets(consensus_rank(panel()), n_boot = 200)

  selected <- rank_select(cb, threshold = 2)
  expect_setequal(selected, cb$confsets$variable[cb$confsets$upper <= 2])

  # Nothing clears a bar of zero; everything clears a bar of p.
  expect_length(rank_select(cb, threshold = 1), 0L)
  expect_length(rank_select(cb, threshold = 5), 5L)
})

test_that("rank_select validates its arguments", {
  set.seed(1)
  cb <- rank_confsets(consensus_rank(panel()), n_boot = 20)

  expect_error(rank_select(1), "must be a `rank_confsets` object")
  expect_error(rank_select(cb, threshold = 0), "at least 1")
  expect_error(rank_select(cb, threshold = NA), "at least 1")
})

test_that("autoplot builds a ggplot from the confidence sets", {
  skip_if_not_installed("ggplot2")
  set.seed(1)
  cb <- rank_confsets(consensus_rank(panel()), n_boot = 50)

  p <- autoplot(cb)
  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))
})

test_that("autoplot is exported, not merely imported", {
  # Importing the ggplot2 generic makes it visible inside the package; only
  # re-exporting it makes `autoplot(cb)` work after `library(rankimp)`. A
  # vignette caught this the hard way.
  expect_true("autoplot" %in% getNamespaceExports("rankimp"))
})
