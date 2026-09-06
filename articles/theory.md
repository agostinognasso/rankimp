# The theory the package rests on

Why a Kemeny median rather than an average, why ties are kept, and what
a bootstrap of a rank is actually estimating. This vignette is the
argument behind the code.
[`vignette("reference")`](../articles/reference.md) is the map of what
to call.

## The problem

A variable importance ranking is an estimate. It is produced by an
estimator with variance, from one sample, under one definition of
importance, and it is almost always reported as though it were a fact.

Three things move it, and they are separable:

The **definition** moves it. Mean decrease in impurity, permutation
importance, LOCO and SHAP are not noisy measurements of one underlying
quantity. They ask different questions, and on correlated predictors
they have different right answers. Permutation importance on a fitted
model asks what the model would lose; LOCO asks what a model built
without the variable would lose. Those diverge by construction.

The **estimator** moves it. Refit the same forest with a different seed
and the ordering changes, because the ensemble is random.

The **sample** moves it. Refit on a different draw from the same
population and the ordering changes again, and this is the one a reader
cares about when they ask whether the finding is real.

Reporting a single ranking collapses all three into one number and
reports it with no error bar. The package treats each source as a
**judge** with a vote, and then does statistics on the panel.

## Why rankings and not scores

Importance scores from different methods are not on a common scale. A
permutation loss of 0.63 and a LOCO loss of 0.025 are not comparable,
and no rescaling makes them so, because they are answers to different
questions. Standardising them would manufacture a comparison that does
not exist.

Ranks are the coarsest thing every method can be made to agree to
produce. That is their virtue and their price, and both matter:

The virtue is that a panel of ranks can be aggregated without pretending
the methods share a scale.

The price is that a disagreement living entirely in the magnitudes
becomes invisible.
[`vignette("method-disagreement")`](../articles/method-disagreement.md)
works through a case where two methods disagree by a factor of six in
the scores and produce the same ordering. Everything downstream in this
package sees nothing.

So: rank when you want to combine methods, and keep the scores when the
size of an effect is the finding. The panel keeps both, in
`attr(J, "scores")`.

## The Kemeny median

Given `K` judges each ranking the same `p` variables, the consensus is
the ranking closest to all of them at once:

``` math
\pi^{*} = \arg\min_{\pi} \sum_{k=1}^{K} w_k \, d_{KS}(\pi, \pi_k)
```

where $`d_{KS}`$ is the Kemeny-Snell distance. That distance counts
pairwise disagreements. For every pair of variables, the two rankings
either agree on which comes first, disagree, or one of them ties the
pair while the other does not; the last case counts half. Summing over
pairs gives a metric on weak orderings.

The reason to use this and not an average of ranks is that it comes with
an axiomatic characterisation. Kemeny and Snell showed that under a
short list of requirements a rank aggregation ought to satisfy, this
distance is the only one available, and the median that comes from it is
the only consensus. Averaging Borda scores satisfies fewer of them, and
the difference shows up in practice rather than only on paper.

The median is also a Condorcet method: if a majority of judges put
variable A above variable B, the consensus does too, whenever such an
ordering is consistent. An average of ranks does not guarantee this. A
variable placed second by most judges and last by one can be pushed
below a variable that no judge preferred to it, because the outlier’s
distance enters the average linearly. A median is robust to that in the
way medians usually are.

Finding it is NP-hard. The package uses exact branch and bound up to ten
variables and heuristics above that, and the threshold is empirical
rather than theoretical: on tied panels of thirty judges, the same exact
solver took 0.010 seconds at ten variables, 0.78 at eleven, and 280 at
twelve. Importance panels are the hard case for these solvers, because
the unimportant variables all tie near zero.

## Ties are part of the answer

The optimisation is over **weak orderings**, meaning rankings that are
allowed to tie. This is not a technical convenience, it is the reason to
use a Kemeny median at all.

