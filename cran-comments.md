## Submission

rankimp 1.0.0. This is a new submission: the package is not yet on CRAN.

## Test environments

* local macOS 15.5, R 4.6.1 and R 4.6.0, `R CMD check --as-cran`
* GitHub Actions, on every push:
  * ubuntu-latest, R devel / release / oldrel-1
  * macOS-latest, R release
  * windows-latest, R release / devel

## R CMD check results

0 errors | 0 warnings | 0 notes, on all six GitHub Actions cells above.

Locally the same check reports two notes. The first is `New submission`, which
is expected: the package is not yet on CRAN. The second is `checking HTML
version of manual`, which says that HTML Tidy is not installed on this machine;
it is a property of the machine rather than of the package. Neither note appears
on any of the cells above.

## win-builder and R-hub

The package was uploaded to the win-builder R-devel queue through the HTTPS
upload form. The FTP route win-builder documents is refused from the network
this was prepared on, which is a property of the network rather than of the
package.

R-hub has not been used. The Windows R-devel cell it would have covered is in
the GitHub Actions matrix above.

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
