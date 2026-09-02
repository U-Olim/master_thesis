script_arg <- grep("^--file=", commandArgs(), value = TRUE)
if (length(script_arg) != 1L) stop("Run this file with Rscript.")
script_path <- normalizePath(sub("^--file=", "", script_arg[1]),
                             winslash = "/", mustWork = TRUE)
audit_dir <- dirname(script_path)
extension_root <- normalizePath(file.path(audit_dir, "..", ".."),
                                winslash = "/", mustWork = TRUE)
repository_root <- normalizePath(file.path(extension_root, ".."),
                                 winslash = "/", mustWork = TRUE)
args <- commandArgs(trailingOnly = TRUE)
if (!"--execute-coverage-audit" %in% args) {
  stop("Coverage audit is guarded. Add --execute-coverage-audit after review.")
}

source(file.path(extension_root, "environment", "check_author_environment.R"))
assert_author_environment(extension_root, write_outputs = FALSE)
if (!requireNamespace("digest", quietly = TRUE)) {
  stop("The canonical environment is missing the digest package needed for SHA-256.")
}
source(file.path(audit_dir, "coverage_audit_functions.R"))
source(file.path(extension_root, "config", "extension_config.R"))

run_start <- Sys.time()
critical_value <- qchisq(0.95, df = 2)
if (!identical(extension_config$critical_value, critical_value)) {
  stop("Configured critical value differs from qchisq(.95, 2).")
}

git_head <- system2("git", c("-C", shQuote(repository_root), "rev-parse", "HEAD"),
                    stdout = TRUE, stderr = TRUE)
if (length(git_head) != 1L || nchar(git_head) != 40L) {
  stop("Could not resolve the source repository commit.")
}

run_source <- readLines(file.path(extension_root, "src", "run_extension.R"),
                        warn = FALSE)
metric_source <- readLines(file.path(extension_root, "src", "metrics.R"),
                           warn = FALSE)
dgp_source <- readLines(file.path(extension_root, "src", "dgp_kappa.R"),
                        warn = FALSE)
required_source_evidence <- c(
  any(grepl("truth <- alpha_true\\(tau\\)", run_source)),
  any(grepl("direct_points <- c\\(truth, truth \\+ cfg\\$power_delta\\)", run_source)),
  any(grepl("covered <- classify_coverage\\(direct_W\\[1\\]", run_source)),
  any(grepl("rejected_true <- classify_rejection\\(direct_W\\[1\\]", run_source)),
  any(grepl("W_true = direct_W\\[1\\]", run_source)),
  any(grepl("W <= critical_value", metric_source, fixed = TRUE)),
  any(grepl("W > critical_value", metric_source, fixed = TRUE)),
  any(grepl("alpha_true <- function\\(tau\\) 1 \\+ qnorm\\(tau\\)", dgp_source)))
if (!all(required_source_evidence)) {
  stop("Executable coverage-definition evidence is incomplete; refusing audit.")
}

output_dir <- file.path(audit_dir, "output")
figures_dir <- file.path(audit_dir, "figures")
overwrite <- "--overwrite" %in% args
for (directory in c(output_dir, figures_dir)) {
  if (dir.exists(directory) && length(list.files(directory, all.files = TRUE,
                                                 no.. = TRUE)) && !overwrite) {
    stop("Refusing to overwrite non-empty directory: ", directory)
  }
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
}

input_paths <- c(
  file.path(extension_root, "final", "output", "n500", "results.csv"),
  file.path(extension_root, "final", "output", "n1000", "results.csv"),
  file.path(extension_root, "final", "output", "n500", "summary.csv"),
  file.path(extension_root, "final", "output", "n1000", "summary.csv"))
if (!all(file.exists(input_paths))) stop("One or more canonical input files are missing.")

