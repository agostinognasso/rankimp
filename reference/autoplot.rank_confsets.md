# Visualise the rank confidence sets

Variables ordered by consensus rank, each with the interval of ranks it
plausibly occupies. Overlapping intervals are the honest way of saying
that two variables cannot be ordered on this evidence, which is the
statement most importance plots decline to make.

## Usage

``` r
# S3 method for class 'rank_confsets'
autoplot(object, ...)
```

## Arguments

- object:

  A `rank_confsets` object.

- ...:

  Reserved for future use.

## Value

A `ggplot` object.

## Details

The rank axis is reversed, so that rank 1, the most important variable,
sits at the top.

## See also

[`rank_confsets()`](rank_confsets.md)

## Examples

``` r
judges <- rbind(c(1, 2, 3, 4), c(1, 3, 2, 4), c(2, 1, 3, 4))
colnames(judges) <- c("income", "age", "balance", "region")
autoplot(rank_confsets(consensus_rank(judges), n_boot = 50))
```
