#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom ggplot2 .data
#' @importFrom stats setNames
#' @importFrom utils capture.output head
## usethis namespace: end
NULL

# Registering `autoplot()` methods is not enough: importing the generic makes it
# visible inside the package, not to the user who attached it. Re-exporting is
# what makes `autoplot(cb)` work after `library(rankimp)`.

#' @importFrom ggplot2 autoplot
#' @export
ggplot2::autoplot