input_inventory <- data.frame(
  record_type = "input",
  relative_path = substring(normalizePath(input_paths, winslash = "/"),
                            nchar(repository_root) + 2L),
  bytes = as.numeric(file.info(input_paths)$size),
  sha256 = vapply(input_paths, digest::digest, character(1),
                  algo = "sha256", file = TRUE, serialize = FALSE),
  purpose = c("n=500 per-replication final results",
              "n=1000 per-replication final results",
              "n=500 published aggregate summary cross-check",
              "n=1000 published aggregate summary cross-check"),
  stringsAsFactors = FALSE)

read_results <- function(path, expected_n) {
  data <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  assert_columns(data, required_result_columns, path)
  if (nrow(data) != 30000L) stop(path, " must contain exactly 30,000 rows.")
  if (!all(data$n == expected_n)) stop(path, " contains an unexpected n value.")
  for (name in c("covered", "rejected_true", "profile_failed",
                 "coverage_failed", "failed")) {
    data[[name]] <- as_logical_strict(data[[name]], name)
  }
  data$source_file <- substring(normalizePath(path, winslash = "/"),
                                nchar(repository_root) + 2L)
  data
}

read_summary <- function(path, expected_n) {
  data <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  assert_columns(data, required_summary_columns, path)
  if (nrow(data) != 60L) stop(path, " must contain exactly 60 rows.")
  if (!all(data$n == expected_n)) stop(path, " contains an unexpected n value.")
  data
}

results <- rbind(read_results(input_paths[1], 500L),
                 read_results(input_paths[2], 1000L))
summaries <- rbind(read_summary(input_paths[3], 500L),
                   read_summary(input_paths[4], 1000L))

expected_tau <- c(0.10, 0.25, 0.50, 0.75, 0.90)
expected_kappa <- c(1.00, 0.50, 0.25, 0.10)
expected_estimators <- c("Oracle-GMM", "Full-GMM", "DML-IVQR-BC")
if (!identical(sort(unique(results$n)), c(500L, 1000L)) ||
    !identical(sort(unique(results$tau)), expected_tau) ||
    !identical(sort(unique(results$kappa)), sort(expected_kappa)) ||
    !setequal(unique(results$estimator), expected_estimators)) {
  stop("Final results do not contain the expected design levels.")
}

keys <- cell_keys(results)
if (nrow(keys) != 120L) stop("Expected 120 estimator design cells; found ", nrow(keys), ".")
cell_sizes <- vapply(seq_len(nrow(keys)), function(index)
  nrow(select_cell(results, keys[index, , drop = FALSE])), integer(1))
if (any(cell_sizes != 500L)) {
  stop("Every estimator design cell must contain exactly 500 rows.")
}

consistency <- consistency_checks(results, critical_value, 500L)
hard_failure_columns <- c(
  "duplicate_replication_rows", "missing_replication_count",
  "unexpected_replication_count", "rejection_indicator_mismatches",
  "coverage_indicator_mismatches",
  "coverage_rejection_complement_mismatches", "alpha_true_formula_mismatches")
if (any(as.matrix(consistency[, hard_failure_columns, drop = FALSE]) != 0)) {
  write.csv(consistency,
            file.path(output_dir, "coverage_audit_consistency_checks.csv"),
            row.names = FALSE)
  stop("Mechanical consistency checks failed; see consistency output.")
}

all_cells <- summarise_all_cells(results, critical_value)
summary_compare <- summaries[, c("n", "tau", "kappa", "estimator",
                                 "Coverage", "Size")]
names(summary_compare)[5:6] <- c("summary_reported_coverage", "summary_reported_size")
all_cells <- merge(all_cells, summary_compare,
                   by = c("n", "tau", "kappa", "estimator"),
                   all.x = TRUE, sort = FALSE)
all_cells$summary_coverage_abs_difference <-
  abs(all_cells$empirical_coverage - all_cells$summary_reported_coverage)
all_cells$summary_size_abs_difference <-
  abs(all_cells$empirical_size - all_cells$summary_reported_size)
