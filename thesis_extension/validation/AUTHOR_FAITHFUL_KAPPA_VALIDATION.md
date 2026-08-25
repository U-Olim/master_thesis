# Author-faithful kappa-extension validation

## Repository protection and executable audit

1. Repository commit: `81b8f9864f1737823ab3b31e5d7fdee6d4c7c0fd`.
2. Author source hashes: `main.R` = `1F838AF3E2580BFD4A6BA66F6050EFD1A62AAF71B358D8B83EA3F00B061EF839`; `fun_callback.R` = `90B5E4B0A278A4B3AA90A1899FA009B1B2145E00DFC7B9C430F7EF00F2AFB866`; `quantreg_Belloni _cv.r` = `8E508215CE31B2EAFE6B85004011BABCA0862FAA944071EDBAE3F4DEBB3D5D3B`.
3. Author code left untouched: initial status was clean; final hashes equal the initial hashes; `git diff --name-only -- simulation` is empty. All implementation and generated validation files are below `thesis_extension/`.
4. Seeds in executable source: Table 2 uses `2019`; Table 3 uses `675`. The extension final runner uses only Table 3's `675` and introduces no replication or worker seed.
5. Workers in executable source: Table 2 uses 8; Table 3 uses `Node=5`. All theoretical-BC profile and direct-evaluation clusters in the extension use 5.
6. BC penalty: exact `R=1000`, `c=2`, `alpha=.1`, RMS scaling, intercept scale one, `rq(...,method="lasso")`, and a fresh `runif(n*R)` matrix per call. There is no caching or reuse across candidates or kappa values and no PSOCK RNG stream setup.
7. Density convention: exact `dnorm(e,mean(e),var(e))`; it is intentionally not corrected. Oracle/Full use its diagonal matrix; DML uses the square root of that matrix.
8. Oracle: Table 2 `gmm_quantile` with `X[,1:10]`, formula-intercept quantile regression, no intercept in `M`, `J`, or `psi=t(Z)-delta*t(X)`, and the author score/covariance/W calculation.
9. Full: the identical Table 2 GMM calculation with all 100 controls.
10. DML-BC: Table 3 `hdm_naive` theoretical branch with `l1_norm=FALSE`, `POST=FALSE`, `penalty=TRUE`; quantreg Lasso; square-root-density weighted instrument residualization; `hdm::rlasso(...,post=FALSE)`; raw residual `Z-cbind(1,X)*delta`; and unchanged score/covariance/W.
11. No cross-fitting: confirmed. Table 3 defines a separate cross-fit function but the theoretical calls used by the extension call `hdm_naive`, not that function.

The exact score is `g=psi %*% (tau-I(e<=0))`. The covariance is `psi %*% diag(diag((tau-I)%*%t(tau-I))) %*% t(psi)`. The statistic is `W_N=t(g)%*%solve(covariance)%*%g`; no extra `n` scaling is introduced. Base R `which.min` supplies first/minimum-candidate tie breaking.

## DGP and design validation

12. Kappa DGP: `d_kappa=kappa*(z1+z2)+sqrt(2*(1-kappa^2))*w+epsilon`, `D_kappa=pnorm(d_kappa)`. Original primitives are drawn in author order; `v1` and `v2` replace the two original inline instrument-noise draws without reordering; only then is `w` drawn. One primitive object is reused across all four kappa values within a replication.
13. Kappa-one equivalence: with a fixed supplied primitive object, both `max(abs(d_original-d_kappa1))` and `max(abs(D_original-D_kappa1))` were exactly `0`.
14. Diagnostic moments from 100,000 observations:

| kappa | Var(d) | Cov(z1,d) | Cov(z2,d) | Cov(u,d) |
|---:|---:|---:|---:|---:|
| 1.00 | 3.003950 | 0.997285 | 0.994838 | 0.298116 |
| 0.50 | 3.003721 | 0.494916 | 0.496777 | 0.288956 |
| 0.25 | 3.007386 | 0.245715 | 0.249097 | 0.287395 |
| 0.10 | 3.008811 | 0.096402 | 0.100631 | 0.286775 |

These are close to the targets `Var(d)=3`, relevance covariance `kappa`, and endogeneity covariance `.3`. A separate tiny calibration at `n=500,1000` produced declining descriptive first-stage F statistics and partial R-squared values as kappa fell; exact values are in `calibration/tiny_calibration.csv`. These are descriptive, not IVQR identification statistics.

