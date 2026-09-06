# Do the judges agree?

When the global agreement with the consensus is low, reporting the
consensus alone hides the disagreement instead of describing it.
Clustering the judges in the space of the Kemeny-Snell distance recovers
the sub-populations of methods that see the model differently. Marginal
against conditional importance measures typically separate here whenever
the predictors are correlated, and that separation is itself the
finding.

## Usage

``` r
judge_clusters(
  judges,
  k = NULL,
  weights = NULL,
  algorithm = c("auto", "exact", "quick", "fast", "decor"),
  n_null = 199L,
  alpha = 0.05,
  seed = 1L,
  medoid_limit = 20000L
)

# S3 method for class 'judge_clusters'
print(x, ...)
```

## Arguments

- judges:

  A `judges` object or a ranking matrix.

- k:

  Number of clusters, or `NULL` to select it automatically.

- weights:

  Optional per-judge weights, one per row. Taken from a `judges` panel
  when it carries them. They weigh each group's consensus, not the
  distances.

- algorithm:

  Solver used for each group's consensus, passed to
  [`consensus_rank()`](consensus_rank.md).

- n_null:

  Panels drawn from a single population to judge the observed grouping
  against. `0` skips the test, and the largest silhouette then wins
  outright. Ignored when `k` is given.

- alpha:

  How rarely a single population must group as sharply as this panel
  does before the panel is called divided.

- seed:

  Seed for the reference panels. The caller's random stream is restored
  afterwards.

- medoid_limit:

  Largest number of candidate medoid sets to enumerate before falling
  back on a greedy start.

- x:

  A `judge_clusters` object.

- ...:

  Unused.

## Value

An object of class `judge_clusters`, a list with elements `clustering`
(a tibble of judge, cluster and silhouette width), `cluster` (the same
assignment as a named integer vector), `k`, `centres` (the group
consensus rankings, one per row), `consensus` (the `consensus_rank`
object behind each centre), `distances` (the Kemeny-Snell distances
between judges), `criterion` (the silhouette at every `k` the search
could have used, reported so the shape of the panel can be inspected;
the automatic choice is the test's, not this column's maximum), `test`
(the observed statistic, its p-value against one population, and the
spread the reference panels were given), and the settings used.

## Details

The groups are k-medians in ranking space: each group's centre is the
Kemeny median of its members, computed by
[`consensus_rank()`](consensus_rank.md), and each judge belongs to the
group whose centre it is closest to. The centre of a group is therefore
a consensus ranking, the object worth reporting, rather than a point in
some embedding.

## Why this returns the same answer twice

Nothing here draws from the RNG. The starting partition is the exactly
optimal set of medoids, found by enumerating every one of them while the
panel is small enough to allow it, and the refinement is deterministic;
ties are broken on the lowest index. A panel of judges is small, so the
usual reason for random restarts, an initialisation too expensive to
optimise, does not apply, and an inference function that answered
differently on every call would be worth less than the answer it gives.

Above `medoid_limit` candidate sets the enumeration is replaced by a
greedy choice, which is still deterministic but no longer certified
optimal; the returned object says which was used.

## Whether to split at all

The panel is left whole unless it groups more sharply than a single
population of judges would. That test is not decoration. The average
silhouette width on its own divides a homogeneous panel far too readily,
because two judges who happen to rank alike sit at distance zero and
score a silhouette of exactly 1: on eight variables and six judges one
transposition apart, the silhouette alone split a single population 62%
of the time. Those same zero distances are what makes a real division
obvious, so the statistic cannot tell the two cases apart by itself. It
has to be told what one population looks like.

So the panel's best split in two is compared against the best split in
two of `n_null` panels drawn from one population, spread to match the
mean distance between the judges actually supplied. The panel is divided
only when fewer than `alpha` of those reference panels split as sharply.
What the test costs in divisions missed, and what it buys in divisions
not invented, is measured in `inst/simulations/cluster-recovery.R`.

## What it is measured to do

