# Reading of rank-calibration.R -----------------------------------------------
#
# Two questions the coverage study could not answer, both settled here from the
# stored bootstrap distributions without refitting anything:
#
#   1. What nominal level would a rank confidence set need for its actual
#      coverage to reach 0.95?
#   2. How much of the measured coverage is the bootstrap, and how much is the
#      imprecision of estimating extreme quantiles from few replicates?
#
#   Rscript inst/simulations/analyse-calibration.R <directory-of-rds>

dir <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(dir)) stop("Pass the directory holding calibration_*.rds")

# `k` variables tied at rank `t` occupy positions `t .. t + k - 1`; a set covers
# when it meets that block. Same criterion as rank-coverage.R.
rank_block_hi <- function(truth) {
  sizes <- table(truth)
  as.integer(truth) + as.integer(sizes[as.character(truth)]) - 1L
}

# `type = 1` and `na.rm`: the rule `rank_confsets()` itself applies, so that a
# figure read off the stored draws is the figure the package would have given.
interval <- function(draws, level) {
  a <- (1 - level) / 2
  c(stats::quantile(draws, a, type = 1L, names = FALSE, na.rm = TRUE),
    stats::quantile(draws, 1 - a, type = 1L, names = FALSE, na.rm = TRUE))
}

coverage <- function(reps, kind, level, truth, block_hi, take = NULL,
                     signal_only = TRUE) {
  keep <- if (signal_only) which(block_hi == truth) else seq_along(truth)
  hits <- vapply(reps, function(r) {
    m <- r[[kind]]
    if (!is.null(take) && take < nrow(m)) m <- m[sample.int(nrow(m), take), , drop = FALSE]
    vapply(keep, function(v) {
      iv <- interval(m[, v], level)
      iv[1] <= block_hi[v] && iv[2] >= truth[v]
    }, logical(1))
  }, logical(length(keep)))
  mean(hits)
}

for (f in sort(list.files(dir, pattern = "^calibration_.*rds$", full.names = TRUE))) {
  cal <- readRDS(f)
  truth <- cal$truth
  block_hi <- rank_block_hi(truth)
  reps <- cal$replicates
  cat(sprintf("\n=== %s : n = %d, %d replicates, data n_boot = %d ===\n",
              basename(f), cal$n, length(reps), cal$data_boot))

  # A bootstrap that repeats itself answers every question with the same few
  # numbers, and nothing downstream shows it. Counted first, before anything is
  # read off these draws: `n_boot` replicates should hold nearly `n_boot`
  # distinct ones on a continuous design, and it was 8.5 out of 400 while
  # `panel_scores()` left the session seed where the seed axis put it.
  distinct <- vapply(reps, function(r)
    length(unique(apply(r$data, 1L, paste, collapse = ","))), numeric(1))
  cat(sprintf("\n0. Distinct resamples per run: mean %.1f of %d (min %d, max %d)\n",
              mean(distinct), cal$data_boot, min(distinct), max(distinct)))

  cat("\n1. Coverage against the nominal level (signal variables)\n")
  levels <- c(0.50, 0.80, 0.90, 0.95, 0.975, 0.99, 0.995, 0.999)
  tab <- t(vapply(levels, function(L) {
    c(judges = coverage(reps, "judges", L, truth, block_hi),
      data = coverage(reps, "data", L, truth, block_hi))
  }, numeric(2)))
  rownames(tab) <- format(levels)
  print(round(tab, 3))

  target <- 0.95
  for (kind in c("judges", "data")) {
    actual <- tab[, kind]
    hit <- which(actual >= target)[1]
    cat(sprintf("   %-7s reaches %.2f actual coverage at nominal %s\n", kind, target,
                if (is.na(hit)) paste0("> ", format(max(levels))) else format(levels[hit])))
  }

  cat("\n2. Coverage at nominal 0.95 against the number of bootstrap replicates\n")
  sizes <- c(50, 100, 200, 400)
  sizes <- sort(unique(c(sizes[sizes <= cal$data_boot], cal$data_boot)))
  if (length(sizes) < 2L) {
    cat("   only", cal$data_boot, "replicates stored: nothing to sweep\n")
  } else {
    set.seed(1)
    sub <- vapply(sizes, function(k)
      coverage(reps, "data", 0.95, truth, block_hi, take = k), numeric(1))
    names(sub) <- paste0("n_boot=", sizes)
    print(round(sub, 3))
    cat("   (the same replicates throughout, so this is a paired comparison:\n",
        "   what changes is only how many draws the quantiles are read from)\n")
  }
}
