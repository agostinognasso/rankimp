# Coverage of the rank confidence sets ---------------------------------------
#
# A 95% rank confidence set claims to contain a variable's true rank 95% of the
# time. This script measures whether it does, for both bootstraps that
# `rank_confsets()` offers, over a Monte Carlo of datasets whose true importance
# ordering is known by construction.
#
# The ground truth is the ordering of the data-generating coefficients. That it
# is also the ordering the *procedure* converges to was checked rather than
# assumed: on 10,000 rows the panel used here recovers the coefficient ordering
# of the five signal variables exactly, in independent draws from both designs.
# The three noise variables are tied at the truth and come out in an arbitrary
# order, which is why they are summarised separately.
#
# Reproducing the numbers in `tasks/todo.md`:
#
#   Rscript inst/simulations/rank-coverage.R <output-directory>
#
# Expect roughly an hour on twelve cores.

if (requireNamespace("rankimp", quietly = TRUE)) {
  library(rankimp)
} else {
  pkgload::load_all(quiet = TRUE)   # from the package source tree
}
library(randomForest)
library(parallel)

out_dir <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(out_dir)) out_dir <- tempdir()
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

cores <- getOption("mc.cores", max(1L, detectCores() - 2L))

# --- the designs -----------------------------------------------------------

designs <- list(
  # Five real predictors whose effects are close enough that ordering the
  # middle of the ranking is genuinely hard, and three pure noise.
  close = c(x1 = 2.00, x2 = 0.60, x3 = 0.55, x4 = 0.50, x5 = 0.45,
            x6 = 0, x7 = 0, x8 = 0),
  # The control: the same shape with effects that separate cleanly.
  separated = c(x1 = 2.00, x2 = 1.40, x3 = 0.90, x4 = 0.55, x5 = 0.30,
                x6 = 0, x7 = 0, x8 = 0)
)

SIGNAL <- paste0("x", 1:5)
NOISE <- paste0("x", 6:8)
NTREE <- 200L
JUDGE_BOOT <- 500L
LEVEL <- 0.95

simulate_data <- function(beta, n) {
  d <- as.data.frame(matrix(rnorm(n * length(beta)), n, length(beta)))
  names(d) <- names(beta)
  d$y <- as.numeric(as.matrix(d) %*% beta + rnorm(n))
  d
}

# --- one Monte Carlo replicate ---------------------------------------------

one_replicate <- function(i, beta, n, data_boot) {
  variables <- names(beta)
  truth <- rank(-beta, ties.method = "min")
  # The seed axis gets its own streams in every replicate. Reusing a fixed
  # `1:3` correlates the estimator's randomness across the Monte Carlo: the
  # same RNG stream draws the same sequence of `mtry` candidate subsets every
  # time, which favours some column positions systematically and does not
  # average out. Measured on three exchangeable noise predictors: with fixed
  # seeds the leftmost won 34.5% against 50% (Wilcoxon p = 1e-07) and 32.5% of
  # pairs tied; with per-replicate seeds, 50.5% and p = 0.48.
  seeds <- 3L * (as.integer(i) - 1L) + 1:3

  attempt <- try({
    d <- simulate_data(beta, n)
    fit <- randomForest(y ~ ., data = d, ntree = NTREE)
    cr <- consensus_rank(importance_judges(
      fit, methods = c("permutation", "mdi"),
      data = d, target = "y", seeds = seeds
    ))
    by_judges <- rank_confsets(cr, n_boot = JUDGE_BOOT, level = LEVEL)
    by_data <- suppressMessages(
      rank_confsets(cr, n_boot = data_boot, level = LEVEL, type = "data")
    )
    list(cr = cr, j = by_judges, d = by_data)
  }, silent = TRUE)

  if (inherits(attempt, "try-error")) return(NULL)

  point <- attempt$cr$ranking$rank[match(variables, attempt$cr$ranking$variable)]
  j <- attempt$j$confsets[match(variables, attempt$j$confsets$variable), ]
  b <- attempt$d$confsets[match(variables, attempt$d$confsets$variable), ]

  data.frame(
    replicate = i,
    variable = variables,
    truth = as.integer(truth[variables]),
    point = as.integer(point),
    judges_lo = j$lower, judges_hi = j$upper,
    data_lo = b$lower, data_hi = b$upper,
    dropped = attempt$d$failed,
    stringsAsFactors = FALSE
  )
}

# --- the grid --------------------------------------------------------------

cells <- rbind(
  data.frame(design = "close", n = 80, data_boot = 50, M = 300),
  data.frame(design = "close", n = 200, data_boot = 50, M = 300),
  data.frame(design = "close", n = 500, data_boot = 50, M = 300),
  data.frame(design = "separated", n = 80, data_boot = 50, M = 300),
  data.frame(design = "separated", n = 200, data_boot = 50, M = 300),
  # Is any shortfall the bootstrap itself or merely 50 replicates of it?
  data.frame(design = "close", n = 80, data_boot = 200, M = 300)
)

