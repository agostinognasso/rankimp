# Set stability is not rank stability

The nearest neighbour of this package on CRAN is
[`stabm`](https://cran.r-project.org/package=stabm), which measures the
stability of feature *selection*: given the sets of features chosen
across resamples, how much do those sets overlap? It implements
twenty-odd indices — Nogueira, Jaccard, Kuncheva, Somol — and it does
that job well.

It answers a different question from this one, and the difference is not
academic. A panel can agree perfectly on *which* variables matter and
disagree completely on *how much*. Set stability cannot see the second
disagreement, because it never looks at the order.

## Two panels

Four judges rank five variables. Both panels put the same three
variables in the top three, every time. They differ only in whether the
judges agree on the order *within* that top three.

``` r

library(rankimp)

vars <- c("income", "age", "balance", "region", "tenure")

# The judges agree on the top-3 set, and cycle its internal order.
disordered <- rbind(
  c(1, 2, 3, 4, 5),
  c(2, 3, 1, 4, 5),
  c(3, 1, 2, 4, 5),
  c(1, 3, 2, 5, 4)
)

# The judges agree on the top-3 set, and on its internal order.
ordered <- rbind(
  c(1, 2, 3, 4, 5),
  c(1, 2, 3, 4, 5),
  c(1, 2, 3, 5, 4),
  c(1, 2, 3, 4, 5)
)

colnames(disordered) <- colnames(ordered) <- vars
```

## What set stability sees

Extract the top-3 set each judge selects, and hand those sets to
`stabm`.

``` r

top3 <- function(J) {
  lapply(seq_len(nrow(J)), function(i) colnames(J)[J[i, ] <= 3])
}

c(
  nogueira_disordered = stabm::stabilityNogueira(top3(disordered), p = 5),
  nogueira_ordered    = stabm::stabilityNogueira(top3(ordered), p = 5),
  jaccard_disordered  = stabm::stabilityJaccard(top3(disordered)),
  jaccard_ordered     = stabm::stabilityJaccard(top3(ordered))
)
#> nogueira_disordered    nogueira_ordered  jaccard_disordered     jaccard_ordered 
#>                   1                   1                   1                   1
```

Every index returns 1. Perfect stability, both panels, because every
judge selected `income`, `age` and `balance`. From the point of view of
set stability these two panels are indistinguishable, and a report that
stops here would say so.

## What rank consensus sees

``` r

cr_disordered <- consensus_rank(disordered)
cr_ordered <- consensus_rank(ordered)

c(tau_disordered = cr_disordered$tau, tau_ordered = cr_ordered$tau)
#> tau_disordered    tau_ordered 
#>           0.70           0.95
```

The panels are not indistinguishable at all. The Emond-Mason `tau_x`
drops from 0.95 to 0.70, and the bootstrap confidence sets say exactly
where the evidence runs out.

``` r

set.seed(1)
rank_confsets(cr_disordered, n_boot = 400)$confsets
#> # A tibble: 5 × 4
#>   variable  rank lower upper
#>   <chr>    <int> <int> <int>
#> 1 income       1     1     3
#> 2 balance      2     1     3
#> 3 age          3     1     3
#> 4 region       4     4     5
#> 5 tenure       5     4     5
```

In the disordered panel, `income`, `age` and `balance` each have a rank
interval of `[1, 3]`. They are jointly the top three and individually
unordered: the data do not support the claim that `income` beats `age`.
Compare the ordered panel:

``` r

set.seed(1)
rank_confsets(cr_ordered, n_boot = 400)$confsets
#> # A tibble: 5 × 4
#>   variable  rank lower upper
#>   <chr>    <int> <int> <int>
#> 1 income       1     1     1
#> 2 age          2     2     2
#> 3 balance      3     3     3
#> 4 region       4     4     5
#> 5 tenure       5     4     5
```

Here every interval is a point. The order is not an artefact of which
judges happened to be in the panel.

## Where the two agree

If the question really is “which variables should I keep”, `stabm` is
right and `rankimp` agrees with it:

``` r

set.seed(1)
cb <- rank_confsets(cr_disordered, n_boot = 400)
rank_select(cb, threshold = 3)
#> [1] "income"  "balance" "age"
```

The three variables clear the bar in both panels, because
[`rank_select()`](../reference/rank_select.md) asks about set
membership, which is the stable thing. Use `stabm` when the selected set
is the deliverable. Use this package when the *ordering* is the
deliverable — when someone will read “income is the most important
driver of default” off the top of a plot and act on it.

## The honest summary

| Question | Tool |
|----|----|
| Do resamples select the same features? | `stabm` |
| Do they select them in the same order? | [`consensus_rank()`](../reference/consensus_rank.md), [`item_consensus()`](../reference/item_consensus.md) |
| Which orderings does the evidence support? | [`rank_confsets()`](../reference/rank_confsets.md), [`prob_topk()`](../reference/prob_topk.md) |
| Which variables am I sure belong in the top k? | [`rank_select()`](../reference/rank_select.md) — and `stabm` agrees |

The overlap is real and worth stating in any paper that cites both. The
gap is that a variable importance *ranking* is the object almost every
applied study actually reports, and no set-based index can put an
interval around it.
