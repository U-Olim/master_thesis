script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[1L]), winslash = "/", mustWork = TRUE)
diagnostic_dir <- dirname(script_path)
extension_root <- normalizePath(file.path(diagnostic_dir, "..", ".."), winslash = "/", mustWork = TRUE)
repo_root <- normalizePath(file.path(extension_root, ".."), winslash = "/", mustWork = TRUE)
args <- commandArgs(trailingOnly = TRUE)

if ("--execute-diagnostic" %in% args) {
  stop("--execute-diagnostic is disabled: the one-shot design was superseded by the pre-specified two-stage diagnostic. No RNG work has started.")
}
valid_modes <- c("--smoke-stage1", "--execute-stage1", "--execute-stage2")
selected <- intersect(args, valid_modes)
if (length(selected) != 1L || length(args) != 1L) {
  stop("Specify exactly one supported mode: --smoke-stage1, --execute-stage1, or --execute-stage2. No RNG work has started.")
}
mode <- selected[1L]

source(file.path(extension_root, "environment", "check_author_environment.R"))
environment_result <- assert_author_environment(extension_root, write_outputs = FALSE)

git_capture <- function(arguments) {
  out <- tryCatch(system2("git", c("-C", shQuote(repo_root), arguments),
                          stdout = TRUE, stderr = TRUE), error = identity)
  if (inherits(out, "error") || (!is.null(attr(out, "status")) && attr(out, "status") != 0L)) {
    stop("Git protection check failed before RNG work: ", paste(out, collapse = "\n"))
  }
  out
}
git_quiet <- function(arguments) {
  status <- tryCatch(system2("git", c("-C", shQuote(repo_root), arguments),
                             stdout = FALSE, stderr = FALSE), error = identity)
  !inherits(status, "error") && identical(as.integer(status), 0L)
}
git_sha <- git_capture(c("rev-parse", "HEAD"))[1L]
protected_author <- git_capture(c("diff", "--name-only", "--", "simulation", "Empirical_work"))
protected_extension <- git_capture(c("diff", "--name-only", "--",
                                      "thesis_extension/config", "thesis_extension/src", "thesis_extension/final"))
if (length(protected_author) || length(protected_extension)) {
  stop("Protected source or final-production files are modified. No RNG work has started.")
}
if (mode %in% c("--execute-stage1", "--execute-stage2")) {
  porcelain <- git_capture(c("status", "--porcelain"))
  if (length(porcelain) || !git_quiet(c("diff", "--quiet")) ||
      !git_quiet(c("diff", "--cached", "--quiet"))) {
    stop("Full-stage execution requires a clean Git worktree/index (ignored outputs are allowed). No RNG work has started.")
  }
}

source(file.path(diagnostic_dir, "grid_sensitivity_config.R"))
source(file.path(extension_root, "src", "dgp_kappa.R"))
source(file.path(extension_root, "src", "author_oracle_wrapper.R"))
source(file.path(extension_root, "src", "author_full_wrapper.R"))
source(file.path(extension_root, "src", "author_bc_dml_wrapper.R"))
source(file.path(diagnostic_dir, "grid_sensitivity_functions.R"))
cfg <- grid_sensitivity_config

output_root <- file.path(diagnostic_dir, "output")
smoke_dir <- file.path(output_root, "smoke")
stage1_dir <- file.path(output_root, "stage1")
stage2_dir <- file.path(output_root, "stage2")
trigger_rule <- paste0(
  "Stage 2 is triggered if any kappa in {0.25,0.10}, tau, estimator cell has either ",
  "either_boundary_acceptance_rate >= 0.05 OR outer_band_contact_rate >= 0.10.")
warnings_seen <- character()
if (identical(Sys.getenv("LC_CTYPE"), "C.UTF-8") &&
    !identical(Sys.getlocale("LC_CTYPE"), "C.UTF-8")) {
  warnings_seen <- c(warnings_seen,
                     "R and worker startup: Setting LC_CTYPE=C.UTF-8 failed; R used the C locale")
}
run_with_warnings <- function(expression) withCallingHandlers(
  expression,
  warning = function(w) {
    warnings_seen <<- c(warnings_seen, conditionMessage(w))
    invokeRestart("muffleWarning")
  })

