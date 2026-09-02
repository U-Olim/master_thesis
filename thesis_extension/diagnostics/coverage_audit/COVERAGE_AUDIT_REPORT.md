# Coverage / size forensic audit

## 1. Purpose

This technical audit diagnoses the saved per-replication W statistic at the true parameter in the completed R=500 Monte Carlo. It does not alter or rerun the empirical design.

## 2. Inputs and provenance

Repository commit: `2cffcc34270efd2259cbf53b9454b261b0a9dead`.
Runtime environment: `R version 3.4.3 (2017-11-30)`.

| relative_path | bytes | sha256 |
|---|---|---|
| thesis_extension/final/output/n500/results.csv | 6209864 | 258fce913afbb8730e5d1afca9d52ebc265ab1bc1638f407b415038bc33bd780 |
| thesis_extension/final/output/n1000/results.csv | 6319843 | 456fc20eb5080d00e2d5dcaabc77422ba3ee088dc358a6a8cb791f1a94b1b4e3 |
| thesis_extension/final/output/n500/summary.csv |   11421 | 5ea9c4368966c39e6b6f874cc7dc9019d1c58b5b56b65ecb9b9b72c823f96f38 |
| thesis_extension/final/output/n1000/summary.csv |   11513 | da067bc5bf1f86703d5764c0ba4d164fbaea6b06f917c70d44bf027332e61cfd |

## 3. Executable coverage definition and schema

The final `results.csv` files preserve `W_true`, `covered`, `rejected_true`, `n`, `replication`, `tau`, `kappa`, `estimator`, `alpha_true`, and failure flags for every replication. The saved estimator labels are `Oracle-GMM`, `Full-GMM`, and `DML-IVQR-BC`.

Executable inspection confirms that `truth <- alpha_true(tau)` is inserted as the first direct evaluation point, independently of the computational alpha grid. The DGP helper defines `alpha_true(tau) = 1 + qnorm(tau)`. The result row saves `W_true = direct_W[1]` and classifies:

`covered = 1{W_true <= qchisq(.95, df=2)}`

`rejected_true = 1{W_true > qchisq(.95, df=2)}`

The unchanged theoretical cutoff is `5.99146454710798`. Coverage is therefore independent of the 41-point profile grid.

## 4. Reference distribution

| probability | df | chi_square_quantile |
|---|---|---|
| 0.500000 | 2.000000 | 1.386294 |
| 0.900000 | 2.000000 | 4.605170 |
| 0.950000 | 2.000000 | 5.991465 |
| 0.990000 | 2.000000 | 9.210340 |

## 5. Primary-cell results

| tau | estimator | coverage | MCSE | MC95_lower | MC95_upper | size | median_W | q90_W | q95_W | q99_W | q95_ratio | mean_W | pattern |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.50 | Oracle-GMM | 0.872 | 0.01494095 | 0.8398543 | 0.8984732 | 0.128 | 1.961251 |  6.778866 |  8.510704 | 11.45799 | 1.420471 | 2.832748 | A: broad rightward shift |
| 0.50 | Full-GMM | 0.896 | 0.01365167 | 0.8661557 | 0.9198058 | 0.104 | 1.646408 |  6.148722 |  7.524173 | 11.97780 | 1.255815 | 2.510839 | C: broad rightward shift and extreme-tail values |
| 0.50 | DML-IVQR-BC | 0.776 | 0.01864532 | 0.7374303 | 0.8103610 | 0.224 | 2.933070 |  9.091672 | 11.156945 | 14.89956 | 1.862140 | 3.922107 | C: broad rightward shift and extreme-tail values |
| 0.75 | Oracle-GMM | 0.860 | 0.01551773 | 0.8268331 | 0.8876773 | 0.140 | 1.820151 |  6.838523 |  8.763125 | 14.03168 | 1.462602 | 2.864776 | C: broad rightward shift and extreme-tail values |
| 0.75 | Full-GMM | 0.790 | 0.01821538 | 0.7521552 | 0.8234227 | 0.210 | 2.503916 |  8.758641 | 12.488816 | 18.07363 | 2.084435 | 3.842788 | C: broad rightward shift and extreme-tail values |
| 0.75 | DML-IVQR-BC | 0.632 | 0.02156738 | 0.5888717 | 0.6731155 | 0.368 | 4.346393 | 13.066817 | 16.034117 | 21.74851 | 2.676160 | 5.833755 | C: broad rightward shift and extreme-tail values |
| 0.90 | Oracle-GMM | 0.904 | 0.01317452 | 0.8750130 | 0.9268265 | 0.096 | 1.909292 |  5.932913 |  7.394906 | 12.42520 | 1.234240 | 2.700631 | A: broad rightward shift |
| 0.90 | Full-GMM | 0.530 | 0.02232039 | 0.4861906 | 0.5733519 | 0.470 | 5.160904 | 17.204085 | 20.072067 | 28.05482 | 3.350110 | 7.318385 | C: broad rightward shift and extreme-tail values |
| 0.90 | DML-IVQR-BC | 0.498 | 0.02236050 | 0.4543569 | 0.5416736 | 0.502 | 6.064974 | 15.077851 | 18.681893 | 24.23902 | 3.118085 | 7.090953 | C: broad rightward shift and extreme-tail values |

