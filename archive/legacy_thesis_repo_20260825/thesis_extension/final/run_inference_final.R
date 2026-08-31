# FROZEN FINAL MONTE CARLO.
# DO NOT MODIFY ECONOMETRIC SETTINGS AFTER RESULTS ARE OBSERVED.

if (getRversion() != "3.4.3") {
  stop("The final simulation must run under R 3.4.3; found ",
       R.version.string, ".")
}

root_dir <- getwd()
legacy_library <- file.path(root_dir, "environment", "legacy_R343_library")
.libPaths(c(legacy_library, .Library))
source(file.path(root_dir, "thesis_extension", "config", "final_run_config.R"))

required_versions <- c(
  quantreg = "5.34", hdm = "0.2.0", hqreg = "1.4",
  mvtnorm = "1.0-6", doSNOW = "1.0.16"
)
package_versions <- vapply(names(required_versions), function(package) {
  packageDescription(package, fields = "Version")
}, character(1))
if (!identical(unname(package_versions), unname(required_versions))) {
  stop("Historical package-version check failed: ", paste(
    names(required_versions), " expected=", required_versions,
    " actual=", package_versions, collapse = "; "
  ))
}
suppressPackageStartupMessages({
  library(quantreg)
  library(hdm)
  library(mvtnorm)
})

source(file.path(FINAL_EXTENSION_DIR, "src", "dgp_kappa.R"))
source(file.path(FINAL_EXTENSION_DIR, "src", "wn_profiles.R"))

arguments <- commandArgs(trailingOnly = TRUE)
argument_value <- function(name, default = NULL) {
  exact <- which(arguments == name)
  if (length(exact)) {
    position <- exact[1]
    if (position == length(arguments)) stop("Missing value after ", name, ".")
    return(arguments[position + 1L])
  }
  prefix <- paste0(name, "=")
  selected <- arguments[startsWith(arguments, prefix)]
  if (length(selected)) return(sub(prefix, "", selected[1], fixed = TRUE))
  default
}

validation_mode <- "--validation" %in% arguments
workers <- as.integer(argument_value("--workers", as.character(DEFAULT_WORKERS)))
sample_size <- as.integer(argument_value("--sample-size", NA_character_))
run_root_override <- argument_value("--run-root", NULL)
validation_reps_argument <- argument_value("--validation-reps", NULL)
if (is.na(workers) || workers < 1L) stop("--workers must be a positive integer.")
if (is.na(sample_size) || !(sample_size %in% SAMPLE_SIZES)) {
  stop("--sample-size must be exactly 500 or 1000.")
}
active_sample_sizes <- as.integer(sample_size)
job_tag <- paste0("n", sample_size)
if (!validation_mode && !is.null(validation_reps_argument)) {
  stop("--validation-reps is permitted only with --validation.")
}
if (validation_mode) {
  validation_reps <- as.integer(if (is.null(validation_reps_argument)) "2" else
                                  validation_reps_argument)
  if (!identical(validation_reps, 2L)) {
    stop("Validation mode is hard-limited to rep_id 1 and 2.")
  }
  active_rep_ids <- 1:2
  if (is.null(run_root_override)) {
    stop("Validation mode requires a separate temporary --run-root.")
  }
} else {
  active_rep_ids <- seq_len(FINAL_MC_REPS_PER_SAMPLE_SIZE)
  if (!is.null(run_root_override)) {
    stop("--run-root is permitted only with --validation.")
  }
}

run_root <- if (validation_mode) run_root_override else FINAL_RUN_DIR
checkpoint_dir <- if (validation_mode) {
  file.path(run_root, "checkpoints", job_tag)
} else file.path(FINAL_CHECKPOINT_DIR, job_tag)
output_dir <- if (validation_mode) {
  file.path(run_root, "output", job_tag)
} else file.path(FINAL_OUTPUT_DIR, job_tag)
dir.create(checkpoint_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

git_commit <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = TRUE)
if (length(git_commit) != 1L) stop("Could not identify exactly one Git commit.")
git_commit <- unname(git_commit[1])
git_status_at_start <- system2(
  "git", c("status", "--porcelain"), stdout = TRUE, stderr = TRUE
)
if (!validation_mode && length(git_status_at_start)) {
  stop("Final mode requires a clean repository. Dirty entries: ",
       paste(git_status_at_start, collapse = " | "))
}

