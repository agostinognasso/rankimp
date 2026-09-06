# Bootstrap confidence sets for the consensus ranking

A single consensus ranking is a point estimate. Resampling gives the
sampling distribution of each variable's position, from which follow the
interval of plausible ranks for each variable and the probability that a
variable belongs to the top `k`.

## Usage

``` r
rank_confsets(
  cr,
  n_boot = NULL,
  level = 0.95,
  type = c("judges", "data"),
  algorithm = c("quick", "exact", "fast", "decor")
)

# S3 method for class 'rank_confsets'
print(x, ...)
```

## Arguments

- cr:

  A `consensus_rank` object.

- n_boot:

  Number of bootstrap replicates. Defaults to 500 for `type = "judges"`
  and 50 for `type = "data"`, which refits every model on every
  replicate.

- level:

  Coverage of the rank confidence sets.

- type:

  What to resample: the `"judges"` in the panel, or the `"data"` the
  models were fitted to.

- algorithm:

  Solver used for the replicates. `"quick"` by default; `"exact"`,
  `"fast"` and `"decor"` are also accepted, as in
  [`consensus_rank()`](consensus_rank.md).

- x:

  A `rank_confsets` object.

- ...:

  Unused.

## Value

An object of class `rank_confsets`, a list with elements `confsets` (a
tibble of variable, consensus rank, and the lower and upper ends of the
rank interval), `ranks` (the `n_boot x p` matrix of bootstrap ranks),
`level`, `n_boot`, `type`, `n_units` (how many judges or rows were
resampled), `failed` (replicates dropped) and `consensus` (the `cr` it
came from).

## Details

This is the inferential layer. It is what distinguishes the package from
a rank-averaging exercise, and it is what lets a claim about variable
importance be falsified: "`income` is the third most important variable"
cannot be checked, while "`income` is in the top five with probability
0.97" can.

## What is resampled

Two questions, two answers, and they are not the same question.

`type = "judges"` draws the judges with replacement from `cr$judges`. It
measures how much the consensus depends on *which sources of importance
happened to be in the panel* — a panel of ten permutation replicates and
one SHAP judge will show it. Resampling is done by drawing multinomial
counts and passing them as judge weights rather than by materialising
the resampled panel. The two are equivalent — `ConsRank` treats a weight
of 3 exactly as three copies of the judge — and the weighted form avoids
rebuilding a `K x p` matrix per replicate. Judge weights supplied to
[`consensus_rank()`](consensus_rank.md) are carried through by
multiplying them into the bootstrap counts.

`type = "data"` draws the *rows* with replacement, refits every model on
the resampled data and rebuilds the whole panel from scratch, once per
replicate. It measures how much the consensus depends on the sample the
models were fitted to — the question a reader asks when they wonder
whether the ranking would survive another dataset. It needs a panel
built by [`importance_judges()`](importance_judges.md), whose recipe
carries the fits, the data and the settings; a plain ranking matrix has
no models to refit.

## How a data replicate is built

Each replicate draws `n` rows with replacement, refits every model on
them with [`importance_judges()`](importance_judges.md)'s own machinery,
and measures importance the way the recipe did: on the rows the
bootstrap left out when the original panel judged out of sample (the
`resamples` axis), on the resampled rows themselves when it judged in
sample. Mirroring the recipe is what keeps the bootstrap distribution
centred on the point estimate, without which a percentile interval means
nothing.

Two consequences worth stating plainly:

- A `resamples` axis is **replaced** by the bootstrap's own
  in-bag/out-of-bag split, so a panel of `models x methods x V` judges
  is rebuilt with `models x methods` of them. Each replicate votes with
  fewer judges than the point estimate did, which makes its consensus
  noisier and the intervals, if anything, wider.

- Refits preserve the number of trees and `mtry` and nothing else. A
  forest fitted with a hand-tuned `nodesize` is refitted at the engine's
  default, here as on the `seeds` and `resamples` axes.

One consequence to expect rather than to debug: a replicate's ranking
drifts towards the middle. `n` rows drawn with replacement hold about
0.632`n` distinct ones, and a variable is harder to place on that much
less information, so the top of the ranking drifts down and the bottom
drifts up. Measured over 300 panels of eight predictors with close
effects and eighty rows (`inst/simulations/select-calibration.R`), the
median bootstrap rank of the second variable of the consensus sits 0.55
ranks below it and is worse than it in 51% of panels; the eighth sits
1.00 above. Hand a replicate all the distinct rows instead and it
returns the point estimate exactly — which is how this was told apart
from a panel rebuilt wrongly.

The drift is not large enough to push the consensus rank out of its own
interval: that happened in none of those 2,400 variable-replicates.
Earlier versions of this page warned that it would, on the strength of
one panel whose interval was `[3, 5]` around a consensus rank of 2. That
panel came from the bootstrap that repeated its resamples, and the
intervals it produced were too narrow to be believed.