## 6. Full-cell diagnostics

All 120 expected design cells were found, each with 500 rows. The ten lowest empirical coverage cells are:

| n | tau | kappa | estimator | empirical_coverage | coverage_mc95_lower | coverage_mc95_upper | q95_W_true | q95_ratio_to_chisq2_q95 |
|---|---|---|---|---|---|---|---|---|
|  500 | 0.10 | 1 | Full-GMM | 0.442 | 0.3990760 | 0.4858085 | 18.85903 | 3.147649 |
| 1000 | 0.90 | 1 | DML-IVQR-BC | 0.498 | 0.4543569 | 0.5416736 | 18.68189 | 3.118085 |
| 1000 | 0.10 | 1 | Full-GMM | 0.502 | 0.4583264 | 0.5456431 | 21.08970 | 3.519958 |
| 1000 | 0.90 | 1 | Full-GMM | 0.530 | 0.4861906 | 0.5733519 | 20.07207 | 3.350110 |
|  500 | 0.90 | 1 | Full-GMM | 0.556 | 0.5121869 | 0.5989592 | 17.35619 | 2.896819 |
| 1000 | 0.75 | 1 | DML-IVQR-BC | 0.632 | 0.5888717 | 0.6731155 | 16.03412 | 2.676160 |
|  500 | 0.90 | 1 | DML-IVQR-BC | 0.658 | 0.6153562 | 0.6982345 | 13.71469 | 2.289039 |
|  500 | 0.75 | 1 | DML-IVQR-BC | 0.770 | 0.7311378 | 0.8047451 | 11.57173 | 1.931369 |
| 1000 | 0.50 | 1 | DML-IVQR-BC | 0.776 | 0.7374303 | 0.8103610 | 11.15694 | 1.862140 |
|  500 | 0.25 | 1 | Full-GMM | 0.788 | 0.7500479 | 0.8215605 | 10.64971 | 1.777481 |

Complete 120-cell statistics are in `output/coverage_audit_all_cells.csv`.

## 7. Strong-kappa n=1000 comparison

