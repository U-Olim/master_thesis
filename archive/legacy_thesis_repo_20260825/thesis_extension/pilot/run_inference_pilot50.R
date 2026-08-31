# 50-replication frozen-design inference pilot with restart-safe checkpoints.
MASTER_SEED <- 20260818L
N_REPLICATIONS <- 50L
EXPECTED_RAW_ROWS <- 6000L
EXPECTED_POWER_ROWS <- 24000L
EXPECTED_SUMMARY_ROWS <- 120L
CR_H <- 0.05

if (getRversion() != "3.4.3") {
  stop("This pilot must run under R 3.4.3; found ", R.version.string, ".")
}
required_versions <- c(
  quantreg = "5.34", hdm = "0.2.0", hqreg = "1.4",
  mvtnorm = "1.0-6", doSNOW = "1.0.16"
)
for (package in names(required_versions)) {
  actual <- packageDescription(package, fields = "Version")
  if (is.na(actual) || actual != required_versions[[package]]) {
    stop(package, ": expected version ", required_versions[[package]],
         "; found ", ifelse(is.na(actual), "<not installed>", actual), ".")
  }
}

suppressPackageStartupMessages({
  library(quantreg)
  library(hdm)
  library(mvtnorm)
})

root_dir <- getwd()
extension_dir <- file.path(root_dir, "thesis_extension")
pilot_dir <- file.path(extension_dir, "pilot")
checkpoint_dir <- file.path(pilot_dir, "checkpoints", "inference_pilot50")
dir.create(checkpoint_dir, recursive = TRUE, showWarnings = FALSE)
source(file.path(extension_dir, "config", "kappa_candidates.R"))
source(file.path(extension_dir, "config", "inference_config.R"))
source(file.path(extension_dir, "src", "dgp_kappa.R"))
source(file.path(extension_dir, "src", "wn_profiles.R"))

if (!identical(SAMPLE_SIZES, c(500, 1000)) ||
    !identical(TAUS, c(0.10, 0.25, 0.50, 0.75, 0.90)) ||
    !identical(KAPPA_CANDIDATES, c(1.00, 0.50, 0.25, 0.10)) ||
    !identical(POINT_GRID, seq(-1, 3, by = 0.10)) ||
    !identical(CR_GRID, seq(-1, 3, by = 0.05)) ||
    !identical(POWER_DELTAS, c(-0.50, -0.25, 0.25, 0.50))) {
  stop("Frozen configuration does not match the pilot specification.")
}

arguments <- commandArgs(trailingOnly = TRUE)
argument_value <- function(prefix, default = NULL) {
  selected <- arguments[startsWith(arguments, prefix)]
  if (!length(selected)) return(default)
  sub(prefix, "", selected[1], fixed = TRUE)
}
finalize_only <- "--finalize" %in% arguments
worker_id <- as.integer(argument_value("--worker=", "1"))
n_workers <- as.integer(argument_value("--workers=", "1"))
if (is.na(worker_id) || is.na(n_workers) || worker_id < 1L ||
    n_workers < 1L || worker_id > n_workers) {
  stop("Worker arguments must satisfy 1 <= worker <= workers.")
}

# The master seed deterministically creates 50 distinct replication seeds.
# Each replication resets to its assigned seed before drawing anything. Thus a
# resumed or parallel run produces exactly the same replication as an
# uninterrupted run, independent of worker order or previously completed work.
set.seed(MASTER_SEED)
replication_seeds <- sample.int(.Machine$integer.max, N_REPLICATIONS,
                                replace = FALSE)

alpha_key <- function(alpha) sprintf("%a", alpha)
make_union <- function(tau) {
  truth <- alpha_true(tau)
  requested <- c(CR_GRID, POINT_GRID, truth, truth + POWER_DELTAS)
  requested[!duplicated(alpha_key(requested))]
}
map_indices <- function(union_grid, requested) {
  indices <- match(alpha_key(requested), alpha_key(union_grid))
  if (anyNA(indices)) stop("Failed to map an exact requested alpha.")
  indices
}

