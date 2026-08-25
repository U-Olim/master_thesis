# Author implementation audit

Audit basis: executable source at commit `81b8f9864f1737823ab3b31e5d7fdee6d4c7c0fd`. The initial `git status --short` was empty. The governing executable files and hashes are recorded in `AUTHOR_SOURCE_HASHES.txt`.

## Table 2 (`simulation/main.R`, `simulation/fun_callback.R`)

- Seed: `set.seed(2019)` before creating the cluster.
- Workers: `NumberOfCluster <- 8`; PSOCK/SNOW via `makeCluster` and `%dopar%`.
- Replications and shown sample size: `iter=500`, `sample_size=500` (the repository also contains result files for 1000).
- Quantiles: `.10, .25, .50, .75, .90`.
- Every estimator uses `alpha=seq(-1,3,length=41)`.
- Oracle (`exact`) is `gmm_quantile(y,D,X1,Z,tau)` with `X1=X[,1:10]`. At every candidate it fits `rq(y-alpha*D ~ X)`, including the formula intercept. It computes `e`, then exactly `dnorm(e,mean(e),var(e))`. For residualization it forms `M=t(Z)%*%F%*%X`, `J=t(X)%*%F%*%X`, `delta=M%*%solve(J)`, and `psi=t(Z)-delta%*%t(X)`. Thus this residualization deliberately uses no intercept even though the quantile regression has one.
- Full-GMM (`fullgmm`) calls exactly the same function with all 100 columns of `X`.
- Table 2 DML (`hdm`) uses five-fold `cv.hqreg`, not the theoretical penalty selected for the thesis extension. It takes the coefficient column at `lambda.min`, does no post-Lasso outcome refit, uses the unchanged density convention, square-roots the diagonal density matrix, and residualizes each instrument with `hdm::rlasso(weight*Z_j ~ weight*X, post=FALSE)`. The raw residual is `Z_j-cbind(1,X)%*%coefficients`.
- In all cases the score uses `indicator=ifelse(e<=0,1,0)`, `g=psi%*%(tau-indicator)`, covariance matrix `psi%*%diag(diag((tau-indicator)%*%t(tau-indicator)))%*%t(psi)`, and `W_N=t(g)%*%solve(covariance)%*%g`. There is no explicit division by `n` in either `g` or covariance.
- Point selection is base R `which.min`, hence the first grid point wins an exact tie.
- No cross-fitting is used in Table 2.
- Random draws occur inside each `%dopar%` replication in this order: bivariate `rmvnorm` errors, `n*p` normal `x`, two normal `z` columns, the `Z1` noise, then the `Z2` noise. No PSOCK-worker RNG stream is explicitly fixed.

## Table 3 (`simulation/simulation_quantreg/quantreg_Belloni _cv.r`)

- Seed: `set.seed(675)`.
- Workers: `Node=5`. Each estimator call creates and stops its own five-worker SNOW cluster.
- Replications and shown sample size: `iter=500`, `sample_size=1000`.
- Quantiles: `.25, .50, .75`.
- Candidate grids are `seq(-.5,1.5,length=21)`, `seq(0,2,length=21)`, and `seq(1,3,length=21)` respectively. The thesis changes only this evaluation design to the frozen common 41-point `[-1,3]` grid.
- Oracle `gmm()` uses `rq(y-a*D ~ X)` and a square-root density weighted linear regression `lm(sqrt(F)*Z_j ~ sqrt(F)*X)` for each instrument. It is not the Table 2 Oracle selected by the thesis specification; thesis Oracle/Full wrappers therefore copy Table 2 exactly.
- The theoretical DML call is `hdm_naive(..., l1_norm=FALSE, POST=FALSE)` with default `penalty=TRUE`. Consequently the executable branch is `rq(y-a*D ~ X, tau=tau, method="lasso", lambda=lambda.BC(...))`, no post-Lasso outcome refit, followed by `rlasso(..., post=FALSE)` for instrument residualization. There is no cross-fitting. The separately defined `hdm_crossfit()` is not called.
- `lambda.BC(X,R=1000,tau=.5,c=2,alpha=.1)` computes column RMS values `sigs=sqrt(mean(X_j^2))`, draws a fresh `matrix(runif(n*R),n)` on every invocation, forms the pivotal maximum, takes its `1-alpha=.9` empirical quantile, and returns `c * quantile * sqrt(tau*(1-tau)) * c(1,sigs)`. Thus `R_BC=1000`, `c=2`, and the code's alpha/gamma tail setting is `alpha=.1`. The first element penalizes the intercept with scale one. No penalty or pivotal draw is cached.
- Density, weighted residualization, score, covariance, `W_N`, and `which.min` behavior are exactly as described above for Table 2 DML.
- The theoretical DML's `rq` method is exactly `method="lasso"`. The selected final setting is `POST=FALSE`; `rlasso` receives `post=FALSE`.
- Table 3 generates structural data sequentially in the master R process, in the same primitive order as Table 2. Pivotal Uniform draws occur inside candidate workers. Neither `clusterSetRNGStream`, `doRNG`, nor manual worker seeds are used.
- The reported Table 3 bias convention is exactly `mean(alpha_true-alpha_hat)`, i.e. `Bias = alpha_true - alpha_hat`. The extension also stores `signed_error=alpha_hat-alpha_true`.

## Preserved unusual conventions

The extension does not correct `dnorm(e, mean(e), var(e))`; in particular, the third positional argument remains the normal standard-deviation argument even though the authors pass the sample variance. It also preserves the covariance construction, raw-instrument residual definition, intercept behavior, fresh stochastic penalties, grid-order dependence, and absence of cross-fitting.
