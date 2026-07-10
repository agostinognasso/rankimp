test_that("permutation importance separates signal from noise", {
  skip_if_not_installed("randomForest")
  set.seed(2)
  imp <- importance_permutation(rf_reg, reg_data, "y", n_perm = 3)

  expect_named(imp, c("x1", "x2", "x3"))
  expect_gt(imp[["x1"]], imp[["x3"]])
  expect_gt(imp[["x1"]], 0)
})

test_that("permutation importance works on a ranger fit", {
  skip_if_not_installed("ranger")
  set.seed(2)
  imp <- importance_permutation(rg_plain, reg_data, "y", n_perm = 3)

  expect_named(imp, c("x1", "x2", "x3"))
  expect_gt(imp[["x1"]], imp[["x3"]])
})

test_that("permutation importance on a classifier uses misclassification", {
  skip_if_not_installed("randomForest")
  set.seed(2)
  imp <- importance_permutation(rf_cls, cls_data, "y", n_perm = 3)

  expect_gt(imp[["x1"]], imp[["x3"]])
})

test_that("mdi is read off the fit, for regression and classification", {
  skip_if_not_installed("randomForest")
  imp <- importance_mdi(rf_reg)

  expect_named(imp, c("x1", "x2", "x3"))
  expect_identical(names(which.max(imp)), "x1")
  expect_named(importance_mdi(rf_cls), c("x1", "x2", "x3"))
})

test_that("mdi on ranger requires an impurity fit and says how to get one", {
  skip_if_not_installed("ranger")
  expect_named(importance_mdi(rg_imp), c("x1", "x2", "x3"))
  expect_error(importance_mdi(rg_plain), "impurity")
})

test_that("loco refits without each predictor", {
  skip_if_not_installed("randomForest")
  set.seed(3)
  imp <- importance_loco(rf_reg, reg_data, "y")

  expect_named(imp, c("x1", "x2", "x3"))
  expect_gt(imp[["x1"]], imp[["x3"]])
})

test_that("shap importance via kernelshap, regression", {
  skip_if_not_installed("randomForest")
  skip_if_not_installed("kernelshap")
  set.seed(4)
  imp <- importance_shap(rf_reg, reg_data, "y", n_explain = 15)

  expect_named(imp, c("x1", "x2", "x3"))
  expect_gt(imp[["x1"]], imp[["x3"]])
})

test_that("shap importance averages over classes for a classifier", {
  skip_if_not_installed("randomForest")
  skip_if_not_installed("kernelshap")
  set.seed(5)
  imp <- importance_shap(rf_cls, cls_data, "y", n_explain = 10)

  expect_named(imp, c("x1", "x2", "x3"))
  expect_gt(imp[["x1"]], imp[["x3"]])
})

test_that("backends reject data that does not match the fit", {
  skip_if_not_installed("randomForest")
  expect_error(importance_permutation(rf_reg, reg_data[-1], "y"),
               "missing predictors")
  expect_error(importance_permutation(rf_reg, reg_data, "nope"), "no column")
  expect_error(
    importance_permutation(rf_reg, transform(reg_data, y = factor(y > 0)), "y"),
    "not numeric"
  )
})

test_that("unsupported engines are refused by name", {
  fit <- stats::lm(y ~ x, data = data.frame(y = 1:10, x = 1:10))
  expect_error(importance_mdi(fit), "Unsupported model class")
})
