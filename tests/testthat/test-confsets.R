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

# --- Bootstrapping the data ------------------------------------------------

test_that("the number of replicates defaults to the kind of bootstrap", {
  expect_identical(resolve_n_boot(NULL, "judges"), 500L)
  expect_identical(resolve_n_boot(NULL, "data"), 50L)
  expect_identical(resolve_n_boot(7, "data"), 7L)
})

test_that("the data bootstrap needs a panel that carries its recipe", {
  expect_error(
    rank_confsets(consensus_rank(panel()), n_boot = 3, type = "data"),
    "plain ranking matrix"
  )
})

test_that("an mdi-only panel has no data to resample", {
  skip_if_not_installed("randomForest")
  J <- importance_judges(rf_reg, methods = "mdi")

  expect_error(
    rank_confsets(consensus_rank(J), n_boot = 3, type = "data"),
    "needs the data"
  )
})

test_that("the data bootstrap refits the models and returns usable sets", {
  skip_if_not_installed("randomForest")
  set.seed(20)
  cr <- consensus_rank(importance_judges(
    rf_reg, methods = c("permutation", "mdi"),
    data = reg_data, target = "y", n_perm = 2
  ))

  set.seed(21)
  cb <- rank_confsets(cr, n_boot = 10, type = "data")

  expect_s3_class(cb, "rank_confsets")
  expect_identical(cb$type, "data")
  expect_identical(cb$n_units, nrow(reg_data))
  expect_identical(cb$failed, 0L)
  expect_identical(dim(cb$ranks), c(10L, 3L))
  expect_identical(colnames(cb$ranks), c("x1", "x2", "x3"))
  expect_false(anyNA(cb$ranks))
  expect_true(all(cb$confsets$lower <= cb$confsets$upper))
  expect_true(all(cb$ranks >= 1L & cb$ranks <= 3L))
  expect_output(print(cb), "rows, with replacement")
})

test_that("a data replicate reproduces the point estimate on all the rows", {
  # A replicate's ranking drifts towards the middle: `n` rows drawn with
  # replacement hold about 0.632n distinct ones, and a variable is harder to
  # place on that much less information. Measured over 300 panels of eight close
  # predictors and eighty rows, the second variable's median bootstrap rank sits
  # 0.55 below its consensus rank and the eighth's sits 1.00 above.
  #
  # What must hold is the identity behind it — hand a replicate all the distinct
  # rows and it reproduces the point estimate. That separates bootstrap bias,
  # which is the method, from a panel rebuilt wrongly, which would be a bug.
  skip_if_not_installed("randomForest")
  set.seed(30)
  cr <- consensus_rank(importance_judges(
    rf_reg, methods = c("permutation", "mdi"),
    data = reg_data, target = "y", n_perm = 2
  ))
  point <- as.integer(cr$ranking$rank[match(colnames(cr$judges),
                                            cr$ranking$variable)])
  recipe <- attr(cr$judges, "recipe")

  set.seed(31)
  rows <- sample.int(nrow(reg_data))
  replicated <- data_replicate(recipe, rows, rows, colnames(cr$judges),
                               engine = "quick", weights = NULL,
                               ties = cr$ties)

  expect_identical(replicated, point)
})

test_that("the data bootstrap is reproducible from a seed", {
  skip_if_not_installed("randomForest")
  set.seed(22)
  cr <- consensus_rank(importance_judges(
    rf_reg, methods = "permutation", data = reg_data, target = "y", n_perm = 2
  ))

  set.seed(23)
  first <- rank_confsets(cr, n_boot = 4, type = "data")
  set.seed(23)
  again <- rank_confsets(cr, n_boot = 4, type = "data")

  expect_identical(first$ranks, again$ranks)
})

test_that("the data bootstrap draws a fresh resample for every replicate", {
  # The defect this stands in for: rebuilding the panel called `set.seed()` for
  # the seed axis and left the stream there, so the loop drew its next resample
  # from a state fixed by the last seed and kept redrawing the same rows. The
  # replicates then repeat with a short period — measured on eighty rows and a
  # panel of six judges, four hundred requested replicates held about eight
  # distinct ones, and `n_boot` bought nothing beyond the first few.
  #
  # Stated as something exact: the loop consumes one resample per replicate from
  # the session stream and nothing else, so the stream ends where `n_boot`
  # draws of `sample.int()` would have left it.
  skip_if_not_installed("randomForest")
  set.seed(40)
  cr <- consensus_rank(importance_judges(
    rf_reg, methods = c("permutation", "mdi"),
    data = reg_data, target = "y", seeds = 1:2, n_perm = 2
  ))
  n <- nrow(reg_data)

  set.seed(41)
  cb <- rank_confsets(cr, n_boot = 5, type = "data")
  after <- get(".Random.seed", envir = globalenv())

  set.seed(41)
  for (b in seq_len(5)) sample.int(n, n, replace = TRUE)

  expect_identical(after, get(".Random.seed", envir = globalenv()))
  expect_identical(cb$failed, 0L)
})