all_cells <- all_cells[order(all_cells$n, all_cells$tau, -all_cells$kappa,
                             match(all_cells$estimator, expected_estimators)), ]
rownames(all_cells) <- NULL
if (any(!is.finite(all_cells$summary_coverage_abs_difference)) ||
    any(all_cells$summary_coverage_abs_difference > 1e-12) ||
    any(all_cells$summary_size_abs_difference > 1e-12)) {
  stop("Recomputed coverage/size does not match canonical summary.csv.")
}

primary_taus <- c(0.50, 0.75, 0.90)
primary <- all_cells[all_cells$n == 1000 & all_cells$kappa == 1 &
                       all_cells$tau %in% primary_taus, , drop = FALSE]
primary$distribution_pattern <- vapply(seq_len(nrow(primary)), function(index)
  classify_distribution_pattern(primary[index, , drop = FALSE]), character(1))
strong <- all_cells[all_cells$n == 1000 & all_cells$kappa == 1, , drop = FALSE]
paired <- paired_estimator_comparisons(results, critical_value)
outliers <- primary_outliers(results, primary_taus, expected_estimators, 10L)
reference_quantiles <- data.frame(
  probability = c(0.50, 0.90, 0.95, 0.99),
  df = 2L,
  chi_square_quantile = qchisq(c(0.50, 0.90, 0.95, 0.99), df = 2),
  stringsAsFactors = FALSE)

write.csv(all_cells, file.path(output_dir, "coverage_audit_all_cells.csv"),
          row.names = FALSE)
write.csv(primary, file.path(output_dir, "coverage_audit_primary_cells.csv"),
          row.names = FALSE)
write.csv(strong,
          file.path(output_dir, "coverage_audit_strong_kappa_n1000.csv"),
          row.names = FALSE)
write.csv(paired,
          file.path(output_dir, "coverage_audit_paired_estimators.csv"),
          row.names = FALSE)
write.csv(outliers, file.path(output_dir, "coverage_audit_outliers.csv"),
          row.names = FALSE)
write.csv(consistency,
          file.path(output_dir, "coverage_audit_consistency_checks.csv"),
          row.names = FALSE)
write.csv(reference_quantiles,
          file.path(output_dir, "coverage_audit_reference_quantiles.csv"),
          row.names = FALSE)

figure_files <- make_primary_figures(results, figures_dir, critical_value,
                                     primary_taus, expected_estimators)
figure_files <- c(figure_files,
                  make_q95_comparison_figure(strong, figures_dir,
                                             critical_value, expected_estimators))

run_end <- Sys.time()
runtime_seconds <- as.numeric(difftime(run_end, run_start, units = "secs"))
metadata <- data.frame(
  repository_commit = git_head,
  R_version = R.version.string,
  run_start = format(run_start, "%Y-%m-%d %H:%M:%S %Z"),
  run_end = format(run_end, "%Y-%m-%d %H:%M:%S %Z"),
  runtime_seconds = runtime_seconds,
  result_rows = nrow(results), design_cells = nrow(all_cells),
  primary_cells = nrow(primary), figures = length(figure_files),
  critical_value = critical_value,
  stringsAsFactors = FALSE)
write.csv(metadata, file.path(output_dir, "coverage_audit_run_metadata.csv"),
          row.names = FALSE)

primary_report <- primary[, c(
  "tau", "estimator", "empirical_coverage", "coverage_mcse",
  "coverage_mc95_lower", "coverage_mc95_upper", "empirical_size",
  "median_W_true", "q90_W_true", "q95_W_true", "q99_W_true",
  "q95_ratio_to_chisq2_q95", "mean_W_true", "distribution_pattern")]
names(primary_report) <- c(
  "tau", "estimator", "coverage", "MCSE", "MC95_lower", "MC95_upper",
  "size", "median_W", "q90_W", "q95_W", "q99_W", "q95_ratio", "mean_W",
  "pattern")
