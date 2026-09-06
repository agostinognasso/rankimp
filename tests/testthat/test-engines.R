# The engine adapters are the package's only contact with randomForest and
# ranger, so a change in either shows up here first. The paths worth pinning are
# the ones the happy path never walks: the second engine, and every branch that
# refuses to guess.

test_that("an unsupported fit is named in the error", {
  expect_error(engine_of(structure(list(), class = "gbm")),
               "Unsupported model class 'gbm'")
  expect_error(engine_of(lm(mpg ~ cyl, data = mtcars)), "randomForest, ranger")
})

test_that("a missing engine is reported as something to install", {
  # The message has to name the package and the call that installs it: the user
  # who sees this has a fit built somewhere else and no idea what is missing.
  expect_error(require_engine("NotAnInstalledPackage"),
               "Package `NotAnInstalledPackage` is needed")
  expect_error(require_engine("NotAnInstalledPackage"),
               'install.packages\\("NotAnInstalledPackage"\\)')
  expect_no_error(require_engine("stats"))
})

test_that("a ranger fit without its forest says how to refit", {
  skip_if_not_installed("ranger")
  # `write.forest = FALSE` throws the predictor names away with the forest, and
  # nothing else in the object carries them. Guessing from the training data is
  # not available here, so the adapter has to say what to do instead.
  set.seed(1)
  bare <- ranger::ranger(y ~ ., data = reg_data, num.trees = 20,
                         write.forest = FALSE)

  expect_error(predictors_of(bare), "Cannot recover the predictors")
  expect_error(predictors_of(bare), "write.forest = TRUE")
})

test_that("an unsupervised forest has no response to rank against", {
  skip_if_not_installed("randomForest")
  set.seed(1)
  unsup <- randomForest::randomForest(x = reg_data[, c("x1", "x2", "x3")],
                                      ntree = 20)
  skip_if_not(identical(unsup$type, "unsupervised"))

  expect_error(is_classifier(unsup), "no response to rank importance against")
})

test_that("both engines are recognised and classified", {
  skip_if_not_installed("randomForest")
  skip_if_not_installed("ranger")

  expect_identical(engine_of(rf_reg), "randomForest")
  expect_identical(engine_of(rg_imp), "ranger")
  expect_false(is_classifier(rf_reg))
  expect_true(is_classifier(rf_cls))
  expect_false(is_classifier(rg_imp))
})

test_that("a ranger probability forest predicts a class, not a distribution", {
  skip_if_not_installed("ranger")
  # Permutation and LOCO score a loss, and the misclassification loss needs a
  # label. A probability forest hands back a matrix of class probabilities, so
  # the adapter collapses it to the modal class -- and must return a factor with
  # the forest's own levels, or the loss silently compares against nothing.
  set.seed(1)
  prob <- ranger::ranger(y ~ ., data = cls_data, num.trees = 40,
                         probability = TRUE)

  pred <- predict_response(prob, cls_data)

  expect_s3_class(pred, "factor")
  expect_identical(levels(pred), levels(cls_data$y))
  expect_length(pred, nrow(cls_data))
  expect_true(is_classifier(prob))
  # A probability forest that has learned anything agrees with a plain one most
  # of the time; exact agreement is not the claim, being a usable label is.
  expect_gt(mean(pred == cls_data$y), 0.5)
})

test_that("class probabilities come back from both engines, or say why not", {
  skip_if_not_installed("randomForest")
  skip_if_not_installed("ranger")

  from_rf <- predict_prob(rf_cls, cls_data)
  expect_true(is.matrix(from_rf))
  expect_setequal(colnames(from_rf), levels(cls_data$y))

  set.seed(1)
  prob <- ranger::ranger(y ~ ., data = cls_data, num.trees = 40,
                         probability = TRUE)
  from_rg <- predict_prob(prob, cls_data)
  expect_true(is.matrix(from_rg))
  expect_setequal(colnames(from_rg), levels(cls_data$y))
  expect_equal(unname(rowSums(from_rg)), rep(1, nrow(cls_data)), tolerance = 1e-8)

  # A plain ranger classifier cannot produce them, and the message says which
  # argument to change rather than reporting a failure inside ranger.
  set.seed(1)
  plain_cls <- ranger::ranger(y ~ ., data = cls_data, num.trees = 20)
  expect_error(predict_prob(plain_cls, cls_data), "probability = TRUE")
})

