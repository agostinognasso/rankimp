# Consensus ranking of variable importance

Ask a random forest which variables matter and the answer depends on how
you ask. Mean decrease in impurity, permutation importance, SHAP, LOCO
and drop-column each return a different ordering. So does the same
method under a different seed, or a different fold. Reporting one
ranking, from one method, on one fit, is standard practice and is not
defensible.

`rankimp` treats each of those sources as a **judge** expressing a
ranking over the variables, and asks what the judges agree on.

## The consensus

``` r

library(rankimp)

judges <- rbind(
  permutation_seed1 = c(1, 2, 3, 4),
  permutation_seed2 = c(1, 2, 3, 4),
  shap              = c(1, 3, 2, 4),
  impurity          = c(2, 1, 3, 4)
)
colnames(judges) <- c("income", "age", "balance", "region")

consensus_rank(judges)
#> <consensus_rank>
#>   judges    : 4  
#>   variables : 4 
#>   algorithm : BB (ties allowed) 
#>   tau_x     : 0.8333 
#> 
#> # A tibble: 4 × 2
#>   variable  rank
#>   <chr>    <int>
#> 1 income       1
#> 2 age          2
#> 3 balance      3
#> 4 region       4
```

The consensus is the **Kemeny median**: the ranking minimising the total
Kemeny-Snell distance to the judges,

``` math
\pi^{*} = \arg\min_{\pi} \sum_{k=1}^{K} d_{KS}(\pi, \pi_k).
```

`tau_x` is the average Emond-Mason correlation between the consensus and
the judges. Read it as “how much agreement was there to summarise”. A
consensus with `tau_x = 0.3` is a number, not a conclusion.

## Starting from importance scores

Judges usually arrive as importance scores rather than ranks.
[`importance_to_rank()`](../reference/importance_to_rank.md) converts
them, and it converts ties honestly: variables a judge scores
identically get the same rank rather than an arbitrary order.

``` r

importance <- rbind(
  permutation = c(income = 0.31, age = 0.12, balance = 0.12, region = 0.03),
  impurity    = c(income = 0.44, age = 0.20, balance = 0.05, region = 0.02)
)

importance_to_rank(importance)
#>             income age balance region
#> permutation      1   2       2      4
#> impurity         1   2       3      4
```

Note that the permutation judge cannot separate `age` from `balance`,
and says so.

## Building the panel from fitted models

Hand-building the score matrix is fine for a demonstration and tedious
in practice. [`importance_judges()`](../reference/importance_judges.md)
builds it from fitted models directly — here two methods interrogating
one forest, the smallest panel worth having:

``` r

set.seed(1)
fit <- randomForest::randomForest(mpg ~ ., data = mtcars, ntree = 200)

J <- importance_judges(
  fit,
  methods = c("permutation", "mdi"),
  data    = mtcars,
  target  = "mpg"
)
J
#> <judges> 2 judges x 10 variables
#>   models  : model1 
#>   methods : permutation, mdi 
#>   weights : none (equal) 
#>   recipe  : kept; rank_confsets(type = "data") can rebuild this panel
#> 
#>                    cyl disp hp drat wt qsec vs am gear carb
#> model1:permutation   4    1  3    5  2    6  7  9   10    8
#> model1:mdi           4    1  3    5  2    8  6 10    9    7

consensus_rank(J)$ranking
#> # A tibble: 10 × 2
#>    variable  rank
#>    <chr>    <int>
#>  1 disp         1
#>  2 wt           2
#>  3 hp           3
#>  4 cyl          4
#>  5 drat         5
#>  6 vs           6
#>  7 qsec         7
#>  8 carb         8
#>  9 am           9
#> 10 gear         9
```

Models (`fit_list`), seeds (`seeds`) and resamples of the data
(`resamples`) enter the same way, and every extra axis multiplies the
panel; see [`?importance_judges`](../reference/importance_judges.md).

## Ties are information

Because the Kemeny median is taken over weak orderings, it can return
ties too. Two variables the panel genuinely cannot order come out equal,
which is the thing an average of Borda scores can never say.

``` r

tied <- rbind(
  c(1, 1, 3, 4),
  c(1, 1, 3, 4),
  c(2, 1, 3, 4)
)
colnames(tied) <- c("income", "age", "balance", "region")

consensus_rank(tied)$ranking
#> # A tibble: 4 × 2
#>   variable  rank
#>   <chr>    <int>
#> 1 income       1
#> 2 age          1
#> 3 balance      2
#> 4 region       3
```

## Not every judge deserves an equal vote

Impurity-based importance is biased towards predictors with many
distinct values. A panel that mixes it with out-of-bag permutation
importance should say so rather than let the bias average out.

``` r

consensus_rank(judges, weights = c(1, 1, 1, 0.5))$ranking
#> # A tibble: 4 × 2
#>   variable  rank
#>   <chr>    <int>
#> 1 income       1
#> 2 age          2
#> 3 balance      3
#> 4 region       4
```

[`judge_weights()`](../reference/judge_weights.md) builds these vectors
from a panel — one weight per method, or weights proportional to each
judge’s agreement with the rest — and a panel built by
`importance_judges(..., weights = )` carries them into
[`consensus_rank()`](../reference/consensus_rank.md) on its own.

## What comes next

A consensus without a standard error is still one number.
[`vignette("stability")`](../articles/stability.md) covers the bootstrap
rank confidence sets that say which parts of the ordering are real, and
[`vignette("method-disagreement")`](../articles/method-disagreement.md)
covers what to do when the judges do not agree at all.