generate_primitives <- function(n) {
  sigma <- matrix(c(1, 0.3, 0.3, 1), ncol = 2)
  epsilon <- rmvnorm(n = n, mean = c(0, 0), sigma = sigma)
  x <- matrix(rnorm(n * 100), ncol = 100)
  X <- matrix(pnorm(x), ncol = 100)
  z1 <- rnorm(n, 0, 1)
  z2 <- rnorm(n, 0, 1)
  v1 <- rnorm(n, 0, 1)
  v2 <- rnorm(n, 0, 1)
  w <- rnorm(n, 0, 1)
  Z1 <- z1 + v1 + X[, 2] + X[, 3] + X[, 4]
  Z2 <- z2 + v2 + X[, 7] + X[, 8] + X[, 9] + X[, 10]
  list(
    epsilon = epsilon, X100 = X, X10 = X[, 1:10],
    z1 = z1, z2 = z2, w = w,
    Z = matrix(cbind(Z1, Z2), nrow = n)
  )
}

make_dataset <- function(primitives, kappa) {
  treatment <- make_treatment_kappa(
    primitives$z1, primitives$z2, primitives$epsilon[, 2],
    primitives$w, kappa
  )
  b <- matrix(c(rep(5, 7), rep(0, 93)))
  list(
    y = c(1 + treatment$D + primitives$X100 %*% b +
            primitives$epsilon[, 1] * treatment$D),
    D = treatment$D
  )
}

run_profiles <- function(dat, primitives, tau, union_grid, lambda_bc) {
  list(
    "Oracle-GMM" = oracle_wn_profile(
      dat$y, dat$D, primitives$X10, primitives$Z, tau, union_grid
    ),
    "Full-GMM" = full_wn_profile(
      dat$y, dat$D, primitives$X100, primitives$Z, tau, union_grid
    ),
    "DML-IVQR" = dml_wn_profile_bc(
      dat$y, dat$D, primitives$X100, primitives$Z, tau,
      union_grid, lambda_bc
    )
  )
}

count_components <- function(accepted) {
  clean <- !is.na(accepted) & accepted
  if (!length(clean)) return(0L)
  as.integer(sum(clean & c(TRUE, !head(clean, -1L))))
}
combine_status <- function(messages) {
  messages <- unique(messages[messages != "OK"])
  if (!length(messages)) "OK" else paste(messages, collapse = " | ")
}
checkpoint_path <- function(replication) {
  file.path(checkpoint_dir, sprintf("replication_%03d.rds", replication))
}

