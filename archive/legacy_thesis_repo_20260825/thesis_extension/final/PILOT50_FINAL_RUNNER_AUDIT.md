# Final Minimal-Difference Audit

Compared implementations:

- Authors' Table 2: `simulation/main.R` and `simulation/fun_callback.R`
- Authors' Table 3 BC: `simulation/simulation_quantreg/quantreg_Belloni_cv.r`
- Thesis final: `thesis_extension/final/run_inference_final.R` and sourced frozen thesis functions

Starting provenance commit: `c35fe12da4caa22afc9bcecb79d260d3e4d293de`.

## Executable-feature audit

| Feature | Authors baseline | Thesis final | Classification | Justification |
|---|---|---|---|---|
| n | Table 2 design evaluated at n=500 and n=1000 | Separate n=500 and n=1000 jobs | OPERATIONAL/COMPUTATIONAL ONLY | Same two sample sizes; separation only isolates checkpoints and outputs. |
| Monte Carlo R | `iter=500` per sample size | `R_MC=500` per sample size | OPERATIONAL/COMPUTATIONAL ONLY | Exact author replication count; no 1,000-replication-per-n run. |
| workers | Table 2 uses 8 doSNOW workers | 12 PSOCK workers | OPERATIONAL/COMPUTATIONAL ONLY | User-selected scheduling only; complete replications are worker tasks. |
| tau | .10, .25, .50, .75, .90 | .10, .25, .50, .75, .90 | OPERATIONAL/COMPUTATIONAL ONLY | No executable difference. |
| p | 100 | 100 | OPERATIONAL/COMPUTATIONAL ONLY | No executable difference. |
| DGP primitive distributions | Bivariate normal errors with covariance .3; normal x, z1, z2, v1, v2 | Same author primitives, plus independent standard-normal w | KAPPA-RELATED DGP CHANGE | w is the approved variance-preserving strength extension. |
| primitive draw order | errors, x, z1, z2, v1, v2 | Same original order, then w | KAPPA-RELATED DGP CHANGE | Every original draw precedes the added w draw. |
| D formula | `pnorm(z1+z2+epsilon)` | `pnorm(kappa*(z1+z2)+sqrt(2*(1-kappa^2))*w+epsilon)` | KAPPA-RELATED DGP CHANGE | Sole structural DGP modification; kappa=1 identity is exact and permanently validated. |
| w | absent | one independent N(0,1) draw reused across kappa | KAPPA-RELATED DGP CHANGE | Required auxiliary shock preserves treatment-index variance. |
| Z equations | Author Z1 and Z2 equations | Identical | OPERATIONAL/COMPUTATIONAL ONLY | No executable difference. |
| Y equation | `1+D+X%*%b+epsilon1*D` | Identical conditional on D_kappa | KAPPA-RELATED DGP CHANGE | Y mechanics are unchanged; only approved treatment changes with kappa. |
| oracle controls | X1:X10 | X1:X10 | OPERATIONAL/COMPUTATIONAL ONLY | No executable difference. |
| full controls | X1:X100 | X1:X100 | OPERATIONAL/COMPUTATIONAL ONLY | No executable difference. |
| point alpha grid | `seq(-1,3,length=41)` | `seq(-1,3,by=.10)` | OPERATIONAL/COMPUTATIONAL ONLY | Bit-identical increasing grid, validated at kappa=1. |
| Oracle beta | unpenalized `rq(y-alpha*D ~ X10)` | Same sourced validated implementation | OPERATIONAL/COMPUTATIONAL ONLY | No penalty or estimator change. |
| Full beta | unpenalized `rq(y-alpha*D ~ X100)` | Same sourced validated implementation | OPERATIONAL/COMPUTATIONAL ONLY | No regularization or estimator change. |
| DML beta | Table 2 uses `cv.hqreg`; author Table 3 supplies BC-lasso alternative | `quantreg::rq(..., method="lasso", lambda=lambda_BC)` | AUTHOR-PROVIDED BC PENALTY CHOICE | Thesis final deliberately uses the authors' theoretical Table 3 BC choice, not Table 2 CV. |
| BC formula | Table 3 `lambda.BC`, R_BC=1000, c=2, alpha=.1 | Literal validated `bc_pivotal_lambda`, same constants | AUTHOR-PROVIDED BC PENALTY CHOICE | Formula and mathematical constants are author-provided and unchanged. |
| BC draw timing | Table 3 calls the pivotal draw inside candidate-alpha evaluation | One draw per replication-n-tau, reused across alpha and kappa | BC REPRODUCIBILITY RULE | Penalty depends only on X and tau; fixed draw permits reproducible test inversion without changing the formula. |
| density | `dnorm(e,mean(e),var(e))` | Identical | OPERATIONAL/COMPUTATIONAL ONLY | The authors' third argument is preserved literally. |
| delta | Oracle/Full `M%*%solve(J)`; DML square-root-density weighted residualization | Identical sourced implementations | OPERATIONAL/COMPUTATIONAL ONLY | No residualization change. |
| score | Authors' score | Identical | OPERATIONAL/COMPUTATIONAL ONLY | No executable difference. |
| covariance | Authors' covariance | Identical | OPERATIONAL/COMPUTATIONAL ONLY | No executable difference. |
| W_N | Authors' quadratic criterion | Identical | OPERATIONAL/COMPUTATIONAL ONLY | Full profiles were validated exactly at kappa=1. |
| alpha_hat | first `which.min` on increasing grid | Same first/smallest successful minimizer | OPERATIONAL/COMPUTATIONAL ONLY | Same point-estimation rule; failure bookkeeping does not alter successful estimates. |
| coverage | not reported by original Table 2 runner | direct W_N at exact alpha_true | ADDITIONAL PERFORMANCE EVALUATION | Same W_N statistic on the same datasets; not a separate simulation. |
| power | not reported by original Table 2 runner | direct W_N at alpha_true plus four frozen deltas | ADDITIONAL PERFORMANCE EVALUATION | Same W_N statistic and datasets; no grid approximation. |
| CR grid | not reported by original Table 2 runner | `seq(-1,3,by=.05)` | ADDITIONAL PERFORMANCE EVALUATION | Prespecified thesis test-inversion evaluation only. |
| parameter space | point-search interval [-1,3] | inference space A=[-1,3] | ADDITIONAL PERFORMANCE EVALUATION | No expansion or unrestricted-CR claim. |
| failure handling | Table 2 has no selection-preserving redraw rule | record fixed-draw numerical status; never redraw | OPERATIONAL/COMPUTATIONAL ONLY | Required unbiased accounting; estimates are not modified. |
| RNG/seeds | Table 2 `set.seed(2019)` before doSNOW; no explicit worker RNG mapping | master 20260820 plus rep_id; n=1000 job preserves combined-order RNG position | OPERATIONAL/COMPUTATIONAL ONLY | Distribution and within-dataset draw order are unchanged; explicit mapping makes scheduling/restart reproducible. |
| checkpoints | none in original Table 2 runner | one compatible atomic checkpoint per replication and sample size | OPERATIONAL/COMPUTATIONAL ONLY | Persistence only; invalid checkpoints stop and valid ones are never overwritten. |
| output aggregation | author result matrices and summary tables | separate full-precision raw, power, summary, diagnostics, seed, session, and manifest outputs | OPERATIONAL/COMPUTATIONAL ONLY | Reporting/persistence only; all measures use the same replication outputs. |