write_config_record <- function(path, run_mode, replications, tau_values, kappa_values) {
  writeLines(c(
    paste("mode=", run_mode, sep = ""), "design=pre-specified two-stage sequential diagnostic",
    paste("seed=", cfg$seed, sep = ""), paste("workers=", cfg$workers, sep = ""),
    paste("n=", cfg$sample_size, sep = ""), paste("replications=", replications, sep = ""),
    paste("tau_values=", paste(tau_values, collapse = ","), sep = ""),
    paste("kappa_values=", paste(kappa_values, collapse = ","), sep = ""),
    paste("estimators=", paste(cfg$estimators, collapse = ","), sep = ""),
    "stage1_grid=[-3,5]", "stage1_grid_points=81", "primary_subset=[-1,3]",
    "stage2_new_tails=[-5,-3.1] U [5.1,7]", "stage2_new_points=40", "h=0.1",
    paste("critical_value=", cfg$critical_value, sep = ""),
    "outer_bands=[-3,-2.5] U [4.5,5]", "boundary_trigger_threshold=0.05",
    "outer_band_trigger_threshold=0.10", trigger_rule), path)
}

write_manifest <- function(path, stage_label, extra_lines = character()) {
  script_files <- c(file.path(diagnostic_dir, "grid_sensitivity_config.R"),
                    file.path(diagnostic_dir, "grid_sensitivity_functions.R"), script_path)
  hashes <- tools::md5sum(script_files)
  writeLines(c(paste("stage=", stage_label, sep = ""), paste("Git SHA:", git_sha),
               paste(names(hashes), hashes, sep = " | "), extra_lines,
               "Existing author code and final-run code were not modified."), path)
}

assert_output_namespace_empty <- function(path, label) {
  if (dir.exists(path) && length(list.files(path, all.files = TRUE, no.. = TRUE))) {
    stop(label, " output namespace is not empty; refusing to overwrite it.")
  }
}

range_schema <- c("n", "replication", "tau", "kappa", "estimator", "range",
                  "range_lower", "range_upper", "range_width", "number_grid_points",
                  "profile_failed", "grid_accepted_set_measure", "accepted_grid_share",
                  "number_accepted_grid_points", "left_boundary_accepted",
                  "right_boundary_accepted", "either_boundary_accepted",
                  "both_boundaries_accepted", "all_grid_points_accepted")

