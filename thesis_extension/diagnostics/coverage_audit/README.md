# Coverage / size forensic audit

This directory contains a read-only diagnostic of the completed R=500 Monte Carlo outputs. It does not run estimators, regenerate simulation data, change critical values, or modify canonical results.

## Inputs

- `thesis_extension/final/output/n500/results.csv`
- `thesis_extension/final/output/n1000/results.csv`
- the corresponding `summary.csv` files for an independent aggregate-coverage cross-check
- `thesis_extension/config/extension_config.R`
- `thesis_extension/src/dgp_kappa.R`, `metrics.R`, and `run_extension.R` for executable-definition verification

The actual estimator label retained in the final CSVs is `DML-IVQR-BC`; references to DML-IVQR in the audit mean this exact saved estimator.

## Method

For every one of the 120 `n x tau x kappa x estimator` cells, the audit summarizes the 500 saved direct evaluations of `W_true`. Coverage is recomputed mechanically as `W_true <= qchisq(.95, 2)`. Monte Carlo intervals are 95% Wilson binomial intervals, implemented directly in base R for R 3.4.3 compatibility.

The primary cells are `n=1000`, `kappa=1`, and `tau=.50,.75,.90` for Oracle-GMM, Full-GMM, and DML-IVQR-BC. No observations or outliers are removed.

The descriptive pattern classification uses an explicit rule:

- broad shift: empirical median, q75, and q90 all exceed their chi-square(2) reference quantiles;
- extreme-tail evidence: empirical q99 exceeds 1.5 times the chi-square(2) q99 or the maximum exceeds twice that q99;
- A/B/C/D indicates broad shift only, extreme-tail only, both, or neither/unclear.

This operational classification is descriptive, not a formal test or causal explanation.

## Run

From the repository root, using the canonical R 3.4.3 executable:

```text
"C:\Program Files\R\R-3.4.3\bin\x64\Rscript.exe" --vanilla thesis_extension/diagnostics/coverage_audit/run_coverage_audit.R --execute-coverage-audit
```

The runner refuses to overwrite an existing non-empty `output/` or `figures/` directory unless `--overwrite` is also supplied.

`COVERAGE_AUDIT_MANIFEST.csv` records inputs, code, outputs, and figures. It intentionally cannot record its own SHA-256 because a self-hash would be recursive.