Two variables that half the panel puts in one order and half puts in the
other have no defensible ordering, and a procedure that returns one
anyway is inventing it. Optimising over weak orders lets the answer be
“these two are level”, which is both true and useful. An average of
Borda scores can only produce a tie by numerical coincidence.

The same argument runs one level up. The Kemeny median is often **not
unique**: several rankings attain the same minimum, and the solver
returns all of them. Reporting the first is not neutral, because which
one comes first depends on your column order. Measured on a symmetric
panel, permuting the columns changed which variable won; with three
exchangeable noise predictors, the leftmost took the best rank
systematically. Non-uniqueness is not rare either, arising in 57% to 98%
of replicates in that simulation.

So the package averages each variable’s position over the whole optimal
set and re-ranks with ties. Variables the objective cannot separate come
back equal, which is the same principle applied to the same problem one
level higher. The full set stays available in `consensus_all`.

## Measuring agreement

`tau_x` is the Emond-Mason rank correlation, and it is reported as the
mean correlation between the consensus and the judges.

The reason for this coefficient rather than Kendall’s $`\tau_b`$ is ties
again. $`\tau_b`$ handles ties by a normalisation that breaks the
correspondence with the Kemeny distance, so maximising $`\tau_b`$ and
minimising $`d_{KS}`$ are not the same problem. Emond and Mason’s
$`\tau_x`$ restores it: maximising the mean $`\tau_x`$ to the judges is
exactly minimising the total Kemeny distance. The consensus and the
agreement statistic are then two views of one optimisation, rather than
two numbers that happen to sit near each other.

Read `tau_x` as how much agreement there was to summarise. It is not a
p-value, and it is not a goodness of fit.

## Uncertainty about a rank

A rank is a discrete, non-smooth functional of the data. The usual
asymptotic machinery does not apply: there is no delta method for a
quantity that jumps by a whole unit when two nearly equal scores swap
places. This is why the package bootstraps, and also why the bootstrap
here needs stating carefully rather than assuming.

There are two resampling schemes and they estimate different things.

**Resampling the judges** draws the panel with replacement. What varies
across replicates is which sources of importance are in the panel, so
the interval answers: how much does this consensus depend on my choice
of methods and seeds? It refits nothing, so it is cheap. The package
implements it by drawing multinomial counts and passing them as judge
weights, which is equivalent to materialising the resampled panel
because a weight of 3 is treated exactly as three copies of a judge.

**Resampling the data** draws the rows with replacement, refits every
model, and rebuilds the panel from scratch, once per replicate. What
varies is the sample, so the interval answers: would this ordering
survive another dataset? That is usually the question a reader has.

The two are not interchangeable and the gap is large. Over 300
replicates per cell, a nominal 95% set from the data bootstrap covered
between 0.966 and 0.998. The judge bootstrap covered between 0.582 and
0.929 and reached the nominal level in none of the six cells. Resampling
a panel measures how much the methods argue with each other, which is a
real quantity and a much smaller one than sampling variability.

### What the intervals look like, and why

The data bootstrap covers, and it covers by being wide. On the hardest
cell the interval spans 5.1 of 8 available ranks. That reads like a
failure until you ask what the point estimate does on the same cell: it
recovers the exact order of the five signal variables 5.3% of the time.
The interval is wide because the sample does not order those variables,
and reporting a narrow one would be claiming more than the data contain.

There is a related effect worth expecting rather than debugging. A
bootstrap sample of `n` rows holds about $`0.632n`$ distinct ones, so
each replicate ranks on less information than the full sample, and the
ranking drifts towards the middle: the top of the ordering drifts down
and the bottom drifts up. Measured over 300 panels, the median bootstrap
rank of the second variable sits 0.55 ranks below its consensus rank,
and the eighth sits 1.00 above.

The way to tell that drift apart from a bug is to hand a replicate all
the distinct rows instead of a bootstrap sample. It then reproduces the
point estimate exactly, which says the machinery rebuilds the panel
correctly and the shift is the bootstrap doing what bootstraps do.