The structural truths saved/verified are `-0.28155157`, `0.32551025`, `1`, `1.67448975`, and `2.28155157` for tau `.10,.25,.50,.75,.90`.

## Estimator equivalence and behavior

15. Oracle W-profile equivalence on one identical `n=500`, kappa-one dataset at tau `.5`, over all 41 fixed candidates: maximum absolute difference `0`.
16. Full W-profile equivalence under the same conditions: maximum absolute difference `0`.
17. Controlled DML equivalence at `a=-1,1,3`: after resetting the identical RNG state before reference and extension calls, maximum differences in the 101-element BC penalty, coefficient vector, and W were all `0` at every candidate.
18. Fresh BC validation without RNG resets at `a=-1,-.9,-.8` gave intercept penalties `60.50898`, `59.76552`, and `61.13236`. Variation is expected and retained. Full summaries are in `bc_fresh_draw_validation.csv`.
19. Smoke test: exactly `n=500`, tau `.10,.50,.90`, kappa `1,.5,.25,.1`, all three estimators, two replications, and five DML workers. It produced 72 result rows, 2,952 fixed-grid rows, 432 power rows, point estimates, direct W at truth, six direct false-point W values, coverage/size, grid measures, shares, all boundary flags, raw profiles, aggregate metrics, empirical-power summaries, and failure output.
20. Numerical failures: zero in the 72-profile smoke test. All 72 alpha estimates and all 72 W-at-truth values were finite. Boundary contact, when present, was retained as information rather than counted as failure.
21. Unavoidable environment difference: validation ran under R 4.6.1 with `quantreg 6.1`, `hdm 0.3.2`, `mvtnorm 1.4.2`, `doSNOW 1.0.20`, and `foreach 1.5.2`; the repository README names R 3.4.3 and older packages (`quantreg 5.34`, `hdm 0.2.0`, `mvtnorm 1.0.6`, `doSNOW 1.0.16`). R 3.4.3 is installed locally but lacks `hdm`, so it could not run the complete validation. Algorithmic equivalence was nevertheless exact against independent author-equivalent reference calculations in the available environment. Windows emitted harmless `C.UTF-8` locale warnings when PSOCK workers started.
22. No full Monte Carlo was run. The final runner guard was tested and refused execution without `--execute-final`.
23. Recommendation: the code is ready for review and for an environment/version review on each laptop before authorizing R=500. Do not launch final jobs until package-version choice and output storage are accepted.

## Fixed-grid inferential outputs and failures

The accepted-set quantity is explicitly

`sum_{j=1}^{40} 0.1 * (I_j + I_{j+1}) / 2`,

where `I_j=1[W_N(a_j)<=qchisq(.95,2)]`. It is named **grid-based accepted-set measure within prespecified A=[-1,3]**, lies in `[0,4]`, permits disconnected accepted sets, and is never described as unrestricted confidence-region length. The accepted grid-point share is `sum(I_j)/41`.

Each failure record contains sample size, replication, tau, kappa, estimator, candidate/evaluation point, stage, and message. There is no redraw, substitute replication, or repair algorithm. A profile is flagged failed if any grid W or its direct W-at-truth is non-finite. Aggregation retains finite replication-level quantities with `na.rm=TRUE` and reports numerical-failure counts; power summaries likewise count non-finite false-point W values. This policy must remain visible alongside results rather than silently treating partial failures as rejections or acceptances.

## RNG and restart assessment

The DGP uses the master RNG after one `set.seed(675)`. DML grid and truth/power calculations use fresh five-worker clusters with no explicit worker stream, matching the author's PSOCK behavior and preventing pivotal draws from consuming the master DGP stream. Because worker RNG states are not explicitly controlled, a restart-safe checkpoint system cannot in general reproduce an uninterrupted run unless complete process and RNG states are captured at exact call boundaries. No checkpoint/resume system was added.

## Final-run safeguards

`final/run_final.R` accepts either `--sample-size 500` or `--sample-size=500` (likewise 1000), fixes `R=500`, tau/kappa/grid/workers from the frozen config, and separates output into `final/output/n500` and `final/output/n1000`. It refuses to run unless the explicit `--execute-final` flag is present. No final output directory was created during validation.
