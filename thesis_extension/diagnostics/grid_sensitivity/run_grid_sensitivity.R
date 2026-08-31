script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[1L]), winslash = "/", mustWork = TRUE)
diagnostic_dir <- dirname(script_path)
extension_root <- normalizePath(file.path(diagnostic_dir, "..", ".."), winslash = "/", mustWork = TRUE)
repo_root <- normalizePath(file.path(extension_root, ".."), winslash = "/", mustWork = TRUE)
args <- commandArgs(trailingOnly = TRUE)

smoke <- "--smoke" %in% args
execute_diagnostic <- "--execute-diagnostic" %in% args
if (smoke == execute_diagnostic) {
  stop("Specify exactly one mode: --smoke or --execute-diagnostic. No diagnostic RNG work has started.")
}

source(file.path(extension_root, "environment", "check_author_environment.R"))
environment_result <- assert_author_environment(extension_root, write_outputs = FALSE)

git_output <- function(arguments) {
  out <- tryCatch(system2("git", arguments, stdout = TRUE, stderr = TRUE), error = identity)
  if (inherits(out, "error") || (!is.null(attr(out, "status")) && attr(out, "status") != 0L)) {
    stop("Git protection check failed before RNG work: ", paste(out, collapse = "\n"))
  }
  out
}
git_sha <- git_output(c("-C", shQuote(repo_root), "rev-parse", "HEAD"))[1L]
protected_author <- git_output(c("-C", shQuote(repo_root), "diff", "--name-only", "--", "simulation", "Empirical_work"))
protected_extension <- git_output(c("-C", shQuote(repo_root), "diff", "--name-only", "--",
                                    "thesis_extension/config", "thesis_extension/src", "thesis_extension/final"))
if (length(protected_author) || length(protected_extension)) {
  stop("Protected source or final-production files are modified. No diagnostic RNG work has started.")
}

source(file.path(diagnostic_dir, "grid_sensitivity_config.R"))
source(file.path(extension_root, "src", "dgp_kappa.R"))
source(file.path(extension_root, "src", "author_oracle_wrapper.R"))
source(file.path(extension_root, "src", "author_full_wrapper.R"))
source(file.path(extension_root, "src", "author_bc_dml_wrapper.R"))
source(file.path(diagnostic_dir, "grid_sensitivity_functions.R"))

cfg <- grid_sensitivity_config
replications <- if (smoke) 1L else cfg$diagnostic_replications
tau_values <- if (smoke) 0.50 else cfg$tau_values
kappa_values <- if (smoke) c(1.00, 0.10) else cfg$kappa_values
output_dir <- file.path(diagnostic_dir, "output")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

exact_command <- paste(shQuote("C:/Program Files/R/R-3.4.3/bin/x64/Rscript.exe"),
                       shQuote(script_path), if (smoke) "--smoke" else "--execute-diagnostic")