run_replication <- function(replication) {
  set.seed(replication_seeds[replication])
  rng_start <- .Random.seed
  start_time <- Sys.time()
  raw_rows <- vector("list", 120L)
  power_rows <- vector("list", 480L)
  raw_index <- 0L
  power_index <- 0L
  penalty_count <- 0L
  reuse_checks <- logical(0)
  truth_checks <- logical(0)
  power_checks <- logical(0)

  for (n in SAMPLE_SIZES) {
    primitives <- generate_primitives(n)
    datasets <- lapply(KAPPA_CANDIDATES, function(kappa) {
      make_dataset(primitives, kappa)
    })
    for (tau in TAUS) {
      truth <- alpha_true(tau)
      false_alphas <- truth + POWER_DELTAS
      union_grid <- make_union(tau)
      point_indices <- map_indices(union_grid, POINT_GRID)
      cr_indices <- map_indices(union_grid, CR_GRID)
      truth_index <- map_indices(union_grid, truth)
      false_indices <- map_indices(union_grid, false_alphas)
      truth_checks <- c(truth_checks, identical(union_grid[truth_index], truth))
      power_checks <- c(power_checks,
                        identical(union_grid[false_indices], false_alphas))
      lambda_bc <- bc_pivotal_lambda(
        primitives$X100, R = 1000, tau = tau, c = 2, alpha = 0.1
      )
      penalty_count <- penalty_count + 1L

      for (kappa_index in seq_along(KAPPA_CANDIDATES)) {
        kappa <- KAPPA_CANDIDATES[kappa_index]
        profiles <- run_profiles(
          datasets[[kappa_index]], primitives, tau, union_grid, lambda_bc
        )
        reuse_checks <- c(
          reuse_checks,
          identical(profiles[["DML-IVQR"]]$lambda_bc, lambda_bc)
        )
        for (estimator in names(profiles)) {
          profile <- profiles[[estimator]]
          point_W <- profile$W[point_indices]
          successful_points <- which(is.finite(point_W))
          alpha_hat <- if (length(successful_points)) {
            selected <- successful_points[which.min(point_W[successful_points])]
            POINT_GRID[selected]
          } else NA_real_

          cr_W <- profile$W[cr_indices]
          cr_success <- is.finite(cr_W)
          cr_accepted <- cr_W <= CRITICAL_VALUE
          if (all(cr_success)) {
            indicator <- as.numeric(cr_accepted)
            cr_length <- sum(
              CR_H * (head(indicator, -1L) + tail(indicator, -1L)) / 2
            )
            cr_length_status <- "OK"
          } else {
            cr_length <- NA_real_
            cr_length_status <- "ERROR: missing required CR-grid W evaluation"
          }
          W_true <- profile$W[truth_index]
          covered <- if (is.finite(W_true)) W_true <= CRITICAL_VALUE else NA
          rejected_true <- if (is.finite(W_true)) W_true > CRITICAL_VALUE else NA
          overall_status <- combine_status(c(
            profile$status_by_alpha$status[point_indices],
            profile$status_by_alpha$status[cr_indices],
            profile$status_by_alpha$status[truth_index],
            cr_length_status
          ))

          raw_index <- raw_index + 1L
          raw_rows[[raw_index]] <- data.frame(
            replication = replication, n = n, tau = tau, kappa = kappa,
            estimator = estimator, alpha_true = truth, alpha_hat = alpha_hat,
            bias = alpha_hat - truth, abs_error = abs(alpha_hat - truth),
            squared_error = (alpha_hat - truth)^2,
            W_true = W_true, covered = covered, rejected_true = rejected_true,
            cr_length = cr_length,
            cr_any_accepted = any(cr_accepted, na.rm = TRUE),
            cr_all_accepted = all(!is.na(cr_accepted)) && all(cr_accepted),
            cr_left_boundary_accepted = cr_accepted[1],
            cr_right_boundary_accepted = cr_accepted[length(cr_accepted)],
            cr_n_components_grid = count_components(cr_accepted),
            point_left_boundary = is.finite(alpha_hat) && alpha_hat == -1,
            point_right_boundary = is.finite(alpha_hat) && alpha_hat == 3,
            n_W_success = sum(is.finite(profile$W)),
            n_W_failure = sum(!is.finite(profile$W)),
            status = overall_status,
            stringsAsFactors = FALSE
          )

          for (delta_index in seq_along(POWER_DELTAS)) {
            index <- false_indices[delta_index]
            W_false <- profile$W[index]
            power_index <- power_index + 1L
            power_rows[[power_index]] <- data.frame(
              replication = replication, n = n, tau = tau, kappa = kappa,
              estimator = estimator, delta = POWER_DELTAS[delta_index],
              alpha_false = false_alphas[delta_index], W_false = W_false,
              rejected_false = if (is.finite(W_false)) {
                W_false > CRITICAL_VALUE
              } else NA,
              status = profile$status_by_alpha$status[index],
              stringsAsFactors = FALSE
            )
          }
        }
      }
    }
  }

  end_time <- Sys.time()
  list(
    replication = replication,
    replication_seed = replication_seeds[replication],
    rng_start = rng_start,
    rng_end = .Random.seed,
    start_time = start_time,
    end_time = end_time,
    elapsed_seconds = as.numeric(difftime(end_time, start_time, units = "secs")),
    raw = do.call(rbind, raw_rows),
    power = do.call(rbind, power_rows),
    penalty_count = penalty_count,
    reuse_checks = reuse_checks,
    truth_checks = truth_checks,
    power_checks = power_checks
  )
}

save_checkpoint <- function(result, path) {
  temporary <- tempfile("checkpoint_", tmpdir = checkpoint_dir, fileext = ".rds")
  saveRDS(result, temporary)
  if (!file.rename(temporary, path)) {
    unlink(temporary)
    stop("Could not atomically install checkpoint: ", path)
  }
}

assigned_replications <- seq(worker_id, N_REPLICATIONS, by = n_workers)
if (!finalize_only) {
  for (replication in assigned_replications) {
    path <- checkpoint_path(replication)
    if (file.exists(path)) {
      existing <- readRDS(path)
      if (identical(existing$replication, replication) &&
          identical(existing$replication_seed, replication_seeds[replication]) &&
          nrow(existing$raw) == 120L && nrow(existing$power) == 480L) {
        cat("Skipping validated checkpoint replication", replication, "\n")
        next
      }
      stop("Invalid existing checkpoint: ", path)
    }
    result <- run_replication(replication)
    save_checkpoint(result, path)
    cat("Completed and checkpointed replication", replication,
        "elapsed seconds", format(result$elapsed_seconds, digits = 8), "\n")
  }
}

