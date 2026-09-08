# Assemble the panel of judges

Builds the ranking matrix consumed by
[`consensus_rank()`](consensus_rank.md) from any combination of the four
axes along which a variable importance ranking can vary: the *method*
used, the *model* it interrogates, the *seed* of the ensemble, and the
*resample* of the data. Every combination of the active axes becomes one
judge, one row of the panel, whose importance scores are computed by the
matching backend and turned into a ranking with
[`importance_to_rank()`](importance_to_rank.md).

## Usage

``` r
importance_judges(
  fit_list,
  methods = c("permutation", "mdi"),
  data = NULL,
  target = NULL,
  resamples = NULL,
  seeds = NULL,
  weights = NULL,
  ties_method = c("min", "average", "first"),
  ...
)

# S3 method for class 'judges'
print(x, ...)
```

## Arguments

- fit_list:

  A fitted model, or a (preferably named) list of them. Supported
  engines: randomForest, ranger. Unnamed models are called `model1`,
  `model2`, ...

- methods:

  Character vector of importance methods, among `"permutation"`,
  `"mdi"`, `"shap"`, `"loco"`.

- data:

  Data frame holding the response and the predictors. Required unless
  `methods` is only `"mdi"` and no `seeds` or `resamples` are given.

- target:

  Name of the response column in `data`.

- resamples:

  Optional `rset` (from
  [`rsample::vfold_cv()`](https://rsample.tidymodels.org/reference/vfold_cv.html)
  or
  [`rsample::bootstraps()`](https://rsample.tidymodels.org/reference/bootstraps.html))
  giving the resampling axis.

- seeds:

  Optional integer vector of seeds for the refitting axis.

- weights:

  Optional named numeric vector of method weights, e.g.
  `c(permutation = 1, mdi = 0.5)`. Every method in `methods` must be
  named. The expanded per-judge weights travel with the panel and are
  picked up by [`consensus_rank()`](consensus_rank.md).

- ties_method:

  Passed to [`importance_to_rank()`](importance_to_rank.md).

- ...:

  Unused.

- x:

  A `judges` object.

## Value

An object of class `judges`: an integer ranking matrix with one row per
judge, carrying as attributes the `provenance` of each row (a tibble
with the judge's model, engine, method, seed and resample), the raw
`scores` behind the ranks, the per-judge `weights` (or `NULL`), and the
`recipe` that built it.

## The four axes

- **Methods** (`methods`): each importance method is one voice; see
  [importance_backends](importance_backends.md).

- **Models** (`fit_list`): several fitted models, so that a cross-model
  consensus asks which variables matter regardless of the learner. All
  models must be trained on the same predictors.

- **Seeds** (`seeds`): each seed refits every model on `data` after
  `set.seed(seed)`, measuring the stability of the ranking under the
  ensemble's own randomness. Refits keep the original number of trees
  and `mtry`.

- **Resamples** (`resamples`): an `rset` from the rsample package
  (v-fold CV or bootstrap). Every split refits the models on its
  analysis set; permutation and SHAP importance are then computed on the
  assessment set, and LOCO refits on the analysis set and evaluates on
  the assessment set, giving the out-of-sample versions of those
  importances. MDI, which has no data argument, is read off the refit.

Without `seeds` or `resamples` the supplied fits are used as they are,
and data-dependent importances are in-sample. Axes combine as a full
grid: models x methods x seeds x resamples.

## The recipe

The panel keeps the arguments that built it: the fits, the data, the
target, the methods, the axes and the backend settings. That is what
lets [`rank_confsets()`](rank_confsets.md) rebuild it on a bootstrap
sample of the rows without being handed them all again. That makes the
panel as large as the objects it refers to.

## Reproducibility

Permutation shuffles, SHAP row subsampling and refits draw from the
session RNG; call [`set.seed()`](https://rdrr.io/r/base/Random.html)
before this function for a reproducible panel.

The `seeds` axis sets seeds of its own, and puts the stream back where
it found it, so building a panel does not move the caller's RNG. That is
more than politeness: [`rank_confsets()`](rank_confsets.md) with
`type = "data"` rebuilds the panel once per bootstrap replicate and
draws the next resample from this same stream, and a panel that parked
it made every replicate resample the same rows.

## See also

[importance_backends](importance_backends.md),
[`judge_weights()`](judge_weights.md),
[`consensus_rank()`](consensus_rank.md)

## Examples

``` r
set.seed(1)
fit <- randomForest::randomForest(mpg ~ ., data = mtcars, ntree = 50)
judges <- importance_judges(fit, methods = c("permutation", "mdi"),
                            data = mtcars, target = "mpg", n_perm = 2)
judges
#> <judges> 2 judges x 10 variables
#>   models  : model1 
#>   methods : permutation, mdi 
#>   weights : none (equal) 
#>   recipe  : kept; rank_confsets(type = "data") can rebuild this panel
#> 
#>                    cyl disp hp drat wt qsec vs am gear carb
#> model1:permutation   3    1  4    5  2    8  6 10    9    7
#> model1:mdi           4    1  3    5  2    9  6 10    8    7
consensus_rank(judges)
#> <consensus_rank>
#>   judges    : 2  
#>   variables : 10 
#>   algorithm : BB (ties allowed) 
#>   tau_x     : 0.9556 
#>   note      : 9 equally optimal consensus rankings; combined, so variables they order differently are tied
#> 
#> # A tibble: 10 × 2
#>    variable  rank
#>    <chr>    <int>
#>  1 disp         1
#>  2 wt           2
#>  3 cyl          3
#>  4 hp           3
#>  5 drat         5
#>  6 vs           6
#>  7 carb         7
#>  8 qsec         8
#>  9 gear         8
#> 10 am          10
```
