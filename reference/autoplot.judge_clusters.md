# Visualise the disagreement between judges

Multidimensional scaling of the judges in the space of the Kemeny-Snell
distance, coloured by cluster.

## Usage

``` r
# S3 method for class 'judge_clusters'
autoplot(object, ...)
```

## Arguments

- object:

  A `judge_clusters` object.

- ...:

  Reserved for future use.

## Value

A `ggplot` object.

## Details

What the picture is for: whether the panel is one cloud or several, and
which judges sit between them. The Kemeny-Snell distance is
integer-valued and rarely Euclidean, so two dimensions are a projection
and not the thing itself. The subtitle reports how much of the distance
survives the projection, and a low figure means the plot is a sketch of
the grouping rather than evidence for it.

## See also

[`judge_clusters()`](judge_clusters.md)

## Examples

``` r
judges <- rbind(
  permutation_1 = c(1, 2, 3, 4, 5, 6), permutation_2 = c(1, 2, 3, 4, 6, 5),
  permutation_3 = c(2, 1, 3, 4, 5, 6), impurity_1    = c(6, 5, 4, 3, 2, 1),
  impurity_2    = c(5, 6, 4, 3, 2, 1), impurity_3    = c(6, 5, 4, 3, 1, 2)
)
colnames(judges) <- c("income", "age", "balance", "region", "tenure", "arrears")
autoplot(judge_clusters(judges))
```
