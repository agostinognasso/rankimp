test_that("equal weights are one per judge", {
  m <- rbind(a = c(1, 2, 3), b = c(2, 1, 3))
  expect_identical(judge_weights(m), c(a = 1, b = 1))
})

test_that("method weights need provenance", {
  m <- rbind(c(1, 2, 3), c(2, 1, 3))
  expect_error(judge_weights(m, by = "method", values = c(mdi = 1)),
               "provenance")
})

test_that("method weights expand over the judges and must cover every method", {
  skip_if_not_installed("randomForest")
  set.seed(20)
  J <- importance_judges(rf_reg, methods = c("permutation", "mdi"),
                         data = reg_data, target = "y", n_perm = 2)
  w <- judge_weights(J, by = "method", values = c(permutation = 2, mdi = 1))

  expect_identical(unname(w), c(2, 1))
  expect_identical(names(w), rownames(J))
  expect_error(judge_weights(J, by = "method", values = c(permutation = 2)),
               "mdi")
  expect_error(judge_weights(J, by = "method", values = c(permutation = -1, mdi = 1)),
               "positive")
})

test_that("reliability down-weights the judge who disagrees with everyone", {
  m <- rbind(
    a = c(1, 2, 3, 4),
    b = c(1, 2, 4, 3),
    c = c(2, 1, 3, 4),
    d = c(4, 3, 2, 1) # the dissenter: reverses the panel
  )
  w <- judge_weights(m, by = "reliability")

  expect_lt(w[["d"]], min(w[c("a", "b", "c")]))
  expect_true(all(w > 0))
  expect_equal(mean(w), 1)
})

test_that("reliability weights need at least two judges", {
  m <- matrix(c(1, 2, 3), nrow = 1, dimnames = list("a", NULL))
  expect_error(judge_weights(m, by = "reliability"), "at least two")
})
