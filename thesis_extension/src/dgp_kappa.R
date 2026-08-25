generate_kappa_primitives <- function(n, p = 100L) {
  sigma <- matrix(c(1, 0.3, 0.3, 1), ncol = 2)
  epsilon_pair <- mvtnorm::rmvnorm(n = n, mean = c(0, 0), sigma = sigma)
  x <- matrix(rnorm(n * p), ncol = p)
  X <- matrix(pnorm(x), ncol = p)
  z <- matrix(cbind(rnorm(n, 0, 1), rnorm(n, 0, 1)), ncol = 2)
  v1 <- rnorm(n, 0, 1)
  v2 <- rnorm(n, 0, 1)

  # The only added primitive is drawn after every original primitive draw.
  w <- rnorm(n, 0, 1)
  list(
    u = epsilon_pair[, 1], epsilon = epsilon_pair[, 2],
    epsilon_pair = epsilon_pair, x = x, X = X,
    z1 = z[, 1], z2 = z[, 2], v1 = v1, v2 = v2, w = w
  )
}

make_kappa_dataset <- function(primitives, kappa, s = 7L) {
  with(primitives, {
    d <- kappa * (z1 + z2) + sqrt(2 * (1 - kappa^2)) * w + epsilon
    D <- pnorm(d)
    Z1 <- z1 + v1 + X[, 2] + X[, 3] + X[, 4]
    Z2 <- z2 + v2 + X[, 7] + X[, 8] + X[, 9] + X[, 10]
    Z <- matrix(cbind(Z1, Z2), nrow = length(D))
    b <- matrix(c(rep(5, s), rep(0, ncol(X) - s)))
    y <- 1 + D + X %*% b + u * D
    list(y = y, D = D, d = d, X = X, X1 = X[, 1:10], Z = Z,
         kappa = kappa, primitives = primitives)
  })
}

alpha_true <- function(tau) 1 + qnorm(tau)
