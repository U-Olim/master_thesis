# Deterministic, read-only reporting build for the frozen thesis evidence.

args <- commandArgs(trailingOnly = TRUE)
if (!identical(args, "--build-reporting")) {
  stop("Specify exactly --build-reporting. No output has been created.")
}

options(stringsAsFactors = FALSE, warn = 2)
start_time <- Sys.time()

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
if (length(script_arg) != 1L) stop("Run this file with Rscript.")
script_path <- normalizePath(sub("^--file=", "", script_arg[1L]),
                             winslash = "/", mustWork = TRUE)
report_dir <- dirname(script_path)
repo_root <- normalizePath(file.path(report_dir, "..", ".."),
                           winslash = "/", mustWork = TRUE)
setwd(repo_root)

if (R.version$major != "3" || R.version$minor != "4.3") {
  stop("Canonical R 3.4.3 is required; found ", R.version.string, ".")
}
extension_root <- file.path(repo_root, "thesis_extension")
source(file.path(extension_root, "environment", "check_author_environment.R"))
assert_author_environment(extension_root, write_outputs = FALSE)
if (!requireNamespace("digest", quietly = TRUE)) {
  stop("The preserved digest package is required for SHA-256 manifests.")
}

expected_commit <- "ac9a9ccad027cde05488abb633e66cc02f87cc46"
repo_commit <- trimws(system2("git", c("rev-parse", "HEAD"), stdout = TRUE))
if (!identical(repo_commit, expected_commit)) {
  stop("Unexpected repository commit: ", repo_commit)
}

output_dir <- file.path(report_dir, "output")
figure_dir <- file.path(report_dir, "figures")
reporting_manifest_path <- file.path(report_dir, "REPORTING_OUTPUT_MANIFEST.csv")
empirical_manifest_path <- file.path(report_dir, "EMPIRICAL_RESULTS_MANIFEST.csv")

