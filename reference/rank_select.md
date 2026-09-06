# Select variables with a rank guarantee

Keeps the variables whose whole rank confidence set lies at or above
`threshold`, that is, whose upper (worst) end is no worse than
`threshold`.

## Usage

``` r
rank_select(cb, threshold = 10L)
```

## Arguments

- cb:

  A `rank_confsets` object.

- threshold:

  Worst rank a selected variable may plausibly occupy.

## Value

A character vector of selected variable names, in consensus order.

## Details

Selecting on the point estimate of the rank ignores that the ranking was
estimated in the first place. Selecting on the confidence set makes the
claim "this variable really is among the most important" one that the
data can refuse: a variable whose interval straddles the threshold is
not selected, and the reason is visible.

The rule is deliberately conservative. It answers "which variables am I
sure about", not "which variables should I keep": a variable excluded
here may still carry signal, and [`prob_topk()`](prob_topk.md)
quantifies how much doubt there is.

## What the guarantee is measured to be worth

Conservative is a claim, so it was measured. On 300 panels of eight
predictors with close effects and eighty rows
(`inst/simulations/select-calibration.R`), against the true ordering of
the data-generating coefficients:

|  |  |  |  |  |
|----|----|----|----|----|
| threshold | selected per panel | false selections | panels with one | of those that deserved it, selected |
| 1 | 1.00 | 0.000 | 0.000 | 1.000 |
| 2 | 1.01 | 0.000 | 0.000 | 0.503 |
| 3 | 1.07 | 0.009 | 0.010 | 0.352 |
| 4 | 1.23 | 0.011 | 0.013 | 0.305 |
| 5 | 1.56 | 0.002 | 0.003 | 0.312 |
| 6 | 2.22 | 0.030 | 0.067 | 0.431 |

A selected variable is almost never one that did not deserve it — at
most 3% of selections, and 0% at the thresholds that make the strongest
claim. The price is on the other side: past a threshold of 1 it selects
between a third and a half of the variables that did deserve it. Read a
short list as "these I can defend", never as "these are the ones that
matter".

## See also

[`rank_confsets()`](rank_confsets.md), [`prob_topk()`](prob_topk.md)

## Examples

``` r
judges <- rbind(c(1, 2, 3, 4), c(1, 2, 3, 4), c(1, 2, 4, 3))
colnames(judges) <- c("income", "age", "balance", "region")
cb <- rank_confsets(consensus_rank(judges), n_boot = 50)

rank_select(cb, threshold = 2)
#> [1] "income" "age"   
prob_topk(cb, k = 2)
#> # A tibble: 4 × 2
#>   variable probability
#>   <chr>          <dbl>
#> 1 age                1
#> 2 income             1
#> 3 balance            0
#> 4 region             0
```
