# Empirical results freeze

## Freeze identity

- Repository commit: `ac9a9ccad027cde05488abb633e66cc02f87cc46`
- Freeze date: 2026-09-02
- Canonical runtime: R 3.4.3 (2017-11-30), using the preserved environment under `thesis_extension/environment/`
- Canonical file inventory and SHA-256 hashes: `EMPIRICAL_RESULTS_MANIFEST.csv`

This freeze defines the empirical evidence available to the thesis reporting layer. Reporting code may read these inputs but must not modify them. It does not authorize new simulation, calibration, estimation, tuning, or selective reruns.

## Main Monte Carlo design

- Replications per design: `R_MC = 500`
- Sample sizes: `n = 500, 1000`
- Quantiles: `tau = .10, .25, .50, .75, .90`
- Instrument-strength parameters: `kappa = 1, .5, .25, .1`
- Estimators: `Oracle-GMM`, `Full-GMM`, `DML-IVQR-BC`
- Nominal inference level: `.95`
- Reference distribution: chi-square with 2 degrees of freedom
- Critical value: `qchisq(.95, 2) = 5.99146454710798`
- Primary computational domain: `A0 = [-1,3]`
- Primary grid step: `.10` (41 points)
- False-alternative offsets: `Delta = -1, -.5, -.25, .25, .5, 1`
- True parameter: `alpha0(tau) = 1 + Phi^{-1}(tau)`
- Coverage is evaluated directly at `alpha0(tau)`, independently of whether the true value lies on the computational grid.

The canonical main-run output contains no recorded numerical failures.

## Grid-domain diagnostic status

- Stage 1 was completed for 100 replications at `n=1000` on `A0=[-1,3]` and `A1=[-3,5]` for `kappa = 1, .25, .1`.
- The prespecified Stage-1 trigger fired and Stage 2 was completed on `A2=[-5,7]` using the preserved Stage-1 primitives and interior profiles.
- Stage 1 records one singular-design numerical error: replication 35, `tau=.90`, `kappa=.10`, `DML-IVQR-BC`, candidate `a=-2.1`.
- Stage 2 records zero new numerical errors.
- Domain expansion is interpreted only over the investigated domains. It does not establish global boundedness or unboundedness.

## Coverage forensic audit status

The accepted coverage/size forensic audit is preserved at commit `ac9a9ccad027cde05488abb633e66cc02f87cc46`. It verifies direct evaluation of `W_N(alpha0)`, all 120 design cells, Monte Carlo uncertainty, distributional diagnostics, paired-estimator comparisons, and consistency with the canonical final summaries.

## Calibration status

The preserved 100-replication instrument-strength calibration is the primary descriptive calibration evidence. Its joint first-stage F-statistic and partial R-squared are descriptive strength diagnostics, not formal weak-instrument classification thresholds.

## Reporting constraint

All tables and figures under `thesis_extension/reporting/` must be deterministic transformations or subsets of the frozen inputs. Full machine-readable tables are retained even when a compact main-text candidate is proposed.
