# Reporting schema

## General keys

The main Monte Carlo cell key is `(n, tau, kappa, estimator)`. Power adds `Delta`; replication-level files add `replication`. The expected estimator labels are exactly `Oracle-GMM`, `Full-GMM`, and `DML-IVQR-BC`.

## Point estimation

Source: `thesis_extension/final/output/n500/summary.csv` and `n1000/summary.csv`, created by `aggregate_results()` in `thesis_extension/src/metrics.R`.

- Point estimate: `alpha_hat` in replication-level `results.csv`.
- Signed error: `alpha_hat - alpha_true` in `signed_error`.
- Canonical Bias: mean of replication-level `bias = alpha_true - alpha_hat`. This sign convention is intentionally the opposite of `signed_error`.
- MAE: mean of `absolute_error = abs(alpha_hat - alpha_true)`.
- RMSE: square root of the mean of `squared_error = (alpha_hat - alpha_true)^2`.

Reporting tables copy `Bias`, `MAE`, and `RMSE` from canonical `summary.csv`; they do not redefine or re-estimate these metrics.

## Coverage and size

Executable sources: `thesis_extension/src/run_extension.R`, `metrics.R`, and `dgp_kappa.R`. Reporting source: accepted forensic outputs `coverage_audit_all_cells.csv` and `coverage_audit_strong_kappa_n1000.csv`.

- `W_true` is evaluated directly at `alpha0(tau) = 1 + qnorm(tau)`.
- `covered = (W_true <= qchisq(.95, df=2))`.
- `rejected_true = (W_true > qchisq(.95, df=2))`.
- Coverage is the mean of `covered`; Size is the mean of `rejected_true`.
- MCSE is `sqrt(coverage * (1-coverage) / R_available)`.
- The forensic audit supplies the R-3.4.3-compatible Wilson 95% Monte Carlo interval.

Coverage is independent of the finite alpha grid because `W_true` is evaluated through the direct-point path.

## Confidence-set informativeness

Sources: canonical `summary.csv` and `grid_profile_diagnostics()` in `thesis_extension/src/metrics.R`.

The preferred term is **grid-based accepted-set measure within the prespecified primary computational domain A0=[-1,3]**. It is not an unrestricted confidence-region length.

- `grid_accepted_set_measure`: trapezoidal measure across adjacent accepted grid points, using grid step `.10`.
- `median_grid_accepted_set_measure` and `mean_grid_accepted_set_measure`: cell aggregates of that finite-domain measure.
- `accepted_grid_share`: accepted grid-point count divided by 41.
- `all_41_acceptance_rate`: rate at which all 41 primary-domain grid points are accepted.
- Left/right/either/both boundary rates: acceptance of `-1` and/or `3`.
- `mean_number_accepted_grid_points`: mean accepted-point count.

## Power

Sources: canonical `power_summary.csv`, created by `aggregate_power()` in `thesis_extension/src/metrics.R`.

- `Delta`: false-value offset from `alpha0(tau)`.
- `a_false = alpha0(tau) + Delta` in replication-level `power.csv`.
- `power`: mean of `rejected_false`, where rejection uses the unchanged chi-square(2) 95% cutoff.
- `false_acceptance`: mean of `1 - rejected_false`.

The compact candidate uses `Delta=-.50,+.50`, `n=1000`, and `tau=.10,.50,.90`. These are moderate false alternatives, permit signed-asymmetry comparisons, and retain tail/central quantiles; the full Delta set and all designs remain in full and appendix outputs.

## Grid-domain diagnostic

Sources: Stage-2 `stage2_summary.csv` and `stage2_expansion_summary.csv`, cross-referenced with Stage-1/Stage-2 failure files and definitions in `grid_sensitivity_functions.R`.

- Domains: `A0=[-1,3]`, `A1=[-3,5]`, `A2=[-5,7]`.
- Domain-specific accepted-set measure uses the same trapezoidal grid rule.
- `added_measure_A0_to_A1 = L_A1 - L_A0`.
- `added_measure_A1_to_A2 = L_A2 - L_A1`.
- Boundary acceptance rates refer to either endpoint of the named finite domain.
- All-grid acceptance rates record acceptance of every grid point in that domain.
- “Near-stable within investigated domains” is used only when mean added measure from A1 to A2 and A2 boundary acceptance are both at most `.05`; otherwise the output says “not stabilized within investigated domains.”
- No connected-component metric was produced, so no claim about disconnected sets is reported.

## Instrument-strength calibration

Source: preserved `kappa_strength_summary.csv`; definitions are checked against `run_strength_calibration.R` and the preserved legacy runner.

- Joint first-stage F: nested-model F-test for the two excluded instruments, calculated equivalently from restricted/unrestricted RSS.
- Partial R-squared: `(RSS_restricted - RSS_unrestricted) / RSS_restricted`, cross-checked against the model-R-squared formula.
- Dispersion: p10, p90, and standard deviation from 100 replications per `(n,kappa)`.

These quantities are descriptive strength diagnostics and are not interpreted as formal threshold tests.
