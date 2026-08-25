author_gmm_candidate <- function(y, D, X, Z, tau, a, return_details = FALSE) {
  beta_fit <- quantreg::rq(y - (a * D) ~ X, tau = tau)
  beta <- matrix(beta_fit$coefficients, nrow = 1)
  e <- y - a * D - cbind(1, X) %*% t(beta)
  distribition <- diag(c(dnorm(e, mean(e), var(e))))
  M <- t(Z) %*% distribition %*% X
  J <- t(X) %*% distribition %*% X
  delta <- M %*% solve(J)
  psi <- t(Z) - delta %*% t(X)
  indicator <- ifelse(e <= 0, 1, 0)
  g <- psi %*% (tau - indicator)
  invsigma <- solve(psi %*% diag(diag((tau - indicator) %*% t(tau - indicator))) %*% t(psi))
  W <- drop(t(g) %*% invsigma %*% g)
  if (return_details) list(W = W, beta = beta, e = drop(e), psi = psi) else W
}

author_gmm_profile <- function(y, D, X, Z, tau, alpha_grid) {
  W <- vapply(alpha_grid, function(a) author_gmm_candidate(y, D, X, Z, tau, a), numeric(1))
  list(alpha_hat = alpha_grid[which.min(W)], W = W, alpha_grid = alpha_grid)
}

author_oracle_profile <- function(y, D, X1, Z, tau, alpha_grid) {
  author_gmm_profile(y, D, X1, Z, tau, alpha_grid)
}