if (mode == "--smoke-stage1") {
  dir.create(smoke_dir, recursive = TRUE, showWarnings = FALSE)
  primitive_dir <- file.path(smoke_dir, "primitives")
  start_time <- Sys.time()
  set.seed(cfg$seed)
  out <- run_with_warnings(run_stage1(cfg, 1L, 0.50, c(1.00, 0.10), primitive_dir))
  end_time <- Sys.time()
  out$summary <- summarize_ranges(out$range_metrics)
  out$expansion_summary <- summarize_stage1_expansions(out$expansion_metrics)
  out$trigger_cells <- trigger_cells_from_expansions(out$expansion_metrics, cfg, 1L)

  smoke_files <- c(
    profiles = "smoke_stage1_profiles.csv", range_metrics = "smoke_stage1_range_metrics.csv",
    expansion_metrics = "smoke_stage1_expansion_metrics.csv", failures = "smoke_stage1_failures.csv",
    primitive_hashes = "smoke_stage1_primitive_hashes.csv", summary = "smoke_stage1_summary.csv",
    expansion_summary = "smoke_stage1_expansion_summary.csv", trigger_cells = "smoke_stage1_trigger_cells.csv")
  for (name in names(smoke_files)) {
    write.csv(out[[name]], file.path(smoke_dir, smoke_files[name]), row.names = FALSE)
  }

  hash_check <- verify_primitive_hashes(out$primitive_hashes, primitive_dir, 1L)
  altered_hashes <- out$primitive_hashes
  first_hash_character <- substring(altered_hashes$hash[1L], 1L, 1L)
  altered_hashes$hash[1L] <- paste0(if (first_hash_character == "0") "1" else "0",
                                    substring(altered_hashes$hash[1L], 2L))
  altered_hash_check <- verify_primitive_hashes(altered_hashes, primitive_dir, 1L)
  loaded_primitive <- readRDS(file.path(primitive_dir, primitive_filename(1L)))
  profile_groups <- interaction(out$profiles$replication, out$profiles$tau,
                                out$profiles$kappa, out$profiles$estimator, drop = TRUE)
  checks <- c(
    environment_guard_passed = TRUE,
    profile_row_count_486 = nrow(out$profiles) == 486L,
    range_metric_row_count_12 = nrow(out$range_metrics) == 12L,
    expansion_row_count_6 = nrow(out$expansion_metrics) == 6L,
    six_stage1_profiles = length(table(profile_groups)) == 6L,
    every_stage1_profile_has_81_points = all(table(profile_groups) == 81L),
    A0_has_41_points = all(out$range_metrics$number_grid_points[out$range_metrics$range == "A_0_-1_3"] == 41L),
    A1_has_81_points = all(out$range_metrics$number_grid_points[out$range_metrics$range == "A_1_-3_5"] == 81L),
    A0_is_only_a_subset_of_A1 = validate_stage1_subsetting(out$profiles, cfg),
    shared_A0_W_values_are_identical = validate_stage1_subsetting(out$profiles, cfg),
    critical_value_is_qchisq_95_df2 = identical(cfg$critical_value, qchisq(0.95, df = 2)),
    outer_band_definition_exact = identical(cfg$outer_band_left, c(-3, -2.5)) &&
      identical(cfg$outer_band_right, c(4.5, 5)),
    trigger_thresholds_exact = identical(cfg$boundary_trigger_threshold, 0.05) &&
      identical(cfg$outer_band_trigger_threshold, 0.10),
    weak_trigger_kappa_exact = identical(cfg$weak_trigger_kappa, c(0.25, 0.10)),
    failure_scope_logic = validate_failure_scope(cfg),
    primitive_save_load_roundtrip = is.list(loaded_primitive) &&
      identical(names(loaded_primitive), c("u", "epsilon", "epsilon_pair", "x", "X",
                                           "z1", "z2", "v1", "v2", "w")),
    primitive_hash_verification = isTRUE(hash_check$ok),
    primitive_hash_mismatch_is_rejected = !isTRUE(altered_hash_check$ok),
    profile_schema = identical(names(out$profiles),
                               c("n", "replication", "tau", "kappa", "estimator", "a", "W", "accepted")),
    range_metric_schema = identical(names(out$range_metrics), range_schema),
    failure_schema = identical(names(out$failures),
                               c("n", "replication", "tau", "kappa", "estimator", "a", "stage", "error_message")),
    protected_author_code_unchanged = length(protected_author) == 0L,
    protected_extension_code_unchanged = length(protected_extension) == 0L,
    stage1_R100_not_started = !dir.exists(stage1_dir) || !length(list.files(stage1_dir, all.files = TRUE, no.. = TRUE)),
    stage2_not_started = !dir.exists(stage2_dir) || !length(list.files(stage2_dir, all.files = TRUE, no.. = TRUE)),
    obsolete_execute_diagnostic_disabled = TRUE)

  exact_command <- paste(shQuote("C:/Program Files/R/R-3.4.3/bin/x64/Rscript.exe"),
                         shQuote(script_path), "--smoke-stage1")
  report <- c(
    "PRE-SPECIFIED TWO-STAGE GRID-SENSITIVITY STAGE-1 SMOKE TEST REPORT",
    paste("Git SHA:", git_sha), "Environment result: AUTHOR R343 ENVIRONMENT CHECK: PASS",
    paste("Exact command:", exact_command), paste("Start time:", format(start_time, tz = "UTC", usetz = TRUE)),
    paste("End time:", format(end_time, tz = "UTC", usetz = TRUE)),
    paste("Profile rows:", nrow(out$profiles)), paste("Range metric rows:", nrow(out$range_metrics)),
    paste("Expansion rows:", nrow(out$expansion_metrics)), paste("Failures:", nrow(out$failures)),
    paste("Warnings:", if (length(warnings_seen)) paste(unique(warnings_seen), collapse = " | ") else "none"),
    paste("Encoded trigger rule:", trigger_rule), "Validation checks:",
    paste(names(checks), ifelse(checks, "PASS", "FAIL"), sep = ": "),
    paste("Conclusion:", if (all(checks)) "PASS" else "FAIL"))
  writeLines(report, file.path(diagnostic_dir, "SMOKE_TEST_REPORT.txt"))
  if (!all(checks)) stop("Stage-1 smoke validation failed: ", paste(names(checks)[!checks], collapse = ", "))
  cat("GRID-SENSITIVITY STAGE-1 SMOKE TEST: PASS\n")
}

