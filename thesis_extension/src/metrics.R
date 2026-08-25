grid_profile_diagnostics <- function(profile, critical_value, h = 0.1) {
  accepted <- is.finite(profile$W) & profile$W <= critical_value
  n_accepted <- sum(accepted)
  list(
    accepted = accepted,
    grid_accepted_set_measure = sum(h * (accepted[-length(accepted)] + accepted[-1]) / 2),
    accepted_grid_share = n_accepted / length(accepted),
    left_boundary_accepted = accepted[1],
    right_boundary_accepted = accepted[length(accepted)],
    either_boundary_accepted = accepted[1] || accepted[length(accepted)],
    both_boundaries_accepted = accepted[1] && accepted[length(accepted)],
    all_41_grid_points_accepted = all(accepted),
    number_accepted_grid_points = n_accepted
  )
}

evaluate_direct_points <- function(candidate_function, points, critical_value) {
  W <- vapply(points, candidate_function, numeric(1))
  data.frame(a = points, W = W, rejected = W > critical_value)
}

estimation_metrics <- function(alpha_hat, truth) {
  c(signed_error = alpha_hat - truth, bias = truth - alpha_hat,
    absolute_error = abs(alpha_hat - truth), squared_error = (alpha_hat - truth)^2)
}

aggregate_results <- function(x) {
  groups <- split(x, interaction(x$n, x$tau, x$kappa, x$estimator, drop = TRUE))
  do.call(rbind, lapply(groups, function(g) data.frame(
    n = g$n[1], tau = g$tau[1], kappa = g$kappa[1], estimator = g$estimator[1],
    Bias = mean(g$bias, na.rm = TRUE), MAE = mean(g$absolute_error, na.rm = TRUE),
    RMSE = sqrt(mean(g$squared_error, na.rm = TRUE)),
    Coverage = mean(g$covered, na.rm = TRUE), Size = mean(g$rejected_true, na.rm = TRUE),
    grid_accepted_set_measure = mean(g$grid_accepted_set_measure, na.rm = TRUE),
    accepted_grid_share = mean(g$accepted_grid_share, na.rm = TRUE),
    mean_number_accepted_grid_points = mean(g$number_accepted_grid_points, na.rm = TRUE),
    left_boundary_acceptance_rate = mean(g$left_boundary_accepted, na.rm = TRUE),
    right_boundary_acceptance_rate = mean(g$right_boundary_accepted, na.rm = TRUE),
    either_boundary_acceptance_rate = mean(g$either_boundary_accepted, na.rm = TRUE),
    both_boundaries_acceptance_rate = mean(g$both_boundaries_accepted, na.rm = TRUE),
    all_41_acceptance_rate = mean(g$all_41_grid_points_accepted, na.rm = TRUE),
    numerical_failures = sum(g$failed)
  )))
}

aggregate_power <- function(x) {
  groups <- split(x, interaction(x$n, x$tau, x$kappa, x$estimator, x$Delta, drop = TRUE))
  do.call(rbind, lapply(groups, function(g) data.frame(
    n = g$n[1], tau = g$tau[1], kappa = g$kappa[1], estimator = g$estimator[1],
    Delta = g$Delta[1], power = mean(g$rejection, na.rm = TRUE),
    false_acceptance = mean(g$false_acceptance, na.rm = TRUE),
    numerical_failures = sum(!is.finite(g$W_false))
  )))
}