test_that("the judge bootstrap draws a fresh reweighting for every replicate", {
  # The same invariant on the other branch: one draw per replicate from the
  # caller's stream, so that what the solver does with the RNG cannot correlate
  # one replicate with the next.
  skip_if_not_installed("randomForest")
  set.seed(42)
  cr <- consensus_rank(importance_judges(
    rf_reg, methods = c("permutation", "mdi"),
    data = reg_data, target = "y", seeds = 1:2, n_perm = 2
  ))
  k <- nrow(cr$judges)

  set.seed(43)
  rank_confsets(cr, n_boot = 6)
  after <- get(".Random.seed", envir = globalenv())

  set.seed(43)
  for (b in seq_len(6)) stats::rmultinom(1L, size = k, prob = rep(1 / k, k))

  expect_identical(after, get(".Random.seed", envir = globalenv()))
})

test_that("a replicate that fails is dropped rather than fatal", {
  # The failure this stands in for is real and was measured: a response class
  # too rare to survive a bootstrap draw makes randomForest refuse to refit
  # ("Can't have empty classes in y"). Mocking keeps the test off the RNG.
  skip_if_not_installed("randomForest")
  set.seed(24)
  cr <- consensus_rank(importance_judges(
    rf_reg, methods = "permutation", data = reg_data, target = "y", n_perm = 2
  ))

  honest <- panel_scores
  attempt <- 0L
  local_mocked_bindings(panel_scores = function(...) {
    attempt <<- attempt + 1L
    if (attempt == 1L) stop("engine exploded", call. = FALSE)
    honest(...)
  })

  expect_warning(
    cb <- rank_confsets(cr, n_boot = 4, type = "data"),
    "1 of 4 bootstrap replicates failed"
  )
  expect_identical(cb$failed, 1L)
  expect_true(anyNA(cb$ranks))
  expect_true(all(cb$confsets$lower <= cb$confsets$upper))
  expect_output(print(cb), "dropped")
})

test_that("a bootstrap in which everything fails is an error", {
  skip_if_not_installed("randomForest")
  set.seed(25)
  cr <- consensus_rank(importance_judges(
    rf_reg, methods = "permutation", data = reg_data, target = "y", n_perm = 2
  ))

  local_mocked_bindings(panel_scores = function(...) stop("engine exploded",
                                                          call. = FALSE))
  expect_error(rank_confsets(cr, n_boot = 3, type = "data"),
               "Every bootstrap replicate failed")
})

test_that("a resample axis cannot carry its judge weights into the replicates", {
  skip_if_not_installed("randomForest")
  skip_if_not_installed("rsample")
  set.seed(26)
  J <- importance_judges(rf_reg, methods = c("permutation", "mdi"),
                         data = reg_data, target = "y", n_perm = 2,
                         resamples = rsample::vfold_cv(reg_data, v = 3))
  # Six judges for the point estimate, two once the bootstrap takes over the
  # resampling: per-judge weights cannot follow, and the user is told.
  cr <- consensus_rank(J, weights = rep(1, nrow(J)))

  set.seed(27)
  expect_warning(
    cb <- rank_confsets(cr, n_boot = 3, type = "data"),
    "has 2 judges and the consensus was weighted over 6"
  )
  expect_identical(cb$failed, 0L)
})

test_that("autoplot names what was resampled", {
  skip_if_not_installed("randomForest")
  skip_if_not_installed("ggplot2")
  set.seed(28)
  cr <- consensus_rank(importance_judges(
    rf_reg, methods = "permutation", data = reg_data, target = "y", n_perm = 2
  ))

  set.seed(29)
  p <- autoplot(rank_confsets(cr, n_boot = 4, type = "data"))
  expect_match(p$labels$subtitle, "bootstrap samples of the 120 rows")
})
