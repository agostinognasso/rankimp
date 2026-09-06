# Every function, and when you want it

This is the map. The other vignettes work through problems; this one
says what each function is for, what it hands back, and which mistake it
exists to stop you making. Read `?function` for argument-level detail.

## The pipeline

Everything in the package sits on one line of work.

    importance scores          importance_permutation()  importance_mdi()
          |                    importance_loco()         importance_shap()
          v
       rankings               importance_to_rank()
          |
          v
       a panel                importance_judges()      <- builds all of the above
          |
          +--> weights         judge_weights()
          v
      a consensus             consensus_rank()
          |
          +--> per judge       item_consensus()
          +--> subgroups       judge_clusters()
          v
      uncertainty             rank_confsets()
          |
          +--> probability     prob_topk()
          +--> a decision      rank_select()

Each stage is usable on its own. If you already have a matrix of
rankings from somewhere else, start at
[`consensus_rank()`](../reference/consensus_rank.md) and ignore the top
half.

## Which function do I want?

| The question you are asking | The function |
|----|----|
| How important does this one method say each variable is? | [`importance_permutation()`](../reference/importance_backends.md) and friends |
| I have importance scores; give me a ranking with honest ties | [`importance_to_rank()`](../reference/importance_to_rank.md) |
| Build me a panel from fitted models, across methods, seeds, folds, models | [`importance_judges()`](../reference/importance_judges.md) |
| Some judges deserve less of a vote than others | [`judge_weights()`](../reference/judge_weights.md) |
| What ordering do the judges agree on? | [`consensus_rank()`](../reference/consensus_rank.md) |
| Which judges disagree with that consensus? | [`item_consensus()`](../reference/item_consensus.md) |
| Is this one panel, or two panels stuck together? | [`judge_clusters()`](../reference/judge_clusters.md) |
| How much of this ordering would survive another sample? | [`rank_confsets()`](../reference/rank_confsets.md) |
| What is the chance this variable really belongs in the top five? | [`prob_topk()`](../reference/prob_topk.md) |
| Which variables can I defend putting in a report? | [`rank_select()`](../reference/rank_select.md) |

## Getting importance out of a model

Four backends, one signature each. They all return a named numeric
vector, one score per predictor, and they all compute on the data you
hand them, so they are in-sample unless you pass a holdout set.

`importance_permutation(fit, data, target, n_perm)` shuffles one column
at a time and measures how much worse the predictions get. Averaged over
`n_perm` shuffles. The thing to know: this is computed on a *fitted*
model, so when two predictors are correlated the model can reroute
through the other one and both look unimportant. That is not a bug in
the estimator, it is what the question means once the model is fixed.

`importance_mdi(fit)` reads the mean decrease in impurity the ensemble
already recorded. Free, and biased towards predictors with many distinct
values, which is exactly the bias
[`vignette("credit-scoring")`](../articles/credit-scoring.md) catches in
the act.

`importance_loco(fit, data, target, newdata)` drops each column and
refits. Expensive, and it answers a different question from permutation:
not “does the model use this” but “would a model built without it do
worse”.

`importance_shap(fit, data, target, ...)` delegates to kernelshap and
averages the absolute contributions. Slowest by a wide margin.

``` r

library(rankimp)
set.seed(1)
fit <- randomForest::randomForest(mpg ~ ., data = mtcars, ntree = 200)

round(importance_permutation(fit, mtcars, "mpg", n_perm = 3), 3)
#>   cyl  disp    hp  drat    wt  qsec    vs    am  gear  carb 
#> 1.140 1.514 1.168 0.253 1.484 0.129 0.158 0.038 0.050 0.119
```

## Turning scores into rankings

`importance_to_rank(x, ties_method)` takes a matrix of scores, one row
per judge, and returns ranks. Rank 1 is the most important.