strong_report <- strong[, c(
  "tau", "estimator", "empirical_coverage", "coverage_mcse",
  "coverage_mc95_lower", "coverage_mc95_upper", "empirical_size",
  "median_W_true", "q90_W_true", "q95_W_true", "q99_W_true",
  "q95_ratio_to_chisq2_q95", "mean_W_true")]
names(strong_report) <- c(
  "tau", "estimator", "coverage", "MCSE", "MC95_lower", "MC95_upper",
  "size", "median_W", "q90_W", "q95_W", "q99_W", "q95_ratio", "mean_W")
worst <- head(all_cells[order(all_cells$empirical_coverage),
                        c("n", "tau", "kappa", "estimator",
                          "empirical_coverage", "coverage_mc95_lower",
                          "coverage_mc95_upper", "q95_W_true",
                          "q95_ratio_to_chisq2_q95")], 10L)
paired_primary <- paired[paired$tau %in% primary_taus, c(
  "tau", "comparison", "correlation_W_true",
  "mean_paired_W_difference_A_minus_B",
  "median_paired_W_difference_A_minus_B",
  "q90_paired_W_difference_A_minus_B",
  "q95_paired_W_difference_A_minus_B",
  "fraction_A_rejects_B_accepts", "fraction_A_accepts_B_rejects",
  "fraction_both_reject", "fraction_both_accept")]

outside_cells <- sum(!all_cells$nominal_0p95_inside_mc_interval)
primary_outside <- sum(!primary$nominal_0p95_inside_mc_interval)
total_consistency_mismatches <- sum(as.matrix(
  consistency[, c("rejection_indicator_mismatches",
                  "coverage_indicator_mismatches",
                  "coverage_rejection_complement_mismatches")]))
total_nonfinite <- sum(consistency$na_W_true + consistency$nan_W_true +
                         consistency$positive_inf_W_true +
                         consistency$negative_inf_W_true)
total_negative <- sum(consistency$negative_finite_W_true)
total_failed_flags <- sum(consistency$profile_failed_true +
                            consistency$coverage_failed_true)

oracle_bad <- any(primary$estimator == "Oracle-GMM" &
                    primary$empirical_coverage < 0.95 &
                    !primary$nominal_0p95_inside_mc_interval)
dml_bad <- any(primary$estimator == "DML-IVQR-BC" &
                 primary$empirical_coverage < 0.95 &
                 !primary$nominal_0p95_inside_mc_interval)
if (oracle_bad && dml_bad) {
  guarded_interpretation <- paste(
    "Undercoverage outside the cell-specific Monte Carlo interval appears in",
    "both Oracle-GMM and DML-IVQR-BC primary cells. The discrepancy therefore",
    "cannot be attributed solely to high-dimensional nuisance estimation.")
} else if (!oracle_bad && dml_bad) {
  guarded_interpretation <- paste(
    "The primary discrepancy is concentrated in DML-IVQR-BC while Oracle-GMM",
    "remains compatible with nominal coverage under the stated Monte Carlo",
    "comparison. This localizes, but does not explain, the discrepancy.")
} else {
  guarded_interpretation <- paste(
    "The primary Oracle/DML comparison does not support either pre-specified",
    "localization rule uniformly; estimator-specific results should be reported",
    "cell by cell.")
}

