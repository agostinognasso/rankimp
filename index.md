# rankimp

Mean decrease in impurity, permutation importance, SHAP, LOCO and
drop-column importance give different answers on the same data. So does
one method under a different seed, or a different fold. Reporting a
single ranking from a single method on a single fit is standard practice
and is indefensible.

`rankimp` treats every combination of method, seed, fold and model as a
**judge** expressing a ranking over the predictors, and computes the
Kemeny median of the panel — with ties, with judge weights, and with
confidence sets that say which parts of the ordering the evidence
actually supports.

It builds on [`ConsRank`](https://cran.r-project.org/package=ConsRank)
for the consensus itself; the contribution is the inferential layer on
top.

## Installation

Not on CRAN yet.

``` r

# install.packages("pak")
pak::pak("rankimp")
```

## Usage

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

Variables the panel genuinely cannot separate come out tied, which is
the thing an average of Borda scores can never say.

## Status

Early development, and complete end to end:
[`importance_judges()`](reference/importance_judges.md) interrogates
fitted models (randomForest, ranger) along the method, model, seed and
resample axes, [`rank_confsets()`](reference/rank_confsets.md) puts
intervals around the consensus, and
[`judge_clusters()`](reference/judge_clusters.md) says whether the panel
is one population or two.

| Phase | Content | State |
|----|----|----|
| F1 | [`importance_judges()`](reference/importance_judges.md), backends, weights | done |
| F2 | Consensus, ties, algorithm selection | done |
| F3 | Bootstrap, rank confidence sets, [`prob_topk()`](reference/prob_topk.md), [`rank_select()`](reference/rank_select.md) | done |
| F4 | Judge clustering, plots, vignettes | done |
| F5 | CRAN, methodological paper | — |

The inferential layer came first on purpose.
[`consensus_rank()`](reference/consensus_rank.md) orchestrates
`ConsRank`; [`rank_confsets()`](reference/rank_confsets.md) does not
orchestrate anything, and it is the part that lets a claim about
variable importance be falsified.

## Related work

- [`ConsRank`](https://cran.r-project.org/package=ConsRank) — the Kemeny
  median engine this package orchestrates.
- [`e2tree`](https://cran.r-project.org/package=e2tree) — explains a
  forest with a single tree.
- `Proximum` — how the forest represents the data whose variables are
  ranked here.