warnings_seen <- character()
if (identical(Sys.getenv("LC_CTYPE"), "C.UTF-8") &&
    !identical(Sys.getlocale("LC_CTYPE"), "C.UTF-8")) {
  warnings_seen <- c(warnings_seen, "R and worker startup: Setting LC_CTYPE=C.UTF-8 failed; R used the C locale")
}
start_time <- Sys.time()
set.seed(cfg$seed)
out <- withCallingHandlers(
  run_grid_sensitivity(cfg, replications, tau_values, kappa_values),
  warning = function(w) {
    warnings_seen <<- c(warnings_seen, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
end_time <- Sys.time()
out$summary <- summarize_ranges(out$range_metrics)
out$expansion_summary <- summarize_expansions(out$expansion_metrics)

file_map <- c(
  profiles = "grid_sensitivity_profiles.csv",
  range_metrics = "grid_sensitivity_range_metrics.csv",
  expansion_metrics = "grid_sensitivity_expansion_metrics.csv",
  failures = "grid_sensitivity_failures.csv",
  summary = "grid_sensitivity_summary.csv",
  expansion_summary = "grid_sensitivity_expansion_summary.csv")
for (name in names(file_map)) write.csv(out[[name]], file.path(output_dir, file_map[name]), row.names = FALSE)

expected_profiles <- replications * length(tau_values) * length(kappa_values) * length(cfg$estimators) * 121L
expected_ranges <- replications * length(tau_values) * length(kappa_values) * length(cfg$estimators) * 3L
expected_expansions <- replications * length(tau_values) * length(kappa_values) * length(cfg$estimators)
profile_groups <- interaction(out$profiles$replication, out$profiles$tau, out$profiles$kappa,
                              out$profiles$estimator, drop = TRUE)
checks <- c(
  environment_guard_passed = TRUE,
  profile_row_count = nrow(out$profiles) == expected_profiles,
  range_metric_row_count = nrow(out$range_metrics) == expected_ranges,
  expansion_metric_row_count = nrow(out$expansion_metrics) == expected_expansions,
  every_wide_profile_has_121_points = all(table(profile_groups) == 121L),
  A1_has_41_points = all(out$range_metrics$number_grid_points[out$range_metrics$range == "A_1_-1_3"] == 41L),
  A2_has_81_points = all(out$range_metrics$number_grid_points[out$range_metrics$range == "A_2_-3_5"] == 81L),
  A3_has_121_points = all(out$range_metrics$number_grid_points[out$range_metrics$range == "A_3_-5_7"] == 121L),
  shared_W_values_identical_by_single_profile_subsetting = validate_single_wide_profile_subsetting(out$profiles, cfg),
  critical_value_is_qchisq_95_df2 = identical(cfg$critical_value, qchisq(0.95, df = 2)),
  protected_author_files_unchanged = length(protected_author) == 0L,
  protected_extension_files_unchanged = length(protected_extension) == 0L,
  failure_scope_validation = validate_failure_scope(cfg),
  profile_schema = identical(names(out$profiles), c("n", "replication", "tau", "kappa", "estimator", "a", "W", "accepted")),
  range_metric_schema = identical(names(out$range_metrics), c("n", "replication", "tau", "kappa", "estimator", "range", "range_lower", "range_upper", "range_width", "number_grid_points", "profile_failed", "grid_accepted_set_measure", "accepted_grid_share", "number_accepted_grid_points", "left_boundary_accepted", "right_boundary_accepted", "either_boundary_accepted", "both_boundaries_accepted", "all_grid_points_accepted")),
  expansion_metric_schema = identical(names(out$expansion_metrics), c("n", "replication", "tau", "kappa", "estimator", "L_A1", "L_A2", "L_A3", "added_measure_A1_to_A2", "added_measure_A2_to_A3", "accepted_share_A1", "accepted_share_A2", "accepted_share_A3", "boundary_A1", "boundary_A2", "boundary_A3", "all_grid_A1", "all_grid_A2", "all_grid_A3")),
  failure_schema = identical(names(out$failures), c("n", "replication", "tau", "kappa", "estimator", "a", "stage", "error_message")),
  summary_schema = identical(names(out$summary), c("n", "tau", "kappa", "estimator", "range", "total_replications", "successful_profiles", "failed_profiles", "median_grid_accepted_set_measure", "mean_grid_accepted_set_measure", "median_accepted_grid_share", "mean_accepted_grid_share", "median_number_accepted_grid_points", "mean_number_accepted_grid_points", "left_boundary_acceptance_rate", "right_boundary_acceptance_rate", "either_boundary_acceptance_rate", "both_boundaries_acceptance_rate", "all_grid_points_acceptance_rate")),
  expansion_summary_schema = identical(names(out$expansion_summary), c("n", "tau", "kappa", "estimator", "total_replications", "median_added_measure_A1_to_A2", "mean_added_measure_A1_to_A2", "median_added_measure_A2_to_A3", "mean_added_measure_A2_to_A3", "median_accepted_share_A1", "mean_accepted_share_A1", "median_accepted_share_A2", "mean_accepted_share_A2", "median_accepted_share_A3", "mean_accepted_share_A3", "boundary_acceptance_rate_A1", "boundary_acceptance_rate_A2", "boundary_acceptance_rate_A3", "all_grid_acceptance_rate_A1", "all_grid_acceptance_rate_A2", "all_grid_acceptance_rate_A3")),
  summary_row_count = nrow(out$summary) == length(tau_values) * length(kappa_values) * length(cfg$estimators) * 3L,
  expansion_summary_row_count = nrow(out$expansion_summary) == length(tau_values) * length(kappa_values) * length(cfg$estimators),
  full_R300_not_started = smoke)

if (smoke) {
  report <- c(
    "POST-FINAL GRID-SENSITIVITY SMOKE TEST REPORT",
    paste("Git SHA:", git_sha),
    "Environment result: AUTHOR R343 ENVIRONMENT CHECK: PASS",
    paste("Exact command:", exact_command),
    paste("Start time:", format(start_time, tz = "UTC", usetz = TRUE)),
    paste("End time:", format(end_time, tz = "UTC", usetz = TRUE)),
    paste("Profile rows:", nrow(out$profiles)),
    paste("Range metric rows:", nrow(out$range_metrics)),
    paste("Expansion metric rows:", nrow(out$expansion_metrics)),
    paste("Failures:", nrow(out$failures)),
    paste("Warnings:", if (length(warnings_seen)) paste(unique(warnings_seen), collapse = " | ") else "none"),
    "Validation checks:",
    paste(names(checks), ifelse(checks, "PASS", "FAIL"), sep = ": "),
    paste("Conclusion:", if (all(checks)) "PASS" else "FAIL"))
  writeLines(report, file.path(diagnostic_dir, "SMOKE_TEST_REPORT.txt"))
} else {
  writeLines(capture.output(sessionInfo()), file.path(output_dir, "grid_sensitivity_sessionInfo.txt"))
  config_lines <- c("seed=675", "workers=5", "n=1000", "replications=300",
                    paste("tau_values=", paste(cfg$tau_values, collapse = ","), sep = ""),
                    paste("kappa_values=", paste(cfg$kappa_values, collapse = ","), sep = ""),
                    paste("estimators=", paste(cfg$estimators, collapse = ","), sep = ""),
                    "wide_grid=[-5,7]", "h=0.1", paste("critical_value=", cfg$critical_value, sep = ""))
  writeLines(config_lines, file.path(output_dir, "grid_sensitivity_config.txt"))
  script_files <- c(file.path(diagnostic_dir, "grid_sensitivity_config.R"),
                    file.path(diagnostic_dir, "grid_sensitivity_functions.R"), script_path)
  manifest <- c(paste("Git SHA:", git_sha), paste(names(tools::md5sum(script_files)), tools::md5sum(script_files), sep = " | "),
                "Existing author code and final-run code were not modified.")
  writeLines(manifest, file.path(output_dir, "grid_sensitivity_manifest.txt"))
  log_lines <- c(paste("Exact command:", exact_command), paste("Start time:", start_time), paste("End time:", end_time),
                 paste("Wall-clock seconds:", as.numeric(difftime(end_time, start_time, units = "secs"))),
                 paste("Profile rows:", nrow(out$profiles)), paste("Range metric rows:", nrow(out$range_metrics)),
                 paste("Expansion metric rows:", nrow(out$expansion_metrics)), paste("Failures:", nrow(out$failures)),
                 paste("Warnings:", if (length(warnings_seen)) paste(unique(warnings_seen), collapse = " | ") else "none"))
  writeLines(log_lines, file.path(output_dir, "grid_sensitivity_run_log.txt"))
}

if (!all(checks)) stop("Grid-sensitivity validation failed: ", paste(names(checks)[!checks], collapse = ", "))
cat(if (smoke) "GRID-SENSITIVITY SMOKE TEST: PASS\n" else "GRID-SENSITIVITY FULL DIAGNOSTIC: PASS\n")