UNAPPROVED DIFFERENCES: **0**

## Random-number audit

- Authors' Table 2 seed: `set.seed(2019)` in `simulation/main.R` before creating the doSNOW cluster. The code does not assign deterministic replication-specific worker streams, so worker scheduling/backend RNG state is not mapped to replication IDs.
- Authors' Table 3 seed: `set.seed(675)` in `quantreg_Belloni_cv.r`; its parallel foreach computations likewise do not define a replication-ID seed map, and its BC penalty is redrawn within candidate-alpha evaluation.
- Pilot50 seed behavior: `set.seed(20260818)`, sample 50 distinct integer seeds, then explicitly reset to the assigned seed inside each replication. Manual worker allocation therefore does not change a replication draw.
- Prepared final-run behavior: `rep_seed=20260820+rep_id`. This deterministic replication architecture is retained. Both sample-size jobs use the same ID/seed map; n=1000 advances through the n=500 primitives and five n=500 BC draws so splitting the jobs does not silently move the validated n=1000 draw stream.
- Estimator profiles are asserted not to consume RNG. The fixed two-rep validation must pass this assertion for the n=1000 advancement rule to be accepted.

## Count audit

| Output | n=500 job | n=1000 job | Combined |
|---|---:|---:|---:|
| Raw estimator rows | 30,000 | 30,000 | 60,000 |
| Power rows | 120,000 | 120,000 | 240,000 |
| Performance-summary cells | 60 | 60 | 120 |
| Power-summary cells | 240 | 240 | 480 |
| BC penalty vectors | 2,500 | 2,500 | 5,000 |

`R_MC=500` is the Monte Carlo replication count for each sample size. `R_BC=1000` is the pivotal-Uniform simulation count inside each BC penalty. They are distinct and are asserted separately.
