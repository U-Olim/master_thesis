run_extension <- function(sample_size, replications, tau_values, kappa_values,
                          estimators = c("Oracle-GMM", "Full-GMM", "DML-IVQR-BC"),
                          core = 5L, output_dir = NULL) {
  cfg <- extension_config
  results <- list(); power <- list(); profiles <- list(); failures <- list()
  add_failure <- function(replication, tau, kappa, estimator, a, stage, message) {
    failures[[length(failures) + 1L]] <<- data.frame(
      n = sample_size, replication = replication, tau = tau, kappa = kappa,
      estimator = estimator, a = a, stage = stage, error_message = message)
  }
  safe_gmm_profile <- function(dat, controls, tau) {
    W <- rep(NA_real_, length(cfg$alpha_grid)); errs <- list()
    for (j in seq_along(cfg$alpha_grid)) {
      attempt <- tryCatch(author_gmm_candidate(dat$y, dat$D, controls, dat$Z, tau, cfg$alpha_grid[j]), error = identity)
      if (inherits(attempt, "error")) errs[[length(errs) + 1L]] <- list(a = cfg$alpha_grid[j], message = conditionMessage(attempt)) else W[j] <- attempt
    }
    list(alpha_grid = cfg$alpha_grid, W = W,
         alpha_hat = if (all(!is.finite(W))) NA_real_ else cfg$alpha_grid[which.min(W)], errors = errs)
  }
  safe_direct <- function(fun, points, labels, replication, tau, kappa, estimator) {
    out <- rep(NA_real_, length(points))
    for (j in seq_along(points)) {
      attempt <- tryCatch(fun(points[j]), error = identity)
      if (inherits(attempt, "error")) add_failure(replication, tau, kappa, estimator, points[j], labels[j], conditionMessage(attempt)) else out[j] <- attempt
    }
    out
  }

  for (replication in seq_len(replications)) {
    primitives <- generate_kappa_primitives(sample_size, cfg$p)
    for (kappa in kappa_values) {
      dat <- make_kappa_dataset(primitives, kappa, cfg$s)
      for (tau in tau_values) for (estimator in estimators) {
        if (estimator == "Oracle-GMM") {
          profile <- safe_gmm_profile(dat, dat$X1, tau)
          candidate <- function(a) author_gmm_candidate(dat$y, dat$D, dat$X1, dat$Z, tau, a)
        } else if (estimator == "Full-GMM") {
          profile <- safe_gmm_profile(dat, dat$X, tau)
          candidate <- function(a) author_gmm_candidate(dat$y, dat$D, dat$X, dat$Z, tau, a)
        } else if (estimator == "DML-IVQR-BC") {
          profile <- tryCatch(author_bc_profile(dat$y, dat$D, dat$X, dat$Z, tau, cfg$alpha_grid, core), error = identity)
          if (inherits(profile, "error")) {
            add_failure(replication, tau, kappa, estimator, NA_real_, "profile", conditionMessage(profile))
            profile <- list(alpha_grid = cfg$alpha_grid, W = rep(NA_real_, 41), alpha_hat = NA_real_, errors = list())
          }
          candidate <- NULL
        } else stop("Unknown estimator: ", estimator)
        for (err in profile$errors) add_failure(replication, tau, kappa, estimator, err$a, "profile_candidate", err$message)
        diag <- grid_profile_diagnostics(profile, cfg$critical_value, cfg$grid_step)
        truth <- alpha_true(tau)
        direct_points <- c(truth, truth + cfg$power_delta)
        direct_labels <- c("true_value", paste0("power_delta_", cfg$power_delta))
        if (estimator == "DML-IVQR-BC") {
          direct <- tryCatch(author_bc_evaluate(dat$y, dat$D, dat$X, dat$Z, tau, direct_points, core), error = identity)
          if (inherits(direct, "error")) {
            add_failure(replication, tau, kappa, estimator, NA_real_, "direct_points", conditionMessage(direct))
            direct_W <- rep(NA_real_, length(direct_points))
          } else {
            direct_W <- direct$W
            for (err in direct$errors) {
              idx <- match(err$a, direct_points)
              add_failure(replication, tau, kappa, estimator, err$a, direct_labels[idx], err$message)
            }
          }
        } else {
          direct_W <- safe_direct(candidate, direct_points, direct_labels, replication, tau, kappa, estimator)
        }
        em <- estimation_metrics(profile$alpha_hat, truth)
        failed <- any(!is.finite(profile$W)) || !is.finite(direct_W[1])
        results[[length(results) + 1L]] <- data.frame(
          n = sample_size, replication = replication, tau = tau, kappa = kappa, estimator = estimator,
          alpha_true = truth, alpha_hat = profile$alpha_hat, signed_error = em["signed_error"],
          bias = em["bias"], absolute_error = em["absolute_error"], squared_error = em["squared_error"],
          W_true = direct_W[1], covered = direct_W[1] <= cfg$critical_value,
          rejected_true = direct_W[1] > cfg$critical_value,
          grid_accepted_set_measure = diag$grid_accepted_set_measure,
          accepted_grid_share = diag$accepted_grid_share,
          left_boundary_accepted = diag$left_boundary_accepted,
          right_boundary_accepted = diag$right_boundary_accepted,
          either_boundary_accepted = diag$either_boundary_accepted,
          both_boundaries_accepted = diag$both_boundaries_accepted,
          all_41_grid_points_accepted = diag$all_41_grid_points_accepted,
          number_accepted_grid_points = diag$number_accepted_grid_points, failed = failed)
        power[[length(power) + 1L]] <- data.frame(
          n = sample_size, replication = replication, tau = tau, kappa = kappa, estimator = estimator,
          Delta = cfg$power_delta, a_false = truth + cfg$power_delta, W_false = direct_W[-1],
          rejection = direct_W[-1] > cfg$critical_value,
          false_acceptance = 1 - as.integer(direct_W[-1] > cfg$critical_value))
        profiles[[length(profiles) + 1L]] <- data.frame(
          n = sample_size, replication = replication, tau = tau, kappa = kappa,
          estimator = estimator, a = cfg$alpha_grid, W = profile$W, accepted = diag$accepted)
      }
    }
  }
  empty_failures <- data.frame(
    n = integer(), replication = integer(), tau = numeric(), kappa = numeric(),
    estimator = character(), a = numeric(), stage = character(), error_message = character())
  out <- list(results = do.call(rbind, results), power = do.call(rbind, power),
              profiles = do.call(rbind, profiles),
              failures = if (length(failures)) do.call(rbind, failures) else empty_failures)
  out$summary <- aggregate_results(out$results)
  out$power_summary <- aggregate_power(out$power)
  if (!is.null(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    for (name in names(out)) utils::write.csv(out[[name]], file.path(output_dir, paste0(name, ".csv")), row.names = FALSE)
  }
  out
}
