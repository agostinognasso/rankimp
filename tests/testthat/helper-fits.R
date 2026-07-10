# Shared fixtures. The response is driven by x1, mildly by x2 and not at all
# by x3, so every backend should put x1 above x3.

reg_data <- local({
  set.seed(42)
  n <- 120
  d <- data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
  d$y <- 3 * d$x1 + d$x2 + rnorm(n, sd = 0.5)
  d
})

cls_data <- local({
  set.seed(43)
  n <- 150
  d <- data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
  d$y <- factor(ifelse(d$x1 + 0.3 * d$x2 + rnorm(n, sd = 0.5) > 0, "yes", "no"))
  d
})

if (requireNamespace("randomForest", quietly = TRUE)) {
  set.seed(1)
  rf_reg <- randomForest::randomForest(y ~ ., data = reg_data, ntree = 60)
  set.seed(1)
  rf_cls <- randomForest::randomForest(y ~ ., data = cls_data, ntree = 60)
}

if (requireNamespace("ranger", quietly = TRUE)) {
  set.seed(1)
  rg_imp <- ranger::ranger(y ~ ., data = reg_data, num.trees = 60,
                           importance = "impurity")
  set.seed(1)
  rg_plain <- ranger::ranger(y ~ ., data = reg_data, num.trees = 60)
}
