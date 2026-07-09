test_that("importance scores become rankings with 1 as most important", {
  imp <- rbind(
    permutation = c(income = 0.31, age = 0.12, balance = 0.03),
    impurity    = c(income = 0.44, age = 0.20, balance = 0.05)
  )
  r <- importance_to_rank(imp)

  expect_equal(r, rbind(
    permutation = c(income = 1L, age = 2L, balance = 3L),
    impurity    = c(income = 1L, age = 2L, balance = 3L)
  ))
  expect_type(r, "integer")
})

test_that("variables a judge scores equally receive the same rank", {
  imp <- rbind(judge = c(a = 0.5, b = 0.2, c = 0.2, d = 0.1))
  r <- importance_to_rank(imp)

  expect_identical(unname(r[1, ]), c(1L, 2L, 2L, 4L))
})

test_that("a single judge stays a one-row matrix", {
  imp <- matrix(c(0.3, 0.1, 0.2), nrow = 1, dimnames = list("perm", c("a", "b", "c")))
  r <- importance_to_rank(imp)

  expect_true(is.matrix(r))
  expect_identical(dim(r), c(1L, 3L))
  expect_identical(unname(r[1, ]), c(1L, 3L, 2L))
})

test_that("rankings feed straight into the consensus", {
  set.seed(1)
  imp <- matrix(runif(15), nrow = 3, dimnames = list(NULL, letters[1:5]))
  cr <- consensus_rank(importance_to_rank(imp))

  expect_s3_class(cr, "consensus_rank")
  expect_identical(cr$n_items, 5L)
  expect_identical(cr$n_judges, 3L)
})

test_that("importance_to_rank rejects malformed input", {
  expect_error(importance_to_rank(matrix("a", 2, 2)), "numeric matrix")
  expect_error(importance_to_rank(matrix(c(1, NA, 2, 1), 2, 2)), "missing values")
})

test_that("not-yet-implemented entry points fail loudly", {
  expect_error(importance_judges(list()), "not implemented yet")
  expect_error(rank_confsets(1), "not implemented yet")
  expect_error(judge_clusters(1), "not implemented yet")
  expect_error(rank_select(1), "not implemented yet")
})
