judges_matrix <- function() {
  J <- rbind(
    c(1, 2, 3, 4),
    c(1, 2, 3, 4),
    c(1, 3, 2, 4),
    c(2, 1, 3, 4)
  )
  colnames(J) <- c("income", "age", "balance", "region")
  J
}

test_that("the consensus recovers a ranking the judges mostly agree on", {
  cr <- consensus_rank(judges_matrix())

  expect_s3_class(cr, "consensus_rank")
  expect_identical(
    cr$ranking$variable,
    c("income", "age", "balance", "region")
  )
  expect_identical(cr$ranking$rank, 1:4)
})

test_that("unanimous judges yield a perfect agreement", {
  J <- rbind(c(1, 2, 3), c(1, 2, 3), c(1, 2, 3))
  colnames(J) <- c("a", "b", "c")
  cr <- consensus_rank(J)

  expect_equal(cr$tau, 1)
  expect_identical(cr$ranking$variable, c("a", "b", "c"))
})

test_that("weighting a judge heavily enough pulls the consensus to it", {
  J <- judges_matrix()
  unweighted <- consensus_rank(J)
  weighted <- consensus_rank(J, weights = c(1, 1, 1, 5))

  expect_identical(unweighted$ranking$variable[1], "income")
  expect_identical(weighted$ranking$variable[1], "age")
  expect_true(weighted$weighted)
})

test_that("ties in the consensus survive by default and vanish on request", {
  J <- rbind(c(1, 1, 3, 4), c(1, 1, 3, 4), c(2, 1, 3, 4))
  colnames(J) <- colnames(judges_matrix())

  with_ties <- consensus_rank(J, ties = TRUE)
  expect_true(anyDuplicated(with_ties$ranking$rank) > 0L)

  linear <- consensus_rank(J, ties = FALSE)
  expect_identical(anyDuplicated(linear$ranking$rank), 0L)
})

test_that("the algorithm is chosen from the number of variables", {
  expect_identical(resolve_algorithm("auto", 4L), "BB")
  expect_identical(resolve_algorithm("auto", 12L), "BB")
  expect_identical(resolve_algorithm("auto", 13L), "quick")
  expect_identical(resolve_algorithm("auto", 50L), "quick")
  expect_message(expect_identical(resolve_algorithm("auto", 51L), "fast"))
})

test_that("an explicit algorithm overrides the automatic choice", {
  expect_identical(resolve_algorithm("exact", 99L), "BB")
  expect_identical(resolve_algorithm("quick", 3L), "quick")
})

test_that("malformed ranking matrices are rejected", {
  expect_error(consensus_rank(matrix("a", 2, 2)), "numeric matrix")
  expect_error(consensus_rank(matrix(c(1, NA, 2, 1), 2, 2)), "missing values")
  expect_error(consensus_rank(matrix(1:2, nrow = 2, ncol = 1)), "two variables")
  expect_error(consensus_rank(matrix(c(0, 1, 1, 2), 2, 2)), "Ranks must start at 1")
})

test_that("a judge whose best rank is not 1 is rejected", {
  # The old check was `any(x < 1)`, which waves through a matrix of importance
  # scores as long as every entry exceeds one, and waves through a ranking that
  # starts at 2. Both are user errors worth naming.
  offset <- rbind(c(2, 3, 4, 5), c(2, 3, 4, 5))

  expect_error(consensus_rank(offset), "Ranks must start at 1")
  expect_error(consensus_rank(offset), "importance_to_rank")
})

test_that("the error names the offending judges", {
  panel <- rbind(c(1, 2, 3), c(4, 5, 6), c(1, 2, 3))

  expect_error(consensus_rank(panel), "Judge 2")
})

test_that("the consensus keeps the panel it was computed from", {
  J <- judges_matrix()
  cr <- consensus_rank(J, weights = c(1, 1, 1, 2))

  # rank_confsets() bootstraps the judges, and cannot do that from a ranking.
  expect_identical(cr$judges, J)
  expect_identical(cr$weights, c(1, 1, 1, 2))
})

test_that("an unweighted consensus records no weights", {
  cr <- consensus_rank(judges_matrix())

  expect_null(cr$weights)
  expect_false(cr$weighted)
})

test_that("a degenerate panel does not leak ConsRank's commentary", {
  # Two judges in perfect opposition: the combined input matrix is all zeros and
  # ConsRank announces the fact with print(). Nothing should reach the console.
  J <- rbind(c(1, 2), c(2, 1))

  expect_silent(cr <- consensus_rank(J))
  expect_equal(cr$tau, 0)
})

test_that("weights are validated against the panel", {
  J <- judges_matrix()

  expect_error(consensus_rank(J, weights = c(1, 1)), "one entry per judge")
  expect_error(consensus_rank(J, weights = c(1, 1, 1, 0)), "must be positive")
  expect_error(consensus_rank(J, weights = c(1, 1, 1, NA)), "must be positive")
})

test_that("unnamed columns get placeholder variable names", {
  J <- rbind(c(1, 2, 3), c(1, 2, 3))
  cr <- consensus_rank(J)

  expect_identical(cr$ranking$variable, c("V1", "V2", "V3"))
})
