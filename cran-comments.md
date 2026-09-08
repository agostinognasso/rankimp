## Submission

rankimp 1.0.0. This is a new submission: the package is not yet on CRAN.

## Test environments

* local macOS 15.5, R 4.6.0
* GitHub Actions: ubuntu-latest (release, devel, oldrel-1), macOS-latest
  (release), windows-latest (release)
* win-builder (devel and release)
* R-hub

## R CMD check results

0 errors | 0 warnings | 0 notes

The only note seen locally is `checking HTML version of manual`, which reports
that `tidy` is not installed on the checking machine. It is a property of the
local environment rather than of the package.

## Notes for the reviewer

* `inst/simulations/` ships five scripts that are not run at check time and are
  not needed to use the package. They are the provenance of every quantitative
  claim in the documentation: the coverage, calibration and cluster-recovery
  figures quoted in the help pages and vignettes all come from them, and they
  are shipped so that a reader can rerun them.
* `inst/data-raw/applications.R` is the specification of the shipped
  `applications` dataset as runnable, seeded code, for the same reason.
* Examples that need `randomForest`, `ranger`, `rsample`, `cluster`, `stabm` or
  `kernelshap` are guarded; all six are in Suggests.