The reason this is a function and not a call to
[`rank()`](https://rdrr.io/r/base/rank.html) is ties. Two variables a
judge scores identically should come back with the same rank rather than
being separated by whichever happens to sit further left in the matrix.
The default `ties_method = "min"` does that.

``` r

scores <- rbind(
  permutation = c(income = 0.31, age = 0.12, balance = 0.12, region = 0.03),
  impurity    = c(income = 0.44, age = 0.20, balance = 0.05, region = 0.02)
)
importance_to_rank(scores)
#>             income age balance region
#> permutation      1   2       2      4
#> impurity         1   2       3      4
```

The permutation judge cannot separate `age` from `balance` and says so.

## Building a panel

[`importance_judges()`](../reference/importance_judges.md) is the one
function most users call. It runs the backends over every combination of
four axes and returns a `judges` object, which is an integer matrix with
one row per judge.

The axes:

- `methods`: which definitions of importance to ask.
- `fit_list`: several fitted models, if you want a consensus that holds
  across learners rather than inside one.
- `seeds`: refits under different random seeds, which measures how much
  of the ranking is the ensemble’s own noise.
- `resamples`: an `rset` from rsample. Every split refits on its
  analysis set and scores on its assessment set, so the judges are out
  of sample.

Every axis multiplies. Two methods, two models, three folds and two
seeds is 24 judges, and each one costs a refit.

``` r

J <- importance_judges(
  fit,
  methods = c("permutation", "mdi"),
  data    = mtcars,
  target  = "mpg",
  seeds   = 1:2,
  n_perm  = 2
)
J
#> <judges> 4 judges x 10 variables
#>   models  : model1 
#>   methods : permutation, mdi 
#>   seeds   : 1, 2 
#>   weights : none (equal) 
#>   recipe  : kept; rank_confsets(type = "data") can rebuild this panel
#> 
#>                       cyl disp hp drat wt qsec vs am gear carb
#> model1:permutation:s1   3    1  4    5  2    8  6 10    9    7
#> model1:mdi:s1           4    1  3    5  2    8  6 10    9    7
#> model1:permutation:s2   3    1  4    6  2    8  9 10    7    5
#> model1:mdi:s2           4    1  3    5  2    8  9 10    7    6
```

What the object carries, beyond the ranks:

| Attribute    | What it holds                                            |
|--------------|----------------------------------------------------------|
| `provenance` | one row per judge: model, engine, method, seed, resample |
| `scores`     | the raw importance scores behind the ranks               |
| `weights`    | per-judge weights, or `NULL`                             |
| `recipe`     | everything needed to rebuild the panel on new rows       |

The recipe is what makes `rank_confsets(type = "data")` possible, and it
is why a `judges` object is as large as the objects it refers to.

``` r

attr(J, "provenance")
#> # A tibble: 4 × 6
#>   judge                 model  engine       method       seed resample
#>   <chr>                 <chr>  <chr>        <chr>       <int> <chr>   
#> 1 model1:permutation:s1 model1 randomForest permutation     1 NA      
#> 2 model1:mdi:s1         model1 randomForest mdi             1 NA      
#> 3 model1:permutation:s2 model1 randomForest permutation     2 NA      
#> 4 model1:mdi:s2         model1 randomForest mdi             2 NA
```

## Weighting the judges

`judge_weights(judges, by, values)` builds a weight vector.

`by = "equal"` is the default and does nothing interesting.
`by = "method"` takes one weight per method and expands it over the
panel, which is how you say “impurity gets half a vote because I do not
trust it here”. `by = "reliability"` gives each judge a weight that
grows with its agreement with the rest of the panel, which sharpens the
consensus around the majority and is a choice you should make
deliberately rather than by default: it makes a lone dissenting method
quieter, and sometimes the lone dissenter is right.

## The consensus

`consensus_rank(x, weights, algorithm, ties)` is the centre of the
package. It returns the Kemeny median of the panel: the ranking with the
smallest total distance to all the judges.

The returned object holds:

| Field | What it is |
|----|----|
| `ranking` | the consensus, as a tibble of variable and rank |
| `tau` | mean Emond-Mason agreement between consensus and judges |
| `consensus_all` | every equally optimal consensus, one per row |
| `judges`, `weights` | the panel it was computed from |
| `multiple` | whether the median was non-unique |

Two things about it are worth knowing before you use the number.

The median can tie. Variables the panel genuinely cannot order come back
at the same rank, which an average of Borda scores can never do.

The median can be non-unique, and often is. When several rankings are
equally optimal, the package averages each variable’s position across
them and re-ranks with ties, rather than taking whichever `ConsRank`
returned first. Taking the first is not neutral: it depends on your
column order, and on a symmetric panel it hands the win to whichever
variable sits further left.

`tau` is not a p-value and not a goodness of fit. Read it as how much
agreement there was to summarise. A consensus with `tau = 0.3` is a
number, not a conclusion.

## Asking who disagrees

`item_consensus(cr)` scores every judge against the reported consensus
and returns a tibble sorted worst first. Use it to find the judge that
is dragging `tau` down.

`judge_clusters(judges, k, ...)` asks the same question about the panel
as a whole: is this one population of judges, or two? It is k-medians in
the space of the Kemeny-Snell distance, it draws nothing from the random
number generator, and it will not divide a panel unless the panel
divides more sharply than a single population of judges would.

That last clause is the whole function. Silhouette width on its own
splits a homogeneous panel of six judges 62% of the time, because judges
who rank alike sit at distance zero and score a perfect silhouette. So
the panel’s best division in two is compared against reference panels
drawn from one population, and `k` comes back as 1 unless the comparison
rejects.

When it does divide, `centres` holds each group’s own consensus ranking,
and the honest report is two rankings with an explanation rather than
one ranking with a caveat.

## Uncertainty

`rank_confsets(cr, n_boot, level, type)` puts an interval around each
variable’s rank. There are two bootstraps and they answer different
questions.

`type = "judges"` (the default) resamples the panel. It measures how
much the consensus depends on which sources of importance happened to be
in it. Cheap, because no model is refitted.

`type = "data"` resamples the rows, refits every model and rebuilds the
whole panel, once per replicate. It measures whether the ordering would
survive another sample, which is usually the question a reader actually
has. It needs a panel built by
[`importance_judges()`](../reference/importance_judges.md), because it
needs the recipe.

They are not interchangeable, and the difference is large. Measured over
300 replicates per cell, a nominal 95% set built from the data bootstrap
covered between 0.966 and 0.998; the judge bootstrap covered between
0.582 and 0.929 and reached the nominal level in none of the six cells.
The judge bootstrap is narrower, and it is narrower because it is
measuring something smaller.

The intervals are wide, and that is the finding rather than a defect. On
the hardest cell the interval spans 5.1 of 8 available ranks, and on
that same cell the point estimate gets the exact order of the signal
variables right 5.3% of the time. A narrower interval would be claiming
more than the data hold.

``` r

judges <- rbind(
  c(1, 2, 3, 4), c(1, 2, 3, 4), c(1, 3, 2, 4),
  c(2, 1, 3, 4), c(1, 2, 4, 3), c(2, 1, 4, 3)
)
colnames(judges) <- c("income", "age", "balance", "region")
cb <- rank_confsets(consensus_rank(judges), n_boot = 200)
cb
#> <rank_confsets>
#>   replicates : 200 ( quick )
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
```

## Turning uncertainty into a decision

`prob_topk(cb, k)` reports how often each variable landed in the top `k`
across the bootstrap replicates. It is conservative in the middle of its
range and accurate at the ends: a variable given 0.44 is really in the
top `k` about 56% of the time, and one given 0.98 is there 98% of the
time. It understates rather than overstates, which is the direction to
want.

`rank_select(cb, threshold)` keeps the variables whose entire interval
clears the threshold. This is the function to reach for when someone is
going to act on the answer. It is deliberately conservative and the
measurements say so: at most 3% of its selections are undeserved, and
none at all at the thresholds that make the strongest claim, while it
selects between a third and a half of the variables that did deserve
selection.

Read a short list as “these I can defend”, not as “these are the ones
that matter”. If it returns nothing, that is an answer.

``` r

rank_select(cb, threshold = 2)
#> [1] "income" "age"
prob_topk(cb, k = 2)
#> # A tibble: 4 × 2
#>   variable probability
#>   <chr>          <dbl>
#> 1 income          1   
#> 2 age             0.99
#> 3 balance         0.06
#> 4 region          0
```

## Plots

Three
[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
methods, one per object.

[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html) on
a `consensus_rank` draws the consensus over every rank the judges gave,
with point area showing how many judges sat at each rank. Use it to see
*which* variables the panel could not place.

[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html) on
a `rank_confsets` draws the ordering with its intervals. Overlapping
intervals are the honest way of saying two variables cannot be ordered
on this evidence.

[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html) on
a `judge_clusters` draws the judges in Kemeny-Snell space by
multidimensional scaling. The subtitle reports how much of the distance
survived the projection into two dimensions, because that distance is
rarely Euclidean and a low figure means the picture is a sketch rather
than evidence.

## Under the hood

Two internal layers you do not call but should know exist if you plan to
extend the package.

`R/engines.R` is the only place that knows how randomForest and ranger
differ. Prediction, refitting, class probabilities, and reading the
predictor names all go through it, so supporting a third engine means
extending that file and nothing else.

`R/judges-methods.R` holds the backends themselves. A new definition of
importance goes there, plus one entry in the `methods` argument.

The simulations in `inst/simulations/` are the package’s evidence base.
Every number quoted in the documentation is produced by a script there,
and they are meant to be re-run rather than trusted:

| Script | What it measures |
|----|----|
| `rank-coverage.R` | do the confidence sets cover at their nominal level |
| `cluster-recovery.R` | does [`judge_clusters()`](../reference/judge_clusters.md) find real groups and refuse fake ones |
| `select-calibration.R` | are [`prob_topk()`](../reference/prob_topk.md) and [`rank_select()`](../reference/rank_select.md) calibrated |
| `rank-calibration.R`, `analyse-calibration.R` | diagnostics for the bootstrap machinery |

## Where to go next

[`vignette("theory")`](../articles/theory.md) explains why the consensus
is a Kemeny median and what a bootstrap of a rank is actually
estimating. [`vignette("rankimp-intro")`](../articles/rankimp-intro.md)
is the short tour. [`vignette("stability")`](../articles/stability.md)
covers the confidence sets in depth,
[`vignette("method-disagreement")`](../articles/method-disagreement.md)
covers panels that split, and
[`vignette("credit-scoring")`](../articles/credit-scoring.md) runs the
whole thing end to end on one problem.
