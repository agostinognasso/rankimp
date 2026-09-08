# The applications dataset ----------------------------------------------------
#
# `rankimp` exists because importance measures disagree, and because the
# disagreement is usually not reported. A dataset shipped with it is only worth
# the space if the disagreement is in the data rather than in the telling, and
# if there is a right answer to check the consensus against. Four things are
# built in on purpose:
#
#   1. A known ordering. Every predictor enters a linear predictor with a
#      coefficient, so the effect a ranking ought to recover is the coefficient
#      times the spread of its own variable. It is stored on the data frame as
#      `attr(applications, "effects")`, so a user can score a consensus against
#      it rather than eyeball it.
#   2. A correlated pair. `bureau_score` and `income` correlate at about 0.85
#      and both carry signal. Permutation importance splits the credit between
#      two variables that stand in for each other; impurity importance does not
#      split it the same way. This is the cell where methods disagree, and it is
#      the reason to aggregate judges instead of picking one.
#   3. A signal variable that is a small count. `prior_arrears` is Poisson with
#      a handful of distinct values and a large coefficient. Impurity importance
#      is biased against low-cardinality predictors, so it should underrate a
#      variable that matters.
#   4. Two predictors that do nothing at all. `age` and `credit_lines` enter the
#      outcome nowhere. Anything that ranks them above a signal variable is
#      reporting noise, and `rank_confsets()` should decline to order them.
#
#   Rscript inst/data-raw/applications.R
#
# Writes data/applications.rda. Takes a second.

set.seed(20260908)

n <- 800L

# The correlated block. `bureau_score` is built from the same latent
# creditworthiness as the income, which is how the two come to stand in for
# each other in a forest.
latent <- rnorm(n)
income <- round(exp(log(38000) + 0.45 * (0.93 * latent + 0.37 * rnorm(n))))
bureau_score <- round(pmin(850, pmax(300, 660 + 62 * latent + 17 * rnorm(n))))

debt_ratio <- round(pmin(1, pmax(0.01,
  rbeta(n, 2, 5) * 1.6 - 0.12 * latent)), 3)
employment_yrs <- round(pmax(0, rexp(n, 1 / 7)), 1)
prior_arrears <- rpois(n, 1.1)
credit_lines <- rpois(n, 4)
age <- round(rnorm(n, 44, 12))

predictors <- data.frame(income, bureau_score, debt_ratio, employment_yrs,
                         prior_arrears, credit_lines, age)

# The coefficients are on standardised predictors, so that a coefficient and an
# effect are the same number and the ordering is unambiguous. `credit_lines`
# and `age` are absent by construction rather than small by accident.
coefficients <- c(
  prior_arrears  =  0.90,
  debt_ratio     =  0.78,
  bureau_score   = -0.62,
  income         = -0.45,
  employment_yrs = -0.22,
  credit_lines   =  0.00,
  age            =  0.00
)

standardised <- scale(predictors[, names(coefficients)])
risk <- -1.85 + as.vector(standardised %*% coefficients)
default <- factor(ifelse(rbinom(n, 1L, stats::plogis(risk)) == 1L, "yes", "no"),
                  levels = c("no", "yes"))

applications <- data.frame(predictors, default)
attr(applications, "effects") <- abs(coefficients)

# --- what the specification actually produced --------------------------------

cat("rows:", nrow(applications),
    " default rate:", sprintf("%.1f%%", 100 * mean(default == "yes")), "\n")
cat("correlation of income with bureau_score:",
    round(cor(income, bureau_score), 3), "\n")
cat("distinct values of prior_arrears:", length(unique(prior_arrears)), "\n")
cat("the ordering a ranking ought to recover:\n")
print(sort(attr(applications, "effects"), decreasing = TRUE))

dir.create("data", showWarnings = FALSE)
save(applications, file = file.path("data", "applications.rda"), compress = "xz")
cat("size on disk:",
    format(file.size(file.path("data", "applications.rda")) / 1024, digits = 3),
    "KB\n")