A replicate that fails is dropped rather than allowed to kill the run,
and the count of dropped replicates is warned about and kept in
`failed`. The failure that actually happens is a response class too rare
to survive a bootstrap draw: `randomForest` refuses to refit on a sample
that lost one (`ranger` drops the level and carries on). A rare
*predictor* level is harmless, because subsetting a factor keeps its
levels.

## What the level actually buys

The two bootstraps miss the nominal level in opposite directions, and by
enough that the choice between them is the choice that matters. The
simulation is `inst/simulations/rank-coverage.R`: eight predictors, five
of them real, 300 replicates per cell, nominal 0.95, coverage of the
true rank of the signal variables.

- `type = "data"` — 0.966, 0.969 and 0.978 at `n` of 80, 200 and 500
  with effects close enough that the middle of the ranking is barely
  identifiable; 0.993 and 0.998 at `n` of 80 and 200 with effects that
  separate cleanly.

- `type = "judges"` — 0.582, 0.655 and 0.711 on those same close cells;
  0.801 and 0.929 on the separated ones.

The data bootstrap covers, and it covers by being wide. On the hardest
cell its interval spans 5.1 of the 8 available ranks — it reports that
this sample does not order these variables, which is the truth: the
point estimate recovers the true order of the five signal variables in
5% of replicates there. An interval that admitted less would be claiming
more than the data holds.

The judge bootstrap is narrow on the same cell — 2.0 ranks — and misses
the true rank two times in five. Resampling a panel measures how much
the methods disagree with each other, and that is not how far the
ranking would move on another sample. It is the cheap answer to a
different question, and the gap it leaves is the reason `type = "data"`
exists: 0.966 against 0.582 where the ordering is hardest.

Fifty replicates are enough for the data bootstrap. The same cell at
`n_boot = 200` covers 0.970 against 0.966, a difference inside the Monte
Carlo error of either — which is worth stating because it was not always
true of this package: a defect that made the bootstrap repeat its
resamples once made `n_boot` look decisive (see `NEWS.md`).

Read a rank confidence set as a statement about what the evidence rules
out, not as a calibrated guarantee. The rank is a discrete, non-smooth
functional and a percentile bootstrap is not automatically valid for
such functionals; the figures above are measured on those designs, not
promised in general.

## On the cost

Every replicate solves a Kemeny problem, which is NP-hard.
Branch-and-bound is fast on panels that agree and pathological on panels
that do not: with twelve variables and many ties — the normal case for
importance scores, where unimportant variables all tie near zero — a
single exact solve has been measured at over four minutes, which is a
day and a half for five hundred replicates.

The default is therefore to resample with the `"quick"` heuristic
regardless of the algorithm used for the point estimate, and to say so.
Pass `algorithm = "exact"` if the panel is small and you want optimality
guarantees inside the bootstrap too.

A data replicate additionally refits every model and recomputes every
importance, which is orders of magnitude dearer than reweighting a panel
that already exists. Hence the smaller default for `n_boot`, and a
message reporting the projected cost when the run looks like a long one.

## See also

[`prob_topk()`](prob_topk.md), [`rank_select()`](rank_select.md),
[`autoplot.rank_confsets()`](autoplot.rank_confsets.md)

## Examples

``` r
judges <- rbind(
  c(1, 2, 3, 4), c(1, 2, 3, 4), c(1, 3, 2, 4),
  c(2, 1, 3, 4), c(1, 2, 4, 3), c(2, 1, 4, 3)
)
colnames(judges) <- c("income", "age", "balance", "region")
cb <- rank_confsets(consensus_rank(judges), n_boot = 50)
cb
#> <rank_confsets>
#>   replicates : 50 ( quick )
#>   level      : 0.95 
#>   resampled  : 6 judges, with replacement 
#> 
#> # A tibble: 4 × 4
#>   variable  rank lower upper
#>   <chr>    <int> <int> <int>
#> 1 income       1     1     2
#> 2 age          2     1     2
#> 3 balance      3     2     4
#> 4 region       4     3     4

# Resampling the data instead: every replicate refits the forest.
set.seed(1)
fit <- randomForest::randomForest(mpg ~ ., data = mtcars, ntree = 50)
J <- importance_judges(fit, methods = c("permutation", "mdi"),
                       data = mtcars, target = "mpg", n_perm = 2)
rank_confsets(consensus_rank(J), n_boot = 10, type = "data")
#> <rank_confsets>
#>   replicates : 10 ( quick )
#>   level      : 0.95 
#>   resampled  : 32 rows, with replacement; the panel is rebuilt on each 
#> 
#> # A tibble: 10 × 4
#>    variable  rank lower upper
#>    <chr>    <int> <int> <int>
#>  1 disp         1     1     3
#>  2 wt           2     1     4
#>  3 cyl          3     3     5
#>  4 hp           3     1     3
#>  5 drat         5     4     6
#>  6 vs           6     6    10
#>  7 carb         7     5     9
#>  8 gear         8     7    10
#>  9 qsec         8     5     8
#> 10 am          10     6    10
```
