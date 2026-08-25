norm2n_author <- function(z) sqrt(mean(z^2))

lambda_BC_author <- function(X, R = 1000, tau = 0.5, c = 2, alpha = 0.1) {
  n <- nrow(X)
  sigs <- apply(X, 2, norm2n_author)
  U <- matrix(runif(n * R), n)
  R <- (t(X) %*% (tau - (U < tau))) / (sigs * sqrt(tau * (1 - tau)))
  r <- apply(abs(R), 2, max)
  c * quantile(r, 1 - alpha) * sqrt(tau * (1 - tau)) * c(1, sigs)
}

author_bc_candidate <- function(y, D, X, Z, tau, a, return_details = FALSE) {
  lambda <- lambda_BC_author(X, R = 1000, tau = tau, c = 2, alpha = 0.1)
  lasso <- quantreg::rq(y - a * D ~ X, tau = tau, method = "lasso", lambda = lambda)
  beta <- matrix(lasso$coefficients, ncol = 1)
  e <- y - a * D - cbind(1, X) %*% beta
  distribition <- diag(c(dnorm(e, mean(e), var(e))))
  distribition <- sqrt(distribition)
  psi <- matrix(0, nrow = length(Z[1, ]), ncol = length(Z[, 1]))
  for (j in seq_len(length(Z[1, ]))) {
    delta_fit <- hdm::rlasso(distribition %*% Z[, j] ~ distribition %*% X, post = FALSE)
    delta <- matrix(delta_fit$coefficients, ncol = 1)
    delta <- Z[, j] - cbind(1, X) %*% delta
    psi[j, ] <- t(delta)
  }
  indicator <- ifelse(e <= 0, 1, 0)
  g <- psi %*% (tau - indicator)
  invsigma <- solve(psi %*% diag(diag((tau - indicator) %*% t(tau - indicator))) %*% t(psi))
  W <- drop(t(g) %*% invsigma %*% g)
  if (return_details) list(W = W, lambda = lambda, beta = beta, e = drop(e), psi = psi) else W
}

author_bc_evaluate <- function(y, D, X, Z, tau, points, core = 5L) {
  cl <- snow::makeCluster(core)
  on.exit(snow::stopCluster(cl), add = TRUE)
  doSNOW::registerDoSNOW(cl)
  `%dopar%` <- foreach::`%dopar%`
  values <- foreach::foreach(
    a = points, .inorder = TRUE, .errorhandling = "pass",
    .packages = c("hqreg", "quantreg", "hdm"),
    .export = c("author_bc_candidate", "lambda_BC_author", "norm2n_author")
  ) %dopar% author_bc_candidate(y, D, X, Z, tau, a)
  W <- vapply(values, function(value) if (inherits(value, "error")) NA_real_ else as.numeric(value), numeric(1))
  errors <- lapply(which(!is.finite(W)), function(i) list(
    a = points[i], message = if (inherits(values[[i]], "error")) conditionMessage(values[[i]]) else "non-finite W"))
  list(W = W, points = points, errors = errors)
}

author_bc_profile <- function(y, D, X, Z, tau, alpha_grid, core = 5L) {
  evaluated <- author_bc_evaluate(y, D, X, Z, tau, alpha_grid, core)
  list(alpha_hat = if (any(!is.finite(evaluated$W))) NA_real_ else alpha_grid[which.min(evaluated$W)],
       W = evaluated$W, alpha_grid = alpha_grid, errors = evaluated$errors)
}