input_report <- input_inventory[, c("relative_path", "bytes", "sha256")]
report_lines <- c(
  "# Coverage / size forensic audit",
  "",
  "## 1. Purpose",
  "",
  "This technical audit diagnoses the saved per-replication W statistic at the true parameter in the completed R=500 Monte Carlo. It does not alter or rerun the empirical design.",
  "",
  "## 2. Inputs and provenance",
  "",
  paste0("Repository commit: `", git_head, "`."),
  paste0("Runtime environment: `", R.version.string, "`."),
  "",
  markdown_table(input_report, 0),
  "",
  "## 3. Executable coverage definition and schema",
  "",
  "The final `results.csv` files preserve `W_true`, `covered`, `rejected_true`, `n`, `replication`, `tau`, `kappa`, `estimator`, `alpha_true`, and failure flags for every replication. The saved estimator labels are `Oracle-GMM`, `Full-GMM`, and `DML-IVQR-BC`.",
  "",
  "Executable inspection confirms that `truth <- alpha_true(tau)` is inserted as the first direct evaluation point, independently of the computational alpha grid. The DGP helper defines `alpha_true(tau) = 1 + qnorm(tau)`. The result row saves `W_true = direct_W[1]` and classifies:",
  "",
  "`covered = 1{W_true <= qchisq(.95, df=2)}`",
  "",
  "`rejected_true = 1{W_true > qchisq(.95, df=2)}`",
  "",
  paste0("The unchanged theoretical cutoff is `", format(critical_value, digits = 16), "`. Coverage is therefore independent of the 41-point profile grid."),
  "",
  "## 4. Reference distribution",
  "",
  markdown_table(reference_quantiles, 6),
  "",
  "## 5. Primary-cell results",
  "",
  markdown_table(primary_report, 4),
  "",
  "## 6. Full-cell diagnostics",
  "",
  paste0("All 120 expected design cells were found, each with 500 rows. The ten lowest empirical coverage cells are:"),
  "",
  markdown_table(worst, 4),
  "",
  "Complete 120-cell statistics are in `output/coverage_audit_all_cells.csv`.",
  "",
  "## 7. Strong-kappa n=1000 comparison",
  "",
  markdown_table(strong_report, 4),
  "",
  "## 8. Monte Carlo uncertainty",
  "",
  paste0("Coverage MCSE is `sqrt(p_hat*(1-p_hat)/R_available)`. The reported 95% intervals are Wilson binomial intervals. Nominal 0.95 lies outside the interval in ", outside_cells, " of 120 cells and in ", primary_outside, " of 9 primary cells. This is the audit's explicit Monte Carlo comparison; no broader significance claim is made."),
  "",
  "## 9. Distributional evidence",
  "",
  "The `pattern` column in the primary table applies the operational rule documented in README.md. Histograms, ECDF comparisons, and Q-Q plots retain all finite observations. The rule distinguishes a broad rightward shift from isolated extreme-tail evidence without assigning a theoretical cause.",
  "",
  "## 10. Paired Oracle / Full / DML comparison",
  "",
  markdown_table(paired_primary, 4),
  "",
  guarded_interpretation,
  "",
  "The paired results are descriptive. Correlation and disagreement frequencies are not causal evidence.",
  "",
  "## 11. Outlier and failure checks",
  "",
  paste0("Across all saved result rows, non-finite W_true values: ", total_nonfinite, "; negative finite W values: ", total_negative, "; profile/coverage failure flags: ", total_failed_flags, "; coverage/rejection indicator mismatches: ", total_consistency_mismatches, ". Duplicate and missing replication checks are recorded for every cell in `output/coverage_audit_consistency_checks.csv`. The largest ten W_true values in every primary cell are retained in `output/coverage_audit_outliers.csv`; no outlier was deleted or corrected."),
  "",
  "## 12. What can be concluded",
  "",
  "The audit can establish which completed Monte Carlo cells have rejection frequencies above 5%, whether 0.95 lies outside a cell-specific Monte Carlo interval, whether the empirical W distribution is broadly shifted or dominated by a small upper tail under the stated descriptive rule, and how the three estimators agree on paired replications.",
  "",
  "## 13. What cannot be concluded",
  "",
  "This audit cannot identify a theoretical cause, prove failure of weak-ID-robust inference, invalidate the chi-square reference law, or attribute a discrepancy causally to DML. It does not justify changing the cutoff, grid, tuning, seed, estimator, or sample after observing results.",
  "",
  "## 14. Implications for thesis reporting",
  "",
  "Coverage and size should be reported transparently by estimator, quantile, instrument strength, and sample size, with Monte Carlo uncertainty and the direct-evaluation definition stated explicitly. Unexpected cells should remain in the reported design together with their distributional diagnostics.",
  "",
  "## Safe thesis interpretation",
  "",
  guarded_interpretation,
  "",
  "Where the cell tables show coverage below 0.95, a safe formulation is: 'The empirical rejection frequency at the true parameter exceeds the nominal 5% level in these completed designs.' This is a finite-sample Monte Carlo statement, not a claim about the general validity of the procedure.",
  "",
  paste0("Audit runtime before manifest generation: ", format(runtime_seconds, digits = 6), " seconds."))
