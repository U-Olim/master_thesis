grid_profile_diagnostics <- function(profile, critical_value, h = 0.1) {
  profile_failed <- any(!is.finite(profile$W))
  accepted <- ifelse(is.finite(profile$W), profile$W <= critical_value, NA)
  if (profile_failed) {
    return(list(
      profile_failed = TRUE, accepted = accepted,
      grid_accepted_set_measure = NA_real_, accepted_grid_share = NA_real_,
      left_boundary_accepted = NA, right_boundary_accepted = NA,
      either_boundary_accepted = NA, both_boundaries_accepted = NA,
      all_41_grid_points_accepted = NA, number_accepted_grid_points = NA_integer_
    ))
  }
  n_accepted <- sum(accepted)
  list(
    profile_failed = FALSE, accepted = accepted,
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

classify_rejection <- function(W, critical_value) {
  ifelse(is.finite(W), W > critical_value, NA)
}

classify_coverage <- function(W, critical_value) {
  ifelse(is.finite(W), W <= critical_value, NA)
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
  finite_mean <- function(z) if (any(!is.na(z))) mean(z, na.rm = TRUE) else NA_real_
  finite_median <- function(z) if (any(!is.na(z))) median(z, na.rm = TRUE) else NA_real_
  groups <- split(x, interaction(x$n, x$tau, x$kappa, x$estimator, drop = TRUE))
  do.call(rbind, lapply(groups, function(g) data.frame(
    n = g$n[1], tau = g$tau[1], kappa = g$kappa[1], estimator = g$estimator[1],
    total_replications = nrow(g),
    successful_profiles = sum(!g$profile_failed), failed_profiles = sum(g$profile_failed),
    successful_coverage_evaluations = sum(!g$coverage_failed),
    failed_coverage_evaluations = sum(g$coverage_failed),
    Bias = finite_mean(g$bias), MAE = finite_mean(g$absolute_error),
    RMSE = sqrt(finite_mean(g$squared_error)),
    Coverage = finite_mean(g$covered), Size = finite_mean(g$rejected_true),
    median_grid_accepted_set_measure = finite_median(g$grid_accepted_set_measure),
    mean_grid_accepted_set_measure = finite_mean(g$grid_accepted_set_measure),
    median_accepted_grid_share = finite_median(g$accepted_grid_share),
    mean_accepted_grid_share = finite_mean(g$accepted_grid_share),
    mean_number_accepted_grid_points = finite_mean(g$number_accepted_grid_points),
    left_boundary_acceptance_rate = finite_mean(g$left_boundary_accepted),
    right_boundary_acceptance_rate = finite_mean(g$right_boundary_accepted),
    either_boundary_acceptance_rate = finite_mean(g$either_boundary_accepted),
    both_boundaries_acceptance_rate = finite_mean(g$both_boundaries_accepted),
    all_41_acceptance_rate = finite_mean(g$all_41_grid_points_accepted),
    numerical_failures = sum(g$failed)
  )))
}

aggregate_power <- function(x) {
  finite_mean <- function(z) if (any(!is.na(z))) mean(z, na.rm = TRUE) else NA_real_
  groups <- split(x, interaction(x$n, x$tau, x$kappa, x$estimator, x$Delta, drop = TRUE))
  do.call(rbind, lapply(groups, function(g) data.frame(
    n = g$n[1], tau = g$tau[1], kappa = g$kappa[1], estimator = g$estimator[1],
    Delta = g$Delta[1], total_replications = nrow(g),
    successful_power_evaluations = sum(!g$power_evaluation_failed),
    failed_power_evaluations = sum(g$power_evaluation_failed),
    power = finite_mean(g$rejected_false),
    false_acceptance = finite_mean(g$false_acceptance),
    numerical_failures = sum(g$power_evaluation_failed)
  )))
}
