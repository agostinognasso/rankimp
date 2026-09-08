## Submission

rankimp 1.0.0. This is a new submission: the package is not yet on CRAN.

## Test environments

* local macOS 15.5, R 4.6.0, `R CMD check --as-cran`
* GitHub Actions, on every push:
  * ubuntu-latest, R devel / release / oldrel-1
  * macOS-latest, R release
  * windows-latest, R release / devel

## R CMD check results

0 errors | 0 warnings | 0 notes, on all six GitHub Actions cells above.

Locally the same check reports one note, `checking HTML version of manual`,
which says that HTML Tidy is not installed on this machine. It is a property of
the machine rather than of the package, and it does not appear on any of the
cells above.

## Not run

win-builder and R-hub have not been used. The FTP upload win-builder needs is
refused from the network this was prepared on, and the Windows R-devel cell it
would have covered is in the GitHub Actions matrix above instead.

## Notes for the reviewer

* A spell checker run over the Description flags `Kemeny`. It is correct: the
  surname in the Kemeny median ranking.
* `inst/simulations/` ships five scripts that are not run at check time and are
  not needed to use the package. They are the provenance of every quantitative
  claim in the documentation: the coverage, calibration and cluster-recovery
  figures quoted in the help pages and vignettes all come from them, and they
  are shipped so that a reader can rerun them.
* `inst/data-raw/applications.R` is the specification of the shipped
  `applications` dataset as runnable, seeded code, for the same reason.
* Examples that need `randomForest`, `ranger`, `rsample`, `cluster`, `stabm` or
  `kernelshap` are guarded; all six are in Suggests.