report_path <- file.path(audit_dir, "COVERAGE_AUDIT_REPORT.md")
writeLines(report_lines, report_path)

output_files <- c(list.files(output_dir, recursive = TRUE, full.names = TRUE),
                  list.files(figures_dir, recursive = TRUE, full.names = TRUE),
                  report_path,
                  file.path(audit_dir, "README.md"),
                  file.path(audit_dir, "coverage_audit_functions.R"),
                  script_path)
output_files <- sort(unique(output_files[file.exists(output_files)]))
relative_to_audit <- function(path) {
  normalized <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (substr(normalized, 1, nchar(audit_dir)) == audit_dir) {
    return(substring(normalized, nchar(audit_dir) + 2L))
  }
  substring(normalized, nchar(repository_root) + 2L)
}
purpose_for <- function(path) {
  name <- basename(path)
  if (grepl("\\.png$", name)) return("Distributional diagnostic figure")
  if (name == "COVERAGE_AUDIT_REPORT.md") return("Technical coverage audit report")
  if (name == "README.md") return("Audit scope and reproducibility instructions")
  if (name == "coverage_audit_functions.R") return("Reusable audit calculations")
  if (name == "run_coverage_audit.R") return("Canonical audit runner")
  if (name == "coverage_audit_all_cells.csv") return("Full 120-cell coverage and W summary")
  if (name == "coverage_audit_primary_cells.csv") return("Nine primary-cell summaries")
  if (name == "coverage_audit_strong_kappa_n1000.csv") return("Strong-kappa n=1000 comparison")
  if (name == "coverage_audit_paired_estimators.csv") return("Paired estimator comparisons")
  if (name == "coverage_audit_outliers.csv") return("Largest ten W values per primary cell")
  if (name == "coverage_audit_consistency_checks.csv") return("Failure, ID, and indicator consistency checks")
  if (name == "coverage_audit_reference_quantiles.csv") return("Chi-square(2) reference quantiles")
  if (name == "coverage_audit_run_metadata.csv") return("Commit, environment, and runtime metadata")
  "Coverage audit artifact"
}
audit_inventory <- data.frame(
  record_type = ifelse(grepl("\\.R$|README\\.md$", output_files),
                       "audit_source", "audit_output"),
  relative_path = vapply(output_files, relative_to_audit, character(1)),
  bytes = as.numeric(file.info(output_files)$size),
  sha256 = vapply(output_files, digest::digest, character(1),
                  algo = "sha256", file = TRUE, serialize = FALSE),
  purpose = vapply(output_files, purpose_for, character(1)),
  stringsAsFactors = FALSE)
manifest <- rbind(input_inventory, audit_inventory)
write.csv(manifest, file.path(audit_dir, "COVERAGE_AUDIT_MANIFEST.csv"),
          row.names = FALSE)

cat("COVERAGE AUDIT COMPLETE\n")
cat("Commit:", git_head, "\n")
cat("Cells:", nrow(all_cells), "Primary:", nrow(primary), "\n")
cat("Figures:", length(figure_files), "\n")
cat("Runtime seconds:", runtime_seconds, "\n")