for (d in c(output_dir, figure_dir)) {
  if (dir.exists(d) && length(list.files(d, all.files = TRUE, no.. = TRUE))) {
    stop("Refusing to overwrite non-empty reporting directory: ", d)
  }
}
if (file.exists(reporting_manifest_path) || file.exists(empirical_manifest_path)) {
  stop("Refusing to overwrite an existing reporting manifest.")
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

slash <- function(x) gsub("\\\\", "/", x)
relative_to_repo <- function(x) {
  x <- slash(normalizePath(x, winslash = "/", mustWork = TRUE))
  prefix <- paste0(slash(repo_root), "/")
  if (!startsWith(x, prefix)) stop("Path is outside the repository: ", x)
  substring(x, nchar(prefix) + 1L)
}
sha256_file <- function(path) {
  unname(digest::digest(file = path, algo = "sha256", serialize = FALSE))
}
list_regular_files <- function(path) {
  files <- list.files(path, recursive = TRUE, all.files = TRUE,
                      full.names = TRUE, include.dirs = FALSE)
  info <- file.info(files)
  sort(files[!is.na(info$isdir) & !info$isdir])
}
assert_columns <- function(x, required, label) {
  missing <- setdiff(required, names(x))
  if (length(missing)) stop(label, " is missing columns: ", paste(missing, collapse = ", "))
}
read_csv <- function(path, required = character(0)) {
  if (!file.exists(path)) stop("Missing canonical input: ", path)
  x <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  assert_columns(x, required, path)
  x
}
write_csv <- function(x, name) {
  path <- file.path(output_dir, name)
  write.csv(x, path, row.names = FALSE, na = "")
  path
}
cell_key <- function(x) {
  paste(as.integer(x$n), sprintf("%.2f", as.numeric(x$tau)),
        sprintf("%.2f", as.numeric(x$kappa)), as.character(x$estimator), sep = "|")
}
power_key <- function(x) paste(cell_key(x), sprintf("%+.2f", as.numeric(x$Delta)), sep = "|")
order_cells <- function(x, delta = FALSE) {
  estimator_order <- c("Oracle-GMM", "Full-GMM", "DML-IVQR-BC")
  kappa_order <- c(1, .5, .25, .1)
  pieces <- list(as.numeric(x$n), as.numeric(x$tau),
                 match(as.numeric(x$kappa), kappa_order),
                 match(as.character(x$estimator), estimator_order))
  if (delta) pieces[[5L]] <- as.numeric(x$Delta)
  do.call(order, pieces)
}
same_numeric <- function(x, y, tolerance = 1e-12) {
  if (length(x) != length(y) || any(is.na(x) != is.na(y))) return(FALSE)
  keep <- !is.na(x)
  !length(keep) || all(abs(as.numeric(x[keep]) - as.numeric(y[keep])) <= tolerance)
}

# Canonical input inventory. Reporting itself is deliberately excluded.
canonical_roots <- c(
  file.path(repo_root, "thesis_extension", "final", "output", "n500"),
  file.path(repo_root, "thesis_extension", "final", "output", "n1000"),
  file.path(repo_root, "thesis_extension", "diagnostics", "grid_sensitivity", "output", "stage1"),
  file.path(repo_root, "thesis_extension", "diagnostics", "grid_sensitivity", "output", "stage2"),
  file.path(repo_root, "thesis_extension", "diagnostics", "coverage_audit"),
  file.path(repo_root, "thesis_extension", "calibration", "instrument_strength_100rep"),
  file.path(repo_root, "thesis_extension", "validation", "R343_final_audit"),
  file.path(repo_root, "thesis_extension", "environment")
)
if (any(!dir.exists(canonical_roots))) {
  stop("One or more canonical input directories are missing.")
}
canonical_abs <- unique(unlist(lapply(canonical_roots, list_regular_files)))
canonical_abs <- c(canonical_abs,
  file.path(repo_root, "thesis_extension", "diagnostics", "grid_sensitivity",
            "GRID_RESULTS_MANIFEST.csv"),
  file.path(repo_root, "thesis_extension", "diagnostics", "grid_sensitivity",
            "GRID_RESULTS_PROVENANCE.md"))
canonical_abs <- sort(unique(normalizePath(canonical_abs, winslash = "/", mustWork = TRUE)))
canonical_rel <- vapply(canonical_abs, relative_to_repo, character(1))

role_for <- function(path) {
  if (startsWith(path, "thesis_extension/final/output/")) return("main R=500 Monte Carlo")
  if (startsWith(path, "thesis_extension/diagnostics/grid_sensitivity/")) return("grid-domain diagnostic")
  if (startsWith(path, "thesis_extension/diagnostics/coverage_audit/")) return("coverage forensic audit")
  if (startsWith(path, "thesis_extension/calibration/instrument_strength_100rep/")) return("instrument-strength calibration")
  if (startsWith(path, "thesis_extension/validation/R343_final_audit/")) return("validation provenance")
  if (startsWith(path, "thesis_extension/environment/")) return("R environment provenance")
  stop("Unclassified canonical input: ", path)
}

tracked <- slash(system2("git", "ls-files", stdout = TRUE))
ignored <- slash(system2("git", c("ls-files", "--others", "--ignored", "--exclude-standard"),
                         stdout = TRUE))
tracking_status <- ifelse(canonical_rel %in% tracked, "tracked",
                          ifelse(canonical_rel %in% ignored, "ignored", "untracked"))
if (any(tracking_status == "untracked")) {
  stop("Unexpected untracked canonical inputs: ",
       paste(canonical_rel[tracking_status == "untracked"], collapse = ", "))
}

input_hash_before <- vapply(canonical_abs, sha256_file, character(1))
input_bytes_before <- as.numeric(file.info(canonical_abs)$size)
empirical_manifest <- data.frame(
  relative_path = canonical_rel,
  bytes = format(input_bytes_before, scientific = FALSE, trim = TRUE),
  sha256 = input_hash_before,
  role = vapply(canonical_rel, role_for, character(1)),
  git_status = tracking_status,
  stringsAsFactors = FALSE
)
write.csv(empirical_manifest, empirical_manifest_path, row.names = FALSE)

# Read only canonical aggregate evidence.
summary_required <- c("n", "tau", "kappa", "estimator", "Bias", "MAE", "RMSE",
  "Coverage", "Size", "median_grid_accepted_set_measure", "mean_grid_accepted_set_measure",
  "median_accepted_grid_share", "mean_accepted_grid_share", "mean_number_accepted_grid_points",
  "left_boundary_acceptance_rate", "right_boundary_acceptance_rate",
  "either_boundary_acceptance_rate", "both_boundaries_acceptance_rate",
  "all_41_acceptance_rate", "numerical_failures")
summary_all <- rbind(
  read_csv(file.path(repo_root, "thesis_extension/final/output/n500/summary.csv"), summary_required),
  read_csv(file.path(repo_root, "thesis_extension/final/output/n1000/summary.csv"), summary_required))

power_required <- c("n", "tau", "kappa", "estimator", "Delta", "power",
                    "false_acceptance", "successful_power_evaluations",
                    "failed_power_evaluations", "numerical_failures")
power_all <- rbind(
  read_csv(file.path(repo_root, "thesis_extension/final/output/n500/power_summary.csv"), power_required),
  read_csv(file.path(repo_root, "thesis_extension/final/output/n1000/power_summary.csv"), power_required))

coverage_all <- read_csv(file.path(repo_root,
  "thesis_extension/diagnostics/coverage_audit/output/coverage_audit_all_cells.csv"),
  c("n", "tau", "kappa", "estimator", "R_available", "empirical_coverage",
    "empirical_size", "coverage_mcse", "coverage_mc95_lower", "coverage_mc95_upper"))
coverage_strong <- read_csv(file.path(repo_root,
  "thesis_extension/diagnostics/coverage_audit/output/coverage_audit_strong_kappa_n1000.csv"),
  c("n", "tau", "kappa", "estimator", "empirical_coverage", "empirical_size",
    "coverage_mcse", "coverage_mc95_lower", "coverage_mc95_upper", "median_W_true",
    "q90_W_true", "q95_W_true", "q99_W_true", "mean_W_true",
    "q95_ratio_to_chisq2_q95"))

strength <- read_csv(file.path(repo_root,
  "thesis_extension/calibration/instrument_strength_100rep/kappa_strength_summary.csv"),
  c("n", "kappa", "F_median", "F_sd", "F_p10", "F_p90",
    "partial_R2_median", "partial_R2_sd", "partial_R2_p10", "partial_R2_p90",
    "n_success", "n_failed"))
strength_raw <- read_csv(file.path(repo_root,
  "thesis_extension/calibration/instrument_strength_100rep/kappa_strength_raw.csv"),
  c("replication", "n", "kappa", "first_stage_F", "partial_R2", "status"))

grid_root <- file.path(repo_root, "thesis_extension/diagnostics/grid_sensitivity/output")
stage2_summary <- read_csv(file.path(grid_root, "stage2/stage2_summary.csv"),
  c("n", "tau", "kappa", "estimator", "range", "total_replications",
    "successful_profiles", "failed_profiles", "median_grid_accepted_set_measure",
    "mean_grid_accepted_set_measure", "either_boundary_acceptance_rate",
    "all_grid_points_acceptance_rate"))
stage2_expansion <- read_csv(file.path(grid_root, "stage2/stage2_expansion_summary.csv"),
  c("n", "tau", "kappa", "estimator", "median_added_measure_A0_to_A1",
    "mean_added_measure_A0_to_A1", "median_added_measure_A1_to_A2",
    "mean_added_measure_A1_to_A2", "boundary_acceptance_rate_A0",
    "boundary_acceptance_rate_A1", "boundary_acceptance_rate_A2",
    "all_grid_acceptance_rate_A0", "all_grid_acceptance_rate_A1",
    "all_grid_acceptance_rate_A2"))
stage1_failures <- read_csv(file.path(grid_root, "stage1/stage1_failures.csv"),
  c("n", "replication", "tau", "kappa", "estimator", "a", "stage", "error_message"))
stage2_failures <- read_csv(file.path(grid_root, "stage2/stage2_failures.csv"),
  c("n", "replication", "tau", "kappa", "estimator", "a", "stage", "error_message"))
main_failures <- rbind(
  read_csv(file.path(repo_root, "thesis_extension/final/output/n500/failures.csv"),
           c("n", "replication", "tau", "kappa", "estimator", "a", "stage", "error_message")),
  read_csv(file.path(repo_root, "thesis_extension/final/output/n1000/failures.csv"),
           c("n", "replication", "tau", "kappa", "estimator", "a", "stage", "error_message")))

expected_cells <- expand.grid(
  n = c(500, 1000), tau = c(.10, .25, .50, .75, .90),
  kappa = c(1, .5, .25, .1),
  estimator = c("Oracle-GMM", "Full-GMM", "DML-IVQR-BC"),
  stringsAsFactors = FALSE)
expected_power <- merge(expected_cells,
  data.frame(Delta = c(-1, -.5, -.25, .25, .5, 1), stringsAsFactors = FALSE))
if (nrow(summary_all) != 120L || anyDuplicated(cell_key(summary_all)) ||
    !setequal(cell_key(summary_all), cell_key(expected_cells))) {
  stop("Canonical summary cells are missing, duplicated, or unexpected.")
}
if (nrow(power_all) != 720L || anyDuplicated(power_key(power_all)) ||
    !setequal(power_key(power_all), power_key(expected_power))) {
  stop("Canonical power cells are missing, duplicated, or unexpected.")
}
if (nrow(coverage_all) != 120L || anyDuplicated(cell_key(coverage_all)) ||
    !setequal(cell_key(coverage_all), cell_key(expected_cells))) {
  stop("Coverage-audit cells are missing, duplicated, or unexpected.")
}
if (nrow(coverage_strong) != 15L || any(coverage_strong$n != 1000) ||
    any(abs(coverage_strong$kappa - 1) > 1e-14)) {
  stop("Strong-kappa coverage table is malformed.")
}
if (nrow(strength) != 8L || nrow(strength_raw) != 800L ||
    any(strength$n_success != 100L) || any(strength$n_failed != 0L) ||
    any(strength_raw$status != "OK")) {
  stop("Preserved 100-replication strength calibration is incomplete.")
}
if (nrow(stage2_summary) != 135L || nrow(stage2_expansion) != 45L ||
    nrow(stage1_failures) != 1L || nrow(stage2_failures) != 0L ||
    nrow(main_failures) != 0L || any(summary_all$numerical_failures != 0L)) {
  stop("Failure counts or grid diagnostic dimensions differ from the freeze.")
}

# Table 1: descriptive instrument-strength calibration.
strength_table <- strength[, c("n", "kappa", "F_median", "F_p10", "F_p90", "F_sd",
  "partial_R2_median", "partial_R2_p10", "partial_R2_p90", "partial_R2_sd",
  "n_success", "n_failed")]
strength_table <- strength_table[order(strength_table$n,
  match(strength_table$kappa, c(1, .5, .25, .1))), ]
names(strength_table)[3:6] <- c("median_first_stage_F", "first_stage_F_p10",
  "first_stage_F_p90", "first_stage_F_sd")
write_csv(strength_table, "table_strength_calibration.csv")

# Point performance: copied from canonical summaries.
point_full <- summary_all[, c("n", "tau", "kappa", "estimator", "Bias", "MAE", "RMSE")]
point_full <- point_full[order_cells(point_full), ]
write_csv(point_full, "table_point_performance_full.csv")
point_main <- point_full[point_full$n == 1000 & point_full$tau %in% c(.10, .50, .90), ]
write_csv(point_main, "table_point_performance_main.csv")

# Confidence-set informativeness in the finite primary domain.
cr_columns <- c("n", "tau", "kappa", "estimator",
  "median_grid_accepted_set_measure", "mean_grid_accepted_set_measure",
  "median_accepted_grid_share", "mean_accepted_grid_share",
  "mean_number_accepted_grid_points", "left_boundary_acceptance_rate",
  "right_boundary_acceptance_rate", "either_boundary_acceptance_rate",
  "both_boundaries_acceptance_rate", "all_41_acceptance_rate")
cr_full <- summary_all[, cr_columns]
cr_full$computational_domain <- "A0=[-1,3]"
cr_full$measure_definition <- paste("grid-based accepted-set measure within the prespecified",
                                    "primary computational domain A0=[-1,3]")
cr_full <- cr_full[order_cells(cr_full), ]
write_csv(cr_full, "table_cr_informativeness_full.csv")
cr_main <- cr_full[cr_full$n == 1000 & cr_full$tau %in% c(.10, .50, .90), ]
write_csv(cr_main, "table_cr_informativeness_main.csv")

# Grid-domain diagnostic: one wide row per Stage-2 design cell.
grid_cells <- unique(stage2_expansion[, c("n", "tau", "kappa", "estimator")])
grid_cells <- grid_cells[order(grid_cells$tau,
  match(grid_cells$kappa, c(1, .25, .1)),
  match(grid_cells$estimator, c("Oracle-GMM", "Full-GMM", "DML-IVQR-BC"))), ]
grid_rows <- vector("list", nrow(grid_cells))
for (i in seq_len(nrow(grid_cells))) {
  z <- grid_cells[i, ]
  keep <- stage2_summary$n == z$n & stage2_summary$tau == z$tau &
    stage2_summary$kappa == z$kappa & stage2_summary$estimator == z$estimator
  ranges <- stage2_summary[keep, ]
  ranges <- ranges[match(c("A_0_-1_3", "A_1_-3_5", "A_2_-5_7"), ranges$range), ]
  if (nrow(ranges) != 3L || any(is.na(ranges$range))) stop("Malformed Stage-2 ranges.")
  exp_row <- stage2_expansion[stage2_expansion$n == z$n &
    stage2_expansion$tau == z$tau & stage2_expansion$kappa == z$kappa &
    stage2_expansion$estimator == z$estimator, ]
  if (nrow(exp_row) != 1L) stop("Malformed Stage-2 expansion cell.")
  f1 <- sum(stage1_failures$n == z$n & stage1_failures$tau == z$tau &
            stage1_failures$kappa == z$kappa & stage1_failures$estimator == z$estimator)
  f2 <- sum(stage2_failures$n == z$n & stage2_failures$tau == z$tau &
            stage2_failures$kappa == z$kappa & stage2_failures$estimator == z$estimator)
  stabilized <- exp_row$mean_added_measure_A1_to_A2 <= .05 &&
    exp_row$boundary_acceptance_rate_A2 <= .05
  grid_rows[[i]] <- data.frame(
    n = z$n, tau = z$tau, kappa = z$kappa, estimator = z$estimator,
    replications = ranges$total_replications[1L],
    median_measure_A0 = ranges$median_grid_accepted_set_measure[1L],
    median_measure_A1 = ranges$median_grid_accepted_set_measure[2L],
    median_measure_A2 = ranges$median_grid_accepted_set_measure[3L],
    mean_measure_A0 = ranges$mean_grid_accepted_set_measure[1L],
    mean_measure_A1 = ranges$mean_grid_accepted_set_measure[2L],
    mean_measure_A2 = ranges$mean_grid_accepted_set_measure[3L],
    median_added_measure_A0_to_A1 = exp_row$median_added_measure_A0_to_A1,
    mean_added_measure_A0_to_A1 = exp_row$mean_added_measure_A0_to_A1,
    median_added_measure_A1_to_A2 = exp_row$median_added_measure_A1_to_A2,
    mean_added_measure_A1_to_A2 = exp_row$mean_added_measure_A1_to_A2,
    boundary_acceptance_rate_A0 = exp_row$boundary_acceptance_rate_A0,
    boundary_acceptance_rate_A1 = exp_row$boundary_acceptance_rate_A1,
    boundary_acceptance_rate_A2 = exp_row$boundary_acceptance_rate_A2,
    all_grid_acceptance_rate_A0 = exp_row$all_grid_acceptance_rate_A0,
    all_grid_acceptance_rate_A1 = exp_row$all_grid_acceptance_rate_A1,
    all_grid_acceptance_rate_A2 = exp_row$all_grid_acceptance_rate_A2,
    successful_profiles_A0 = ranges$successful_profiles[1L],
    successful_profiles_A1 = ranges$successful_profiles[2L],
    successful_profiles_A2 = ranges$successful_profiles[3L],
    failed_profiles_A0 = ranges$failed_profiles[1L],
    failed_profiles_A1 = ranges$failed_profiles[2L],
    failed_profiles_A2 = ranges$failed_profiles[3L],
    stage1_recorded_numerical_errors = f1,
    stage2_new_numerical_errors = f2,
    investigated_domain_status = if (stabilized) "near-stable within investigated domains" else
      "not stabilized within investigated domains",
    disconnected_components_established = FALSE,
    interpretation_limit = "does not establish global boundedness or unboundedness",
    stringsAsFactors = FALSE)
}
grid_table <- do.call(rbind, grid_rows)
write_csv(grid_table, "table_grid_domain_diagnostic.csv")

# Power: canonical summaries, with a documented compact subset.
power_full <- power_all[, c("n", "tau", "kappa", "estimator", "Delta", "power",
  "false_acceptance", "successful_power_evaluations", "failed_power_evaluations")]
power_full <- power_full[order_cells(power_full, delta = TRUE), ]
names(power_full)[names(power_full) == "Delta"] <- "delta"
write_csv(power_full, "table_power_full.csv")
power_main <- power_full[power_full$n == 1000 & power_full$tau %in% c(.10, .50, .90) &
  power_full$delta %in% c(-.50, .50), ]
power_main$selection_reason <- paste("moderate signed alternatives; comparable across designs;",
  "tail/central taus retained; full Delta set preserved in full/appendix output")
write_csv(power_main, "table_power_main.csv")

# Coverage: accepted forensic audit, cross-checked below against canonical summaries.
coverage_full <- coverage_all[, c("n", "tau", "kappa", "estimator", "R_available",
  "empirical_coverage", "empirical_size", "coverage_mcse",
  "coverage_mc95_lower", "coverage_mc95_upper",
  "nominal_0p95_inside_mc_interval")]
names(coverage_full)[names(coverage_full) == "empirical_coverage"] <- "coverage"
names(coverage_full)[names(coverage_full) == "empirical_size"] <- "size"
coverage_full <- coverage_full[order_cells(coverage_full), ]
write_csv(coverage_full, "table_coverage_full.csv")

strong_columns <- c("n", "tau", "kappa", "estimator", "R_available",
  "empirical_coverage", "empirical_size", "coverage_mcse", "coverage_mc95_lower",
  "coverage_mc95_upper", "median_W_true", "q90_W_true", "q95_W_true", "q99_W_true",
  "mean_W_true", "q95_ratio_to_chisq2_q95")
coverage_strong_table <- coverage_strong[, strong_columns]
names(coverage_strong_table)[names(coverage_strong_table) == "empirical_coverage"] <- "coverage"
names(coverage_strong_table)[names(coverage_strong_table) == "empirical_size"] <- "size"
coverage_strong_table <- coverage_strong_table[order_cells(coverage_strong_table), ]
write_csv(coverage_strong_table, "table_coverage_strong_n1000.csv")

# Appendix-ready complete outputs.
write_csv(point_full, "appendix_point_performance.csv")
write_csv(cr_full, "appendix_cr_informativeness.csv")
write_csv(power_full, "appendix_power.csv")
write_csv(coverage_full, "appendix_coverage.csv")
write_csv(grid_table, "appendix_grid_diagnostic.csv")

# Base-R graphics. The same y-axis range is used across n for each metric.
estimator_order <- c("Oracle-GMM", "Full-GMM", "DML-IVQR-BC")
kappa_order <- c(1, .5, .25, .1)
tau_order <- c(.10, .25, .50, .75, .90)
plot_styles <- data.frame(lty = c(1, 2, 3), pch = c(1, 2, 3))

plot_design_metric <- function(data, sample_size, metric, ylab, filename,
                               ylim, reference = NULL, delta = NULL) {
  png(filename, width = 1800, height = 1100, res = 150)
  on.exit(dev.off())
  par(mfrow = c(2, 3), mar = c(4.2, 4.3, 2.8, 1.0), oma = c(0, 0, 2, 0))
  for (tau_value in tau_order) {
    keep <- data$n == sample_size & abs(data$tau - tau_value) < 1e-14
    if (!is.null(delta)) keep <- keep & abs(data$delta - delta) < 1e-14
    z <- data[keep, ]
    plot(seq_along(kappa_order), rep(NA_real_, length(kappa_order)), type = "n",
         xlim = c(1, length(kappa_order)), ylim = ylim, xaxt = "n",
         xlab = expression(kappa), ylab = ylab,
         main = paste0("tau=", format(tau_value, nsmall = 2)))
    axis(1, at = seq_along(kappa_order), labels = c("1", ".5", ".25", ".1"))
    if (!is.null(reference)) abline(h = reference, lty = 3)
    for (j in seq_along(estimator_order)) {
      e <- estimator_order[j]
      values <- rep(NA_real_, length(kappa_order))
      for (k in seq_along(kappa_order)) {
        hit <- z$estimator == e & abs(z$kappa - kappa_order[k]) < 1e-14
        if (sum(hit) != 1L) stop("Unexpected plotting cell count.")
        values[k] <- z[[metric]][hit]
      }
      lines(seq_along(kappa_order), values, type = "b",
            lty = plot_styles$lty[j], pch = plot_styles$pch[j])
    }
  }
  plot.new()
  legend("center", legend = estimator_order, lty = plot_styles$lty,
         pch = plot_styles$pch, bty = "n")
  title(main = paste0("n=", sample_size), outer = TRUE)
  invisible(NULL)
}

rmse_ylim <- c(0, max(point_full$RMSE) * 1.05)
measure_ylim <- c(0, max(cr_full$median_grid_accepted_set_measure) * 1.05)
for (sample_size in c(500, 1000)) {
  plot_design_metric(point_full, sample_size, "RMSE", "RMSE",
    file.path(figure_dir, paste0("rmse_n", sample_size, ".png")), rmse_ylim)
  plot_design_metric(cr_full, sample_size, "median_grid_accepted_set_measure",
    "Median accepted-set measure in A0",
    file.path(figure_dir, paste0("accepted_measure_n", sample_size, ".png")), measure_ylim)
  plot_design_metric(coverage_full, sample_size, "coverage", "Empirical coverage",
    file.path(figure_dir, paste0("coverage_n", sample_size, ".png")), c(0, 1), .95)
  plot_design_metric(power_full, sample_size, "power", "Empirical power",
    file.path(figure_dir, paste0("power_minus050_n", sample_size, ".png")),
    c(0, 1), delta = -.50)
  plot_design_metric(power_full, sample_size, "power", "Empirical power",
    file.path(figure_dir, paste0("power_plus050_n", sample_size, ".png")),
    c(0, 1), delta = .50)
}

grid_aggregate <- aggregate(median_grid_accepted_set_measure ~ kappa + range,
                            data = stage2_summary, FUN = mean)
domain_order <- c("A_0_-1_3", "A_1_-3_5", "A_2_-5_7")
png(file.path(figure_dir, "grid_domain_expansion.png"),
    width = 1400, height = 950, res = 150)
par(mar = c(5, 5, 4, 2))
plot(1:3, rep(NA_real_, 3), type = "n", xaxt = "n", xlim = c(1, 3),
     ylim = c(0, max(grid_aggregate$median_grid_accepted_set_measure) * 1.08),
     xlab = "Investigated computational domain",
     ylab = "Mean across cells of median accepted-set measure",
     main = "Grid-domain expansion diagnostic (n=1000)")
axis(1, at = 1:3, labels = c("A0 [-1,3]", "A1 [-3,5]", "A2 [-5,7]"))
for (j in seq_along(c(1, .25, .1))) {
  kval <- c(1, .25, .1)[j]
  values <- vapply(domain_order, function(r) {
    z <- grid_aggregate[abs(grid_aggregate$kappa - kval) < 1e-14 &
                        grid_aggregate$range == r, "median_grid_accepted_set_measure"]
    if (length(z) != 1L) stop("Missing grid-domain plotting cell.")
    z
  }, numeric(1))
  lines(1:3, values, type = "b", lty = j, pch = j)
}
legend("topleft", legend = c("kappa=1", "kappa=.25", "kappa=.1"),
       lty = 1:3, pch = 1:3, bty = "n")
mtext("Finite investigated domains only; no claim of global unboundedness.",
      side = 1, line = 3.7, cex = .8)
dev.off()

# Internal consistency checks.
checks <- list()
add_check <- function(check, passed, observed, expected, details = "") {
  checks[[length(checks) + 1L]] <<- data.frame(
    check = check, status = if (isTRUE(passed)) "PASS" else "FAIL",
    observed = as.character(observed), expected = as.character(expected),
    details = details, stringsAsFactors = FALSE)
  if (!isTRUE(passed)) stop("Reporting consistency check failed: ", check)
}
add_check("expected main design cells", nrow(summary_all) == 120L, nrow(summary_all), 120)
add_check("no duplicate main design rows", anyDuplicated(cell_key(summary_all)) == 0L,
          anyDuplicated(cell_key(summary_all)), 0)
add_check("all expected main design keys", setequal(cell_key(summary_all), cell_key(expected_cells)),
          length(unique(cell_key(summary_all))), 120)
add_check("all three estimators present", setequal(unique(summary_all$estimator), estimator_order),
          paste(sort(unique(summary_all$estimator)), collapse = "; "),
          paste(sort(estimator_order), collapse = "; "))
add_check("expected power design cells", nrow(power_all) == 720L, nrow(power_all), 720)
add_check("no duplicate power design rows", anyDuplicated(power_key(power_all)) == 0L,
          anyDuplicated(power_key(power_all)), 0)

coverage_match <- match(cell_key(coverage_all), cell_key(summary_all))
add_check("coverage keys match canonical summary", all(!is.na(coverage_match)),
          sum(!is.na(coverage_match)), 120)
add_check("coverage matches canonical summary",
          same_numeric(coverage_all$empirical_coverage, summary_all$Coverage[coverage_match]),
          max(abs(coverage_all$empirical_coverage - summary_all$Coverage[coverage_match])), 0)
add_check("size matches canonical summary",
          same_numeric(coverage_all$empirical_size, summary_all$Size[coverage_match]),
          max(abs(coverage_all$empirical_size - summary_all$Size[coverage_match])), 0)
add_check("point metrics copied from canonical summary",
          same_numeric(point_full$Bias, summary_all$Bias[match(cell_key(point_full), cell_key(summary_all))]) &&
          same_numeric(point_full$MAE, summary_all$MAE[match(cell_key(point_full), cell_key(summary_all))]) &&
          same_numeric(point_full$RMSE, summary_all$RMSE[match(cell_key(point_full), cell_key(summary_all))]),
          "exact within 1e-12", "exact within 1e-12")
add_check("power copied from canonical power summary",
          same_numeric(power_full$power,
            power_all$power[match(paste(cell_key(power_full), sprintf("%+.2f", power_full$delta), sep = "|"),
                                  power_key(power_all))]),
          "exact within 1e-12", "exact within 1e-12")
add_check("no main-run failures", nrow(main_failures) == 0L, nrow(main_failures), 0)
add_check("one recorded Stage-1 numerical error", nrow(stage1_failures) == 1L,
          nrow(stage1_failures), 1)
add_check("zero new Stage-2 numerical errors", nrow(stage2_failures) == 0L,
          nrow(stage2_failures), 0)
add_check("compact point table is documented subset", nrow(point_main) == 36L,
          nrow(point_main), 36)
add_check("compact CR table is documented subset", nrow(cr_main) == 36L,
          nrow(cr_main), 36)
add_check("compact power table is documented subset", nrow(power_main) == 72L,
          nrow(power_main), 72)
add_check("full grid diagnostic cells", nrow(grid_table) == 45L, nrow(grid_table), 45)

input_hash_after <- vapply(canonical_abs, sha256_file, character(1))
input_bytes_after <- as.numeric(file.info(canonical_abs)$size)
input_unchanged <- identical(input_hash_before, input_hash_after) &&
  identical(input_bytes_before, input_bytes_after)
add_check("canonical input hashes unchanged during reporting build", input_unchanged,
          sum(input_hash_before != input_hash_after), 0,
          "SHA-256 and byte counts checked before and after generation")
consistency <- do.call(rbind, checks)
write_csv(consistency, "reporting_consistency_checks.csv")

run_metadata <- data.frame(
  repository_commit = repo_commit,
  R_version = R.version.string,
  run_start = format(start_time, "%Y-%m-%d %H:%M:%S %Z"),
  metadata_time = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  runtime_seconds_to_metadata = as.numeric(difftime(Sys.time(), start_time, units = "secs")),
  canonical_input_files = length(canonical_abs),
  reporting_files_expected_including_output_manifest = 34L,
  warnings = 0L,
  errors = 0L,
  stochastic_operations = 0L,
  estimator_calls = 0L,
  simulation_or_calibration_calls = 0L,
  stringsAsFactors = FALSE)
write_csv(run_metadata, "reporting_run_metadata.csv")

# Reporting-output manifest. It intentionally excludes itself because a file
# cannot contain its own stable cryptographic digest.
created_abs <- list_regular_files(report_dir)
created_abs <- created_abs[normalizePath(created_abs, winslash = "/", mustWork = TRUE) !=
                           slash(reporting_manifest_path)]
created_rel <- vapply(created_abs, relative_to_repo, character(1))
purpose_for_output <- function(path) {
  base <- basename(path)
  if (base == "build_thesis_results.R") return("deterministic R 3.4.3 reporting build")
  if (base == "EMPIRICAL_RESULTS_FREEZE.md") return("empirical evidence freeze")
  if (base == "EMPIRICAL_RESULTS_MANIFEST.csv") return("canonical input hashes and roles")
  if (base == "REPORTING_SCHEMA.md") return("metric-source and definition schema")
  if (base == "THESIS_TABLE_FIGURE_PLAN.md") return("page-efficient Chapter 5 asset plan")
  if (grepl("reporting_consistency_checks", base)) return("internal reporting consistency checks")
  if (grepl("reporting_run_metadata", base)) return("reporting runtime and environment metadata")
  if (grepl("appendix_", base)) return("complete appendix-ready machine-readable table")
  if (grepl("table_", base)) return("thesis reporting candidate table")
  if (grepl("\\.png$", base)) return("candidate thesis result figure")
  return("reporting support file")
}
reporting_manifest <- data.frame(
  relative_path = created_rel,
  bytes = format(as.numeric(file.info(created_abs)$size), scientific = FALSE, trim = TRUE),
  sha256 = vapply(created_abs, sha256_file, character(1)),
  purpose = vapply(created_rel, purpose_for_output, character(1)),
  stringsAsFactors = FALSE)
write.csv(reporting_manifest, reporting_manifest_path, row.names = FALSE)

total_runtime <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
final_files <- list_regular_files(report_dir)
if (length(final_files) != 34L) {
  stop("Unexpected reporting output count: ", length(final_files), "; expected 34.")
}
cat("Reporting build completed successfully.\n")
cat("Repository commit:", repo_commit, "\n")
cat("R version:", R.version.string, "\n")
cat("Canonical input files:", length(canonical_abs), "\n")
cat("Reporting files:", length(final_files), "\n")
cat("Figures:", length(list.files(figure_dir, pattern = "\\.png$")), "\n")
cat("Tables/metadata CSVs:", length(list.files(output_dir, pattern = "\\.csv$")), "\n")
cat("Warnings: 0\nErrors: 0\n")
cat("Runtime_seconds:", format(total_runtime, digits = 10), "\n")
