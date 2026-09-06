# Importance backends

Each backend asks a fitted model for one named numeric vector of
importance scores over its predictors, higher meaning more important.
They are the judges' voices:
[`importance_judges()`](importance_judges.md) calls them once per judge,
and they can equally be called directly when a single score vector is
all that is needed.

## Usage

``` r
importance_permutation(fit, data, target, n_perm = 5L, ...)

importance_mdi(fit, data = NULL, target = NULL, ...)

importance_shap(fit, data, target, n_explain = 100L, bg_n = 200L, ...)

importance_loco(fit, data, target, newdata = NULL, ...)
```

## Arguments

- fit:

  A fitted model (randomForest or ranger).

- data:

  A data frame holding the response and every predictor the model was
  trained on. For `importance_mdi()` the scores are read off the fit, so
  `data` and `target` are accepted but unused.

- target:

  Name of the response column in `data`.

- n_perm:

  Number of independent shuffles per predictor.

- ...:

  Ignored. It absorbs the arguments meant for the other backends when
  the call comes from [`importance_judges()`](importance_judges.md),
  which forwards its own `...` to every backend it invokes.

- n_explain:

  Maximum number of rows to explain.

- bg_n:

  Size of the background sample, passed to
  [`kernelshap::kernelshap()`](https://rdrr.io/pkg/kernelshap/man/kernelshap.html).

- newdata:

  Optional data frame on which the losses are evaluated.

## Value

A named numeric vector of importance scores, one per predictor.

## Details

Permutation, MDI and LOCO are implemented natively against the supported
engines (randomForest, ranger); SHAP delegates to the kernelshap
package. Scores are computed on the data supplied, so permutation and
LOCO are in-sample unless `data` is a holdout set.
[`importance_judges()`](importance_judges.md) with a `resamples` axis is
the out-of-sample version.

Backends that randomise (permutation shuffles, SHAP row subsampling,
LOCO refits) draw from the session RNG: call
[`set.seed()`](https://rdrr.io/r/base/Random.html) first for
reproducibility.

## Functions

- `importance_permutation()`: Permutation importance: the mean increase
  in loss (RMSE for regression, misclassification rate for
  classification) when one predictor's column is shuffled, over `n_perm`
  shuffles.

- `importance_mdi()`: Mean decrease in impurity, read off the fit:
  `IncNodePurity` (regression) or `MeanDecreaseGini` (classification)
  for randomForest, `variable.importance` for a ranger model fitted with
  `importance = "impurity"`.

- `importance_shap()`: Mean absolute SHAP value, via
  [`kernelshap::kernelshap()`](https://rdrr.io/pkg/kernelshap/man/kernelshap.html).
  For classifiers the mean is also taken across classes; ranger
  classifiers must be fitted with `probability = TRUE`. At most
  `n_explain` rows of `data` are explained (sampled without replacement
  when there are more), against a background sample of `bg_n` rows drawn
  by kernelshap.

- `importance_loco()`: Leave-one-covariate-out: the increase in loss
  when the model is refitted on `data` without one predictor (preserving
  the original number of trees and `mtry`, capped) and compared with
  `fit`. Losses are evaluated on `newdata` when supplied, on `data`
  otherwise; `data` should be the data `fit` was trained on, or the
  comparison mixes training sets. The most expensive backend: one refit
  per predictor.

## See also

[`importance_judges()`](importance_judges.md),
[`importance_to_rank()`](importance_to_rank.md)

## Examples

``` r
set.seed(1)
fit <- randomForest::randomForest(mpg ~ ., data = mtcars, ntree = 50)
importance_permutation(fit, mtcars, "mpg", n_perm = 2)
#>        cyl       disp         hp       drat         wt       qsec         vs 
#> 1.01361029 1.28509655 0.95826539 0.32828607 1.28350077 0.15253210 0.21873259 
#>         am       gear       carb 
#> 0.01526597 0.10372949 0.16919032 
set.seed(1)
fit <- randomForest::randomForest(mpg ~ ., data = mtcars, ntree = 50)
importance_mdi(fit)
#>       cyl      disp        hp      drat        wt      qsec        vs        am 
#> 133.67414 231.23742 139.77667  67.23439 223.99242  20.20954  60.85933  16.41063 
#>      gear      carb 
#>  33.48527  38.07309 
set.seed(1)
small <- mtcars[c("mpg", "wt", "hp", "qsec")]
fit <- randomForest::randomForest(mpg ~ ., data = small, ntree = 30)
importance_loco(fit, small, "mpg")
#>         wt         hp       qsec 
#>  0.4500931 -0.1779224 -0.2474492 
```
