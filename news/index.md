# Changelog

## rankimp 0.1.0

### New

- [`importance_judges()`](../reference/importance_judges.md) builds the
  panel from fitted models along the four axes of the roadmap, which are
  method, model, seed and resample, and records the provenance, raw
  scores and per-judge weights on the returned `judges` object, which
  [`consensus_rank()`](../reference/consensus_rank.md) consumes weights
  and all. Supported engines: randomForest and ranger; resamples come
  from
  [`rsample::vfold_cv()`](https://rsample.tidymodels.org/reference/vfold_cv.html)
  or
  [`rsample::bootstraps()`](https://rsample.tidymodels.org/reference/bootstraps.html),
  refit on the analysis set and scored on the assessment set.

- Importance backends:
  [`importance_permutation()`](../reference/importance_backends.md),
  [`importance_mdi()`](../reference/importance_backends.md) and
  [`importance_loco()`](../reference/importance_backends.md) are
  implemented natively against the supported engines;
  [`importance_shap()`](../reference/importance_backends.md) delegates
  to kernelshap. The originally planned SHAP backend, fastshap, was
  archived from CRAN on 2026-05-27 (and vip is gone too), so kernelshap
  is the dependency of record.

- [`judge_weights()`](../reference/judge_weights.md) expands method
  weights over a panel, or weighs each judge by its mean Emond–Mason
  `tau_x` agreement with the rest of the panel (`by = "reliability"`).

- [`rank_confsets()`](../reference/rank_confsets.md) bootstraps the
  judges to put a rank confidence set around the consensus,
  [`prob_topk()`](../reference/prob_topk.md) reports the probability
  that a variable belongs to the top `k`, and
  [`rank_select()`](../reference/rank_select.md) keeps the variables
  whose whole interval clears a threshold. Resampling is done with
  multinomial judge weights rather than by rebuilding the panel, which
  `ConsRank` treats identically.

- `rank_confsets(type = "data")` resamples the *rows* instead of the
  panel: every replicate draws the data with replacement, refits every
  model and rebuilds the panel from scratch. It answers the question the
  judge bootstrap cannot, namely whether the ranking would survive
  another sample, and it needs a panel from
  [`importance_judges()`](../reference/importance_judges.md), which now
  carries the recipe that built it. A replicate mirrors the recipe: a
  panel that judged out of sample keeps judging out of sample, on the
  rows the bootstrap left behind. A `resamples` axis is replaced by that
  in-bag/out-of-bag split, so each replicate votes with
  `models x methods` judges rather than `models x methods x V`.
  Replicates that fail, the usual case being a response class too rare
  to survive a draw, are dropped, counted and warned about instead of
  killing the run.

- [`item_consensus()`](../reference/item_consensus.md) scores every
  judge against the consensus, so that a low `tau_x` can be read as a
  split panel rather than as noise.

- [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  for `rank_confsets` draws the consensus ranking with its intervals.

- [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  for `consensus_rank` draws the consensus over every rank the judges
  gave, point area being the number of judges at each rank. One number
  per variable is equally consistent with a panel that agreed and one
  that was split, and this is the difference. It is per variable, where
  `tau_x` and [`item_consensus()`](../reference/item_consensus.md)
  measure it per judge. It was the last entry point still raising “not
  implemented”; the helper that raised it is gone with it.

- Two vignettes for the parts the task-shaped ones do not cover.
  [`vignette("reference")`](../articles/reference.md) is the map: what
  each exported function is for, what it returns, which mistake it
  exists to prevent, and a table for picking one by the question you are
  asking. [`vignette("theory")`](../articles/theory.md) is the argument
  behind the code: why the consensus is a Kemeny median rather than an
  average of ranks, why ties and non-unique optima are kept rather than
  broken, why `tau_x` and not Kendall’s tau_b, what each of the two
  bootstraps is estimating, and why the heterogeneity test needs a
  reference distribution instead of a silhouette threshold.

- [`vignette("credit-scoring")`](../articles/credit-scoring.md) runs the
  four axes at once on a synthetic portfolio of two model families, two
  methods, three folds and two seeds, making 24 judges, and is no longer
  a placeholder. Its point is what the package refuses to say: the three
  real drivers all come back with the interval `[1, 3]`, so
  `rank_select(threshold = 2)` returns nothing, and only the unordered
  set of three is defensible.
  [`judge_clusters()`](../reference/judge_clusters.md) then finds the
  panel divided along **method** rather than model family, which is mean
  decrease in impurity preferring the continuous variable to the small
  count.

- [`vignette("against-set-stability")`](../articles/against-set-stability.md)
  separates this package from `stabm`: two panels with identical
  Nogueira and Jaccard set stability, one of which has a completely
  unordered top three.

### Changed

- `algorithm = "auto"` uses exact branch-and-bound up to ten variables
  rather than twelve. Its cost is not smooth in `p` and the panels this
  package produces are the hard ones, because unimportant variables tie
  near zero. On tied panels of thirty judges one exact solve took 0.010
  s at `p = 10`, 0.78 s at `p = 11` and 280 s at `p = 12`, while
  `"quick"` returned the identical consensus and `tau_x` on twenty out
  of twenty tied panels at `p = 10`.

- [`consensus_rank()`](../reference/consensus_rank.md) no longer reports
  an arbitrary one of the equally optimal consensus rankings. The Kemeny
  median need not be unique and `ConsRank` returns every ranking
  attaining the minimum; taking the first was not neutral, because which
  came first depended on the order of the columns. On a symmetric panel
  of three indistinguishable variables, permuting the columns changed
  the winner, and in simulation a variable of pure noise outranked a
  real one by sitting further left. Several optima arose in 57% to 98%
  of replicates there, so this was the normal case rather than an edge
  case. The optima are now combined, each variable taking its average
  position over them and those that come out equal being tied, so
  variables the objective cannot separate are reported as equal. The
  full set stays in `consensus_all`. The same correction applies to both
  bootstrap branches of
  [`rank_confsets()`](../reference/rank_confsets.md) and to
  [`item_consensus()`](../reference/item_consensus.md), which now scores
  judges against the consensus the user was shown.

### Correctness

- [`judge_clusters()`](../reference/judge_clusters.md) is implemented:
  k-medians in the space of the Kemeny-Snell distance, started from the
  exactly optimal set of medoids and refined until the assignments
  settle, with each group’s centre the Kemeny median of its own members.
  It draws nothing from the RNG and returns the same answer on every
  call. `k = NULL` divides the panel only when it splits more sharply
  than a single population of judges would, tested against reference
  panels spread to match, without which the silhouette alone divided a
  homogeneous panel 62% of the time. A panel the test rejects is
  reported as divided **in two**, which is the division the evidence is
  about: reading `k` off the largest silhouette instead attaches an
  uncalibrated number to a calibrated decision, and it measured worse
  everywhere it differed: on ten judges or more it never once chose
  `k = 2`, and recovery of a true two-group partition *fell* as judges
  were added (0.877 at six, 0.747 at ten, 0.690 at sixteen) where it now
  rises to 0.943, at an identical false division rate.
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  shows the panel in Kemeny-Snell space. Behaviour is measured in
  `inst/simulations/cluster-recovery.R` rather than asserted.

- [`consensus_rank()`](../reference/consensus_rank.md) no longer leaks
  `ConsRank`’s console output on degenerate panels. The previous calling
  handler never invoked `muffleMessage()`, so it suppressed nothing, and
  the messages that matter are emitted with
  [`print()`](https://rdrr.io/r/base/print.html) and cannot be caught by
  a handler at all. They are captured instead.

- [`consensus_rank()`](../reference/consensus_rank.md) rejects a judge
  whose best rank is not 1. The previous check tested `any(x < 1)`,
  which admitted rankings starting at 2 and admitted a matrix of
  importance scores, contradicting the documented contract. The error
  now names the offending judges and points at
  [`importance_to_rank()`](../reference/importance_to_rank.md).

- [`prob_topk()`](../reference/prob_topk.md) and
  [`rank_select()`](../reference/rank_select.md) are measured for the
  first time, in `inst/simulations/select-calibration.R`. Both read the
  bootstrap rankings the resample bug used to repeat, so neither had
  ever been seen working. On 300 panels of eight close predictors and
  eighty rows: [`prob_topk()`](../reference/prob_topk.md) is
  conservative in the middle of its range and accurate at the ends, so
  that a variable given 0.44 is in the top `k` 56% of the time and one
  given 0.98 is there 98% of the time.
  [`rank_select()`](../reference/rank_select.md) falsely selects at most
  3% of what it selects, while selecting between a third and a half of
  the variables that deserved it. Both numbers are now in the
  documentation.

- The warning in [`?rank_confsets`](../reference/rank_confsets.md) that
  a data-bootstrap interval “need not contain the consensus rank”
  described the resample bug, not the method. It rested on one panel
  with an interval of `[3, 5]` around a consensus rank of 2, produced by
  the bootstrap that repeated its draws and so reported intervals too
  narrow to be believed. Re-measured on the fixed machinery over the
  same design, it happened in none of 2,400 variable-replicates. What is
  real, and now documented in its place, is the drift: a replicate ranks
  on about 0.632`n` distinct rows, so the top of the ranking drifts down
  and the bottom drifts up by 0.55 ranks for the second variable and
  1.00 for the eighth.

- `rank_confsets(type = "data")` draws a fresh resample for every
  replicate. `panel_scores()` calls
  [`set.seed()`](https://rdrr.io/r/base/Random.html) for the seed axis
  and used to leave the session stream parked where the last seed put
  it; the bootstrap loop draws its next resample from that stream, so
  every replicate set out from the same state and the resamples fell
  into a cycle a few draws long. Four hundred requested replicates held
  about eight distinct ones, and `n_boot` bought almost nothing beyond
  the first few. The panel now puts the caller’s stream back where it
  found it, so
  [`importance_judges()`](../reference/importance_judges.md) no longer
  moves it either, and the bootstrap restores it around each replicate,
  which keeps the replicates independent whatever a backend does with
  the RNG. The judge bootstrap was never affected: nothing on that path
  seeds.

- [`?rank_confsets`](../reference/rank_confsets.md) and
  [`vignette("stability")`](../articles/stability.md) report the
  coverage the intervals were measured to have rather than leaving the
  nominal level to speak for itself, and the two bootstraps miss it in
  opposite directions. Resampling the data covered 0.966 to 0.998 of the
  time across the six cells measured, at or above the nominal 0.95, and
  wide: 5.1 of 8 ranks on the hardest cell. Resampling the judges
  covered 0.582 to 0.929, and never reached the nominal level. Fifty
  replicates are enough for the data bootstrap (0.966 against 0.970 at
  200). The simulation ships as `inst/simulations/rank-coverage.R`.

### API

- [`consensus_rank()`](../reference/consensus_rank.md) retains the panel
  and the judge weights in the returned object, as `$judges` and
  `$weights`. [`rank_confsets()`](../reference/rank_confsets.md)
  bootstraps the judges and cannot do that from a ranking alone.
- [`importance_judges()`](../reference/importance_judges.md) records the
  recipe that built the panel, meaning the fits, the data, the target,
  the methods, the axes and the backend settings, as an attribute of the
  returned `judges` object, so that
  [`rank_confsets()`](../reference/rank_confsets.md) can rebuild the
  panel on a bootstrap sample without being handed them all again. The
  panel is correspondingly as large as the objects it refers to.
- [`rank_confsets()`](../reference/rank_confsets.md) gained `type`, and
  `n_boot` now defaults by kind: 500 replicates for the judge bootstrap,
  50 for the data bootstrap, which refits every model on every
  replicate. A long data bootstrap announces its projected cost,
  measured on the first replicate.

### Initial scaffolding

- [`consensus_rank()`](../reference/consensus_rank.md) computes the
  Kemeny median of a panel of judges, with ties, optional judge weights,
  and automatic selection of the `ConsRank` solver from the number of
  variables.
- [`importance_to_rank()`](../reference/importance_to_rank.md) converts
  importance scores to rankings, preserving ties between variables a
  judge scores equally.
- [`print()`](https://rdrr.io/r/base/print.html) method for the
  `consensus_rank` class, reporting the `tau_x` agreement and warning
  when several consensus rankings are equally optimal.
- The ingestion (F1), inference (F3) and heterogeneity (F4) entry points
  were declared and documented from the first commit, failing with an
  error naming their phase until implemented. All of them are now
  implemented; [`judge_clusters()`](../reference/judge_clusters.md) (F4)
  was the last.
