# Weights for the panel of judges

Not every judge deserves an equal say. Impurity-based importance is
known to favour high-cardinality predictors, so a panel that mixes it
with permutation importance may want to down-weight it rather than let
the two cancel out. The returned vector plugs straight into
[`consensus_rank()`](consensus_rank.md)'s `weights` argument.

## Usage

``` r
judge_weights(judges, by = c("equal", "method", "reliability"), values = NULL)
```

## Arguments

- judges:

  A `judges` object from [`importance_judges()`](importance_judges.md),
  or a plain ranking matrix (judges in rows) for the schemes that need
  no provenance.

- by:

  Weighting scheme: `"equal"`, `"method"` or `"reliability"`.

- values:

  Named numeric vector of method weights, when `by = "method"`: every
  method present in the panel must be named.

## Value

A named numeric vector of positive weights, one per judge.

## Schemes

- `"equal"`: every judge weighs 1.

- `"method"`: one weight per importance method, supplied through
  `values` and expanded over the judges. Needs the provenance that
  [`importance_judges()`](importance_judges.md) records, so it only
  works on a `judges` object.

- `"reliability"`: a judge's weight grows with its agreement with the
  rest of the panel: \\w_k = (1 + \bar\tau_k)/2\\, where \\\bar\tau_k\\
  is the mean Emond–Mason \\\tau_x\\ correlation between judge \\k\\ and
  every other judge, computed with
  [`ConsRank::tau_x()`](https://rdrr.io/pkg/ConsRank/man/tau_x.html).
  Weights are normalised to mean 1, and floored at machine epsilon so
  that a judge in perfect disagreement with everyone is effectively,
  though not numerically, excluded. Down-weighting the dissenters
  sharpens the consensus around the majority view; when dissent is the
  interesting signal, look at [`judge_clusters()`](judge_clusters.md)
  instead of weighting it away.

## See also

[`importance_judges()`](importance_judges.md),
[`consensus_rank()`](consensus_rank.md)

## Examples

``` r
judges <- rbind(
  c(1, 2, 3, 4), c(1, 2, 4, 3), c(2, 1, 3, 4), c(4, 3, 2, 1)
)
colnames(judges) <- c("income", "age", "balance", "region")
judge_weights(judges, by = "reliability")
#> judge1 judge2 judge3 judge4 
#>   1.25   1.25   1.25   0.25 
```
