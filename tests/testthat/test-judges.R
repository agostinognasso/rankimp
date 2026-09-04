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
  expect_error(judge_clusters(1), "not implemented yet")
})

test_that("importance_judges builds a model x method panel with provenance", {
  skip_if_not_installed("randomForest")
  skip_if_not_installed("ranger")
  set.seed(10)
  J <- importance_judges(
    list(rf = rf_reg, rg = rg_imp),
    methods = c("permutation", "mdi"),
    data = reg_data, target = "y", n_perm = 2
  )

  expect_s3_class(J, "judges")
  expect_true(is.matrix(J))
  expect_identical(dim(J), c(4L, 3L))
  expect_identical(
    rownames(J),
    c("rf:permutation", "rf:mdi", "rg:permutation", "rg:mdi")
  )
  expect_identical(colnames(J), c("x1", "x2", "x3"))
  expect_true(all(apply(J, 1L, min) == 1L))

  prov <- attr(J, "provenance")
  expect_identical(prov$model, c("rf", "rf", "rg", "rg"))
  expect_identical(prov$engine, c("randomForest", "randomForest", "ranger", "ranger"))
  expect_identical(prov$method, rep(c("permutation", "mdi"), 2L))
  expect_identical(dim(attr(J, "scores")), dim(J))
  expect_null(attr(J, "weights"))
  expect_false(consensus_rank(J)$weighted)
})

test_that("the panel's method weights flow into the consensus", {
  skip_if_not_installed("randomForest")
  set.seed(11)
  J <- importance_judges(rf_reg, methods = c("permutation", "mdi"),
                         data = reg_data, target = "y", n_perm = 2,
                         weights = c(permutation = 1, mdi = 0.5))

  w <- attr(J, "weights")
  expect_identical(unname(w), c(1, 0.5))
  expect_identical(names(w), rownames(J))

  cr <- consensus_rank(J)
  expect_true(cr$weighted)
  expect_identical(cr$weights, w)
  expect_identical(cr$ranking$variable[1], "x1")

  # An explicit `weights` argument still wins over the panel's own.
  expect_identical(consensus_rank(J, weights = c(2, 2))$weights, c(2, 2))
})

test_that("the seed axis refits and records provenance", {
  skip_if_not_installed("randomForest")
  set.seed(12)
  J <- importance_judges(rf_reg, methods = "mdi", data = reg_data,
                         target = "y", seeds = c(1, 2))

  expect_identical(dim(J), c(2L, 3L))
  prov <- attr(J, "provenance")
  expect_identical(prov$seed, c(1L, 2L))
  expect_identical(prov$judge, c("model1:mdi:s1", "model1:mdi:s2"))

  scores <- attr(J, "scores")
  expect_false(identical(scores[1L, ], scores[2L, ]))
})

test_that("the resample axis refits per split", {
  skip_if_not_installed("randomForest")
  skip_if_not_installed("rsample")
  set.seed(13)
  cv <- rsample::vfold_cv(reg_data, v = 2)
  J <- importance_judges(rf_reg, methods = c("permutation", "mdi"),
                         data = reg_data, target = "y",
                         resamples = cv, n_perm = 2)

  expect_identical(dim(J), c(4L, 3L))
  prov <- attr(J, "provenance")
  expect_setequal(unique(prov$resample), c("Fold1", "Fold2"))
  expect_true(all(grepl("Fold[12]$", prov$judge)))
})

test_that("data is demanded exactly when a method or an axis needs it", {
  skip_if_not_installed("randomForest")
  expect_error(importance_judges(rf_reg, methods = "permutation"),
               "`data` and `target`")
  expect_error(importance_judges(rf_reg, methods = "mdi", seeds = 1:2),
               "`data` and `target`")

  J <- importance_judges(rf_reg, methods = "mdi")
  expect_identical(dim(J), c(1L, 3L))
})

test_that("models trained on different predictors are refused", {
  skip_if_not_installed("randomForest")
  set.seed(14)
  rf_small <- randomForest::randomForest(y ~ x1 + x2, data = reg_data, ntree = 30)
  expect_error(
    importance_judges(list(a = rf_reg, b = rf_small), methods = "mdi"),
    "same predictors"
  )
})

test_that("method weights must cover every method", {
  skip_if_not_installed("randomForest")
  expect_error(
    importance_judges(rf_reg, methods = c("permutation", "mdi"),
                      data = reg_data, target = "y",
                      weights = c(permutation = 1)),
    "mdi"
  )
})

test_that("a judges panel prints its axes", {
  skip_if_not_installed("randomForest")
  J <- importance_judges(rf_reg, methods = "mdi")
  out <- capture.output(print(J))
  expect_match(out[1], "<judges> 1 judges x 3 variables", fixed = TRUE)
})

test_that("the panel records the recipe that built it", {
  skip_if_not_installed("randomForest")
  set.seed(15)
  J <- importance_judges(rf_reg, methods = c("permutation", "mdi"),
                         data = reg_data, target = "y", n_perm = 2)

  recipe <- attr(J, "recipe")
  expect_identical(recipe$methods, c("permutation", "mdi"))
  expect_identical(recipe$target, "y")
  expect_identical(recipe$predictors, c("x1", "x2", "x3"))
  expect_identical(recipe$dots$n_perm, 2)
  expect_false(recipe$out_of_sample)
  expect_identical(names(recipe$fit_list), "model1")
  expect_output(print(J), "recipe")

  # The data bootstrap reads the recipe off `cr$judges`, so it has to survive
  # the trip through consensus_rank().
  expect_identical(attr(consensus_rank(J)$judges, "recipe"), recipe)
})

test_that("a resample axis marks the panel as judged out of sample", {
  skip_if_not_installed("randomForest")
  skip_if_not_installed("rsample")
  set.seed(16)
  J <- importance_judges(rf_reg, methods = "mdi", data = reg_data, target = "y",
                         resamples = rsample::vfold_cv(reg_data, v = 2))

  expect_true(attr(J, "recipe")$out_of_sample)
})