From that script, 300 panels per cell of eight variables. A panel drawn
from **one population** is divided anyway 2.0% of the time at six judges
(4.0% when those judges are noisier), 5.3% at ten and 8.3% at sixteen,
against a nominal `alpha` of 5%. Two well-separated populations are
recovered exactly 0.877 of the time at six judges, 0.873 at ten and
0.943 at sixteen; on groups that are close, or judges that are noisy, it
falls a long way: 0.360 at six judges with the group centres four
transpositions apart, and 0.073 when the judges stray three.

On real panels of permutation against LOCO judges over correlated
predictors, 100 datasets per cell, the panel divides in two 23 times in
100 at a correlation of 0.9 with six judges and 82 times in 100 with
sixteen. All 23 of the six-judge divisions fell exactly on the method
families; 69 of the 82 at sixteen judges did. Panel size is what buys
sensitivity here, and six judges, which is two methods by three seeds,
has little of it.
[`vignette("method-disagreement")`](../articles/method-disagreement.md)
works through one of the panels that does not divide.

The hypothesis is "one population", so the statistic is the best
division in two, not the best over every `k`. Testing the maximum over
`k` sounds more general and is worse: the reference pays a multiplicity
that grows with the panel, and power falls away as judges are added.
Measured on two clearly separated groups at the same level: 0.233 at six
judges down to 0.067 at twelve for the maximum, against 0.633 up to
0.917 for the two-group statistic.

A panel the test rejects is therefore reported as divided **in two**,
which is the division the evidence is about. Reading `k` off the largest
silhouette instead attaches an uncalibrated number to a calibrated
decision, and it measures worse: on two separated groups the partition
is recovered exactly 0.943 of the time at sixteen judges against 0.690
for the largest silhouette, at the same false division rate. It is also
what made larger panels perform worse: recovery fell from 0.877 at six
judges to 0.690 at sixteen, and now rises to 0.943. Pass `k` explicitly
to fit any other number; a panel that genuinely holds three groups is
reported as two.

All of it is read off the distances alone, through the exactly optimal
medoid partitions, which is what makes hundreds of reference panels
affordable. Which judge goes where, and what each group ranks, is the
k-medians refinement of that partition.

## Reproducibility

The reference panels are drawn from `seed`, and the session's random
stream is put back where it was found: a call neither depends on the
stream nor disturbs it, and two calls on the same panel agree down to
the p-value.

## See also

[`item_consensus()`](item_consensus.md) for the same question asked one
judge at a time,
[`autoplot.judge_clusters()`](autoplot.judge_clusters.md) to see the
panel in Kemeny-Snell space.

## Examples

``` r
# Three judges who rank by one logic, three by another. Four variables would
# not be enough for the test to call it: with 24 possible rankings a panel
# groups this sharply by chance often enough to matter.
judges <- rbind(
  permutation_1 = c(1, 2, 3, 4, 5, 6), permutation_2 = c(1, 2, 3, 4, 6, 5),
  permutation_3 = c(2, 1, 3, 4, 5, 6), impurity_1    = c(6, 5, 4, 3, 2, 1),
  impurity_2    = c(5, 6, 4, 3, 2, 1), impurity_3    = c(6, 5, 4, 3, 1, 2)
)
colnames(judges) <- c("income", "age", "balance", "region", "tenure", "arrears")

het <- judge_clusters(judges)
het
#> <judge_clusters>
#>   judges    : 6  
#>   variables : 6 
#>   clusters  : 2 (silhouette 0.905, p = 0.005 against one population) 
#>   start     : enumerated medoids 
#> 
#> # A tibble: 6 × 3
#>   judge         cluster silhouette
#>   <chr>           <int>      <dbl>
#> 1 permutation_1       1      0.930
#> 2 permutation_2       1      0.893
#> 3 permutation_3       1      0.893
#> 4 impurity_1          2      0.930
#> 5 impurity_2          2      0.893
#> 6 impurity_3          2      0.893
#> 
#> Group consensus:
#>           income age balance region tenure arrears
#> cluster_1      1   2       3      4      5       6
#> cluster_2      6   5       4      3      2       1
split(rownames(judges), het$cluster)
#> $`1`
#> [1] "permutation_1" "permutation_2" "permutation_3"
#> 
#> $`2`
#> [1] "impurity_1" "impurity_2" "impurity_3"
#> 
```
