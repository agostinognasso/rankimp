# What `judge_clusters()` actually does -----------------------------------------
#
# Automatic selection of the number of groups has two ways of being wrong, and
# only one of them is usually measured. Missing a real division is the visible
# failure. Splitting a panel that does not divide is the invisible one, and it
# is the more damaging here: the whole point of the function is to say "these
# methods see the model differently", and a false split says it about methods
# that do not.
#
# Two parts:
#
#   1. Synthetic panels with a known structure. Recovery of the partition, and
#      the rate of false division on panels drawn from one population.
#   2. Real panels, where marginal and conditional importances are computed on
#      correlated predictors. This is the claim `vignette("method-disagreement")`
#      makes, and the part that cannot be checked by construction.
#
#   Rscript inst/simulations/cluster-recovery.R <output-directory>
#
# Expect a couple of minutes for part 1 and about a quarter of an hour for
# part 2 on twelve cores.

if (requireNamespace("rankimp", quietly = TRUE)) {
  library(rankimp)
} else {
  pkgload::load_all(quiet = TRUE)
}
library(parallel)

out_dir <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(out_dir)) out_dir <- tempdir()
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
cores <- getOption("mc.cores", max(1L, detectCores() - 2L))

P <- 8L           # variables a judge ranks
REPLICATES <- 300L

# --- ranking machinery -------------------------------------------------------

# A random walk of adjacent transpositions. `steps` controls how far a judge
# strays from its group's centre: 0 reproduces it, and enough steps forget it.
perturb <- function(ranking, steps) {
  order_of <- order(ranking)
  for (s in seq_len(steps)) {
    i <- sample.int(length(ranking) - 1L, 1L)
    order_of[c(i, i + 1L)] <- order_of[c(i + 1L, i)]
  }
  out <- integer(length(ranking))
  out[order_of] <- seq_along(ranking)
  out
}

# Two labellings induce the same partition. Comparing an adjusted Rand index
# with 1 would ask a floating point number to be exact.
same_partition <- function(a, b) {
  all(outer(a, a, "==") == outer(b, b, "=="))
}

# Adjusted Rand index, written out rather than depended on.
adjusted_rand <- function(a, b) {
  tab <- table(a, b)
  n <- length(a)
  sum_ij <- sum(choose(tab, 2L))
  sum_i <- sum(choose(rowSums(tab), 2L))
  sum_j <- sum(choose(colSums(tab), 2L))
  expected <- sum_i * sum_j / choose(n, 2L)
  maximum <- (sum_i + sum_j) / 2
  if (maximum == expected) return(1)
  (sum_ij - expected) / (maximum - expected)
}

named_panel <- function(rows, labels) {
  m <- do.call(rbind, rows)
  rownames(m) <- labels
  colnames(m) <- paste0("x", seq_len(ncol(m)))
  m
}

# --- part 1: synthetic panels ------------------------------------------------

# `separation` is how far the second group's centre sits from the first, in
# adjacent transpositions; `noise` is how far each judge strays from its own.
one_synthetic <- function(i, separation, noise, groups, judges) {
  centre1 <- seq_len(P)
  centre2 <- if (groups == 1L) centre1 else perturb(centre1, separation)
  # The panel is the same size either way: otherwise the false division rate
  # would be measured on a smaller panel than the recovery rate.
  truth <- rep(seq_len(groups), each = judges / groups)
  centres <- list(centre1, centre2)

  rows <- lapply(truth, function(g) perturb(centres[[g]], noise))
  panel <- named_panel(rows, paste0("j", seq_along(rows)))

  het <- judge_clusters(panel)
  data.frame(
    replicate = i, separation = separation, noise = noise, groups = groups,
    judges = judges, k = het$k,
    ari = adjusted_rand(truth, het$cluster),
    exact_partition = het$k == groups && same_partition(truth, het$cluster)
  )
}

grid <- expand.grid(
  separation = c(4L, 8L, 16L),
  noise = c(1L, 3L),
  groups = 1:2,
  judges = 6L
)
# One population has no separation to vary: keep a single row for it.
grid <- grid[!(grid$groups == 1L & grid$separation != 4L), ]

# How much a bigger panel buys. The panel the roadmap describes — two methods
# by three seeds — is six judges, and six points in a discrete space is very
# little to establish a grouping from.
grid <- rbind(grid, expand.grid(separation = 16L, noise = 1L, groups = 1:2,
                                judges = c(10L, 16L)))

RNGkind("L'Ecuyer-CMRG")
set.seed(20260906L)

part1 <- do.call(rbind, lapply(seq_len(nrow(grid)), function(g) {
  cell <- grid[g, ]
  res <- mclapply(seq_len(REPLICATES), one_synthetic,
                  separation = cell$separation, noise = cell$noise,
                  groups = cell$groups, judges = cell$judges,
                  mc.cores = cores, mc.set.seed = TRUE)
  do.call(rbind, Filter(is.data.frame, res))
}))

