# rankimp 0.0.0.9000

## New

* `importance_judges()` builds the panel from fitted models along the four
  axes of the roadmap — method, model, seed, resample — and records the
  provenance, raw scores and per-judge weights on the returned `judges`
  object, which `consensus_rank()` consumes weights and all. Supported
  engines: randomForest and ranger; resamples come from `rsample::vfold_cv()`
  or `rsample::bootstraps()`, refit on the analysis set and scored on the
  assessment set.
* Importance backends: `importance_permutation()`, `importance_mdi()` and
  `importance_loco()` are implemented natively against the supported engines;
  `importance_shap()` delegates to kernelshap. The originally planned SHAP
  backend, fastshap, was archived from CRAN on 2026-05-27 (and vip is gone
  too), so kernelshap is the dependency of record.
* `judge_weights()` expands method weights over a panel, or weighs each judge
  by its mean Emond–Mason `tau_x` agreement with the rest of the panel
  (`by = "reliability"`).
* `rank_confsets()` bootstraps the judges to put a rank confidence set around
  the consensus, `prob_topk()` reports the probability that a variable belongs
  to the top `k`, and `rank_select()` keeps the variables whose whole interval
  clears a threshold. Resampling is done with multinomial judge weights rather
  than by rebuilding the panel, which `ConsRank` treats identically.
* `rank_confsets(type = "data")` resamples the *rows* instead of the panel:
  every replicate draws the data with replacement, refits every model and
  rebuilds the panel from scratch. It answers the question the judge bootstrap
  cannot — whether the ranking would survive another sample — and it needs a
  panel from `importance_judges()`, which now carries the recipe that built it.
  A replicate mirrors the recipe: a panel that judged out of sample keeps
  judging out of sample, on the rows the bootstrap left behind. A `resamples`
  axis is replaced by that in-bag/out-of-bag split, so each replicate votes with
  `models x methods` judges rather than `models x methods x V`. Replicates that
  fail — a response class too rare to survive a draw is the case that happens —
  are dropped, counted and warned about instead of killing the run.
* `item_consensus()` scores every judge against the consensus, so that a low
  `tau_x` can be read as a split panel rather than as noise.
* `autoplot()` for `rank_confsets` draws the consensus ranking with its
  intervals.
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

## Correctness

* `consensus_rank()` no longer leaks `ConsRank`'s console output on degenerate
  panels. The previous calling handler never invoked `muffleMessage()`, so it
  suppressed nothing, and the messages that matter are emitted with `print()`
  and cannot be caught by a handler at all. They are captured instead.
* `consensus_rank()` rejects a judge whose best rank is not 1. The previous
  check tested `any(x < 1)`, which admitted rankings starting at 2 and admitted
  a matrix of importance scores, contradicting the documented contract. The
  error now names the offending judges and points at `importance_to_rank()`.

## API

* `consensus_rank()` retains the panel and the judge weights in the returned
  object, as `$judges` and `$weights`. `rank_confsets()` bootstraps the judges
  and cannot do that from a ranking alone.
* `importance_judges()` records the recipe that built the panel — the fits, the
  data, the target, the methods, the axes and the backend settings — as an
  attribute of the returned `judges` object, so that `rank_confsets()` can
  rebuild the panel on a bootstrap sample without being handed them all again.
  The panel is correspondingly as large as the objects it refers to.
* `rank_confsets()` gained `type`, and `n_boot` now defaults by kind: 500
  replicates for the judge bootstrap, 50 for the data bootstrap, which refits
  every model on every replicate. A long data bootstrap announces its projected
  cost, measured on the first replicate.

## Initial scaffolding

* `consensus_rank()` computes the Kemeny median of a panel of judges, with
  ties, optional judge weights, and automatic selection of the `ConsRank`
  solver from the number of variables.
* `importance_to_rank()` converts importance scores to rankings, preserving
  ties between variables a judge scores equally.
* `print()` method for the `consensus_rank` class, reporting the `tau_x`
  agreement and warning when several consensus rankings are equally optimal.
* The ingestion (F1), inference (F3) and heterogeneity (F4) entry points were
  declared and documented from the first commit, failing with an error naming
  their phase until implemented. Of these, only `judge_clusters()` (F4) still
  does.
