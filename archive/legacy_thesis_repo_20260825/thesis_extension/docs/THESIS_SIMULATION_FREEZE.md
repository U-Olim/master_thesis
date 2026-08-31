# Thesis Simulation Freeze

Freeze date: 2026-08-24  
Freeze provenance commit: `c35fe12da4caa22afc9bcecb79d260d3e4d293de`  
Final master seed: `20260820`  
Monte Carlo replications: `500` for n=500 and `500` for n=1000  
Final operational workers per sample-size job: `12`  
BC pivotal simulations per penalty: `R_BC=1000`

## A. Research question

The final Monte Carlo studies how weakening the excluded-instrument contribution to treatment affects finite-sample point estimation, test inversion within a prespecified parameter space, null rejection, and power for Oracle-GMM, Full-GMM, and DML-IVQR across sample sizes and quantiles.

## B. Replicated author baseline

The authors' Table 2 is the primary Monte Carlo baseline. The authors' Table 3 Belloni-Chernozhukov (BC) implementation supplies the theoretical pivotal penalty used by the thesis DML estimator. The permanent kappa=1 regression fixture established exact treatment identity and, on 10 common datasets, exact full-profile equivalence for Oracle-GMM, Full-GMM, matched-RNG Table-2 DML-CV, and conditional matched-penalty author/thesis DML-BC. Every required comparison passed with maximum W difference zero and no warnings or errors.

## C. Frozen DGP

For each replication and sample size, draw the authors' primitives in the original order: `(u, epsilon)`, `x`, `z1`, `z2`, `v1`, `v2`; draw the thesis-only `w` afterward. Controls and observed instruments follow the authors' Table 2 code. Treatment is

`d(kappa) = kappa * (z1 + z2) + sqrt(2 * (1 - kappa^2)) * w + epsilon`

and `D(kappa) = pnorm(d(kappa))`, with `kappa = (1.00, 0.50, 0.25, 0.10)`. The same original primitives and `w` are reused across kappa within a replication. At kappa=1 the construction remains exactly identical to the authors' treatment.

## D. Frozen estimators

- Oracle-GMM uses the validated Table 2 criterion with `X1:X10`.
- Full-GMM uses the same validated criterion with `X1:X100`.
- DML-IVQR uses the current grid-invariant `dml_wn_profile_bc()` implementation, not Table-2 `cv.hqreg`.

The score, covariance, and W_N formulas are unchanged. Oracle/Full use `M %*% solve(J)`. DML uses square-root density weighting and `hdm::rlasso(..., post=FALSE)`.

The only structural modification to the authors' Monte Carlo DGP is instrument strength through kappa and its variance-preserving auxiliary shock w. Oracle-GMM and Full-GMM retain the authors' Table 2 implementation. DML-IVQR uses the authors' theoretical Belloni-Chernozhukov penalty specification, with the validated fixed pivotal draw within each dataset and quantile for reproducible test inversion. Coverage, power, and confidence-region measures are additional evaluations of the same W_N statistic.

The executable thesis DML is not the authors' Table 2 CV implementation. Its beta penalty is the author-provided theoretical BC choice from Table 3.

## E. Frozen nuisance and tuning implementation

Density is literally `dnorm(e, mean(e), var(e))`; `akj()` is not used. One BC pivotal penalty is generated for every replication–n–tau combination with `R_BC=1000`, `c=2`, and `alpha=0.1`. That exact vector is reused for every alpha and all four kappa values. No BC Uniforms are redrawn across alpha.

## F. Parameter space and grids

Sample sizes are `(500, 1000)` and quantiles are `(0.10, 0.25, 0.50, 0.75, 0.90)`. The point grid is `seq(-1, 3, by=0.10)` and the first/smallest `which.min` minimizer is used without refinement. The prespecified inference parameter space is `A=[-1,3]`, evaluated on `seq(-1, 3, by=0.05)`. There is no interpolation, smoothing, crossing refinement, local adaptation, or automatic expansion.

Automatic expansion was rejected because pre-final thesis pilots found acceptance persisting far into the tails and potentially disconnected acceptance. Finite expansion therefore did not provide a meaningful unrestricted boundary.