source_files <- file.path(root_dir, c(
  "thesis_extension/config/inference_config.R",
  "thesis_extension/config/kappa_candidates.R",
  "thesis_extension/config/final_run_config.R",
  "thesis_extension/src/dgp_kappa.R",
  "thesis_extension/src/wn_profiles.R",
  "thesis_extension/final/run_inference_final.R"
))
freeze_document <- file.path(
  root_dir, "thesis_extension", "docs", "THESIS_SIMULATION_FREEZE.md"
)
if (!all(file.exists(c(source_files, freeze_document)))) {
  stop("One or more frozen source/provenance files are missing.")
}
source_hashes <- unname(tools::md5sum(source_files))
names(source_hashes) <- substring(source_files, nchar(root_dir) + 2L)
freeze_hash <- unname(tools::md5sum(freeze_document))

CR_H <- 0.05
frozen_config_snapshot <- list(
  schema_version = FINAL_SCHEMA_VERSION,
  final_mc_reps_per_sample_size = FINAL_MC_REPS_PER_SAMPLE_SIZE,
  final_master_seed = FINAL_MASTER_SEED,
  design_sample_sizes = SAMPLE_SIZES,
  active_sample_size = sample_size,
  final_default_workers = DEFAULT_WORKERS,
  expected_raw_rows_per_sample_size = EXPECTED_RAW_ROWS_PER_SAMPLE_SIZE,
  expected_power_rows_per_sample_size = EXPECTED_POWER_ROWS_PER_SAMPLE_SIZE,
  expected_summary_rows_per_sample_size = EXPECTED_SUMMARY_ROWS_PER_SAMPLE_SIZE,
  expected_power_summary_rows_per_sample_size =
    EXPECTED_POWER_SUMMARY_ROWS_PER_SAMPLE_SIZE,
  expected_bc_penalties_per_sample_size =
    EXPECTED_BC_PENALTIES_PER_SAMPLE_SIZE,
  taus = TAUS,
  kappas = KAPPA_CANDIDATES,
  point_grid = POINT_GRID,
  cr_grid = CR_GRID,
  power_deltas = POWER_DELTAS,
  parameter_lower = PARAMETER_LOWER,
  parameter_upper = PARAMETER_UPPER,
  critical_value = CRITICAL_VALUE,
  cr_h = CR_H,
  bc_R = 1000L,
  bc_c = 2,
  bc_alpha = 0.1,
  package_versions = package_versions,
  source_hashes = source_hashes,
  freeze_hash = freeze_hash
)

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

object_md5 <- function(object) {
  path <- tempfile("primitive_", fileext = ".rds")
  on.exit(unlink(path), add = TRUE)
  saveRDS(object, path, compress = FALSE)
  unname(tools::md5sum(path))
}

