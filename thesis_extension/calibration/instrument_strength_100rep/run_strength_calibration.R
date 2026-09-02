# Current-compatible reproduction of the archived 100-replication
# descriptive instrument-strength calibration. This is not an IVQR estimator.

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
if (length(script_arg) != 1L) stop("Run this file with Rscript.")
script_path <- normalizePath(sub("^--file=", "", script_arg[1]),
                             winslash = "/", mustWork = TRUE)
calibration_dir <- dirname(script_path)
extension_root <- normalizePath(file.path(calibration_dir, "..", ".."),
                                winslash = "/", mustWork = TRUE)

source(file.path(extension_root, "environment", "check_author_environment.R"))
assert_author_environment(extension_root, write_outputs = FALSE)
source(file.path(extension_root, "config", "extension_config.R"))
source(file.path(extension_root, "src", "dgp_kappa.R"))

args <- commandArgs(trailingOnly = TRUE)
if (!"--execute-calibration" %in% args) {
  stop("Calibration is guarded. Add --execute-calibration only after review.")
}

PILOT_SEED <- 20260813L
N_REPLICATIONS <- 100L
SAMPLE_SIZES <- c(500L, 1000L)
KAPPA_VALUES <- c(1.00, 0.50, 0.25, 0.10)
P <- 100L
Q_EXCLUDED <- 2L
K_UNRESTRICTED <- 13L

stopifnot(
  identical(SAMPLE_SIZES, extension_config$sample_sizes),
  identical(KAPPA_VALUES, extension_config$kappa),
  N_REPLICATIONS == 100L,
  P == extension_config$p
)

empty_row <- function(replication, n, kappa, status) {
  data.frame(
    replication = replication, n = n, kappa = kappa,
    first_stage_F = NA_real_, partial_R2 = NA_real_,
    beta_Z1 = NA_real_, beta_Z2 = NA_real_,
    R2_restricted = NA_real_, R2_unrestricted = NA_real_,
    RSS_restricted = NA_real_, RSS_unrestricted = NA_real_,
    nested_F = NA_real_, partial_R2_from_model_R2 = NA_real_,
    cov_z1_d_latent = NA_real_, cov_z2_d_latent = NA_real_,
    status = status, stringsAsFactors = FALSE)
}

safe_stats <- function(values) {
  values <- values[is.finite(values)]
  if (!length(values)) {
    return(c(mean = NA_real_, median = NA_real_, sd = NA_real_,
             p10 = NA_real_, p90 = NA_real_, min = NA_real_, max = NA_real_))
  }
  c(mean = mean(values), median = median(values), sd = sd(values),
    p10 = unname(quantile(values, 0.10)),
    p90 = unname(quantile(values, 0.90)),
    min = min(values), max = max(values))
}

set.seed(PILOT_SEED)
warning_log <- character(0)
raw_rows <- vector("list", N_REPLICATIONS * length(SAMPLE_SIZES) *
                   length(KAPPA_VALUES))
row_index <- 0L
identity_checks <- 0L
common_draw_checks <- 0L

