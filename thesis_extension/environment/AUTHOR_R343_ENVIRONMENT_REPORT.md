# Authors' R 3.4.3 environment reconstruction report

## Source of truth and paths

The authors' `simulation/Readme.md` documents R 3.4.3, quantreg 5.34, hdm 0.2.0, hqreg 1.4, mvtnorm `1.0.6`, and doSNOW 1.0.16. The executable used here is:

`C:\Program Files\R\R-3.4.3\bin\x64\Rscript.exe`

It reports `R version 3.4.3 (2017-11-30)`, Windows x86-64. The isolated library is:

`C:\Users\User\master_thesis\thesis_extension\environment\legacy_R343_library`

During guarded execution `.libPaths()` contains only that library followed by `C:/Program Files/R/R-3.4.3/library`. No R 4.x user library is visible.

## Required versions and mvtnorm notation

| Package | README text | DESCRIPTION | packageVersion() | Installed library |
|---|---:|---:|---:|---|
| quantreg | 5.34 | 5.34 | 5.34 | isolated R343 |
| hdm | 0.2.0 | 0.2.0 | 0.2.0 | isolated R343 |
| hqreg | 1.4 | 1.4 | 1.4 | isolated R343 |
| mvtnorm | 1.0.6 | **1.0-6** | **1.0.6** | isolated R343 |
| doSNOW | 1.0.16 | 1.0.16 | 1.0.16 | isolated R343 |

The apparent mvtnorm discrepancy is notation, not a substituted release. The installed package's raw DESCRIPTION field is exactly `1.0-6`; R's `packageVersion()` normalizes that version to `1.0.6`. The guard enforces both representations.

## Reconstruction method

The machine already contained R 3.4.3 and a partial R 3.4 library whose required headline packages (except hdm) had the exact requested versions and recorded `Built: 3.4.3`. That library was copied into the project-local isolated path without overwriting the original.

The missing dependency closure was resolved from the dated Posit/CRAN snapshot `https://packagemanager.posit.co/cran/2017-11-30`. Exact Windows R 3.4 binaries were downloaded into `package_archives_R343/`. The locally present, hashed `hdm_0.2.0.tar.gz` was installed from its unchanged extracted source. Four copied packages that initially reported `Built: 3.4.4`—SparseM, foreach, iterators, and snow—were rebuilt from the exact locally archived source versions with R 3.4.3 and Rtools 3.5. They now report `Built: 3.4.3`. The nine core/runtime packages quantreg, hdm, hqreg, mvtnorm, doSNOW, SparseM, foreach, iterators, and snow all report `Built: 3.4.3`.

The authors did not document exact transitive dependency versions. They were not guessed or taken from current CRAN: the reconstruction records the actual versions selected by the R-release-date snapshot. The installed non-base dependency set is:

| Packages and exact versions |
|---|
| Formula 1.2-2; MatrixModels 0.4-1; R6 2.2.2; RColorBrewer 1.1-2; Rcpp 0.12.14; SparseM 1.77 |
| backports 1.1.1; checkmate 1.8.5; colorspace 1.3-2; dichromat 2.0-0; digest 0.6.12 |
| foreach 1.4.3; ggplot2 2.2.1; glmnet 2.0-13; gtable 0.2.0; iterators 1.0.8 |
| labeling 0.3; lazyeval 0.2.1; magrittr 1.5; munsell 0.4.3; plyr 1.8.4 |
| reshape2 1.4.2; rlang 0.1.4; scales 0.5.0; snow 0.4-2; stringi 1.1.6 |
| stringr 1.2.0; tibble 1.3.4; viridisLite 0.2.0 |

Base/recommended dependencies come only from R 3.4.3, including MASS 7.3-47, Matrix 1.2-12, lattice 0.20-35, and codetools 0.2-15. The complete visible inventory is in `installed_packages_R343.csv`; important runtime/dependency versions are in `package_versions_R343.txt`; full session information is in `sessionInfo_R343.txt`.

All saved package archives and their SHA-256 values are recorded in `package_archive_hashes_R343.csv`. Key source archive hashes are:

- hdm 0.2.0: `14DD57D18E2EB2BE79F4C47F9AF981045306F8914F57D679E7360346C81AED07`
- quantreg 5.34: `04F6FE7452EA63D1F2A77960934666132D2F90F139529515E795E35FED73AF2E`
- hqreg 1.4: `B14AE16FDABD7B32AC9AED7A80353FE871456B2A01CF537702A4CB5BF3B8DFC8`
- mvtnorm 1.0-6: `AC1F55D8C33FB9F0D7D15C6210AE82875CE93A28F76FEC5A46EE6C1B75499F79`
- doSNOW 1.0.16: `161434ECD55F04D6B070DA784B222A7686C914B73DE558EEF6048A229022398E`

`library_manifest_R343.csv` separately hashes every installed package DESCRIPTION for HP-to-Lenovo verification.

## Guard results

`check_author_environment.R` passed under the explicit R 3.4.3 executable. It checks R equality, raw DESCRIPTION versions, normalized `packageVersion()` values, successful loading, the first library path, and the originating library of every required package.

The final runner now calls this assertion before reading config, calling `set.seed`, generating data, or creating a cluster. Tests showed:

- R 4.6.1 is rejected immediately with an environment-mismatch error.
- Correct R 3.4.3 passes the environment check and then remains stopped by the separate `--execute-final` safety guard.
- No `final/output` directory was created.

## Authoritative R 3.4.3 validation

All outputs are isolated under `validation/R343/`; the earlier R 4.6.1 files were not overwritten.

- Kappa=1: maximum latent-treatment and transformed-treatment differences were exactly `0`.
- Oracle: maximum difference over the 41-point W profile was `0`.
- Full: maximum difference over the 41-point W profile was `0`.
- Controlled DML at `a=-1,1,3`: maximum BC-penalty, beta, and W differences were all `0`.
- Fresh BC calls: consecutive intercept penalties were `60.50898`, `59.76552`, and `61.13236`; stochastic variation was retained.
- Smoke test: 72 estimator profiles, 2,952 grid evaluations, 432 false-point/power evaluations, 72 finite point estimates, and zero failure records.

The repeated `Setting LC_CTYPE=C.UTF-8 failed` messages are Windows locale startup warnings. They did not change the active `C` locale or cause a validation failure.

## Integrity and final-run status

The author source hashes before and after reconstruction match `audit/AUTHOR_SOURCE_HASHES.txt`, and `git diff -- simulation` is empty. Therefore `ORIGINAL AUTHOR FILE MODIFICATIONS = 0`.

The final R=500 Monte Carlo for neither n=500 nor n=1000 was executed. The environment and validation are ready for review; final authorization remains separate.
