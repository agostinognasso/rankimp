# Turn importance scores into rankings

Each row of `x` holds the importance that one judge assigns to each
variable; the result holds the rank that judge gives each variable, with
`1` for the most important. Variables a judge scores equally receive the
same rank, because pretending to separate them would invent information
the judge never supplied.

## Usage

``` r
importance_to_rank(x, ties_method = c("min", "average", "first"))
```

## Arguments

- x:

  Numeric matrix or data frame of importance scores, judges in rows and
  variables in columns. Higher is more important.

- ties_method:

  Passed to [`base::rank()`](https://rdrr.io/r/base/rank.html). The
  default, `"min"`, produces the weak orderings that the Kemeny
  framework expects.

## Value

An integer matrix of rankings with the same dimensions and dimnames as
`x`, suitable for [`consensus_rank()`](consensus_rank.md).

## Examples

``` r
imp <- rbind(
  permutation = c(income = 0.31, age = 0.12, balance = 0.12),
  impurity    = c(income = 0.44, age = 0.20, balance = 0.05)
)
importance_to_rank(imp)
#>             income age balance
#> permutation      1   2       2
#> impurity         1   2       3
```