test_that("a refit keeps the size of the forest it came from", {
  skip_if_not_installed("ranger")
  # LOCO refits on one predictor fewer, so `mtry` has to be capped or ranger
  # refuses. Everything else is the engine default, which is documented: a
  # hand-tuned `min.node.size` does not survive a refit.
  x <- reg_data[, c("x1", "x2")]
  refitted <- refit(rg_imp, x, reg_data$y)

  expect_s3_class(refitted, "ranger")
  expect_identical(refitted$num.trees, rg_imp$num.trees)
  expect_lte(refitted$mtry, ncol(x))
  # An MDI query on a refitted judge has to still work.
  expect_false(is.null(refitted$variable.importance))
})

test_that("a refit of a probability forest is still a probability forest", {
  skip_if_not_installed("ranger")
  # Otherwise a LOCO replicate of a SHAP panel loses the probabilities halfway
  # through and fails on the next call rather than here.
  set.seed(1)
  prob <- ranger::ranger(y ~ ., data = cls_data, num.trees = 30,
                         probability = TRUE)

  refitted <- refit(prob, cls_data[, c("x1", "x2")], cls_data$y)

  expect_identical(refitted$treetype, "Probability estimation")
})

test_that("a randomForest refit keeps its size too", {
  skip_if_not_installed("randomForest")
  x <- reg_data[, c("x1", "x2")]

  refitted <- refit(rf_reg, x, reg_data$y)

  expect_s3_class(refitted, "randomForest")
  expect_identical(refitted$ntree, rf_reg$ntree)
  expect_lte(refitted$mtry, ncol(x))
})

test_that("the loss matches the kind of response", {
  # Not a formality: a classification loss on a numeric response would compare
  # doubles with `!=` and report a rate near 1 for a perfect fit.
  expect_equal(prediction_loss(c(1, 2, 3), c(1, 2, 3)), 0)
  expect_equal(prediction_loss(c(0, 0), c(1, -1)), 1)
  y <- factor(c("a", "b", "a", "b"))
  expect_equal(prediction_loss(y, factor(c("a", "b", "a", "b"))), 0)
  expect_equal(prediction_loss(y, factor(c("a", "b", "b", "a"))), 0.5)
})

test_that("check_data refuses what it cannot use", {
  skip_if_not_installed("randomForest")

  expect_error(check_data(rf_reg, as.matrix(reg_data), "y"),
               "`data` must be a data frame")
  expect_error(check_data(rf_reg, reg_data, c("y", "x1")),
               "`target` must be a single column name")
  expect_error(check_data(rf_reg, reg_data, NA_character_),
               "`target` must be a single column name")
  expect_error(check_data(rf_reg, reg_data, 1),
               "`target` must be a single column name")
  expect_error(check_data(rf_reg, reg_data, "absent"),
               "has no column called 'absent'")
  expect_error(check_data(rf_reg, reg_data[, c("y", "x1")], "y"),
               "missing predictors the model was trained on: x2, x3")
})

test_that("check_data promotes a character response and matches it to the fit", {
  skip_if_not_installed("randomForest")
  # Every modelling function in R does this promotion, so refusing it would be
  # a surprise; what must not be silent is a response of the wrong *kind*.
  chr <- cls_data
  chr$y <- as.character(chr$y)

  info <- check_data(rf_cls, chr, "y")
  expect_true(is.factor(info$y))
  expect_setequal(levels(info$y), levels(cls_data$y))
  expect_identical(info$predictors, predictors_of(rf_cls))

  numeric_y <- cls_data
  numeric_y$y <- as.numeric(cls_data$y)
  expect_error(check_data(rf_cls, numeric_y, "y"),
               "classifier but `data\\$y` is not a factor")

  factor_y <- reg_data
  factor_y$y <- factor(reg_data$y > 0)
  expect_error(check_data(rf_reg, factor_y, "y"),
               "regression but `data\\$y` is not numeric")
})
