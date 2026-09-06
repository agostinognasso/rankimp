# Probability that a variable lands in the top k

The proportion of bootstrap replicates in which the variable's consensus
rank is at most `k`. Ties are counted as membership: a variable tied at
rank `k` with another is in the top `k`.

## Usage

``` r
prob_topk(cb, k = 5L)
```

## Arguments

- cb:

  A `rank_confsets` object.

- k:

  Size of the top set.

## Value

A tibble of variables and probabilities, in decreasing order of
probability.

## How much to believe the number

It is conservative in the middle and honest at the ends. Measured on 300
panels of eight predictors with close effects and eighty rows, pooled
over `k = 1..6` and binned by the reported probability
(`inst/simulations/select-calibration.R`):

|          |                       |
|----------|-----------------------|
| reported | actually in the top k |
| 0.15     | 0.18                  |
| 0.35     | 0.41                  |
| 0.44     | 0.56                  |
| 0.55     | 0.64                  |
| 0.75     | 0.83                  |
| 0.98     | 0.98                  |

A variable given 0.44 is in the top `k` about 56% of the time, so the
number understates by up to twelve points where it is least decisive,
and is accurate where it is near 0 or near 1. The direction is the one
to want — the function does not claim more than it can show — and it has
the same cause as the wide intervals: a replicate sees about 0.632`n`
distinct rows, ranks the variables worse than the full sample does, and
drops some of them out of the top `k` more often than the sampling
distribution would.

## See also

[`rank_confsets()`](rank_confsets.md)

## Examples

``` r
judges <- rbind(c(1, 2, 3, 4), c(1, 3, 2, 4), c(2, 1, 3, 4))
colnames(judges) <- c("income", "age", "balance", "region")
prob_topk(rank_confsets(consensus_rank(judges), n_boot = 50), k = 2)
#> # A tibble: 4 × 2
#>   variable probability
#>   <chr>          <dbl>
#> 1 income          1   
#> 2 age             0.78
#> 3 balance         0.22
#> 4 region          0   
```
