# Kemeny consensus ranking of variable importance

Given `K` judges, each expressing a ranking over the same `p` variables,
returns the median ranking in the sense of Kemeny: the ranking that
minimises the total Kemeny-Snell distance to the judges, \$\$\pi^{\*} =
\arg\min\_{\pi} \sum\_{k=1}^{K} w_k \\ d\_{KS}(\pi, \pi_k).\$\$

## Usage

``` r
consensus_rank(
  x,
  weights = NULL,
  algorithm = c("auto", "exact", "quick", "fast", "decor"),
  ties = TRUE
)

# S3 method for class 'consensus_rank'
print(x, ...)
```

## Arguments

- x:

  A `consensus_rank` object.

- weights:

  Optional numeric vector of length `nrow(x)` giving the weight of each
  judge. Weights let a permutation importance computed out-of-bag count
  for more than an impurity-based one. When `x` is a `judges` object
  carrying method weights (see
  [`importance_judges()`](importance_judges.md) and
  [`judge_weights()`](judge_weights.md)), those are used unless
  `weights` overrides them.

- algorithm:

  One of `"auto"`, `"exact"`, `"quick"`, `"fast"`, `"decor"`.

- ties:

  Keep ties in the consensus ranking.

- ...:

  Unused.

## Value

An object of class `consensus_rank`, a list with elements `ranking` (a
tibble of variable and consensus rank), `tau` (the average `tau_x`
agreement between the consensus and the judges), `consensus_all` (every
optimal consensus found, one per row), `judges` and `weights` (the panel
as supplied), and the settings used.

When several rankings attain the minimum, `ranking` holds their
combination rather than an arbitrary one of them: see the section below.

The panel is kept because the consensus alone is a point estimate:
[`rank_confsets()`](rank_confsets.md) resamples the judges to put an
interval around it, and it cannot do that from a ranking.

## Details

Ties in the consensus are meaningful and are kept by default. Variables
that the judges genuinely cannot separate *should* come out equal, which
is what distinguishes a Kemeny median from an average of Borda scores.
Set `ties = FALSE` to force a linear order.

## When the median is not unique

Several rankings can attain the same minimum, and `ConsRank` returns
them all. Reporting one of them would be arbitrary in a way that is not
neutral: which comes first depends on the order of the columns, so a
variable can gain a position by sitting to the left. That was measured —
on a symmetric panel, permuting the columns changed the winner; in a
simulation with three exchangeable noise predictors the leftmost took
the best rank systematically, and the situation is not rare, arising in
57% to 98% of replicates there.

The consensus reported is therefore the optimal set combined: each
variable takes its average position over the optima, and those that come
out equal are tied. Variables the objective genuinely cannot separate
are reported as equal, which is the point of taking a median over weak
orderings. The whole set remains in `consensus_all`.

## Choice of algorithm

Finding the Kemeny median is NP-hard, so `algorithm = "auto"` picks by
problem size:

- `p <= 10` — `"exact"`, branch-and-bound.

- `11 <= p <= 50` — `"quick"`.

- `p > 50` — `"fast"`, with a message. The integer-programming route of
  the roadmap, which would restore optimality guarantees at this size,
  is a phase F2 deliverable.

The exact threshold is ten rather than the fifteen `ConsRank` permits,
because the cost of branch-and-bound is not a smooth function of `p` and
the panels this package produces are the hard ones. Importance scores
tie: the unimportant variables all sit near zero and rank equal. On tied
panels of thirty judges the same solver took 0.010 s at `p = 10`, 0.78 s
at `p = 11` and 280 s at `p = 12`. Meanwhile `"quick"` returned the
identical consensus and the identical `tau_x` on twenty out of twenty
tied panels at `p = 10`. Exactness above ten variables buys little and
can cost minutes, so ask for it deliberately with `algorithm = "exact"`.

## See also

[`importance_to_rank()`](importance_to_rank.md),
[`rank_confsets()`](rank_confsets.md)

## Examples

``` r
judges <- rbind(
  c(1, 2, 3, 4),
  c(1, 2, 4, 3),
  c(2, 1, 3, 4)
)
colnames(judges) <- c("income", "age", "balance", "region")
consensus_rank(judges)
#> <consensus_rank>
#>   judges    : 3  
#>   variables : 4 
#>   algorithm : BB (ties allowed) 
#>   tau_x     : 0.7778 
#> 
#> # A tibble: 4 × 2
#>   variable  rank
#>   <chr>    <int>
#> 1 income       1
#> 2 age          2
#> 3 balance      3
#> 4 region       4
```
