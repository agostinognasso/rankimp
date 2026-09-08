# rankimp 1.0.0

First stable release. The interface is settled and breaking changes from here
go through a deprecation cycle.

## New

* `applications` is a new dataset: 800 synthetic loan applications, seven
  predictors and a default indicator, shipped so that a question about a
  ranking has an answer to check against. The effects a ranking ought to
  recover are stored on the data frame as `attr(applications, "effects")`.
* It is built to make importance measures disagree, because a dataset on which
  they agree has nothing to say about a package for reconciling them.
  `bureau_score` and `income` come from one latent creditworthiness and
  correlate at 0.84, so the credit for the signal has to be divided somehow,
  and both measures below invert them relative to the truth. `prior_arrears` is
  the largest effect in the data and takes six distinct values: on a forest of
  500 trees, impurity importance puts it fourth while permutation importance
  puts it first. Over the seven predictors the two agree with each other at a
  Kendall tau of 0.71, and against the truth at 0.59 for impurity and 0.88 for
  permutation.

# rankimp 0.1.0

## New

* `importance_judges()` builds the panel from fitted models along the four
  axes of the roadmap, which are method, model, seed and resample, and records
  the provenance, raw scores and per-judge weights on the returned `judges`
  object, which `consensus_rank()` consumes weights and all. Supported engines:
  randomForest and ranger; resamples come from `rsample::vfold_cv()` or
  `rsample::bootstraps()`, refit on the analysis set and scored on the
  assessment set.
* Importance backends: `importance_permutation()`, `importance_mdi()` and
  `importance_loco()` are implemented natively against the supported engines;
  `importance_shap()` delegates to kernelshap. The originally planned SHAP
  backend, fastshap, was archived from CRAN on 2026-05-27 (and vip is gone too),
  so kernelshap is the dependency of record.
* `judge_weights()` expands method weights over a panel, or weighs each judge
  by its mean Emond-Mason `tau_x` agreement with the rest of the panel
  (`by = "reliability"`).
* `rank_confsets()` bootstraps the judges to put a rank confidence set around
  the consensus, `prob_topk()` reports the probability that a variable belongs
  to the top `k`, and `rank_select()` keeps the variables whose whole interval
  clears a threshold. Resampling is done with multinomial judge weights rather
  than by rebuilding the panel, which `ConsRank` treats identically.
* `rank_confsets(type = "data")` resamples the *rows* instead of the panel:
  every replicate draws the data with replacement, refits every model and
  rebuilds the panel from scratch. It answers the question the judge bootstrap
  cannot, namely whether the ranking would survive another sample, and it needs
  a panel from `importance_judges()`, which now carries the recipe that built
  it. A replicate mirrors the recipe: a panel that judged out of sample keeps
  judging out of sample, on the rows the bootstrap left behind. A `resamples`
  axis is replaced by that in-bag/out-of-bag split, so each replicate votes with
  `models x methods` judges rather than `models x methods x V`. Replicates that
  fail, the usual case being a response class too rare to survive a draw, are
  dropped, counted and warned about instead of killing the run.
* `item_consensus()` scores every judge against the consensus, so that a low
  `tau_x` can be read as a split panel rather than as noise.
* `autoplot()` for `rank_confsets` draws the consensus ranking with its
  intervals.
* `autoplot()` for `consensus_rank` draws the consensus over every rank the
  judges gave, point area being the number of judges at each rank. One number
  per variable is equally consistent with a panel that agreed and one that was
  split, and this is the difference. It is per variable, where `tau_x` and
  `item_consensus()` measure it per judge. It was the last entry point still
  raising "not implemented"; the helper that raised it is gone with it.
* Two vignettes for the parts the task-shaped ones do not cover.
  `vignette("reference")` is the map: what each exported function is for, what
  it returns, which mistake it exists to prevent, and a table for picking one
  by the question you are asking. `vignette("theory")` is the argument behind
  the code: why the consensus is a Kemeny median rather than an average of
  ranks, why ties and non-unique optima are kept rather than broken, why
  `tau_x` and not Kendall's tau_b, what each of the two bootstraps is
  estimating, and why the heterogeneity test needs a reference distribution
  instead of a silhouette threshold.