if (mode == "--execute-stage1") {
  assert_output_namespace_empty(stage1_dir, "Stage 1")
  dir.create(stage1_dir, recursive = TRUE, showWarnings = FALSE)
  primitive_dir <- file.path(stage1_dir, "primitives")
  start_time <- Sys.time()
  set.seed(cfg$seed)
  out <- run_with_warnings(run_stage1(cfg, cfg$diagnostic_replications,
                                      cfg$tau_values, cfg$kappa_values, primitive_dir))
  end_time <- Sys.time()
  out$summary <- summarize_ranges(out$range_metrics)
  out$expansion_summary <- summarize_stage1_expansions(out$expansion_metrics)
  out$trigger_cells <- trigger_cells_from_expansions(out$expansion_metrics, cfg,
                                                      cfg$diagnostic_replications)
  trigger <- any(out$trigger_cells$cell_triggered)
  stopifnot(nrow(out$profiles) == 364500L, nrow(out$range_metrics) == 9000L,
            nrow(out$expansion_metrics) == 4500L, nrow(out$summary) == 90L,
            nrow(out$expansion_summary) == 45L, nrow(out$trigger_cells) == 30L,
            nrow(out$primitive_hashes) == 100L)
  hash_check <- verify_primitive_hashes(out$primitive_hashes, primitive_dir, 100L)
  if (!isTRUE(hash_check$ok)) stop(hash_check$message)
  stage1_files <- c(
    profiles = "stage1_profiles.csv", range_metrics = "stage1_range_metrics.csv",
    expansion_metrics = "stage1_expansion_metrics.csv", failures = "stage1_failures.csv",
    summary = "stage1_summary.csv", expansion_summary = "stage1_expansion_summary.csv",
    trigger_cells = "stage1_trigger_cells.csv", primitive_hashes = "stage1_primitive_hashes.csv")
  for (name in names(stage1_files)) write.csv(out[[name]], file.path(stage1_dir, stage1_files[name]), row.names = FALSE)
  triggered_cells <- out$trigger_cells[out$trigger_cells$cell_triggered, , drop = FALSE]
  decision_lines <- c(paste("STAGE2_TRIGGER =", if (trigger) "TRUE" else "FALSE"),
                      paste("FROZEN_RULE =", trigger_rule), "TRIGGERED_CELLS:",
                      if (nrow(triggered_cells)) capture.output(print(triggered_cells, row.names = FALSE)) else "none")
  writeLines(decision_lines, file.path(stage1_dir, "stage1_trigger_decision.txt"))
  writeLines(capture.output(sessionInfo()), file.path(stage1_dir, "stage1_sessionInfo.txt"))
  write_config_record(file.path(stage1_dir, "stage1_config.txt"), "stage1", 100L,
                      cfg$tau_values, cfg$kappa_values)
  write_manifest(file.path(stage1_dir, "stage1_manifest.txt"), "stage1",
                 c("primitive_hash_algorithm=MD5", "primitive_count=100"))
  writeLines(c("RUN_STATUS=COMPLETE", paste("Git SHA:", git_sha),
               paste("Start time:", start_time), paste("End time:", end_time),
               paste("Wall-clock seconds:", as.numeric(difftime(end_time, start_time, units = "secs"))),
               "Profile rows: 364500", "Range metric rows: 9000", "Expansion rows: 4500",
               paste("Failures:", nrow(out$failures)),
               paste("Warnings:", if (length(warnings_seen)) paste(unique(warnings_seen), collapse = " | ") else "none"),
               paste("STAGE2_TRIGGER =", if (trigger) "TRUE" else "FALSE"),
               "Stage 2 was not started automatically."), file.path(stage1_dir, "stage1_run_log.txt"))
  cat("GRID-SENSITIVITY STAGE 1: COMPLETE; STAGE 2 NOT STARTED\n")
}