for (n in SAMPLE_SIZES) {
  for (replication in seq_len(N_REPLICATIONS)) {
    # generate_kappa_primitives preserves the authors' primitive draw order
    # and draws the extension-only w last.
    primitives <- generate_kappa_primitives(n = n, p = P)
    primitive_reference <- primitives
    d_original <- primitives$z1 + primitives$z2 + primitives$epsilon
    D_original <- pnorm(d_original)

    baseline <- make_kappa_dataset(primitives, kappa = 1,
                                   s = extension_config$s)
    if (!identical(baseline$d, d_original) ||
        !identical(baseline$D, D_original)) {
      stop("kappa=1 identity failed at n=", n,
           ", replication=", replication, ".")
    }
    identity_checks <- identity_checks + 1L

    for (kappa in KAPPA_VALUES) {
      row_index <- row_index + 1L
      if (!identical(primitives, primitive_reference)) {
        stop("Primitive object changed at n=", n,
             ", replication=", replication, ", kappa=", kappa, ".")
      }
      common_draw_checks <- common_draw_checks + 1L

      row_result <- tryCatch(
        withCallingHandlers({
          dataset <- make_kappa_dataset(primitives, kappa = kappa,
                                        s = extension_config$s)
          X10 <- dataset$X[, 1:10, drop = FALSE]
          colnames(X10) <- paste0("X", seq_len(10L))
          restricted_data <- data.frame(D = dataset$D, X10)
          unrestricted_data <- data.frame(
            D = dataset$D, X10,
            Z1 = dataset$Z[, 1], Z2 = dataset$Z[, 2])

          restricted_fit <- lm(D ~ ., data = restricted_data)
          unrestricted_fit <- lm(D ~ ., data = unrestricted_data)
          if (restricted_fit$rank != 11L ||
              unrestricted_fit$rank != K_UNRESTRICTED) {
            stop("Unexpected regression rank: restricted=",
                 restricted_fit$rank, ", unrestricted=",
                 unrestricted_fit$rank, ".")
          }

          RSS_R <- sum(residuals(restricted_fit)^2)
          RSS_U <- sum(residuals(unrestricted_fit)^2)
          TSS <- sum((dataset$D - mean(dataset$D))^2)
          R2_R <- 1 - RSS_R / TSS
          R2_U <- 1 - RSS_U / TSS
          F_manual <- ((RSS_R - RSS_U) / Q_EXCLUDED) /
            (RSS_U / (n - K_UNRESTRICTED))
          F_nested <- anova(restricted_fit, unrestricted_fit)$F[2]
          partial_R2_rss <- (RSS_R - RSS_U) / RSS_R
          partial_R2_models <- (R2_U - R2_R) / (1 - R2_R)

          f_tolerance <- sqrt(.Machine$double.eps) *
            max(1, abs(F_manual), abs(F_nested))
          r2_tolerance <- sqrt(.Machine$double.eps) *
            max(1, abs(partial_R2_rss), abs(partial_R2_models))
          if (!is.finite(F_manual) || !is.finite(F_nested) ||
              abs(F_manual - F_nested) > f_tolerance) {
            stop("Manual and nested-model F-statistics disagree.")
          }
          if (!is.finite(partial_R2_rss) ||
              !is.finite(partial_R2_models) ||
              abs(partial_R2_rss - partial_R2_models) > r2_tolerance) {
            stop("Partial-R2 formulas disagree.")
          }

          coefficients_U <- coef(unrestricted_fit)
          data.frame(
            replication = replication, n = n, kappa = kappa,
            first_stage_F = F_manual,
            partial_R2 = partial_R2_rss,
            beta_Z1 = unname(coefficients_U["Z1"]),
            beta_Z2 = unname(coefficients_U["Z2"]),
            R2_restricted = R2_R, R2_unrestricted = R2_U,
            RSS_restricted = RSS_R, RSS_unrestricted = RSS_U,
            nested_F = F_nested,
            partial_R2_from_model_R2 = partial_R2_models,
            cov_z1_d_latent = cov(primitives$z1, dataset$d),
            cov_z2_d_latent = cov(primitives$z2, dataset$d),
            status = "OK", stringsAsFactors = FALSE)
        }, warning = function(warning_condition) {
          warning_log <<- c(
            warning_log,
            paste0("n=", n, ", replication=", replication,
                   ", kappa=", kappa, ": ",
                   conditionMessage(warning_condition)))
          invokeRestart("muffleWarning")
        }),
        error = function(error_condition) {
          empty_row(replication, n, kappa,
                    paste0("ERROR: ", conditionMessage(error_condition)))
        })
      raw_rows[[row_index]] <- row_result
    }
  }
}

raw_results <- do.call(rbind, raw_rows)
expected_rows <- N_REPLICATIONS * length(SAMPLE_SIZES) * length(KAPPA_VALUES)
if (nrow(raw_results) != expected_rows) {
  stop("Expected ", expected_rows, " rows; found ", nrow(raw_results), ".")
}