* `vignette("credit-scoring")` runs the four axes at once on a synthetic
  portfolio of two model families, two methods, three folds and two seeds,
  making 24 judges, and is no longer a placeholder. Its point is what the
  package refuses to say: the three real drivers all come back with the interval
  `[1, 3]`, so `rank_select(threshold = 2)` returns nothing, and only the
  unordered set of three is defensible. `judge_clusters()` then finds the panel
  divided along **method** rather than model family, which is mean decrease in
  impurity preferring the continuous variable to the small count.
* `vignette("against-set-stability")` separates this package from `stabm`:
  two panels with identical Nogueira and Jaccard set stability, one of which has
  a completely unordered top three.

## Changed

* `algorithm = "auto"` uses exact branch-and-bound up to ten variables rather
  than twelve. Its cost is not smooth in `p` and the panels this package
  produces are the hard ones, because unimportant variables tie near zero. On
  tied panels of thirty judges one exact solve took 0.010 s at `p = 10`, 0.78 s
  at `p = 11` and 280 s at `p = 12`, while `"quick"` returned the identical
  consensus and `tau_x` on twenty out of twenty tied panels at `p = 10`.

* `consensus_rank()` no longer reports an arbitrary one of the equally optimal
  consensus rankings. The Kemeny median need not be unique and `ConsRank`
  returns every ranking attaining the minimum; taking the first was not neutral,
  because which came first depended on the order of the columns. On a symmetric
  panel of three indistinguishable variables, permuting the columns changed the
  winner, and in simulation a variable of pure noise outranked a real one by
  sitting further left. Several optima arose in 57% to 98% of replicates there,
  so this was the normal case rather than an edge case. The optima are now
  combined, each variable taking its average position over them and those that
  come out equal being tied, so variables the objective cannot separate are
  reported as equal. The full set stays in `consensus_all`. The same correction
  applies to both bootstrap branches of `rank_confsets()` and to
  `item_consensus()`, which now scores judges against the consensus the user was
  shown.

## Correctness

* `judge_clusters()` is implemented: k-medians in the space of the Kemeny-Snell
  distance, started from the exactly optimal set of medoids and refined until
  the assignments settle, with each group's centre the Kemeny median of its own
  members. It draws nothing from the RNG and returns the same answer on every
  call. `k = NULL` divides the panel only when it splits more sharply than a
  single population of judges would, tested against reference panels spread to
  match, without which the silhouette alone divided a homogeneous panel 62% of
  the time. A panel the test rejects is reported as divided **in two**, which is
  the division the evidence is about: reading `k` off the largest silhouette
  instead attaches an uncalibrated number to a calibrated decision, and it
  measured worse everywhere it differed: on ten judges or more it never once
  chose `k = 2`, and recovery of a true two-group partition *fell* as judges
  were added (0.877 at six, 0.747 at ten, 0.690 at sixteen) where it now rises
  to 0.943, at an identical false division rate. `autoplot()` shows the panel in
  Kemeny-Snell space. Behaviour is measured in
  `inst/simulations/cluster-recovery.R` rather than asserted.

* `consensus_rank()` no longer leaks `ConsRank`'s console output on degenerate
  panels. The previous calling handler never invoked `muffleMessage()`, so it
  suppressed nothing, and the messages that matter are emitted with `print()`
  and cannot be caught by a handler at all. They are captured instead.
* `consensus_rank()` rejects a judge whose best rank is not 1. The previous
  check tested `any(x < 1)`, which admitted rankings starting at 2 and admitted
  a matrix of importance scores, contradicting the documented contract. The
  error now names the offending judges and points at `importance_to_rank()`.

