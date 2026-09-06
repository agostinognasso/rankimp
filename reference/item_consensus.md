# Agreement of each judge with the consensus

The Emond-Mason `tau_x` between each judge's ranking and the consensus.
`cr$tau` is the (weighted) mean of this column; the column itself says
whether that mean summarises a panel that agrees or averages a panel
that is split, which are different situations reported by the same
number.

## Usage

``` r
item_consensus(cr)
```

## Arguments

- cr:

  A `consensus_rank` object.

## Value

A tibble with one row per judge: its name (or index), its weight, and
its `tau_x` against the consensus, in increasing order of agreement.

## Details

A judge with a `tau_x` near zero is not necessarily wrong. Marginal and
conditional importance measures disagree by construction when the
predictors are correlated, and one of them will look like an outlier
against a panel dominated by the other.

## See also

[`judge_clusters()`](judge_clusters.md) for what to do when the
agreement is low.

## Examples

``` r
judges <- rbind(
  permutation = c(1, 2, 3, 4),
  shap        = c(1, 3, 2, 4),
  impurity    = c(4, 3, 2, 1)
)
colnames(judges) <- c("income", "age", "balance", "region")
item_consensus(consensus_rank(judges))
#> # A tibble: 3 × 3
#>   judge       weight  tau_x
#>   <chr>        <dbl>  <dbl>
#> 1 impurity         1 -0.667
#> 2 permutation      1  0.667
#> 3 shap             1  1    
```