generate_primitives <- function(n) {
  sigma <- matrix(c(1, 0.3, 0.3, 1), ncol = 2)
  epsilon <- mvtnorm::rmvnorm(n = n, mean = c(0, 0), sigma = sigma)
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

# Preserve the already validated combined n=500-then-n=1000 RNG position when
# the two sample sizes are launched as separate jobs. Estimator profiles are
# asserted below not to consume RNG, so only the n=500 primitives and its five
# BC pivotal draws must be advanced before generating the n=1000 primitives.
advance_rng_to_sample_size <- function(sample_size) {
  if (identical(as.integer(sample_size), 500L)) return(invisible(FALSE))
  skipped_primitives <- generate_primitives(500L)
  for (tau in TAUS) {
    invisible(bc_pivotal_lambda(
      skipped_primitives$X100, R = 1000, tau = tau, c = 2, alpha = 0.1
    ))
  }
  invisible(TRUE)
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
empty_alpha_diagnostics <- function() {
  data.frame(
    rep_id = integer(0), rep_seed = integer(0), estimator = character(0),
    n = integer(0), tau = numeric(0), kappa = numeric(0), alpha = numeric(0),
    status = character(0), stringsAsFactors = FALSE
  )
}

run_replication <- function(rep_id) {
  rep_seed <- as.integer(FINAL_MASTER_SEED + rep_id)
  set.seed(rep_seed)
  rng_start <- .Random.seed
  start_time <- Sys.time()
  advance_rng_to_sample_size(active_sample_sizes)
  rng_after_sample_size_advance <- .Random.seed
  raw_rows <- vector("list", 60L)
  power_rows <- vector("list", 240L)
  penalty_rows <- vector("list", 5L)
  primitive_rows <- vector("list", 1L)
  diagnostic_rows <- list()
  raw_index <- 0L
  power_index <- 0L
  penalty_index <- 0L
  primitive_index <- 0L
  penalty_count <- 0L
  reuse_checks <- logical(0)
  truth_checks <- logical(0)
  power_checks <- logical(0)
  profile_rng_checks <- logical(0)

  for (n in active_sample_sizes) {
    primitives <- generate_primitives(n)
    primitive_index <- primitive_index + 1L
    primitive_rows[[primitive_index]] <- data.frame(
      rep_id = rep_id, rep_seed = rep_seed, n = n,
      primitive_md5 = object_md5(primitives), stringsAsFactors = FALSE
    )
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
      power_checks <- c(
        power_checks, identical(union_grid[false_indices], false_alphas)
      )

      lambda_bc <- bc_pivotal_lambda(
        primitives$X100, R = 1000, tau = tau, c = 2, alpha = 0.1
      )
      penalty_count <- penalty_count + 1L
      penalty_index <- penalty_index + 1L
      penalty_rows[[penalty_index]] <- data.frame(
        rep_id = rep_id, rep_seed = rep_seed, n = n, tau = tau,
        lambda_index = seq_along(lambda_bc), lambda_value = as.numeric(lambda_bc),
        stringsAsFactors = FALSE
      )

      for (kappa_index in seq_along(KAPPA_CANDIDATES)) {
        kappa <- KAPPA_CANDIDATES[kappa_index]
        rng_before_profile_evaluation <- .Random.seed
        profiles <- run_profiles(
          datasets[[kappa_index]], primitives, tau, union_grid, lambda_bc
        )
        profile_rng_checks <- c(
          profile_rng_checks,
          identical(rng_before_profile_evaluation, .Random.seed)
        )
        reuse_checks <- c(
          reuse_checks,
          identical(profiles[["DML-IVQR"]]$lambda_bc, lambda_bc)
        )

        for (estimator in names(profiles)) {
          profile <- profiles[[estimator]]
          non_ok <- profile$status_by_alpha$status != "OK"
          if (any(non_ok)) {
            diagnostic_rows[[length(diagnostic_rows) + 1L]] <- data.frame(
              rep_id = rep_id, rep_seed = rep_seed, estimator = estimator,
              n = n, tau = tau, kappa = kappa,
              alpha = profile$status_by_alpha$alpha[non_ok],
              status = profile$status_by_alpha$status[non_ok],
              stringsAsFactors = FALSE
            )
          }

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
            accepted_set_measure_A <- sum(
              CR_H * (head(indicator, -1L) + tail(indicator, -1L)) / 2
            )
            cr_measure_status <- "OK"
          } else {
            accepted_set_measure_A <- NA_real_
            cr_measure_status <- "ERROR: missing required CR-grid W evaluation"
          }

          W_true <- profile$W[truth_index]
          covered <- if (is.finite(W_true)) W_true <= CRITICAL_VALUE else NA
          rejected_true <- if (is.finite(W_true)) W_true > CRITICAL_VALUE else NA
          overall_status <- combine_status(c(
            profile$status_by_alpha$status[point_indices],
            profile$status_by_alpha$status[cr_indices],
            profile$status_by_alpha$status[truth_index],
            cr_measure_status
          ))

          raw_index <- raw_index + 1L
          raw_rows[[raw_index]] <- data.frame(
            rep_id = rep_id, rep_seed = rep_seed, n = n, tau = tau,
            kappa = kappa, estimator = estimator, alpha_true = truth,
            alpha_hat = alpha_hat,
            signed_error = alpha_hat - truth,
            authors_style_bias = truth - alpha_hat,
            abs_error = abs(alpha_hat - truth),
            squared_error = (alpha_hat - truth)^2,
            W_true = W_true, covered = covered,
            rejected_true = rejected_true,
            accepted_set_measure_A = accepted_set_measure_A,
            cr_any_accepted = any(cr_accepted, na.rm = TRUE),
            full_A_accepted = all(!is.na(cr_accepted)) && all(cr_accepted),
            cr_left_boundary_accepted = cr_accepted[1],
            cr_right_boundary_accepted = cr_accepted[length(cr_accepted)],
            cr_n_components_grid = count_components(cr_accepted),
            point_left_boundary = is.finite(alpha_hat) &&
              alpha_hat == PARAMETER_LOWER,
            point_right_boundary = is.finite(alpha_hat) &&
              alpha_hat == PARAMETER_UPPER,
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
              rep_id = rep_id, rep_seed = rep_seed, n = n, tau = tau,
              kappa = kappa, estimator = estimator,
              delta = POWER_DELTAS[delta_index],
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
  diagnostics <- if (length(diagnostic_rows)) {
    do.call(rbind, diagnostic_rows)
  } else empty_alpha_diagnostics()
  list(
    schema_version = FINAL_SCHEMA_VERSION,
    git_commit = git_commit,
    sample_size = sample_size,
    rep_id = rep_id,
    rep_seed = rep_seed,
    timestamp = format(end_time, tz = "Europe/Berlin", usetz = TRUE),
    R_version = R.version.string,
    package_versions = package_versions,
    frozen_config_snapshot = frozen_config_snapshot,
    rng_start = rng_start,
    rng_after_sample_size_advance = rng_after_sample_size_advance,
    rng_end = .Random.seed,
    start_time = start_time,
    end_time = end_time,
    elapsed_seconds = as.numeric(difftime(end_time, start_time, units = "secs")),
    primitive_audit = do.call(rbind, primitive_rows),
    raw = do.call(rbind, raw_rows),
    power = do.call(rbind, power_rows),
    diagnostics = diagnostics,
    bc_penalties = do.call(rbind, penalty_rows),
    penalty_count = penalty_count,
    reuse_checks = reuse_checks,
    truth_checks = truth_checks,
    power_checks = power_checks,
    profile_rng_checks = profile_rng_checks
  )
}

checkpoint_path <- function(rep_id) {
  file.path(checkpoint_dir, sprintf("replication_%04d.rds", rep_id))
}

validate_checkpoint <- function(checkpoint, rep_id) {
  expected_seed <- as.integer(FINAL_MASTER_SEED + rep_id)
    identical(checkpoint$schema_version, FINAL_SCHEMA_VERSION) &&
    identical(checkpoint$git_commit, git_commit) &&
    identical(checkpoint$sample_size, as.integer(sample_size)) &&
    identical(checkpoint$rep_id, as.integer(rep_id)) &&
    identical(checkpoint$rep_seed, expected_seed) &&
    identical(checkpoint$R_version, R.version.string) &&
    identical(checkpoint$package_versions, package_versions) &&
    identical(checkpoint$frozen_config_snapshot, frozen_config_snapshot) &&
    is.data.frame(checkpoint$raw) && nrow(checkpoint$raw) == 60L &&
    is.data.frame(checkpoint$power) && nrow(checkpoint$power) == 240L &&
    is.data.frame(checkpoint$diagnostics) &&
    is.data.frame(checkpoint$bc_penalties) &&
    nrow(checkpoint$bc_penalties) == 505L &&
    identical(checkpoint$penalty_count, 5L) &&
    all(checkpoint$reuse_checks) && all(checkpoint$truth_checks) &&
    all(checkpoint$power_checks) && all(checkpoint$profile_rng_checks)
}

read_valid_checkpoint <- function(rep_id) {
  path <- checkpoint_path(rep_id)
  checkpoint <- tryCatch(readRDS(path), error = function(condition) condition)
  if (inherits(checkpoint, "error") ||
      !validate_checkpoint(checkpoint, rep_id)) {
    stop("Incompatible or invalid checkpoint for rep_id ", rep_id, ": ", path)
  }
  checkpoint
}

save_checkpoint_atomic <- function(result) {
  final_path <- checkpoint_path(result$rep_id)
  if (file.exists(final_path)) {
    stop("Refusing to overwrite completed checkpoint: ", final_path)
  }
  temporary_path <- tempfile(
    paste0("replication_", sprintf("%04d", result$rep_id), "_"),
    tmpdir = checkpoint_dir, fileext = ".tmp"
  )
  saveRDS(result, temporary_path)
  installed <- file.rename(temporary_path, final_path)
  if (!installed) {
    if (file.exists(temporary_path)) unlink(temporary_path)
    stop("Could not atomically install checkpoint: ", final_path)
  }
  invisible(final_path)
}

log_path <- file.path(output_dir, "final_run_log.txt")
append_log <- function(...) {
  line <- paste(...)
  cat(format(Sys.time(), tz = "Europe/Berlin", usetz = TRUE), line, "\n",
      file = log_path, append = TRUE)
  cat(line, "\n")
}

existing_ids <- integer(0)
for (rep_id in active_rep_ids) {
  if (file.exists(checkpoint_path(rep_id))) {
    read_valid_checkpoint(rep_id)
    existing_ids <- c(existing_ids, rep_id)
  }
}
missing_ids <- setdiff(active_rep_ids, existing_ids)
append_log(
  "START", paste0("validation=", validation_mode),
  paste0("sample_size=", sample_size), paste0("workers=", workers),
  paste0("active_rep_ids=", paste(active_rep_ids, collapse = ",")),
  paste0("validated_existing=", paste(existing_ids, collapse = ",")),
  paste0("missing=", paste(missing_ids, collapse = ","))
)
if (length(existing_ids)) {
  for (rep_id in existing_ids) append_log("SKIP rep_id=", rep_id)
}

if (length(missing_ids) && workers == 1L) {
  for (rep_id in missing_ids) {
    result <- run_replication(rep_id)
    save_checkpoint_atomic(result)
    append_log("COMPLETE rep_id=", rep_id, "rep_seed=", result$rep_seed,
               "elapsed_seconds=", format(result$elapsed_seconds, digits = 12))
  }
} else if (length(missing_ids)) {
  cluster <- parallel::makeCluster(workers, type = "PSOCK")
  tryCatch({
    parallel::clusterCall(cluster, function(root, legacy_lib) {
      setwd(root)
      .libPaths(c(legacy_lib, .Library))
      suppressPackageStartupMessages({
        library(quantreg)
        library(hdm)
        library(mvtnorm)
      })
      NULL
    }, root_dir, legacy_library)
    worker_exports <- c(
      "FINAL_MASTER_SEED", "FINAL_SCHEMA_VERSION", "SAMPLE_SIZES", "TAUS",
      "KAPPA_CANDIDATES", "POINT_GRID", "CR_GRID", "POWER_DELTAS",
      "PARAMETER_LOWER", "PARAMETER_UPPER", "CRITICAL_VALUE", "CR_H",
      "sample_size", "active_sample_sizes",
      "package_versions", "git_commit", "frozen_config_snapshot",
      "alpha_true", "alpha_key", "make_union", "map_indices", "object_md5",
      "generate_primitives", "advance_rng_to_sample_size",
      "make_treatment_kappa", "make_dataset",
      ".finish_wn_profile", ".evaluate_profile_alpha", ".gmm_wn_profile",
      "oracle_wn_profile", "full_wn_profile", "bc_pivotal_lambda",
      "dml_wn_profile_bc", "run_profiles", "count_components",
      "combine_status", "empty_alpha_diagnostics", "run_replication"
    )
    parallel::clusterExport(cluster, worker_exports, envir = environment())
    position <- 1L
    while (position <= length(missing_ids)) {
      batch <- missing_ids[position:min(position + workers - 1L,
                                        length(missing_ids))]
      batch_results <- parallel::parLapply(
        cluster, batch, function(rep_id) run_replication(rep_id)
      )
      for (result in batch_results) {
        save_checkpoint_atomic(result)
        append_log("COMPLETE rep_id=", result$rep_id,
                   "rep_seed=", result$rep_seed,
                   "elapsed_seconds=", format(result$elapsed_seconds, digits = 12))
      }
      position <- position + length(batch)
    }
  }, finally = parallel::stopCluster(cluster))
}

paths <- vapply(active_rep_ids, checkpoint_path, character(1))
if (!all(file.exists(paths))) {
  stop("Cannot finalize; missing rep_ids: ",
       paste(active_rep_ids[!file.exists(paths)], collapse = ", "))
}
results <- lapply(active_rep_ids, read_valid_checkpoint)
raw <- do.call(rbind, lapply(results, `[[`, "raw"))
power <- do.call(rbind, lapply(results, `[[`, "power"))
diagnostics <- do.call(rbind, lapply(results, `[[`, "diagnostics"))
bc_penalties <- do.call(rbind, lapply(results, `[[`, "bc_penalties"))
primitive_audit <- do.call(rbind, lapply(results, `[[`, "primitive_audit"))
rownames(raw) <- NULL
rownames(power) <- NULL
rownames(diagnostics) <- NULL
rownames(bc_penalties) <- NULL
rownames(primitive_audit) <- NULL
raw <- raw[order(raw$rep_id, raw$n, raw$tau, -raw$kappa, raw$estimator), ]
power <- power[order(power$rep_id, power$n, power$tau, -power$kappa,
                     power$estimator, power$delta), ]
if (nrow(diagnostics)) {
  diagnostics <- diagnostics[order(
    diagnostics$rep_id, diagnostics$n, diagnostics$tau, -diagnostics$kappa,
    diagnostics$estimator, diagnostics$alpha
  ), ]
}
bc_penalties <- bc_penalties[order(
  bc_penalties$rep_id, bc_penalties$n, bc_penalties$tau,
  bc_penalties$lambda_index
), ]
primitive_audit <- primitive_audit[order(primitive_audit$rep_id,
                                         primitive_audit$n), ]

group_key <- interaction(raw$n, raw$tau, raw$kappa, raw$estimator,
                         drop = TRUE, lex.order = TRUE)
summary_rows <- lapply(split(raw, group_key), function(dat) {
  successful <- dat$status == "OK" & is.finite(dat$alpha_hat) &
    is.finite(dat$W_true) & is.finite(dat$accepted_set_measure_A) &
    !is.na(dat$covered) & !is.na(dat$rejected_true)
  valid <- dat[successful, ]
  n_success <- nrow(valid)
  coverage <- if (n_success) mean(valid$covered) else NA_real_
  size <- if (n_success) mean(valid$rejected_true) else NA_real_
  data.frame(
    n = dat$n[1], tau = dat$tau[1], kappa = dat$kappa[1],
    estimator = dat$estimator[1],
    mean_signed_error = if (n_success) mean(valid$signed_error) else NA_real_,
    Bias = if (n_success) mean(valid$authors_style_bias) else NA_real_,
    MAE = if (n_success) mean(valid$abs_error) else NA_real_,
    RMSE = if (n_success) sqrt(mean(valid$squared_error)) else NA_real_,
    coverage = coverage,
    size_null_rejection_rate = size,
    MCSE_coverage = if (n_success) {
      sqrt(coverage * (1 - coverage) / n_success)
    } else NA_real_,
    median_accepted_set_measure_A = if (n_success) {
      median(valid$accepted_set_measure_A)
    } else NA_real_,
    mean_accepted_set_measure_A = if (n_success) {
      mean(valid$accepted_set_measure_A)
    } else NA_real_,
    full_A_acceptance_rate = if (n_success) mean(valid$full_A_accepted) else NA_real_,
    left_CR_boundary_contact_rate = if (n_success) {
      mean(valid$cr_left_boundary_accepted)
    } else NA_real_,
    right_CR_boundary_contact_rate = if (n_success) {
      mean(valid$cr_right_boundary_accepted)
    } else NA_real_,
    point_left_boundary_rate = if (n_success) {
      mean(valid$point_left_boundary)
    } else NA_real_,
    point_right_boundary_rate = if (n_success) {
      mean(valid$point_right_boundary)
    } else NA_real_,
    numerical_failure_rate = mean(!successful),
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
  rejection_probability <- if (n_success) mean(valid$rejected_false) else NA_real_
  data.frame(
    n = dat$n[1], tau = dat$tau[1], kappa = dat$kappa[1],
    estimator = dat$estimator[1], delta = dat$delta[1],
    rejection_probability = rejection_probability,
    MCSE = if (n_success) {
      sqrt(rejection_probability * (1 - rejection_probability) / n_success)
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

replication_seeds <- data.frame(
  rep_id = active_rep_ids,
  rep_seed = as.integer(FINAL_MASTER_SEED + active_rep_ids),
  stringsAsFactors = FALSE
)

expected_raw_rows <- length(active_rep_ids) * 60L
expected_power_rows <- length(active_rep_ids) * 240L
expected_penalty_count <- length(active_rep_ids) * 5L
sanity <- c(
  coverage_complement = all(
    is.na(raw$covered) | is.na(raw$rejected_true) |
      (as.integer(raw$covered) + as.integer(raw$rejected_true) == 1L)
  ),
  accepted_measure_bounds = all(is.na(raw$accepted_set_measure_A) |
    (raw$accepted_set_measure_A >= 0 & raw$accepted_set_measure_A <= 4)),
  alpha_hat_bounds = all(is.na(raw$alpha_hat) |
    (raw$alpha_hat >= PARAMETER_LOWER & raw$alpha_hat <= PARAMETER_UPPER)),
  power_inside_A = all(power$alpha_false >= PARAMETER_LOWER &
                         power$alpha_false <= PARAMETER_UPPER),
  signed_error_definition = max(abs(
    raw$signed_error - (raw$alpha_hat - raw$alpha_true)
  ), na.rm = TRUE) <= 1e-12,
  authors_bias_definition = max(abs(
    raw$authors_style_bias - (raw$alpha_true - raw$alpha_hat)
  ), na.rm = TRUE) <= 1e-12,
  row_counts = nrow(raw) == expected_raw_rows &&
    nrow(power) == expected_power_rows &&
    nrow(summary) == EXPECTED_SUMMARY_ROWS_PER_SAMPLE_SIZE &&
    nrow(power_summary) == EXPECTED_POWER_SUMMARY_ROWS_PER_SAMPLE_SIZE,
  penalty_count = sum(vapply(results, `[[`, integer(1), "penalty_count")) ==
    expected_penalty_count,
  penalty_rows = nrow(bc_penalties) == expected_penalty_count * 101L,
  seed_mapping = identical(raw$rep_seed,
    as.integer(FINAL_MASTER_SEED + raw$rep_id)),
  reuse = all(unlist(lapply(results, `[[`, "reuse_checks"))),
  truth_mapping = all(unlist(lapply(results, `[[`, "truth_checks"))),
  power_mapping = all(unlist(lapply(results, `[[`, "power_checks"))),
  estimator_profiles_do_not_consume_rng = all(unlist(lapply(
    results, `[[`, "profile_rng_checks"
  )))
)
if (!validation_mode) {
  sanity <- c(sanity,
    final_raw_rows = nrow(raw) == EXPECTED_RAW_ROWS_PER_SAMPLE_SIZE,
    final_power_rows = nrow(power) == EXPECTED_POWER_ROWS_PER_SAMPLE_SIZE,
    final_summary_rows = nrow(summary) ==
      EXPECTED_SUMMARY_ROWS_PER_SAMPLE_SIZE,
    final_power_summary_rows = nrow(power_summary) ==
      EXPECTED_POWER_SUMMARY_ROWS_PER_SAMPLE_SIZE,
    final_bc_penalties = expected_penalty_count ==
      EXPECTED_BC_PENALTIES_PER_SAMPLE_SIZE,
    final_checkpoint_count = length(paths) ==
      FINAL_MC_REPS_PER_SAMPLE_SIZE
  )
}
if (!all(sanity)) {
  stop("Finalization validation failed: ",
       paste(names(sanity)[!sanity], collapse = ", "))
}

options(digits = 17)
write.csv(raw, file.path(output_dir, "final_raw.csv"), row.names = FALSE)
write.csv(power, file.path(output_dir, "final_power.csv"), row.names = FALSE)
write.csv(summary, file.path(output_dir, "final_summary.csv"), row.names = FALSE)
write.csv(power_summary, file.path(output_dir, "final_power_summary.csv"),
          row.names = FALSE)
write.csv(diagnostics, file.path(output_dir, "final_diagnostics.csv"),
          row.names = FALSE)
write.csv(replication_seeds,
          file.path(output_dir, "final_replication_seeds.csv"),
          row.names = FALSE)
writeLines(capture.output(sessionInfo()),
           file.path(output_dir, "final_sessionInfo.txt"))

earliest_start <- min(vapply(results, function(x) as.numeric(x$start_time), numeric(1)))
latest_end <- max(vapply(results, function(x) as.numeric(x$end_time), numeric(1)))
total_replication_seconds <- sum(vapply(
  results, `[[`, numeric(1), "elapsed_seconds"
))
output_filenames <- c(
  "final_raw.csv", "final_power.csv", "final_summary.csv",
  "final_power_summary.csv", "final_diagnostics.csv",
  "final_replication_seeds.csv", "final_sessionInfo.txt",
  "final_manifest.txt", "final_run_log.txt"
)
manifest <- c(
  "FROZEN FINAL MONTE CARLO MANIFEST",
  paste("schema_version:", FINAL_SCHEMA_VERSION),
  paste("validation_mode:", validation_mode),
  paste("sample_size:", sample_size),
  paste("git_commit:", git_commit),
  paste("git_status_entries_at_start:", length(git_status_at_start)),
  paste("freeze_document_md5:", freeze_hash),
  paste("final_master_seed:", FINAL_MASTER_SEED),
  paste("Monte_Carlo_replications_for_sample_size:", length(active_rep_ids)),
  paste("rep_ids:", paste(active_rep_ids, collapse = ",")),
  paste("start_time:", format(as.POSIXct(earliest_start, origin = "1970-01-01"),
                              tz = "Europe/Berlin", usetz = TRUE)),
  paste("end_time:", format(as.POSIXct(latest_end, origin = "1970-01-01"),
                            tz = "Europe/Berlin", usetz = TRUE)),
  paste("sum_replication_elapsed_seconds:",
        format(total_replication_seconds, digits = 17)),
  paste("workers:", workers),
  paste("R_version:", R.version.string),
  paste("package_versions:", paste(names(package_versions), package_versions,
                                    sep = "=", collapse = ";")),
  paste("raw_rows:", nrow(raw)),
  paste("power_rows:", nrow(power)),
  paste("summary_rows:", nrow(summary)),
  paste("power_summary_rows:", nrow(power_summary)),
  paste("diagnostic_rows:", nrow(diagnostics)),
  paste("checkpoint_count:", length(paths)),
  paste("BC_penalty_vectors:", expected_penalty_count),
  paste("BC_penalty_coefficients_stored_in_checkpoints:", nrow(bc_penalties)),
  paste("raw_profiles_with_numerical_failure:",
        sum(summary$failed_replications)),
  paste("power_rows_with_failure:", sum(power_summary$failed_replications)),
  paste("executed_rep_ids_this_invocation:", paste(missing_ids, collapse = ",")),
  paste("skipped_rep_ids_this_invocation:", paste(existing_ids, collapse = ",")),
  paste("output_filenames:", paste(output_filenames, collapse = ",")),
  "source_file_md5:",
  paste(names(source_hashes), source_hashes, sep = " = "),
  paste("all_sanity_checks:", all(sanity))
)
writeLines(manifest, file.path(output_dir, "final_manifest.txt"))
append_log("FINALIZED", paste0("raw_rows=", nrow(raw)),
           paste0("power_rows=", nrow(power)),
           paste0("diagnostic_rows=", nrow(diagnostics)),
           paste0("all_sanity_checks=", all(sanity)))
cat(paste(manifest, collapse = "\n"), "\n")