* `prob_topk()` and `rank_select()` are measured for the first time, in
  `inst/simulations/select-calibration.R`. Both read the bootstrap rankings the
  resample bug used to repeat, so neither had ever been seen working. On 300
  panels of eight close predictors and eighty rows: `prob_topk()` is
  conservative in the middle of its range and accurate at the ends, so that a
  variable given 0.44 is in the top `k` 56% of the time and one given 0.98 is
  there 98% of the time. `rank_select()` falsely selects at most 3% of what it
  selects, while selecting between a third and a half of the variables that
  deserved it. Both numbers are now in the documentation.

* The warning in `?rank_confsets` that a data-bootstrap interval "need not
  contain the consensus rank" described the resample bug, not the method. It
  rested on one panel with an interval of `[3, 5]` around a consensus rank of 2,
  produced by the bootstrap that repeated its draws and so reported intervals
  too narrow to be believed. Re-measured on the fixed machinery over the same
  design, it happened in none of 2,400 variable-replicates. What is real, and
  now documented in its place, is the drift: a replicate ranks on about 0.632`n`
  distinct rows, so the top of the ranking drifts down and the bottom drifts up
  by 0.55 ranks for the second variable and 1.00 for the eighth.

* `rank_confsets(type = "data")` draws a fresh resample for every replicate.
  `panel_scores()` calls `set.seed()` for the seed axis and used to leave the
  session stream parked where the last seed put it; the bootstrap loop draws its
  next resample from that stream, so every replicate set out from the same state
  and the resamples fell into a cycle a few draws long. Four hundred requested
  replicates held about eight distinct ones, and `n_boot` bought almost nothing
  beyond the first few. The panel now puts the caller's stream back where it
  found it, so `importance_judges()` no longer moves it either, and the
  bootstrap restores it around each replicate, which keeps the replicates
  independent whatever a backend does with the RNG. The judge bootstrap was
  never affected: nothing on that path seeds.

* `?rank_confsets` and `vignette("stability")` report the coverage the intervals
  were measured to have rather than leaving the nominal level to speak for
  itself, and the two bootstraps miss it in opposite directions. Resampling the
  data covered 0.966 to 0.998 of the time across the six cells measured, at or
  above the nominal 0.95, and wide: 5.1 of 8 ranks on the hardest cell.
  Resampling the judges covered 0.582 to 0.929, and never reached the nominal
  level. Fifty replicates are enough for the data bootstrap (0.966 against 0.970
  at 200). The simulation ships as `inst/simulations/rank-coverage.R`.

## API

* `consensus_rank()` retains the panel and the judge weights in the returned
  object, as `$judges` and `$weights`. `rank_confsets()` bootstraps the judges
  and cannot do that from a ranking alone.
* `importance_judges()` records the recipe that built the panel, meaning the
  fits, the data, the target, the methods, the axes and the backend settings, as
  an attribute of the returned `judges` object, so that `rank_confsets()` can
  rebuild the panel on a bootstrap sample without being handed them all again.
  The panel is correspondingly as large as the objects it refers to.
* `rank_confsets()` gained `type`, and `n_boot` now defaults by kind: 500
  replicates for the judge bootstrap, 50 for the data bootstrap, which refits
  every model on every replicate. A long data bootstrap announces its projected
  cost, measured on the first replicate.

## Initial scaffolding

* `consensus_rank()` computes the Kemeny median of a panel of judges, with
  ties, optional judge weights, and automatic selection of the `ConsRank` solver
  from the number of variables.
* `importance_to_rank()` converts importance scores to rankings, preserving
  ties between variables a judge scores equally.
* `print()` method for the `consensus_rank` class, reporting the `tau_x`
  agreement and warning when several consensus rankings are equally optimal.
* The ingestion (F1), inference (F3) and heterogeneity (F4) entry points were
  declared and documented from the first commit, failing with an error naming
  their phase until implemented. All of them are now implemented;
  `judge_clusters()` (F4) was the last.