summary_rows <- vector("list", length(SAMPLE_SIZES) * length(KAPPA_VALUES))
summary_index <- 0L
for (n in SAMPLE_SIZES) {
  for (kappa in KAPPA_VALUES) {
    summary_index <- summary_index + 1L
    group <- raw_results[raw_results$n == n & raw_results$kappa == kappa, ]
    successful <- group$status == "OK"
    f_stats <- safe_stats(group$first_stage_F[successful])
    r2_stats <- safe_stats(group$partial_R2[successful])
    summary_rows[[summary_index]] <- data.frame(
      n = n, kappa = kappa,
      F_mean = f_stats["mean"], F_median = f_stats["median"],
      F_sd = f_stats["sd"], F_p10 = f_stats["p10"],
      F_p90 = f_stats["p90"], F_min = f_stats["min"],
      F_max = f_stats["max"],
      partial_R2_mean = r2_stats["mean"],
      partial_R2_median = r2_stats["median"],
      partial_R2_sd = r2_stats["sd"],
      partial_R2_p10 = r2_stats["p10"],
      partial_R2_p90 = r2_stats["p90"],
      partial_R2_min = r2_stats["min"],
      partial_R2_max = r2_stats["max"],
      n_success = sum(successful), n_failed = sum(!successful),
      stringsAsFactors = FALSE)
  }
}
summary_results <- do.call(rbind, summary_rows)
rownames(summary_results) <- NULL

output_dir <- file.path(calibration_dir, "current_reproduction_output")
if (dir.exists(output_dir) && length(list.files(output_dir, all.files = TRUE,
                                                no.. = TRUE))) {
  stop("Refusing to overwrite non-empty output directory: ", output_dir)
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(raw_results, file.path(output_dir, "kappa_strength_raw.csv"),
          row.names = FALSE)
write.csv(summary_results,
          file.path(output_dir, "kappa_strength_summary.csv"),
          row.names = FALSE)

f_report <- summary_results[, c("n", "kappa", "F_mean", "F_median")]
r2_report <- summary_results[, c(
  "n", "kappa", "partial_R2_mean", "partial_R2_median")]
n_failed <- sum(raw_results$status != "OK")
report <- c(
  "DML-IVQR descriptive instrument-strength calibration reproduction",
  "", paste("R version:", R.version.string),
  paste("Pilot seed:", PILOT_SEED),
  paste("Replications per sample size:", N_REPLICATIONS),
  paste("Sample sizes:", paste(SAMPLE_SIZES, collapse = ", ")),
  paste("Candidate kappa values:",
        paste(format(KAPPA_VALUES, nsmall = 2), collapse = ", ")),
  paste("Expected and observed design rows:", expected_rows), "",
  "Restricted regression: D(kappa) ~ 1 + X1 + ... + X10",
  "Unrestricted regression: D(kappa) ~ 1 + X1 + ... + X10 + Z1 + Z2",
  "Z1 and Z2 are observed instruments; X1 through X10 are controls.",
  "One current-API primitive object is reused across kappa per replication.",
  "", paste("kappa=1 exact baseline identity checks passed:", identity_checks),
  paste("Common-draw invariant checks passed:", common_draw_checks),
  "Manual and nested-model F-statistics agreed for every successful row.",
  "Both partial-R2 formulas agreed for every successful row.", "",
  "Mean and median joint first-stage F-statistics:",
  capture.output(print(f_report, row.names = FALSE, digits = 8)), "",
  "Mean and median partial R-squared:",
  capture.output(print(r2_report, row.names = FALSE, digits = 8)), "",
  paste("Failed design rows:", n_failed),
  paste("Warnings captured:", length(warning_log)),
  if (length(warning_log)) c("Warning details:", unique(warning_log)) else
    "Warning details: none", "",
  "These statistics descriptively calibrate the simulation design.",
  "They are not formal IVQR identification statistics.")
writeLines(report, file.path(output_dir, "kappa_strength_report.txt"))
cat(paste(report, collapse = "\n"), "\n")