# --- run -------------------------------------------------------------------

RNGkind("L'Ecuyer-CMRG")
raw <- list()

for (k in seq_len(nrow(cells))) {
  cell <- cells[k, ]
  label <- sprintf("%s_n%d_boot%d", cell$design, cell$n, cell$data_boot)
  started <- proc.time()[["elapsed"]]
  set.seed(20260905L + k)

  results <- mclapply(
    seq_len(cell$M), one_replicate,
    beta = designs[[cell$design]], n = cell$n, data_boot = cell$data_boot,
    mc.cores = cores, mc.set.seed = TRUE
  )
  kept <- Filter(Negate(is.null), results)
  out <- do.call(rbind, kept)
  out$design <- cell$design
  out$n <- cell$n
  out$data_boot <- cell$data_boot
  raw[[label]] <- out

  saveRDS(out, file.path(out_dir, paste0("coverage_", label, ".rds")))
  message(sprintf("[%d/%d] %-24s %3d/%3d replicates in %5.1f min",
                  k, nrow(cells), label, length(kept), cell$M,
                  (proc.time()[["elapsed"]] - started) / 60))
}

# --- summarise -------------------------------------------------------------

# Coverage against a truth that contains ties.
#
# `k` variables tied at rank `t` occupy positions `t .. t + k - 1` in any
# ranking, in an order nothing in the data determines. The consensus never
# returns them tied. Importance scores are continuous, so two are never exactly
# equal, and this was checked: across every cell the noise block came out tied
# 0.000 of the time. Demanding that each of their sets contain `t` therefore
# asks two of the three for something structurally unavailable, and measures the
# encoding rather than the method. A set covers when it meets the block.
#
# For a truth without ties the block is a single rank and this is the ordinary
# criterion.
rank_block_hi <- function(truth) {
  sizes <- table(truth)
  as.integer(truth) + as.integer(sizes[as.character(truth)]) - 1L
}

covers <- function(lo, hi, truth, block_hi) lo <= block_hi & hi >= truth

summarise_cell <- function(x) {
  block <- ifelse(x$variable %in% SIGNAL, "signal", "noise")
  # The truth is the same in every replicate, so the block bounds are read off
  # one of them and mapped back by variable.
  one <- x[x$replicate == x$replicate[1], c("variable", "truth")]
  bounds <- setNames(rank_block_hi(one$truth), one$variable)
  block_hi <- bounds[x$variable]
  per <- function(kind) {
    lo <- x[[paste0(kind, "_lo")]]
    hi <- x[[paste0(kind, "_hi")]]
    hit <- covers(lo, hi, x$truth, block_hi)
    reps <- split(hit, x$replicate)
    data.frame(
      bootstrap = kind,
      coverage_signal = mean(hit[block == "signal"]),
      coverage_noise = mean(hit[block == "noise"]),
      coverage_all = mean(hit),
      # Every variable of a replicate covered at once, not one at a time.
      coverage_simultaneous = mean(vapply(reps, all, logical(1))),
      width_signal = mean((hi - lo + 1)[block == "signal"]),
      width_all = mean(hi - lo + 1)
    )
  }
  out <- rbind(per("judges"), per("data"))
  out$design <- x$design[1]
  out$n <- x$n[1]
  out$data_boot <- x$data_boot[1]
  out$replicates <- length(unique(x$replicate))
  # Monte Carlo standard error of the all-variable coverage.
  out$mcse <- sqrt(out$coverage_all * (1 - out$coverage_all) /
                     (out$replicates * length(unique(x$variable))))
  out$dropped_per_run <- mean(x$dropped)
  out[c("design", "n", "data_boot", "bootstrap", "replicates",
        "coverage_signal", "coverage_noise", "coverage_all",
        "coverage_simultaneous", "mcse", "width_signal", "width_all",
        "dropped_per_run")]
}

summary_table <- do.call(rbind, lapply(raw, summarise_cell))
rownames(summary_table) <- NULL
write.csv(summary_table, file.path(out_dir, "coverage_summary.csv"),
          row.names = FALSE)

print(summary_table, digits = 3)

# Coverage per variable, for the headline cell.
headline <- raw[["close_n80_boot50"]]
one <- headline[headline$replicate == headline$replicate[1], c("variable", "truth")]
bhi <- setNames(rank_block_hi(one$truth), one$variable)
by_variable <- do.call(rbind, lapply(split(headline, headline$variable), function(v) {
  data.frame(variable = v$variable[1], truth = v$truth[1],
             judges = mean(covers(v$judges_lo, v$judges_hi, v$truth, bhi[v$variable[1]])),
             data = mean(covers(v$data_lo, v$data_hi, v$truth, bhi[v$variable[1]])))
}))
cat("\nPer variable, close design at n = 80:\n")
print(by_variable, row.names = FALSE, digits = 3)
