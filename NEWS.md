# rankimp 0.0.0.9000

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
