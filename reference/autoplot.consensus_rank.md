# Visualise a consensus ranking against the panel it came from

The consensus rank of each variable, drawn on top of every rank the
judges actually gave it. Point area is the number of judges at that
rank, so the picture is exact rather than jittered.

## Usage

``` r
# S3 method for class 'consensus_rank'
autoplot(object, ...)
```

## Arguments

- object:

  A `consensus_rank` object.

- ...:

  Reserved for future use.

## Value

A `ggplot` object.

## Details

What it is for: a consensus ranking reports one number per variable, and
that number is equally consistent with a panel that agreed and a panel
that was split down the middle. The spread behind each point is the
difference, and it is per variable. `tau_x` and
[`item_consensus()`](item_consensus.md) measure agreement per *judge*,
which is a different question and will not tell you *which* variables
the panel could not place.

Variables the consensus could not separate come out at the same rank and
are drawn at the same height; that is a finding, not a drawing artefact.
Where the Kemeny median is not unique the plot plots the combined
ranking, the one [`consensus_rank()`](consensus_rank.md) reports, and
says so in the subtitle.

The rank axis is reversed, so rank 1, the most important variable, sits
at the top.

## See also

[`consensus_rank()`](consensus_rank.md),
[`item_consensus()`](item_consensus.md),
[`autoplot.rank_confsets()`](autoplot.rank_confsets.md)

## Examples

``` r
judges <- rbind(
  permutation = c(1, 2, 3, 4), impurity = c(1, 3, 2, 4), loco = c(2, 1, 3, 4)
)
colnames(judges) <- c("income", "age", "balance", "region")
autoplot(consensus_rank(judges))
```
