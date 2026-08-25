script_arg <- grep("^--file=", commandArgs(), value = TRUE)
root <- normalizePath(file.path(dirname(normalizePath(sub("^--file=", "", script_arg[1]))), ".."))
source(file.path(root, "environment", "check_author_environment.R"))
assert_author_environment(root, write_outputs = FALSE)
output_dir <- Sys.getenv("THESIS_VALIDATION_OUTPUT_DIR", unset = file.path(root, "validation"))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
source(file.path(root, "src", "metrics.R"))

critical <- qchisq(.95, df = 2)
W <- rep(1, 41)
W[17] <- NA_real_
profile <- list(W = W, alpha_grid = seq(-1, 3, by = .1), alpha_hat = 0.6)
diagnostics <- grid_profile_diagnostics(profile, critical, .1)
alpha_hat <- if (diagnostics$profile_failed) NA_real_ else profile$alpha_hat

template <- data.frame(
  n = 500L, tau = .5, kappa = 1, estimator = "Artificial-Test",
  bias = c(0, NA), absolute_error = c(0, NA), squared_error = c(0, NA),
  covered = c(TRUE, TRUE), rejected_true = c(FALSE, FALSE),
  grid_accepted_set_measure = c(4, NA), accepted_grid_share = c(1, NA),
  number_accepted_grid_points = c(41, NA),
  left_boundary_accepted = c(TRUE, NA), right_boundary_accepted = c(TRUE, NA),
  either_boundary_accepted = c(TRUE, NA), both_boundaries_accepted = c(TRUE, NA),
  all_41_grid_points_accepted = c(TRUE, NA),
  profile_failed = c(FALSE, TRUE), coverage_failed = c(FALSE, FALSE),
  failed = c(FALSE, TRUE))
summary <- aggregate_results(template)

failed_candidate_rejection <- classify_rejection(NA_real_, critical)
stopifnot(
  isTRUE(diagnostics$profile_failed), is.na(diagnostics$accepted[17]),
  is.na(diagnostics$grid_accepted_set_measure), is.na(diagnostics$accepted_grid_share),
  is.na(diagnostics$left_boundary_accepted), is.na(diagnostics$number_accepted_grid_points),
  is.na(alpha_hat), is.na(failed_candidate_rejection),
  summary$total_replications == 2L, summary$successful_profiles == 1L,
  summary$failed_profiles == 1L, summary$successful_coverage_evaluations == 2L,
  summary$failed_coverage_evaluations == 0L)

result <- data.frame(
  profile_failed = diagnostics$profile_failed,
  failed_candidate_accepted = diagnostics$accepted[17],
  failed_candidate_rejected = failed_candidate_rejection,
  alpha_hat = alpha_hat,
  grid_accepted_set_measure = diagnostics$grid_accepted_set_measure,
  accepted_grid_share = diagnostics$accepted_grid_share,
  total_replications = summary$total_replications,
  successful_profiles = summary$successful_profiles,
  failed_profiles = summary$failed_profiles,
  stringsAsFactors = FALSE)
write.csv(result, file.path(output_dir, "artificial_failure_policy_validation.csv"), row.names = FALSE)
cat("Artificial failure policy: PASS\n")
print(result)