| tau | estimator | coverage | MCSE | MC95_lower | MC95_upper | size | median_W | q90_W | q95_W | q99_W | q95_ratio | mean_W |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.10 | Oracle-GMM | 0.860 | 0.015517732 | 0.8268331 | 0.8876773 | 0.140 | 2.043472 |  7.230656 |  9.723492 | 14.703643 | 1.6228907 | 3.075559 |
| 0.10 | Full-GMM | 0.502 | 0.022360501 | 0.4583264 | 0.5456431 | 0.498 | 5.950064 | 16.977942 | 21.089704 | 29.828637 | 3.5199581 | 7.810588 |
| 0.10 | DML-IVQR-BC | 0.968 | 0.007870959 | 0.9486551 | 0.9802085 | 0.032 | 1.448997 |  4.195722 |  5.256164 |  7.473151 | 0.8772753 | 1.935914 |
| 0.25 | Oracle-GMM | 0.874 | 0.014840755 | 0.8420323 | 0.9002647 | 0.126 | 1.845218 |  6.604231 |  8.299874 | 11.251017 | 1.3852830 | 2.707778 |
| 0.25 | Full-GMM | 0.790 | 0.018215378 | 0.7521552 | 0.8234227 | 0.210 | 2.572579 |  8.219690 | 10.940098 | 18.066406 | 1.8259473 | 3.747744 |
| 0.25 | DML-IVQR-BC | 0.894 | 0.013766917 | 0.8639491 | 0.9180429 | 0.106 | 1.720336 |  6.071379 |  7.810569 | 10.719204 | 1.3036160 | 2.526663 |
| 0.50 | Oracle-GMM | 0.872 | 0.014940950 | 0.8398543 | 0.8984732 | 0.128 | 1.961251 |  6.778866 |  8.510704 | 11.457993 | 1.4204715 | 2.832748 |
| 0.50 | Full-GMM | 0.896 | 0.013651667 | 0.8661557 | 0.9198058 | 0.104 | 1.646408 |  6.148722 |  7.524173 | 11.977804 | 1.2558154 | 2.510839 |
| 0.50 | DML-IVQR-BC | 0.776 | 0.018645321 | 0.7374303 | 0.8103610 | 0.224 | 2.933070 |  9.091672 | 11.156945 | 14.899557 | 1.8621398 | 3.922107 |
| 0.75 | Oracle-GMM | 0.860 | 0.015517732 | 0.8268331 | 0.8876773 | 0.140 | 1.820151 |  6.838523 |  8.763125 | 14.031679 | 1.4626016 | 2.864776 |
| 0.75 | Full-GMM | 0.790 | 0.018215378 | 0.7521552 | 0.8234227 | 0.210 | 2.503916 |  8.758641 | 12.488816 | 18.073634 | 2.0844346 | 3.842788 |
| 0.75 | DML-IVQR-BC | 0.632 | 0.021567383 | 0.5888717 | 0.6731155 | 0.368 | 4.346393 | 13.066817 | 16.034117 | 21.748505 | 2.6761598 | 5.833755 |
| 0.90 | Oracle-GMM | 0.904 | 0.013174521 | 0.8750130 | 0.9268265 | 0.096 | 1.909292 |  5.932913 |  7.394906 | 12.425199 | 1.2342402 | 2.700631 |
| 0.90 | Full-GMM | 0.530 | 0.022320394 | 0.4861906 | 0.5733519 | 0.470 | 5.160904 | 17.204085 | 20.072067 | 28.054818 | 3.3501103 | 7.318385 |
| 0.90 | DML-IVQR-BC | 0.498 | 0.022360501 | 0.4543569 | 0.5416736 | 0.502 | 6.064974 | 15.077851 | 18.681893 | 24.239017 | 3.1180846 | 7.090953 |

## 8. Monte Carlo uncertainty

Coverage MCSE is `sqrt(p_hat*(1-p_hat)/R_available)`. The reported 95% intervals are Wilson binomial intervals. Nominal 0.95 lies outside the interval in 54 of 120 cells and in 9 of 9 primary cells. This is the audit's explicit Monte Carlo comparison; no broader significance claim is made.

## 9. Distributional evidence

The `pattern` column in the primary table applies the operational rule documented in README.md. Histograms, ECDF comparisons, and Q-Q plots retain all finite observations. The rule distinguishes a broad rightward shift from isolated extreme-tail evidence without assigning a theoretical cause.

## 10. Paired Oracle / Full / DML comparison