if (mode == "--execute-stage2") {
  required_stage1 <- file.path(stage1_dir, c(
    "stage1_profiles.csv", "stage1_range_metrics.csv", "stage1_expansion_metrics.csv",
    "stage1_failures.csv", "stage1_summary.csv", "stage1_expansion_summary.csv",
    "stage1_trigger_cells.csv", "stage1_trigger_decision.txt", "stage1_sessionInfo.txt",
    "stage1_config.txt", "stage1_run_log.txt", "stage1_manifest.txt", "stage1_primitive_hashes.csv"))
  if (any(!file.exists(required_stage1))) {
    stop("Stage 2 blocked: required Stage-1 outputs are missing. No Stage-2 estimator work has started.")
  }
  decision <- readLines(file.path(stage1_dir, "stage1_trigger_decision.txt"), warn = FALSE)
  if (!any(trimws(decision) == "STAGE2_TRIGGER = TRUE")) {
    stop("Stage 2 blocked: the frozen Stage-1 trigger is not TRUE. No Stage-2 estimator work has started.")
  }
  trigger_cells <- read.csv(file.path(stage1_dir, "stage1_trigger_cells.csv"),
                            stringsAsFactors = FALSE)
  required_trigger_columns <- c(
    "n", "tau", "kappa", "estimator", "total_replications", "failed_profiles",
    "either_boundary_acceptance_count", "either_boundary_acceptance_rate",
    "outer_band_contact_count", "outer_band_contact_rate", "boundary_rule_triggered",
    "outer_band_rule_triggered", "cell_triggered")
  recomputed_boundary <- trigger_cells$either_boundary_acceptance_rate >= cfg$boundary_trigger_threshold
  recomputed_outer <- trigger_cells$outer_band_contact_rate >= cfg$outer_band_trigger_threshold
  if (!identical(names(trigger_cells), required_trigger_columns) || nrow(trigger_cells) != 30L ||
      !all(trigger_cells$kappa %in% cfg$weak_trigger_kappa) ||
      !all(trigger_cells$total_replications == 100L) ||
      !identical(trigger_cells$boundary_rule_triggered, recomputed_boundary) ||
      !identical(trigger_cells$outer_band_rule_triggered, recomputed_outer) ||
      !identical(trigger_cells$cell_triggered, recomputed_boundary | recomputed_outer) ||
      !any(trigger_cells$cell_triggered)) {
    stop("Stage 2 blocked: Stage-1 trigger cells do not reproduce the frozen decision rule. No Stage-2 estimator work has started.")
  }
  run_log <- readLines(file.path(stage1_dir, "stage1_run_log.txt"), warn = FALSE)
  if (!any(trimws(run_log) == "RUN_STATUS=COMPLETE")) {
    stop("Stage 2 blocked: Stage 1 is not recorded complete. No Stage-2 estimator work has started.")
  }
  hash_table <- read.csv(file.path(stage1_dir, "stage1_primitive_hashes.csv"),
                         stringsAsFactors = FALSE)
  primitive_dir <- file.path(stage1_dir, "primitives")
  hash_check <- verify_primitive_hashes(hash_table, primitive_dir, 100L)
  if (!isTRUE(hash_check$ok)) stop("Stage 2 blocked: ", hash_check$message,
                                   " No Stage-2 estimator work has started.")
  stage1_profiles <- read.csv(file.path(stage1_dir, "stage1_profiles.csv"),
                              stringsAsFactors = FALSE)
  stage1_groups <- interaction(stage1_profiles$replication, stage1_profiles$tau,
                               stage1_profiles$kappa, stage1_profiles$estimator, drop = TRUE)
  if (nrow(stage1_profiles) != 364500L || length(table(stage1_groups)) != 4500L ||
      !all(table(stage1_groups) == 81L) ||
      !all(vapply(split(stage1_profiles$a, stage1_groups),
                  function(a) length(a) == length(cfg$stage1_grid) &&
                    all(is.finite(as.numeric(a))) &&
                    all(abs(as.numeric(a) - cfg$stage1_grid) <= 1e-14), logical(1)))) {
    stop("Stage 2 blocked: Stage-1 profile dimensions/grid are invalid. No Stage-2 estimator work has started.")
  }
  assert_output_namespace_empty(stage2_dir, "Stage 2")
  dir.create(stage2_dir, recursive = TRUE, showWarnings = FALSE)
  start_time <- Sys.time()
  set.seed(cfg$seed)
  out <- run_with_warnings(run_stage2(cfg, stage1_profiles, primitive_dir))
  end_time <- Sys.time()
  out$summary <- summarize_ranges(out$range_metrics)
  out$expansion_summary <- summarize_stage2_expansions(out$expansion_metrics)
  stopifnot(nrow(out$tail_profiles) == 180000L, nrow(out$combined_profiles) == 544500L,
            nrow(out$range_metrics) == 13500L, nrow(out$expansion_metrics) == 4500L,
            nrow(out$summary) == 135L, nrow(out$expansion_summary) == 45L)
  stage2_files <- c(
    tail_profiles = "stage2_tail_profiles.csv", combined_profiles = "combined_profiles_-5_7.csv",
    range_metrics = "stage2_range_metrics.csv", expansion_metrics = "stage2_expansion_metrics.csv",
    failures = "stage2_failures.csv", summary = "stage2_summary.csv",
    expansion_summary = "stage2_expansion_summary.csv")
  for (name in names(stage2_files)) write.csv(out[[name]], file.path(stage2_dir, stage2_files[name]), row.names = FALSE)
  writeLines(capture.output(sessionInfo()), file.path(stage2_dir, "stage2_sessionInfo.txt"))
  write_config_record(file.path(stage2_dir, "stage2_config.txt"), "stage2", 100L,
                      cfg$tau_values, cfg$kappa_values)
  write_manifest(file.path(stage2_dir, "stage2_manifest.txt"), "stage2",
                 c("stage1_primitive_hashes_verified=TRUE", "stage1_interior_profiles_reused_read_only=TRUE"))
  writeLines(c("RUN_STATUS=COMPLETE", paste("Git SHA:", git_sha),
               paste("Start time:", start_time), paste("End time:", end_time),
               paste("Wall-clock seconds:", as.numeric(difftime(end_time, start_time, units = "secs"))),
               "Tail profile rows: 180000", "Combined profile rows: 544500",
               "Range metric rows: 13500", "Expansion rows: 4500",
               paste("Failures:", nrow(out$failures)),
               paste("Warnings:", if (length(warnings_seen)) paste(unique(warnings_seen), collapse = " | ") else "none")),
             file.path(stage2_dir, "stage2_run_log.txt"))
  cat("GRID-SENSITIVITY STAGE 2: COMPLETE\n")
}