## Testing whether a panel is one population

When agreement is low, the interesting question is whether the
disagreement is spread evenly or whether the panel has a seam in it.
[`judge_clusters()`](../reference/judge_clusters.md) looks for the seam
by k-medians in Kemeny-Snell space, where each group’s centre is the
Kemeny median of its own members. The centre of a group is therefore a
consensus ranking, an object you can report, rather than a point in some
embedding.

The hard part is not finding groups. It is refusing to find them.

Silhouette width, the usual internal measure of how well-separated a
clustering is, fails badly here for a specific reason: judges who rank
alike sit at distance exactly zero, and a cluster of identical judges
scores a silhouette of 1. Real panels repeat themselves constantly,
because two methods often agree exactly. Measured on eight variables and
six judges one transposition apart, silhouette width on its own split a
single population 62% of the time.

Those same zero distances are what makes a genuine division obvious, so
the statistic cannot separate the two cases by itself. It has to be told
what one population looks like.

So the package builds a reference. It draws panels of the same shape
from a single population, spread to match the mean pairwise distance in
the observed panel, and asks how often such a panel divides as sharply
as this one did. The sampler is a random walk of adjacent
transpositions, calibrated by matching the mean rather than a low
quantile: matching a low quantile targets a within-group distance, which
makes the reference population tight, and a tight population produces
duplicate rankings whose zero distances score a silhouette near 1.
Measured, that cost most of the power, 0.805 falling to 0.173 on the
same design at the same level.

The statistic is the best division **in two**, not the best over every
`k`. Testing the maximum sounds more general and is worse: the reference
then pays a multiplicity that grows with the panel, and power falls away
as judges are added. Measured on two clearly separated groups at the
same level, 0.233 at six judges down to 0.067 at twelve for the maximum,
against 0.633 up to 0.917 for the two-group statistic.

A panel the test rejects is reported as divided in two, which is the
division the evidence is about. Reading `k` off the largest silhouette
instead attaches an uncalibrated number to a calibrated decision, and it
measures worse: on ten judges or more it never once chose two, and
recovery of a true two-group partition fell as judges were added.

## What none of this protects you from

Every judge in a panel of tree-ensemble methods is a tree-ensemble
method. Averaging over methods, seeds, folds and two forest
implementations measures how much the answer depends on those choices. A
bias that all the judges share passes through the consensus untouched
and comes out looking like agreement.

[`vignette("credit-scoring")`](../articles/credit-scoring.md) shows this
concretely: the panel splits along the method axis because mean decrease
in impurity prefers a continuous variable to a small count, and the
split is visible only because the panel contained a method that does not
share that bias. Had every judge been an impurity judge, the consensus
would have been narrow, confident and wrong in the same direction
throughout.

Widen the panel along the axis you are worried about. A confidence set
is only as honest as the panel it summarises.

## Sources

The consensus itself is computed by
[`ConsRank`](https://cran.r-project.org/package=ConsRank), which
implements the branch-and-bound and heuristic solvers. The contribution
of this package is the inferential layer on top: the bootstrap schemes,
the calibration of the selection rules, and the test behind
[`judge_clusters()`](../reference/judge_clusters.md).

- Kemeny, J. G. and Snell, J. L. (1962). *Mathematical Models in the
  Social Sciences*. Ginn. The distance and its axiomatic
  characterisation.
- Emond, E. J. and Mason, D. W. (2002). A new rank correlation
  coefficient with application to the consensus ranking problem.
  *Journal of Multi-Criteria Decision Analysis*, 11(1), 17-28.
- Amodio, S., D’Ambrosio, A. and Siciliano, R. (2016). Accurate
  algorithms for identifying the median ranking when dealing with weak
  and partial rankings under the Kemeny axiomatic approach. *European
  Journal of Operational Research*, 249(2).

Every measured number quoted above comes from a script in
`inst/simulations/`, and those are meant to be re-run rather than
believed.
