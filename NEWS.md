# rankimp 0.0.0.9000

## New

* `rank_confsets()` bootstraps the judges to put a rank confidence set around
  the consensus, `prob_topk()` reports the probability that a variable belongs
  to the top `k`, and `rank_select()` keeps the variables whose whole interval
  clears a threshold. Resampling is done with multinomial judge weights rather
  than by rebuilding the panel, which `ConsRank` treats identically.
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

## Initial scaffolding

* `consensus_rank()` computes the Kemeny median of a panel of judges, with
  ties, optional judge weights, and automatic selection of the `ConsRank`
  solver from the number of variables.
* `importance_to_rank()` converts importance scores to rankings, preserving
  ties between variables a judge scores equally.
* `print()` method for the `consensus_rank` class, reporting the `tau_x`
  agreement and warning when several consensus rankings are equally optimal.
* The ingestion (F1), inference (F3) and heterogeneity (F4) entry points are
  declared and documented; calling them raises an error naming the phase in
  which they are scheduled.
