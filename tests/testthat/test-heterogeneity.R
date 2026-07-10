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

test_that("the phase F4 clustering is still declared, not implemented", {
  expect_error(judge_clusters(1), "not implemented yet")
})
