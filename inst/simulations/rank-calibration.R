# Calibration of the rank confidence sets -------------------------------------
#
# `rank-coverage.R` measures whether a nominal 95% set covers. It cannot say
# what the nominal level would have to be to actually cover 95%, nor what the
# coverage would have been with a different `n_boot`, because it stores only the
# ends of each interval.
#
# This script stores the whole bootstrap rank distribution of every replicate,
# so both questions are answered afterwards without refitting anything:
#
#   * any nominal level, by recomputing the quantiles;
#   * any smaller `n_boot`, by subsampling the stored draws.
#
# Design and procedure are the ones in rank-coverage.R: same generating
# coefficients, same panel, per-replicate seeds.
#
#   Rscript inst/simulations/rank-calibration.R <output-directory>
#
# Expect about fifty minutes on twelve cores.

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

# The hard design: ordering the middle of the ranking is genuinely difficult.
BETA <- c(x1 = 2.00, x2 = 0.60, x3 = 0.55, x4 = 0.50, x5 = 0.45,
          x6 = 0, x7 = 0, x8 = 0)
NTREE <- 200L
JUDGE_BOOT <- 1000L

simulate_data <- function(beta, n) {
  d <- as.data.frame(matrix(rnorm(n * length(beta)), n, length(beta)))
  names(d) <- names(beta)
  d$y <- as.numeric(as.matrix(d) %*% beta + rnorm(n))
  d
}

one_replicate <- function(i, n, data_boot) {
  seeds <- 3L * (as.integer(i) - 1L) + 1:3
  attempt <- try({
    d <- simulate_data(BETA, n)
    fit <- randomForest(y ~ ., data = d, ntree = NTREE)
    cr <- consensus_rank(importance_judges(
      fit, methods = c("permutation", "mdi"),
      data = d, target = "y", seeds = seeds
    ))
    list(
      judges = rank_confsets(cr, n_boot = JUDGE_BOOT)$ranks,
      data = suppressMessages(
        rank_confsets(cr, n_boot = data_boot, type = "data")
      )$ranks,
      point = cr$ranking$rank[match(names(BETA), cr$ranking$variable)]
    )
  }, silent = TRUE)
  if (inherits(attempt, "try-error")) NULL else attempt
}

cells <- rbind(
  data.frame(n = 80, data_boot = 400, M = 300),
  data.frame(n = 200, data_boot = 200, M = 300)
)

RNGkind("L'Ecuyer-CMRG")

for (k in seq_len(nrow(cells))) {
  cell <- cells[k, ]
  label <- sprintf("n%d_boot%d", cell$n, cell$data_boot)
  started <- proc.time()[["elapsed"]]
  set.seed(20260906L + k)

  results <- mclapply(seq_len(cell$M), one_replicate,
                      n = cell$n, data_boot = cell$data_boot,
                      mc.cores = cores, mc.set.seed = TRUE)
  kept <- Filter(Negate(is.null), results)

  saveRDS(
    list(replicates = kept, n = cell$n, data_boot = cell$data_boot,
         judge_boot = JUDGE_BOOT, beta = BETA,
         truth = rank(-BETA, ties.method = "min")),
    file.path(out_dir, paste0("calibration_", label, ".rds"))
  )
  message(sprintf("[%d/%d] %-14s %3d/%3d replicates in %5.1f min",
                  k, nrow(cells), label, length(kept), cell$M,
                  (proc.time()[["elapsed"]] - started) / 60))
}
