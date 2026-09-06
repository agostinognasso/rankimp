# What `prob_topk()` and `rank_select()` are worth ----------------------------
#
# Both read `cb$ranks`, the matrix of bootstrap consensus rankings, and neither
# had ever been measured. That matters more than it usually would: until
# 2026-09-06 the data bootstrap drew the same handful of resamples over and over
# (about eight distinct ones in four hundred requested), so `prob_topk()` was
# averaging an indicator over a few repeated draws and reporting the result to
# three decimal places. The machinery is fixed; this script asks what the two
# functions actually deliver on it.
#
# Three questions, one Monte Carlo:
#
#   1. How far does the median bootstrap rank sit from the point estimate?
#      `?rank_confsets` warns that a data-bootstrap interval need not contain
#      the consensus rank, and used to illustrate it with a single observation
#      ("the second variable had a median bootstrap rank of three") taken from
#      the broken bootstrap. This measures the drift instead of anecdote.
#   2. Is `prob_topk()` calibrated? A variable given probability 0.8 of being in
#      the top k should be there about 80% of the time.
#   3. Does `rank_select(threshold)` control the false selection rate it
#      promises? It keeps variables whose whole interval clears the threshold,
#      so a selected variable whose true rank is worse than the threshold is a
#      false selection.
#
#   Rscript inst/simulations/select-calibration.R <output-directory>
#
# Expect about a quarter of an hour on twelve cores.

if (requireNamespace("rankimp", quietly = TRUE)) {
  library(rankimp)
} else {
  pkgload::load_all(quiet = TRUE)
}
library(randomForest)
library(parallel)

out_dir <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(out_dir)) out_dir <- tempdir()
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
cores <- getOption("mc.cores", max(1L, detectCores() - 2L))

# The design, the sample size and the panel are `rank-coverage.R`'s hardest
# cell, so the numbers here sit alongside the coverage numbers rather than
# describing some other situation.
BETA <- c(x1 = 2.00, x2 = 0.60, x3 = 0.55, x4 = 0.50, x5 = 0.45,
          x6 = 0, x7 = 0, x8 = 0)
N <- 80L
NTREE <- 200L
N_BOOT <- 50L
LEVEL <- 0.95
REPLICATES <- 300L
THRESHOLDS <- 1:6
TOPK <- 1:6

VARIABLES <- names(BETA)
TRUTH <- rank(-BETA, ties.method = "min")
# The three noise variables are tied at the truth, so "the true rank" is a block
# of positions and not one number. Same criterion as `rank-coverage.R`.
BLOCK_HI <- TRUTH + as.integer(table(TRUTH)[as.character(TRUTH)]) - 1L
names(BLOCK_HI) <- VARIABLES

# A variable is genuinely in the top k when its block of true positions starts
# at or before k: a noise variable tied across positions 6-8 is never in the top
# 5, and x1 at position 1 always is.
truly_in_top <- function(k) TRUTH <= k
# ... and genuinely clears a threshold when even the worst position of its block
# does, which is the claim `rank_select()` makes about a selected variable.
truly_clears <- function(t) BLOCK_HI <= t

simulate_data <- function(n) {
  d <- as.data.frame(matrix(rnorm(n * length(BETA)), n, length(BETA)))
  names(d) <- VARIABLES
  d$y <- as.numeric(as.matrix(d) %*% BETA + rnorm(n))
  d
}

one_replicate <- function(i) {
  # Independent seed streams per replicate, for the reason documented in
  # `rank-coverage.R`: a fixed `1:3` correlates the estimator's randomness
  # across the Monte Carlo and favours column positions systematically.
  seeds <- 3L * (as.integer(i) - 1L) + 1:3

  attempt <- try({
    d <- simulate_data(N)
    fit <- randomForest(y ~ ., data = d, ntree = NTREE)
    cr <- consensus_rank(importance_judges(
      fit, methods = c("permutation", "mdi"),
      data = d, target = "y", seeds = seeds
    ))
    cb <- suppressMessages(
      rank_confsets(cr, n_boot = N_BOOT, level = LEVEL, type = "data")
    )
    list(cr = cr, cb = cb)
  }, silent = TRUE)
  if (inherits(attempt, "try-error")) return(NULL)

  cr <- attempt$cr
  cb <- attempt$cb
  point <- cr$ranking$rank[match(VARIABLES, cr$ranking$variable)]
  ranks <- cb$ranks[, VARIABLES, drop = FALSE]

  probs <- vapply(TOPK, function(k) {
    p <- prob_topk(cb, k = k)
    p$probability[match(VARIABLES, p$variable)]
  }, numeric(length(VARIABLES)))
  colnames(probs) <- paste0("p_top", TOPK)

  selected <- vapply(THRESHOLDS, function(t) {
    VARIABLES %in% rank_select(cb, threshold = t)
  }, logical(length(VARIABLES)))
  colnames(selected) <- paste0("sel_", THRESHOLDS)

  cbind(
    data.frame(
      replicate = i,
      variable = VARIABLES,
      truth = as.integer(TRUTH),
      block_hi = as.integer(BLOCK_HI),
      point = as.integer(point),
      boot_median = apply(ranks, 2L, stats::median),
      lower = cb$confsets$lower[match(VARIABLES, cb$confsets$variable)],
      upper = cb$confsets$upper[match(VARIABLES, cb$confsets$variable)],
      stringsAsFactors = FALSE
    ),
    as.data.frame(probs),
    as.data.frame(selected)
  )
}