finalize_results <- function() {
  paths <- vapply(seq_len(N_REPLICATIONS), checkpoint_path, character(1))
  if (!all(file.exists(paths))) {
    missing <- which(!file.exists(paths))
    stop("Cannot finalize; missing checkpoints: ", paste(missing, collapse = ", "))
  }
  results <- lapply(paths, readRDS)
  for (replication in seq_len(N_REPLICATIONS)) {
    result <- results[[replication]]
    if (!identical(result$replication, replication) ||
        !identical(result$replication_seed, replication_seeds[replication]) ||
        nrow(result$raw) != 120L || nrow(result$power) != 480L) {
      stop("Checkpoint validation failed for replication ", replication, ".")
    }
  }
  raw <- do.call(rbind, lapply(results, `[[`, "raw"))
  power <- do.call(rbind, lapply(results, `[[`, "power"))
  rownames(raw) <- NULL
  rownames(power) <- NULL

  group_key <- interaction(raw$n, raw$tau, raw$kappa, raw$estimator,
                           drop = TRUE, lex.order = TRUE)
  summary_rows <- lapply(split(raw, group_key), function(dat) {
    successful <- dat$status == "OK" & is.finite(dat$alpha_hat) &
      is.finite(dat$W_true) & is.finite(dat$cr_length) & !is.na(dat$covered)
    valid <- dat[successful, ]
    n_success <- nrow(valid)
    coverage <- if (n_success) mean(valid$covered) else NA_real_
    size <- if (n_success) mean(valid$rejected_true) else NA_real_
    data.frame(
      n = dat$n[1], tau = dat$tau[1], kappa = dat$kappa[1],
      estimator = dat$estimator[1],
      mean_bias = if (n_success) mean(valid$bias) else NA_real_,
      MAE = if (n_success) mean(valid$abs_error) else NA_real_,
      RMSE = if (n_success) sqrt(mean(valid$squared_error)) else NA_real_,
      coverage = coverage, rejection_at_truth = size,
      MCSE_coverage = if (n_success) sqrt(coverage * (1 - coverage) / n_success) else NA_real_,
      MCSE_size = if (n_success) sqrt(size * (1 - size) / n_success) else NA_real_,
      mean_CR_length = if (n_success) mean(valid$cr_length) else NA_real_,
      median_CR_length = if (n_success) median(valid$cr_length) else NA_real_,
      proportion_CR_all_A = if (n_success) mean(valid$cr_all_accepted) else NA_real_,
      proportion_CR_left_boundary = if (n_success) mean(valid$cr_left_boundary_accepted) else NA_real_,
      proportion_CR_right_boundary = if (n_success) mean(valid$cr_right_boundary_accepted) else NA_real_,
      point_left_boundary_rate = if (n_success) mean(valid$point_left_boundary) else NA_real_,
      point_right_boundary_rate = if (n_success) mean(valid$point_right_boundary) else NA_real_,
      successful_replications = n_success,
      failed_replications = nrow(dat) - n_success,
      stringsAsFactors = FALSE
    )
  })
  summary <- do.call(rbind, summary_rows)
  summary <- summary[order(summary$n, summary$tau, -summary$kappa,
                           summary$estimator), ]
  rownames(summary) <- NULL

  power_key <- interaction(power$n, power$tau, power$kappa,
                           power$estimator, power$delta,
                           drop = TRUE, lex.order = TRUE)
  power_summary_rows <- lapply(split(power, power_key), function(dat) {
    successful <- dat$status == "OK" & is.finite(dat$W_false) &
      !is.na(dat$rejected_false)
    valid <- dat[successful, ]
    n_success <- nrow(valid)
    estimated_power <- if (n_success) mean(valid$rejected_false) else NA_real_
    data.frame(
      n = dat$n[1], tau = dat$tau[1], kappa = dat$kappa[1],
      estimator = dat$estimator[1], delta = dat$delta[1],
      power = estimated_power,
      MCSE_power = if (n_success) {
        sqrt(estimated_power * (1 - estimated_power) / n_success)
      } else NA_real_,
      successful_replications = n_success,
      failed_replications = nrow(dat) - n_success,
      stringsAsFactors = FALSE
    )
  })
  power_summary <- do.call(rbind, power_summary_rows)
  power_summary <- power_summary[order(
    power_summary$n, power_summary$tau, -power_summary$kappa,
    power_summary$estimator, power_summary$delta
  ), ]
  rownames(power_summary) <- NULL

  diagnostics_rows <- lapply(split(raw, group_key), function(dat) {
    data.frame(
      n = dat$n[1], tau = dat$tau[1], kappa = dat$kappa[1],
      estimator = dat$estimator[1], total_profiles = nrow(dat),
      W_failures = sum(dat$n_W_failure),
      non_OK_statuses = sum(dat$status != "OK"),
      CR_length_NA_count = sum(is.na(dat$cr_length)),
      point_boundary_hits = sum(dat$point_left_boundary | dat$point_right_boundary),
      CR_left_boundary_contacts = sum(dat$cr_left_boundary_accepted %in% TRUE),
      CR_right_boundary_contacts = sum(dat$cr_right_boundary_accepted %in% TRUE),
      full_A_CR_count = sum(dat$cr_all_accepted),
      stringsAsFactors = FALSE
    )
  })
  diagnostics <- do.call(rbind, diagnostics_rows)
  diagnostics <- diagnostics[order(
    diagnostics$n, diagnostics$tau, -diagnostics$kappa,
    diagnostics$estimator
  ), ]
  rownames(diagnostics) <- NULL

  success_rows <- raw$status == "OK" & is.finite(raw$W_true) &
    !is.na(raw$covered) & !is.na(raw$rejected_true)
  sanity <- c(
    coverage_complement = all(
      (as.integer(raw$covered[success_rows]) +
         as.integer(raw$rejected_true[success_rows])) == 1L
    ),
    cr_length_bounds = all(is.na(raw$cr_length) |
                             (raw$cr_length >= 0 & raw$cr_length <= 4)),
    alpha_hat_bounds = all(is.na(raw$alpha_hat) |
                             (raw$alpha_hat >= -1 & raw$alpha_hat <= 3)),
    power_inside = all(power$alpha_false >= -1 & power$alpha_false <= 3),
    bias_definition = max(abs(raw$bias - (raw$alpha_hat - raw$alpha_true)),
                          na.rm = TRUE) <= 1e-12,
    row_counts = nrow(raw) == EXPECTED_RAW_ROWS &&
      nrow(power) == EXPECTED_POWER_ROWS &&
      nrow(summary) == EXPECTED_SUMMARY_ROWS &&
      nrow(power_summary) == 480L && nrow(diagnostics) == 120L,
    penalty_count = sum(vapply(results, `[[`, integer(1), "penalty_count")) == 500L,
    reuse = all(unlist(lapply(results, `[[`, "reuse_checks"))),
    truth_mapping = all(unlist(lapply(results, `[[`, "truth_checks"))),
    power_mapping = all(unlist(lapply(results, `[[`, "power_checks")))
  )
  if (!all(sanity)) {
    stop("Final validation failed: ", paste(names(sanity)[!sanity], collapse = ", "))
  }

  raw_path <- file.path(pilot_dir, "inference_pilot50_raw.csv")
  power_path <- file.path(pilot_dir, "inference_pilot50_power.csv")
  summary_path <- file.path(pilot_dir, "inference_pilot50_summary.csv")
  power_summary_path <- file.path(pilot_dir, "inference_pilot50_power_summary.csv")
  diagnostics_path <- file.path(pilot_dir, "inference_pilot50_diagnostics.csv")
  report_path <- file.path(pilot_dir, "inference_pilot50_report.txt")
  write.csv(raw, raw_path, row.names = FALSE)
  write.csv(power, power_path, row.names = FALSE)
  write.csv(summary, summary_path, row.names = FALSE)
  write.csv(power_summary, power_summary_path, row.names = FALSE)
  write.csv(diagnostics, diagnostics_path, row.names = FALSE)

  earliest_start <- min(vapply(results, function(x) as.numeric(x$start_time), numeric(1)))
  latest_end <- max(vapply(results, function(x) as.numeric(x$end_time), numeric(1)))
  total_cpu_like <- sum(vapply(results, `[[`, numeric(1), "elapsed_seconds"))
  wall_seconds <- latest_end - earliest_start
  coverage_ranges <- do.call(rbind, lapply(unique(summary$estimator), function(estimator) {
    values <- summary$coverage[summary$estimator == estimator]
    data.frame(estimator = estimator, min_coverage = min(values, na.rm = TRUE),
               max_coverage = max(values, na.rm = TRUE), stringsAsFactors = FALSE)
  }))
  kappa_patterns <- aggregate(
    cbind(median_CR_length, proportion_CR_all_A) ~ estimator + kappa,
    data = summary, FUN = median, na.rm = TRUE
  )
  power_patterns <- aggregate(
    power ~ estimator + kappa + delta,
    data = power_summary, FUN = mean, na.rm = TRUE
  )
  point_patterns <- aggregate(
    cbind(point_left_boundary_rate, point_right_boundary_rate) ~ estimator + kappa,
    data = summary, FUN = mean, na.rm = TRUE
  )
  report <- c(
    "50-replication full-design inference pilot",
    "",
    paste("R version:", R.version.string),
    paste("Master seed:", MASTER_SEED),
    paste("Start timestamp:", format(as.POSIXct(earliest_start, origin = "1970-01-01"), tz = "Europe/Berlin")),
    paste("End timestamp:", format(as.POSIXct(latest_end, origin = "1970-01-01"), tz = "Europe/Berlin")),
    paste("Elapsed wall-clock seconds:", format(wall_seconds, digits = 12)),
    paste("Sum of per-replication elapsed seconds:", format(total_cpu_like, digits = 12)),
    paste("Approximate wall-clock seconds per replication:", format(wall_seconds / 50, digits = 10)),
    "Parallel workers may overlap replication elapsed intervals.",
    "",
    paste("Expected/actual raw rows:", EXPECTED_RAW_ROWS, "/", nrow(raw)),
    paste("Expected/actual power rows:", EXPECTED_POWER_ROWS, "/", nrow(power)),
    paste("Expected/actual summary rows:", EXPECTED_SUMMARY_ROWS, "/", nrow(summary)),
    paste("Power-summary rows:", nrow(power_summary)),
    paste("Diagnostic rows:", nrow(diagnostics)),
    "",
    paste("W failures:", sum(raw$n_W_failure)),
    paste("Non-OK raw statuses:", sum(raw$status != "OK")),
    paste("CR-length NA count:", sum(is.na(raw$cr_length))),
    paste("Coverage failures:", sum(is.na(raw$covered))),
    paste("Power failures:", sum(is.na(power$rejected_false))),
    paste("Point left-boundary hits:", sum(raw$point_left_boundary)),
    paste("Point right-boundary hits:", sum(raw$point_right_boundary)),
    paste("CR left-boundary contacts:", sum(raw$cr_left_boundary_accepted %in% TRUE)),
    paste("CR right-boundary contacts:", sum(raw$cr_right_boundary_accepted %in% TRUE)),
    paste("Full-A CRs:", sum(raw$cr_all_accepted)),
    paste("CR-length range:", paste(range(raw$cr_length, na.rm = TRUE), collapse = " to ")),
    "",
    paste("BC penalties generated:", sum(vapply(results, `[[`, integer(1), "penalty_count")), "(expected 500)"),
    paste("All penalty-reuse checks:", sanity["reuse"]),
    paste("All exact truth mappings:", sanity["truth_mapping"]),
    paste("All exact power mappings:", sanity["power_mapping"]),
    "",
    "Checkpoint/restart rule:",
    "set.seed(20260818) deterministically creates 50 distinct replication seeds.",
    "Each replication resets to its assigned seed and writes one atomic RDS checkpoint.",
    "A resumed/parallel run validates and skips completed checkpoints, so worker order",
    "and interruption cannot alter any replication's random draws or duplicate results.",
    "",
    "Coverage ranges by estimator (50-replication pilot only):",
    capture.output(print(coverage_ranges, row.names = FALSE, right = FALSE)),
    "",
    "Median CR length and full-A proportions across kappa (median over n/tau cells):",
    capture.output(print(kappa_patterns, row.names = FALSE, right = FALSE)),
    "",
    "Mean cell-level power across kappa and delta (averaged over n/tau; diagnostic):",
    capture.output(print(power_patterns, row.names = FALSE, right = FALSE)),
    "",
    "Point-boundary rates across kappa (mean over n/tau cells):",
    capture.output(print(point_patterns, row.names = FALSE, right = FALSE)),
    "",
    paste("All sanity checks:", all(sanity)),
    "This 50-replication pilot is not the final thesis Monte Carlo. Non-monotone",
    "finite-sample patterns were retained and no frozen choice was tuned."
  )
  writeLines(report, report_path)
  cat(paste(report, collapse = "\n"), "\n")
}

if (finalize_only) finalize_results()