## G. Coverage, power, and accepted-set definitions

The critical value is `qchisq(0.95, df=2)` and acceptance is `W_N(a) <= critical value`. Coverage and size are evaluated directly at `alpha_true(tau)=1+qnorm(tau)`, never inferred from the CR grid. Power is evaluated directly at `alpha_true + Delta`, with `Delta=(-0.50,-0.25,0.25,0.50)`.

The accepted-set measure within A is the frozen trapezoidal binary measure `sum_j 0.05 * (I_j + I_{j+1}) / 2`. It equals four when every grid point is accepted and zero when none is accepted. Missing required W evaluations produce `NA`, not rejection. Full-A acceptance means only that the test fails to reject every candidate on the 81-point grid in prespecified A.

"CR length" is the grid-based accepted-set measure within prespecified A=[-1,3], not the length of an unrestricted confidence region on R.

## H. Common random numbers

Within a replication, one primitive dataset is generated for each n and reused across every tau. Its original primitives and `w` are reused across all kappa, and estimators receive the same constructed dataset. One BC penalty per n–tau is reused across kappa and alpha. Primitives are never regenerated separately by estimator.

## I. Final seed, Monte Carlo R, and execution

The final design uses `R_MC=500` separately for n=500 and n=1000, matching the authors' Monte Carlo replication count. This is distinct from `R_BC=1000`, the number of pivotal Uniform simulations used for each BC penalty. `FINAL_MASTER_SEED=20260820`; replication `rep_id` explicitly calls `set.seed(20260820 + rep_id)`, giving seeds 20260821 through 20261320. Scheduling and restart order cannot affect substantive draws. The complete ID/seed mapping is a required output for each sample-size job.

The two final jobs use 12 workers operationally and write separate checkpoints and outputs under `checkpoints/n500`, `checkpoints/n1000`, `output/n500`, and `output/n1000`. To retain the already validated combined n=500-then-n=1000 random-number design, the n=1000 job deterministically advances past the n=500 primitives and five n=500 BC pivotal draws before generating n=1000 primitives. Validated estimator profiles consume no RNG.

Expected per-sample-size counts are 30,000 raw rows, 120,000 power rows, 60 performance-summary cells, 240 power-summary cells, and 2,500 BC penalty vectors. Combined counts are 60,000 raw rows, 240,000 power rows, 120 performance-summary cells, 480 power-summary cells, and 5,000 BC penalty vectors.

## J. Reporting conventions

Every n–tau–kappa–estimator cell reports mean signed error `mean(alpha_hat-alpha_true)`, authors-style bias `mean(alpha_true-alpha_hat)` as the primary Bias comparison, MAE, RMSE, coverage, size/null rejection, coverage MCSE, median and mean accepted-set measure within A, full-A and boundary-contact rates, point-boundary rates, and numerical-failure rate. Power cells report rejection probability and binomial MCSE. Raw results retain full numeric precision.

## K. No post-result revision

No tuning, grid, estimator, DGP, penalty, density, score, inference, or reporting-design choice in this freeze will be revised after the final Monte Carlo results are observed.

## Frozen-choice provenance

| Frozen choice | Provenance |
|---|---|
| Original DGP, Oracle-GMM, Full-GMM, Table-2 baseline | Authors' Table 2 |
| BC pivotal penalty formula and constants | Authors' Table 3 and paper theory |
| Variance-preserving kappa extension and common `w` | Pre-final thesis design and kappa pilots |
| Current grid-invariant BC reuse policy | Paper theory, authors' Table 3, and numerical reproducibility decision |
| Density, delta, score, covariance, W_N | Validated author replication code |
| A, point grid, CR grid, trapezoidal accepted-set measure | Frozen inference config and pre-final thesis pilots |
| Direct truth and false-value evaluation | Frozen inference config and numerical reproducibility decision |
| No automatic expansion | Pre-final tail/grid pilots |
| Replication-specific seed rule and atomic checkpoints | Numerical reproducibility decision |

## Frozen software environment

The final run uses R 3.4.3 with quantreg 5.34, hdm 0.2.0, hqreg 1.4, mvtnorm 1.0-6, and doSNOW 1.0.16. Packages must not be installed or updated for the final run.