| tau | comparison | correlation_W_true | mean_paired_W_difference_A_minus_B | median_paired_W_difference_A_minus_B | q90_paired_W_difference_A_minus_B | q95_paired_W_difference_A_minus_B | fraction_A_rejects_B_accepts | fraction_A_accepts_B_rejects | fraction_both_reject | fraction_both_accept |
|---|---|---|---|---|---|---|---|---|---|---|
| 0.50 | DML vs Oracle | 0.5277306 |  1.0893589 |  0.91152788 |  5.413071 |  6.547684 | 0.164 | 0.068 | 0.060 | 0.708 |
| 0.50 | DML vs Full | 0.4277470 |  1.4112674 |  1.05872338 |  6.000909 |  7.666084 | 0.166 | 0.046 | 0.058 | 0.730 |
| 0.50 | Oracle vs Full | 0.5273021 |  0.3219085 |  0.24492060 |  3.267543 |  5.224577 | 0.084 | 0.060 | 0.044 | 0.812 |
| 0.75 | DML vs Oracle | 0.6556702 |  2.9689790 |  2.43560893 |  8.090994 | 10.326911 | 0.256 | 0.028 | 0.112 | 0.604 |
| 0.75 | DML vs Full | 0.6074615 |  1.9909672 |  1.31787015 |  7.238506 |  9.493017 | 0.206 | 0.048 | 0.162 | 0.584 |
| 0.75 | Oracle vs Full | 0.4363167 | -0.9780117 | -0.44009126 |  2.901830 |  4.329857 | 0.066 | 0.136 | 0.074 | 0.724 |
| 0.90 | DML vs Oracle | 0.6853196 |  4.3903218 |  3.78810271 | 10.440040 | 12.535148 | 0.416 | 0.010 | 0.086 | 0.488 |
| 0.90 | DML vs Full | 0.4967409 | -0.2274317 |  0.03303273 |  7.374447 |  9.443748 | 0.184 | 0.152 | 0.318 | 0.346 |
| 0.90 | Oracle vs Full | 0.3510453 | -4.6177535 | -2.79993089 |  1.668693 |  2.913889 | 0.020 | 0.394 | 0.076 | 0.510 |

Undercoverage outside the cell-specific Monte Carlo interval appears in both Oracle-GMM and DML-IVQR-BC primary cells. The discrepancy therefore cannot be attributed solely to high-dimensional nuisance estimation.

The paired results are descriptive. Correlation and disagreement frequencies are not causal evidence.

## 11. Outlier and failure checks

Across all saved result rows, non-finite W_true values: 0; negative finite W values: 0; profile/coverage failure flags: 0; coverage/rejection indicator mismatches: 0. Duplicate and missing replication checks are recorded for every cell in `output/coverage_audit_consistency_checks.csv`. The largest ten W_true values in every primary cell are retained in `output/coverage_audit_outliers.csv`; no outlier was deleted or corrected.

## 12. What can be concluded

The audit can establish which completed Monte Carlo cells have rejection frequencies above 5%, whether 0.95 lies outside a cell-specific Monte Carlo interval, whether the empirical W distribution is broadly shifted or dominated by a small upper tail under the stated descriptive rule, and how the three estimators agree on paired replications.

## 13. What cannot be concluded

This audit cannot identify a theoretical cause, prove failure of weak-ID-robust inference, invalidate the chi-square reference law, or attribute a discrepancy causally to DML. It does not justify changing the cutoff, grid, tuning, seed, estimator, or sample after observing results.

## 14. Implications for thesis reporting

Coverage and size should be reported transparently by estimator, quantile, instrument strength, and sample size, with Monte Carlo uncertainty and the direct-evaluation definition stated explicitly. Unexpected cells should remain in the reported design together with their distributional diagnostics.

## Safe thesis interpretation

Undercoverage outside the cell-specific Monte Carlo interval appears in both Oracle-GMM and DML-IVQR-BC primary cells. The discrepancy therefore cannot be attributed solely to high-dimensional nuisance estimation.

Where the cell tables show coverage below 0.95, a safe formulation is: 'The empirical rejection frequency at the true parameter exceeds the nominal 5% level in these completed designs.' This is a finite-sample Monte Carlo statement, not a claim about the general validity of the procedure.

Audit runtime before manifest generation: 4.76062 seconds.