set.seed(20260906L)
res <- do.call(rbind, Filter(is.data.frame,
  mclapply(seq_len(REPLICATES), one_replicate,
           mc.cores = cores, mc.set.seed = TRUE)))
saveRDS(res, file.path(out_dir, "select_calibration.rds"))

cat("=== replicates completed:", length(unique(res$replicate)),
    "of", REPLICATES, "===\n")

# --- 1. drift of the bootstrap median from the point estimate ---------------

cat("\n=== 1. Median bootstrap rank against the point estimate ===\n")
cat("(close design, n =", N, ", n_boot =", N_BOOT, ", by CONSENSUS position)\n\n")

drift <- do.call(rbind, lapply(split(res, res$point), function(g) {
  data.frame(
    point_rank = g$point[1L],
    observations = nrow(g),
    mean_boot_median = mean(g$boot_median),
    median_boot_median = stats::median(g$boot_median),
    mean_drift = mean(g$boot_median - g$point),
    drifted_worse = mean(g$boot_median > g$point),
    outside_own_interval = mean(g$point < g$lower | g$point > g$upper)
  )
}))
print(drift, row.names = FALSE, digits = 3)
cat("\nmean_drift            : median bootstrap rank minus consensus rank\n")
cat("drifted_worse         : the bootstrap median is worse than the estimate\n")
cat("outside_own_interval  : the consensus rank falls outside its own interval\n")

# --- 2. is prob_topk() calibrated? ------------------------------------------

cat("\n=== 2. prob_topk() calibration ===\n")
cat("(every variable of every replicate, pooled over k =",
    paste(range(TOPK), collapse = "-"), ")\n\n")

pooled <- do.call(rbind, lapply(TOPK, function(k) {
  data.frame(
    k = k,
    reported = res[[paste0("p_top", k)]],
    actual = truly_in_top(k)[res$variable]
  )
}))
pooled$bin <- cut(pooled$reported, breaks = seq(0, 1, by = 0.1),
                  include.lowest = TRUE, right = FALSE)
calibration <- do.call(rbind, lapply(split(pooled, pooled$bin), function(b) {
  if (!nrow(b)) return(NULL)
  data.frame(
    bin = as.character(b$bin[1L]),
    cases = nrow(b),
    mean_reported = mean(b$reported),
    actually_in_top_k = mean(b$actual),
    gap = mean(b$actual) - mean(b$reported)
  )
}))
print(calibration, row.names = FALSE, digits = 3)
cat("\ngap : how much the truth exceeds the reported probability.\n")
cat("      Positive throughout means the probabilities are conservative,\n")
cat("      negative means they overstate. Zero is calibration.\n")

# --- 3. does rank_select() control false selection? -------------------------

cat("\n=== 3. rank_select() false selection ===\n\n")

selection <- do.call(rbind, lapply(THRESHOLDS, function(t) {
  sel <- res[[paste0("sel_", t)]]
  ok <- truly_clears(t)[res$variable]
  n_sel <- sum(sel)
  data.frame(
    threshold = t,
    selected_per_run = n_sel / length(unique(res$replicate)),
    # Of the variables it selected, how many did not deserve it.
    false_selection_rate = if (n_sel) mean(!ok[sel]) else NA_real_,
    # At least one false selection somewhere in the run.
    runs_with_a_false_selection =
      mean(vapply(split(sel & !ok, res$replicate), any, logical(1))),
    # And what it costs: the variables that deserved selection and missed it.
    power = if (any(ok)) mean(sel[ok]) else NA_real_
  )
}))
print(selection, row.names = FALSE, digits = 3)
cat("\nfalse_selection_rate : selected variables whose true rank block does\n")
cat("                       not clear the threshold\n")
cat("power                : variables that deserved selection and got it\n")
