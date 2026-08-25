# Final author-faithful pre-run audit

## 1. Author source integrity

1. **Original author files modified?** No. `git diff -- simulation` is empty.
2. **Substantive author source differences?** Zero. Every tracked R/r source file under `simulation/` and `Empirical_work/` has canonical content identical to its pristine `HEAD` blob.
3. **Raw versus canonical hashes:** Windows working-tree CRLF makes the raw SHA-256 differ from the pristine LF Git blob. After byte-level CRLF-to-LF normalization, all three critical canonical hashes match. Exact raw and canonical hashes and the procedure are in `audit/AUTHOR_SOURCE_INTEGRITY.md`. The earlier raw evidence remains in `audit/AUTHOR_SOURCE_HASHES.txt`.

`ORIGINAL AUTHOR SOURCE CODE CHANGES = 0`.

## 2. Frozen environment and RNG

4. **R:** `R version 3.4.3 (2017-11-30)`, explicit executable `C:\Program Files\R\R-3.4.3\bin\x64\Rscript.exe`.
5. **Packages:** quantreg 5.34; hdm 0.2.0; hqreg 1.4; mvtnorm DESCRIPTION 1.0-6 (`packageVersion()` 1.0.6); doSNOW 1.0.16. The strict isolated-library guard passed.
6. **Seed:** final runner contains the sole production `set.seed(extension_config$seed)`, with `seed=675`. There are no replication/candidate/worker seeds, `clusterSetRNGStream`, doRNG, RNGkind changes, or other RNG stabilization in `src/` or `final/`.
7. **Workers:** `Node/core=5`; no 12-worker configuration exists.
8. **Parallel backend:** theoretical DML evaluation uses `snow::makeCluster(core)`, `doSNOW::registerDoSNOW(cl)`, and `on.exit(snow::stopCluster(cl), add=TRUE)`. Foreach loads `c("hqreg","quantreg","hdm")`, preserves input order, and executes each requested point once.
9. **BC parameters:** `R_BC=1000`, `c=2`, `alpha=.1`, unchanged scaling and intercept treatment.
10. **Fresh pivotal draws:** `lambda_BC_author()` still calls `runif(n*R)` on every invocation. There is no caching or penalty reuse. Consecutive no-reset calls produced different intercept penalties: 60.50898, 59.76552, and 61.13236.

## 3. Frozen DGP and estimators

11. **Kappa formula:** `d=kappa*(z1+z2)+sqrt(2*(1-kappa^2))*w+epsilon`; `D=pnorm(d)`.
12. **Common random numbers:** original primitives are drawn in author order, `w` is drawn afterward, and the same `u, epsilon, X, z1, z2, v1, v2, w` object is reused across all four kappa values within a replication. Outcome construction is the author-type-preserving matrix expression `y=1+D+X%*%b+u*D`, with no `drop()` or vector coercion.
13. **Kappa=1 equivalence:** maximum latent-treatment difference `0`; maximum transformed-treatment difference `0`.
14. **Oracle equivalence:** maximum absolute W difference over all 41 candidates `0`.
15. **Full equivalence:** maximum absolute W difference over all 41 candidates `0`.
16. **DML equivalence:** at `a=-1,1,3`, maximum penalty-vector, beta, and W differences were all `0` after controlled RNG resets.
17. **Cross-fitting:** none. The Table 3 theoretical `hdm_naive(...,POST=FALSE)` logic remains the source of the estimator wrapper.
18. **Density:** unchanged author convention `dnorm(e,mean(e),var(e))`; DML retains its square-root diagonal weighting.

## 4. Frozen inference design

19. **Grid:** fixed `seq(-1,3,by=.1)`, exactly 41 ordered candidates, no interpolation, refinement, adaptation, or expansion. Base `which.min()` retains first-candidate tie breaking.
20. **Power alternatives:** direct evaluations at `alpha_true + Delta` for `Delta={-1,-.5,-.25,.25,.5,1}`.
21. **Coverage:** direct evaluation at exact `alpha_true=1+qnorm(tau)`, independent of profile completeness. A finite W_true produces covered/rejected_true; a failed or non-finite W_true produces NA for both.
22. **Numerical failures:** any failed/non-finite grid candidate flags the complete profile failed. Raw successful candidates and candidate failure records remain, but alpha_hat, error metrics, accepted-set summaries, shares, boundary diagnostics, and accepted-point count are NA. Failed candidates are neither accepted nor rejected. Coverage and each power alternative remain independently usable when their direct evaluations succeed. Summaries report total, successful, and failed profile/coverage/power denominators.
23. **Primary informativeness statistic:** `median_grid_accepted_set_measure`, computed only over complete successful profiles. The mean is retained as `mean_grid_accepted_set_measure`; median and mean accepted-grid shares are also reported. The object is named the median grid-based accepted-set measure within prespecified `A=[-1,3]`, never unrestricted or continuous CR length.

The artificial one-NA test passed: profile_failed TRUE; failed-candidate accepted/rejected both NA; alpha_hat NA; accepted-set measure/share NA; and aggregate denominators correctly showed 2 total, 1 successful, and 1 failed profile without changing coverage denominators.

## 5. Final R 3.4.3 validation

24. **Smoke counts:** n=500, two replications, tau `.10,.50,.90`, four kappa values, three estimators; 72 profiles, 2,952 grid rows, and 432 power rows.
25. **Smoke failures:** zero profile failures, zero coverage failures, zero power-evaluation failures, and zero failure-log rows. Every aggregate cell reports two total/two successful/zero failed profiles and coverage evaluations; every power cell reports two successful/zero failed evaluations.
26. **Final R=500 executions:** **NO**. R 4.6.1 was rejected before RNG work; an injected quantreg 5.35 DESCRIPTION response was rejected; correct R 3.4.3 passed the environment guard and was then stopped by the separate final authorization guard. No `final/output` directory exists.
27. **Recommendation:** all five requested fidelity corrections and all required historical validations passed. The implementation is ready for review and subsequent separately authorized final execution.

The repeated Windows `C.UTF-8` startup warning is non-fatal and leaves the historical session in locale `C`.
