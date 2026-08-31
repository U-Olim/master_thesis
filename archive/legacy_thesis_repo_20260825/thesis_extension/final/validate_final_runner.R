# Two-replication regression validation for the split-sample final runner.
# This script is hard-limited to final rep_id 1 and 2 for n=500 and n=1000.

main <- function() {
  if (getRversion() != "3.4.3") {
    stop("Runner validation must use R 3.4.3; found ", R.version.string, ".")
  }
  root_dir <- getwd()
  runner_path <- file.path(
    root_dir, "thesis_extension", "final", "run_inference_final.R"
  )
  report_path <- file.path(
    root_dir, "thesis_extension", "final", "final_runner_validation_report.txt"
  )
  rscript_path <- file.path(R.home("bin"), "Rscript.exe")
  sample_sizes <- c(500L, 1000L)
  if (!file.exists(runner_path) || !file.exists(rscript_path)) {
    stop("Runner or Rscript executable is missing.")
  }

  validation_root <- tempfile("final_runner_validation_")
  sequential_root <- file.path(validation_root, "sequential")
  parallel_root <- file.path(validation_root, "parallel")
  restart_root <- file.path(validation_root, "restart")
  dir.create(validation_root, recursive = TRUE, showWarnings = FALSE)

  run_child <- function(label, workers, run_root, sample_size) {
    log_stem <- paste0(label, "_n", sample_size)
    stdout_path <- file.path(validation_root, paste0(log_stem, "_stdout.txt"))
    stderr_path <- file.path(validation_root, paste0(log_stem, "_stderr.txt"))
    start <- Sys.time()
    status <- system2(
      rscript_path,
      c(
        "--vanilla", runner_path, "--validation", "--validation-reps", "2",
        "--sample-size", as.character(sample_size),
        "--workers", as.character(workers), "--run-root", run_root
      ),
      stdout = stdout_path, stderr = stderr_path
    )
    end <- Sys.time()
    if (!identical(as.integer(status), 0L)) {
      stop(log_stem, " runner invocation failed with status ", status,
           ". stdout: ", paste(readLines(stdout_path, warn = FALSE), collapse = " | "),
           ". stderr: ", paste(readLines(stderr_path, warn = FALSE), collapse = " | "))
    }
    as.numeric(difftime(end, start, units = "secs"))
  }

  output_files <- c(
    "final_raw.csv", "final_power.csv", "final_summary.csv",
    "final_power_summary.csv", "final_diagnostics.csv",
    "final_replication_seeds.csv"
  )
  output_path <- function(run_root, sample_size, filename) {
    file.path(run_root, "output", paste0("n", sample_size), filename)
  }
  checkpoint_path <- function(run_root, sample_size, rep_id) {
    file.path(
      run_root, "checkpoints", paste0("n", sample_size),
      sprintf("replication_%04d.rds", rep_id)
    )
  }
  read_output <- function(run_root, sample_size, filename) {
    read.csv(output_path(run_root, sample_size, filename),
             stringsAsFactors = FALSE, check.names = FALSE)
  }
  compare_data_frames <- function(left, right, label) {
    if (!identical(names(left), names(right)) ||
        !identical(dim(left), dim(right))) {
      stop(label, " schema/dimension mismatch.")
    }
    numeric_names <- names(left)[vapply(left, is.numeric, logical(1))]
    nonnumeric_names <- setdiff(names(left), numeric_names)
    numeric_max <- 0
    for (name in numeric_names) {
      left_values <- left[[name]]
      right_values <- right[[name]]
      if (!identical(is.na(left_values), is.na(right_values))) {
        stop(label, " NA-pattern mismatch in ", name, ".")
      }
      complete <- !is.na(left_values)
      if (any(complete)) {
        numeric_max <- max(
          numeric_max,
          max(abs(left_values[complete] - right_values[complete]))
        )
      }
    }
    if (numeric_max != 0) {
      stop(label, " maximum numeric difference is ",
           format(numeric_max, digits = 17), ".")
    }
    for (name in nonnumeric_names) {
      if (!identical(left[[name]], right[[name]])) {
        stop(label, " nonnumeric mismatch in ", name, ".")
      }
    }
    list(exact = identical(left, right), max_numeric_difference = numeric_max)
  }
  substantive_checkpoint_fields <- c(
    "schema_version", "git_commit", "sample_size", "rep_id", "rep_seed",
    "R_version", "package_versions", "frozen_config_snapshot", "rng_start",
    "rng_after_sample_size_advance", "rng_end", "primitive_audit", "raw",
    "power", "diagnostics", "bc_penalties", "penalty_count", "reuse_checks",
    "truth_checks", "power_checks", "profile_rng_checks"
  )
  read_checkpoint <- function(run_root, sample_size, rep_id) {
    readRDS(checkpoint_path(run_root, sample_size, rep_id))
  }
  compare_checkpoints <- function(left, right, label) {
    for (field in substantive_checkpoint_fields) {
      if (!identical(left[[field]], right[[field]])) {
        stop(label, " checkpoint mismatch in substantive field ", field, ".")
      }
    }
    TRUE
  }

  sequential_wall <- setNames(numeric(length(sample_sizes)), sample_sizes)
  parallel_wall <- setNames(numeric(length(sample_sizes)), sample_sizes)
  restart_wall <- setNames(numeric(length(sample_sizes)), sample_sizes)
  comparison_maxima <- numeric(0)
  comparison_exact <- logical(0)
  checkpoint_exact <- logical(0)
  restart_checks <- list()
  sequential_checkpoints <- list()

  for (sample_size in sample_sizes) {
    sequential_wall[as.character(sample_size)] <- run_child(
      "sequential", 1L, sequential_root, sample_size
    )
    parallel_wall[as.character(sample_size)] <- run_child(
      "parallel", 2L, parallel_root, sample_size
    )

    for (filename in output_files) {
      comparison <- compare_data_frames(
        read_output(sequential_root, sample_size, filename),
        read_output(parallel_root, sample_size, filename),
        paste("sequential-vs-parallel n=", sample_size, filename)
      )
      comparison_maxima <- c(
        comparison_maxima, comparison$max_numeric_difference
      )
      comparison_exact <- c(comparison_exact, comparison$exact)
    }
    for (rep_id in 1:2) {
      left <- read_checkpoint(sequential_root, sample_size, rep_id)
      right <- read_checkpoint(parallel_root, sample_size, rep_id)
      checkpoint_exact <- c(checkpoint_exact, compare_checkpoints(
        left, right,
        paste("sequential-vs-parallel n=", sample_size, "rep_id", rep_id)
      ))
      sequential_checkpoints[[paste(sample_size, rep_id, sep = "_")]] <- left
    }

    restart_checkpoint_dir <- dirname(checkpoint_path(
      restart_root, sample_size, 1L
    ))
    dir.create(restart_checkpoint_dir, recursive = TRUE, showWarnings = FALSE)
    copied <- file.copy(
      checkpoint_path(sequential_root, sample_size, 1L),
      checkpoint_path(restart_root, sample_size, 1L), overwrite = FALSE
    )
    if (!copied) stop("Could not stage rep_id 1 for n=", sample_size, ".")
    restart_wall[as.character(sample_size)] <- run_child(
      "restart", 2L, restart_root, sample_size
    )
    restart_log <- readLines(output_path(
      restart_root, sample_size, "final_run_log.txt"
    ), warn = FALSE)
    skipped_one <- any(grepl("SKIP rep_id= 1", restart_log, fixed = TRUE))
    completed_two <- any(grepl("COMPLETE rep_id= 2", restart_log, fixed = TRUE))
    completed_one <- any(grepl("COMPLETE rep_id= 1", restart_log, fixed = TRUE))
    if (!skipped_one || !completed_two || completed_one) {
      stop("Restart execution failed for n=", sample_size, ".")
    }
    restart_checks[[as.character(sample_size)]] <- c(
      skipped_rep_1 = skipped_one,
      completed_rep_2 = completed_two,
      reran_rep_1 = completed_one
    )

    for (filename in output_files) {
      comparison <- compare_data_frames(
        read_output(sequential_root, sample_size, filename),
        read_output(restart_root, sample_size, filename),
        paste("clean-vs-restart n=", sample_size, filename)
      )
      comparison_maxima <- c(
        comparison_maxima, comparison$max_numeric_difference
      )
      comparison_exact <- c(comparison_exact, comparison$exact)
    }
    for (rep_id in 1:2) {
      checkpoint_exact <- c(checkpoint_exact, compare_checkpoints(
        read_checkpoint(sequential_root, sample_size, rep_id),
        read_checkpoint(restart_root, sample_size, rep_id),
        paste("clean-vs-restart n=", sample_size, "rep_id", rep_id)
      ))
    }
  }

  if (!all(comparison_exact) || !all(checkpoint_exact) ||
      max(comparison_maxima) != 0) {
    stop("Split-sample substantive reproducibility comparison failed.")
  }
  all_profile_rng_checks <- all(unlist(lapply(
    sequential_checkpoints, `[[`, "profile_rng_checks"
  )))
  if (!all_profile_rng_checks) {
    stop("An estimator profile consumed RNG; n=1000 stream advancement is invalid.")
  }

  elapsed_by_sample <- vapply(sample_sizes, function(sample_size) {
    mean(vapply(1:2, function(rep_id) {
      sequential_checkpoints[[paste(sample_size, rep_id, sep = "_")]]$elapsed_seconds
    }, numeric(1)))
  }, numeric(1))
  names(elapsed_by_sample) <- sample_sizes

  report <- c(
    "FINAL SPLIT-SAMPLE RUNNER TWO-REPLICATION VALIDATION",
    "",
    paste("R version:", R.version.string),
    "rep_id: 1, 2 only",
    "rep_seed: 20260821, 20260822",
    "sample-size jobs: n=500 and n=1000",
    "",
    paste("Sequential wall seconds n=500:",
          format(sequential_wall["500"], digits = 17)),
    paste("Sequential wall seconds n=1000:",
          format(sequential_wall["1000"], digits = 17)),
    paste("Parallel workers=2 wall seconds n=500:",
          format(parallel_wall["500"], digits = 17)),
    paste("Parallel workers=2 wall seconds n=1000:",
          format(parallel_wall["1000"], digits = 17)),
    paste("Restart wall seconds n=500 (rep_id 2 only):",
          format(restart_wall["500"], digits = 17)),
    paste("Restart wall seconds n=1000 (rep_id 2 only):",
          format(restart_wall["1000"], digits = 17)),
    paste("Mean checkpoint elapsed seconds by sample size:",
          paste(names(elapsed_by_sample), format(elapsed_by_sample, digits = 17),
                sep = "=", collapse = ", ")),
    "",
    paste("Exact substantive output-file comparisons:",
          sum(comparison_exact), "/", length(comparison_exact)),
    paste("Exact substantive checkpoint comparisons:",
          sum(checkpoint_exact), "/", length(checkpoint_exact)),
    paste("Maximum substantive numeric difference:",
          format(max(comparison_maxima), digits = 17)),
    paste("Estimator profiles consumed no RNG:", all_profile_rng_checks),
    "Primitive fingerprints, alpha_hat, W_true, W_false, coverage, power,",
    "accepted-set measures, diagnostic classifications, BC penalties, RNG",
    "states, and replication seeds are bitwise identical.",
    "",
    paste("Restart n=500 skipped rep_id 1:", restart_checks[["500"]][1]),
    paste("Restart n=500 completed rep_id 2:", restart_checks[["500"]][2]),
    paste("Restart n=500 reran rep_id 1:", restart_checks[["500"]][3]),
    paste("Restart n=1000 skipped rep_id 1:", restart_checks[["1000"]][1]),
    paste("Restart n=1000 completed rep_id 2:", restart_checks[["1000"]][2]),
    paste("Restart n=1000 reran rep_id 1:", restart_checks[["1000"]][3]),
    "",
    "No 12-worker benchmark was run.",
    "Sequential-vs-parallel result: PASS",
    "Restart result: PASS",
    "Overall validation: PASS"
  )
  writeLines(report, report_path)
  cat(paste(report, collapse = "\n"), "\n")

  normalized_validation_root <- normalizePath(
    validation_root, winslash = "/", mustWork = TRUE
  )
  normalized_temp_root <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
  if (!startsWith(normalized_validation_root, paste0(normalized_temp_root, "/"))) {
    stop("Refusing to remove validation directory outside tempdir().")
  }
  unlink(validation_root, recursive = TRUE, force = TRUE)
  invisible(TRUE)
}

main()