saveRDS(part1, file.path(out_dir, "cluster_synthetic.rds"))

summarise1 <- function(x) {
  by_cell <- split(x, list(x$groups, x$separation, x$noise, x$judges), drop = TRUE)
  do.call(rbind, lapply(by_cell, function(cell) {
    data.frame(
      groups = cell$groups[1L],
      judges = cell$judges[1L],
      separation = cell$separation[1L],
      noise = cell$noise[1L],
      replicates = nrow(cell),
      found_k = mean(cell$k == cell$groups),
      # For one population this is the false division rate.
      split_anyway = if (cell$groups[1L] == 1L) mean(cell$k > 1L) else NA_real_,
      recovered = if (cell$groups[1L] > 1L) mean(cell$exact_partition) else NA_real_,
      mean_ari = mean(cell$ari, na.rm = TRUE)
    )
  }))
}

cat("\n=== 1. Synthetic panels: ", REPLICATES, " replicates per cell ===\n", sep = "")
cat("(P = ", P, " variables; separation and noise are adjacent transpositions)\n\n",
    sep = "")
print(summarise1(part1), row.names = FALSE, digits = 3)
cat("\nfound_k       : the chosen k equals the true number of groups\n")
cat("split_anyway  : one population divided anyway — the false division rate\n")
cat("recovered     : two populations, partition exactly right\n")

# --- part 2: marginal against conditional on correlated predictors -----------

if (!requireNamespace("randomForest", quietly = TRUE)) {
  message("randomForest not installed: skipping part 2.")
  quit(save = "no")
}
library(randomForest)

REPLICATES2 <- 100L
N <- 300L

# x1 and x2 carry the same signal and are nearly interchangeable. A marginal
# measure credits both; a conditional one credits whichever it drops second.
# That is the disagreement the vignette claims, and the panel should split on
# it rather than average it away.
simulate_correlated <- function(n, rho) {
  z <- rnorm(n)
  # x = z + e with e ~ N(0, s^2) gives cor(x1, x2) = 1 / (1 + s^2).
  s <- sqrt((1 - rho) / rho)
  d <- data.frame(
    x1 = z + rnorm(n, sd = s),
    x2 = z + rnorm(n, sd = s),
    x3 = rnorm(n), x4 = rnorm(n), x5 = rnorm(n)
  )
  d$y <- 1.5 * z + 0.8 * d$x3 + rnorm(n)
  d
}

one_real <- function(i, rho, n_seeds) {
  seeds <- n_seeds * (as.integer(i) - 1L) + seq_len(n_seeds)
  attempt <- try({
    d <- simulate_correlated(N, rho)
    fit <- randomForest(y ~ ., data = d, ntree = 200L)
    J <- importance_judges(fit, methods = c("permutation", "loco"),
                           data = d, target = "y", seeds = seeds, n_perm = 5)
    het <- judge_clusters(J)
    family <- attr(J, "provenance")$method
    data.frame(
      replicate = i, rho = rho, judges = nrow(J), k = het$k,
      # Does the division fall on the method family, whatever k it chose?
      matches_family = het$k == 2L && same_partition(family, het$cluster),
      ari_family = adjusted_rand(family, het$cluster),
      tau = consensus_rank(J)$tau
    )
  }, silent = TRUE)
  if (inherits(attempt, "try-error")) NULL else attempt
}

cells2 <- rbind(data.frame(rho = 0.9, n_seeds = 3L),
                data.frame(rho = 0.9, n_seeds = 8L),
                data.frame(rho = 0.5, n_seeds = 3L))

part2 <- do.call(rbind, lapply(seq_len(nrow(cells2)), function(j) {
  cell <- cells2[j, ]
  set.seed(20260907L + round(100 * cell$rho) + cell$n_seeds)
  res <- mclapply(seq_len(REPLICATES2), one_real, rho = cell$rho,
                  n_seeds = cell$n_seeds, mc.cores = cores, mc.set.seed = TRUE)
  do.call(rbind, Filter(is.data.frame, res))
}))

saveRDS(part2, file.path(out_dir, "cluster_real.rds"))

cat("\n=== 2. Real panels: permutation against LOCO on correlated predictors ===\n\n")
print(do.call(rbind, lapply(split(part2, list(part2$rho, part2$judges), drop = TRUE),
                           function(cell) {
  data.frame(
    rho = cell$rho[1L], judges = cell$judges[1L], replicates = nrow(cell),
    mean_tau = mean(cell$tau),
    split_in_two = mean(cell$k == 2L),
    along_the_method = mean(cell$matches_family),
    mean_ari = mean(cell$ari_family)
  )
})), row.names = FALSE, digits = 3)
cat("\nalong_the_method : split in two AND the two groups are exactly the two\n",
    "                   method families, which is the vignette's claim\n", sep = "")
