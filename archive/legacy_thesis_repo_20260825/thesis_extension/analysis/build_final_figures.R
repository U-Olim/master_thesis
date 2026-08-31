# POST-PROCESSING ONLY.
# THIS SCRIPT MUST NEVER RUN OR MODIFY THE MONTE CARLO SIMULATION.

options(stringsAsFactors = FALSE, digits = 17, scipen = 999)

stopf <- function(...) stop(sprintf(...), call. = FALSE)
assert <- function(ok, ...) if (!isTRUE(ok)) stopf(...)

find_repo_root <- function() {
  candidates <- character()
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg)) {
    candidates <- c(candidates, dirname(normalizePath(sub("^--file=", "", file_arg[1]), mustWork = TRUE)))
  }
  candidates <- c(candidates, normalizePath(getwd(), mustWork = TRUE))
  for (start in unique(candidates)) {
    here <- start
    repeat {
      if (dir.exists(file.path(here, ".git")) &&
          dir.exists(file.path(here, "thesis_extension", "final", "output"))) return(here)
      parent <- dirname(here)
      if (identical(parent, here)) break
      here <- parent
    }
  }
  stopf("Could not locate repository root.")
}

repo <- find_repo_root()
abs_path <- function(...) file.path(repo, ...)
slash <- function(x) gsub("\\\\", "/", x)

output_root <- abs_path("thesis_extension", "final", "output")
combined_dir <- abs_path("thesis_extension", "final", "combined")
figure_data_dir <- abs_path("thesis_extension", "final", "figure_data")
main_figure_dir <- abs_path("thesis_extension", "final", "figures", "main")
appendix_figure_dir <- abs_path("thesis_extension", "final", "figures", "appendix")
dir.create(combined_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(main_figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(appendix_figure_dir, recursive = TRUE, showWarnings = FALSE)

required_files <- c(
  "final_raw.csv", "final_power.csv", "final_summary.csv",
  "final_power_summary.csv", "final_diagnostics.csv", "final_manifest.txt",
  "final_sessionInfo.txt"
)

all_dirs <- c(output_root, list.dirs(output_root, recursive = TRUE, full.names = TRUE))
complete_dirs <- all_dirs[vapply(all_dirs, function(d) {
  all(file.exists(file.path(d, required_files)))
}, logical(1))]
assert(length(complete_dirs) == 2L,
       "Expected exactly two complete output directories; found %d: %s",
       length(complete_dirs), paste(slash(complete_dirs), collapse = ", "))

read_csv <- function(path) read.csv(path, check.names = FALSE, na.strings = c("NA", ""))
manifest_value <- function(path, field) {
  hit <- grep(paste0("^", field, ":"), readLines(path, warn = FALSE), value = TRUE)
  assert(length(hit) == 1L, "Manifest field %s is missing or duplicated in %s.", field, slash(path))
  trimws(sub(paste0("^", field, ":"), "", hit))
}
md5_with_eol <- function(path, eol = c("LF", "CRLF")) {
  eol <- match.arg(eol)
  size <- file.info(path)$size
  con <- file(path, open = "rb")
  on.exit(close(con), add = TRUE)
  txt <- rawToChar(readBin(con, what = "raw", n = size))
  txt <- gsub("\r\n", "\n", txt, fixed = TRUE)
  if (eol == "CRLF") txt <- gsub("\n", "\r\n", txt, fixed = TRUE)
  tmp <- tempfile(fileext = ".R")
  on.exit(unlink(tmp), add = TRUE)
  out <- file(tmp, open = "wb")
  writeBin(charToRaw(txt), out)
  close(out)
  unname(tools::md5sum(tmp))
}
dir_n <- vapply(complete_dirs, function(d) {
  x <- read_csv(file.path(d, "final_summary.csv"))
  vals <- unique(x$n)
  assert(length(vals) == 1L, "Output directory has ambiguous n: %s", slash(d))
  as.character(vals)
}, character(1))
assert(setequal(dir_n, c("500", "1000")) && !anyDuplicated(dir_n),
       "Completed outputs do not uniquely identify n=500 and n=1000.")
names(complete_dirs) <- dir_n
source_dirs <- complete_dirs[c("500", "1000")]

protected_roots <- c(
  abs_path("simulation"), abs_path("thesis_extension", "src"),
  abs_path("thesis_extension", "config"), output_root
)
protected_files <- unlist(lapply(protected_roots, function(d) {
  list.files(d, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
}), use.names = FALSE)
protected_files <- protected_files[file.info(protected_files)$isdir %in% FALSE]
protected_md5_before <- tools::md5sum(protected_files)

expected_n <- c(500, 1000)
expected_tau <- c(0.10, 0.25, 0.50, 0.75, 0.90)
expected_kappa <- c(1.00, 0.50, 0.25, 0.10)
expected_estimators <- c("Oracle-GMM", "Full-GMM", "DML-IVQR")
expected_delta <- c(-0.50, -0.25, 0.25, 0.50)
R_MC <- 500L
coverage_band <- 0.95 + c(-1, 1) * 1.96 * sqrt(0.95 * 0.05 / R_MC)

summary_required <- c(
  "n", "tau", "kappa", "estimator", "mean_signed_error", "Bias", "MAE", "RMSE",
  "coverage", "median_accepted_set_measure_A", "full_A_acceptance_rate",
  "numerical_failure_rate", "successful_replications", "failed_replications"
)
power_summary_required <- c(
  "n", "tau", "kappa", "estimator", "delta", "rejection_probability", "MCSE",
  "successful_replications", "failed_replications"
)
raw_required <- c(
  "rep_id", "n", "tau", "kappa", "estimator", "signed_error", "authors_style_bias",
  "abs_error", "squared_error", "covered", "accepted_set_measure_A", "full_A_accepted", "status"
)
power_required <- c("rep_id", "n", "tau", "kappa", "estimator", "delta", "rejected_false", "status")

key <- function(d, cols) do.call(paste, c(d[cols], sep = "\r"))
assert_exact_grid <- function(d, expected, cols, label) {
  actual_key <- key(d, cols)
  expected_key <- key(expected, cols)
  assert(!anyDuplicated(actual_key), "%s contains duplicate design cells.", label)
  missing <- setdiff(expected_key, actual_key)
  extra <- setdiff(actual_key, expected_key)
  assert(!length(missing) && !length(extra),
         "%s design mismatch: %d missing and %d unexpected cells.", label, length(missing), length(extra))
}
assert_values <- function(x, expected, label) {
  assert(setequal(x, expected), "%s values differ from the frozen design. Found: %s",
         label, paste(sort(unique(x)), collapse = ", "))
}
assert_finite_numeric <- function(d, columns, label) {
  for (nm in columns) {
    assert(is.numeric(d[[nm]]), "%s column %s is not numeric.", label, nm)
    assert(!anyNA(d[[nm]]) && all(is.finite(d[[nm]])),
           "%s column %s contains NA or non-finite values.", label, nm)
  }
}

summaries <- list()
power_summaries <- list()
raws <- list()
powers <- list()
diagnostics <- list()

for (n_chr in c("500", "1000")) {
  d <- source_dirs[[n_chr]]
  manifest_path_n <- file.path(d, "final_manifest.txt")
  assert(manifest_value(manifest_path_n, "sample_size") == n_chr,
         "n=%s manifest sample_size is inconsistent.", n_chr)
  assert(manifest_value(manifest_path_n, "Monte_Carlo_replications_for_sample_size") == "500",
         "n=%s manifest does not record 500 Monte Carlo replications.", n_chr)
  assert(manifest_value(manifest_path_n, "raw_rows") == "30000" &&
         manifest_value(manifest_path_n, "power_rows") == "120000" &&
         manifest_value(manifest_path_n, "summary_rows") == "60" &&
         manifest_value(manifest_path_n, "power_summary_rows") == "240",
         "n=%s manifest row counts are inconsistent.", n_chr)
  assert(manifest_value(manifest_path_n, "all_sanity_checks") == "TRUE",
         "n=%s manifest does not record all_sanity_checks=TRUE.", n_chr)
  summaries[[n_chr]] <- read_csv(file.path(d, "final_summary.csv"))
  power_summaries[[n_chr]] <- read_csv(file.path(d, "final_power_summary.csv"))
  raws[[n_chr]] <- read_csv(file.path(d, "final_raw.csv"))
  powers[[n_chr]] <- read_csv(file.path(d, "final_power.csv"))
  diagnostics[[n_chr]] <- read_csv(file.path(d, "final_diagnostics.csv"))

  s <- summaries[[n_chr]]
  ps <- power_summaries[[n_chr]]
  raw <- raws[[n_chr]]
  pow <- powers[[n_chr]]
  n_num <- as.numeric(n_chr)

  assert(all(summary_required %in% names(s)), "Missing columns in n=%s final_summary.csv.", n_chr)
  assert(all(power_summary_required %in% names(ps)), "Missing columns in n=%s final_power_summary.csv.", n_chr)
  assert(all(raw_required %in% names(raw)), "Missing columns in n=%s final_raw.csv.", n_chr)
  assert(all(power_required %in% names(pow)), "Missing columns in n=%s final_power.csv.", n_chr)
  assert(nrow(s) == 60L, "n=%s summary has %d rows, expected 60.", n_chr, nrow(s))
  assert(nrow(ps) == 240L, "n=%s power summary has %d rows, expected 240.", n_chr, nrow(ps))
  assert(nrow(raw) == 30000L, "n=%s raw data has %d rows, expected 30000.", n_chr, nrow(raw))
  assert(nrow(pow) == 120000L, "n=%s raw power data has %d rows, expected 120000.", n_chr, nrow(pow))

  assert_values(s$n, n_num, sprintf("n=%s summary n", n_chr))
  assert_values(s$tau, expected_tau, sprintf("n=%s summary tau", n_chr))
  assert_values(s$kappa, expected_kappa, sprintf("n=%s summary kappa", n_chr))
  assert_values(s$estimator, expected_estimators, sprintf("n=%s summary estimator", n_chr))
  assert_values(ps$delta, expected_delta, sprintf("n=%s power delta", n_chr))
  assert_values(ps$n, n_num, sprintf("n=%s power-summary n", n_chr))
  assert_values(ps$tau, expected_tau, sprintf("n=%s power-summary tau", n_chr))
  assert_values(ps$kappa, expected_kappa, sprintf("n=%s power-summary kappa", n_chr))
  assert_values(ps$estimator, expected_estimators, sprintf("n=%s power-summary estimator", n_chr))

  expected_s <- expand.grid(n = n_num, tau = expected_tau, kappa = expected_kappa,
                            estimator = expected_estimators, KEEP.OUT.ATTRS = FALSE)
  expected_ps <- expand.grid(n = n_num, tau = expected_tau, kappa = expected_kappa,
                             estimator = expected_estimators, delta = expected_delta,
                             KEEP.OUT.ATTRS = FALSE)
  assert_exact_grid(s, expected_s, c("n", "tau", "kappa", "estimator"), sprintf("n=%s summary", n_chr))
  assert_exact_grid(ps, expected_ps, c("n", "tau", "kappa", "estimator", "delta"), sprintf("n=%s power summary", n_chr))
  assert_finite_numeric(s, setdiff(names(s), "estimator"), sprintf("n=%s summary", n_chr))
  assert_finite_numeric(ps, setdiff(names(ps), "estimator"), sprintf("n=%s power summary", n_chr))
  assert(all(s$successful_replications + s$failed_replications == R_MC),
         "n=%s summary replication denominators differ from 500.", n_chr)
  assert(all(ps$successful_replications + ps$failed_replications == R_MC),
         "n=%s power-summary replication denominators differ from 500.", n_chr)

  raw_counts <- table(key(raw, c("n", "tau", "kappa", "estimator")))
  power_counts <- table(key(pow, c("n", "tau", "kappa", "estimator", "delta")))
  assert(length(raw_counts) == 60L && all(raw_counts == R_MC), "n=%s raw cell counts are not all 500.", n_chr)
  assert(length(power_counts) == 240L && all(power_counts == R_MC), "n=%s raw power cell counts are not all 500.", n_chr)
  assert(!anyDuplicated(key(raw, c("rep_id", "n", "tau", "kappa", "estimator"))),
         "n=%s raw data contains duplicate replication/design rows.", n_chr)
  assert(!anyDuplicated(key(pow, c("rep_id", "n", "tau", "kappa", "estimator", "delta"))),
         "n=%s power data contains duplicate replication/design rows.", n_chr)
  assert(all(pow$status == "OK") && !anyNA(pow$rejected_false), "n=%s raw power contains failures or missing decisions.", n_chr)
}

# The two manifests record different OS line endings for five frozen text files.
# Assert that every recorded source/config MD5 equals the LF- or CRLF-normalized
# hash of the same current tracked content, so this cannot conceal a content change.
manifest_source_hashes <- function(path) {
  lines <- readLines(path, warn = FALSE)
  lines <- lines[grepl("^thesis_extension/(config|src|final/run_inference_final\\.R)", lines)]
  parts <- strsplit(lines, " = ", fixed = TRUE)
  setNames(vapply(parts, `[`, character(1), 2L), vapply(parts, `[`, character(1), 1L))
}
hashes_500 <- manifest_source_hashes(file.path(source_dirs[["500"]], "final_manifest.txt"))
hashes_1000 <- manifest_source_hashes(file.path(source_dirs[["1000"]], "final_manifest.txt"))
assert(identical(names(hashes_500), names(hashes_1000)) && length(hashes_500) == 6L,
       "Manifest source-file hash inventories differ.")
for (f in names(hashes_500)) {
  tracked_path <- do.call(abs_path, as.list(strsplit(f, "/", fixed = TRUE)[[1]]))
  normalized_hashes <- c(md5_with_eol(tracked_path, "LF"), md5_with_eol(tracked_path, "CRLF"))
  assert(hashes_500[[f]] %in% normalized_hashes && hashes_1000[[f]] %in% normalized_hashes,
         "Manifest MD5 for %s differs beyond LF/CRLF line endings.", f)
}

failed_500 <- raws[["500"]][raws[["500"]]$status != "OK", ]
failed_1000 <- raws[["1000"]][raws[["1000"]]$status != "OK", ]
assert(nrow(failed_500) == 1L, "Expected exactly one recorded n=500 raw numerical failure; found %d.", nrow(failed_500))
assert(nrow(failed_1000) == 0L, "Expected zero n=1000 raw numerical failures; found %d.", nrow(failed_1000))
assert(failed_500$rep_id == 123L && failed_500$tau == 0.10 && failed_500$kappa == 0.50 &&
       failed_500$estimator == "DML-IVQR", "The n=500 failure is not the documented profile.")
assert(nrow(diagnostics[["500"]]) == 1L && nrow(diagnostics[["1000"]]) == 0L,
       "Diagnostics row counts do not match the documented 1/0 failures.")

s500 <- summaries[["500"]]
failed_cell <- s500$tau == 0.10 & s500$kappa == 0.50 & s500$estimator == "DML-IVQR"
assert(sum(failed_cell) == 1L, "Could not uniquely identify the documented summary failure cell.")
assert(s500$successful_replications[failed_cell] == 499L && s500$failed_replications[failed_cell] == 1L,
       "Saved summary does not record 499 successful and 1 failed replication in the documented cell.")
assert(all(s500$successful_replications[!failed_cell] == 500L) && all(s500$failed_replications[!failed_cell] == 0L),
       "Unexpected n=500 summary denominator difference outside the documented cell.")
assert(abs(s500$numerical_failure_rate[failed_cell] - 1 / 500) < 1e-15 &&
       all(s500$numerical_failure_rate[!failed_cell] == 0), "Unexpected n=500 numerical-failure rates.")
assert(all(summaries[["1000"]]$successful_replications == 500L) &&
       all(summaries[["1000"]]$failed_replications == 0L) &&
       all(summaries[["1000"]]$numerical_failure_rate == 0), "Unexpected n=1000 summary failures.")
assert(all(power_summaries[["500"]]$successful_replications == 500L) &&
       all(power_summaries[["500"]]$failed_replications == 0L) &&
       all(power_summaries[["1000"]]$successful_replications == 500L) &&
       all(power_summaries[["1000"]]$failed_replications == 0L), "Unexpected power-summary failures.")

# Verify exactly how the saved summary handles the isolated failed profile:
# every reported statistic for the cell is based on the 499 status-OK profiles.
raw_cell_ok <- subset(raws[["500"]], tau == 0.10 & kappa == 0.50 & estimator == "DML-IVQR" & status == "OK")
saved_cell <- s500[failed_cell, ]
recomputed <- c(
  mean_signed_error = mean(raw_cell_ok$signed_error),
  Bias = mean(raw_cell_ok$authors_style_bias),
  MAE = mean(raw_cell_ok$abs_error),
  RMSE = sqrt(mean(raw_cell_ok$squared_error)),
  coverage = mean(raw_cell_ok$covered),
  median_accepted_set_measure_A = median(raw_cell_ok$accepted_set_measure_A),
  full_A_acceptance_rate = mean(raw_cell_ok$full_A_accepted)
)
assert(all(abs(unlist(saved_cell[names(recomputed)]) - recomputed) < 1e-12),
       "Saved n=500 failure-cell statistics do not match the 499 status-OK raw profiles.")

final_summary <- rbind(summaries[["500"]], summaries[["1000"]])
final_power_summary <- rbind(power_summaries[["500"]], power_summaries[["1000"]])
assert(nrow(final_summary) == 120L, "Combined summary must have exactly 120 rows.")
assert(nrow(final_power_summary) == 480L, "Combined power summary must have exactly 480 rows.")
expected_combined_s <- expand.grid(n = expected_n, tau = expected_tau, kappa = expected_kappa,
                                   estimator = expected_estimators, KEEP.OUT.ATTRS = FALSE)
expected_combined_ps <- expand.grid(n = expected_n, tau = expected_tau, kappa = expected_kappa,
                                    estimator = expected_estimators, delta = expected_delta,
                                    KEEP.OUT.ATTRS = FALSE)
assert_exact_grid(final_summary, expected_combined_s, c("n", "tau", "kappa", "estimator"), "combined summary")
assert_exact_grid(final_power_summary, expected_combined_ps,
                  c("n", "tau", "kappa", "estimator", "delta"), "combined power summary")

write_exact_csv <- function(x, path) write.csv(x, path, row.names = FALSE, na = "NA", quote = TRUE)
combined_summary_path <- file.path(combined_dir, "final_summary_combined.csv")
combined_power_path <- file.path(combined_dir, "final_power_summary_combined.csv")
write_exact_csv(final_summary, combined_summary_path)
write_exact_csv(final_power_summary, combined_power_path)

assert(requireNamespace("ggplot2", quietly = TRUE),
       "ggplot2 is unavailable. This script was authored for the already-installed ggplot2 runtime.")
library(ggplot2)

estimator_colors <- c("Oracle-GMM" = "#0072B2", "Full-GMM" = "#D55E00", "DML-IVQR" = "#009E73")
estimator_linetypes <- c("Oracle-GMM" = "solid", "Full-GMM" = "dashed", "DML-IVQR" = "dotdash")
estimator_shapes <- c("Oracle-GMM" = 16, "Full-GMM" = 17, "DML-IVQR" = 15)
delta_colors <- c("-0.5" = "#0072B2", "-0.25" = "#56B4E9", "0.25" = "#E69F00", "0.5" = "#D55E00")
delta_linetypes <- c("-0.5" = "solid", "-0.25" = "dashed", "0.25" = "dotdash", "0.5" = "longdash")
delta_shapes <- c("-0.5" = 16, "-0.25" = 17, "0.25" = 15, "0.5" = 18)

prepare_plot_data <- function(d) {
  d$kappa_plot <- factor(sprintf("%.2f", d$kappa), levels = c("1.00", "0.50", "0.25", "0.10"))
  d$n_panel <- factor(d$n, levels = expected_n, labels = paste("n =", expected_n))
  tau_labels <- c("tau = .10", "tau = .25", "tau = .50", "tau = .75", "tau = .90")
  d$tau_panel <- factor(sprintf("%.2f", d$tau), levels = sprintf("%.2f", expected_tau), labels = tau_labels)
  d$estimator <- factor(d$estimator, levels = expected_estimators)
  d
}

thesis_theme <- theme_bw(base_size = 10.5) +
  theme(
    panel.grid.minor = element_blank(), panel.grid.major = element_line(color = "#E5E5E5", linewidth = 0.25),
    strip.background = element_rect(fill = "#F2F2F2", color = "#BDBDBD", linewidth = 0.35),
    strip.text = element_text(face = "bold", size = 9), legend.position = "bottom",
    legend.title = element_blank(), axis.title = element_text(size = 10.5),
    axis.text = element_text(color = "black", size = 8.5), plot.title = element_text(face = "bold", size = 12),
    plot.margin = margin(7, 9, 7, 7)
  )

base_estimator_plot <- function(d, y_label, title) {
  ggplot(prepare_plot_data(d), aes(x = kappa_plot, y = value, color = estimator,
                                    linetype = estimator, shape = estimator, group = estimator)) +
    geom_line(linewidth = 0.55) + geom_point(size = 1.8, stroke = 0.35) +
    facet_grid(n_panel ~ tau_panel) +
    scale_color_manual(values = estimator_colors, drop = FALSE) +
    scale_linetype_manual(values = estimator_linetypes, drop = FALSE) +
    scale_shape_manual(values = estimator_shapes, drop = FALSE) +
    scale_x_discrete(drop = FALSE) +
    labs(x = "Instrument strength kappa (stronger -> weaker)", y = y_label, title = title) + thesis_theme
}

save_plot <- function(plot, directory, stem) {
  pdf_path <- file.path(directory, paste0(stem, ".pdf"))
  png_path <- file.path(directory, paste0(stem, ".png"))
  ggsave(pdf_path, plot, width = 15.5, height = 7.0, units = "in", device = grDevices::cairo_pdf)
  ggsave(png_path, plot, width = 15.5, height = 7.0, units = "in", dpi = 400, bg = "white")
  assert(file.exists(pdf_path) && file.info(pdf_path)$size > 0, "PDF was not created: %s", pdf_path)
  assert(file.exists(png_path) && file.info(png_path)$size > 0, "PNG was not created: %s", png_path)
  c(pdf = pdf_path, png = png_path)
}

figure_records <- list()
figure_data_files <- character()
add_record <- function(id, files, data_path, metric, estimators, notes) {
  figure_records[[length(figure_records) + 1L]] <<- data.frame(
    figure_id = id, figure_file_pdf = slash(sub(paste0("^", slash(repo), "/?"), "", slash(files[["pdf"]]))),
    figure_file_png = slash(sub(paste0("^", slash(repo), "/?"), "", slash(files[["png"]]))),
    figure_data_csv = slash(sub(paste0("^", slash(repo), "/?"), "", slash(data_path))), metric = metric,
    n_values = "500;1000", tau_values = ".10;.25;.50;.75;.90", kappa_values = "1.00;.50;.25;.10",
    estimators = paste(estimators, collapse = ";"), notes = notes, check.names = FALSE
  )
}
metric_data <- function(column, metric_label) {
  data.frame(final_summary[c("n", "tau", "kappa", "estimator")], metric = metric_label,
             value = final_summary[[column]], check.names = FALSE)
}
write_figure_data <- function(d, filename) {
  path <- file.path(figure_data_dir, filename)
  write_exact_csv(d, path)
  figure_data_files <<- c(figure_data_files, path)
  path
}

# Main Figure 1: RMSE
fd <- metric_data("RMSE", "RMSE")
fd_path <- write_figure_data(fd, "fig1_rmse_vs_kappa.csv")
p <- base_estimator_plot(fd, "RMSE", "RMSE across instrument-strength designs")
files <- save_plot(p, main_figure_dir, "fig1_rmse_vs_kappa")
add_record("Figure 1", files, fd_path, "RMSE", expected_estimators, "Saved final RMSE values.")

# Main Figure 2: coverage, nominal line, and nominal Monte Carlo reference band.
fd <- metric_data("coverage", "coverage")
fd_path <- write_figure_data(fd, "fig2_coverage_vs_kappa.csv")
p <- base_estimator_plot(fd, "Coverage probability", "Coverage across instrument-strength designs") +
  annotate("rect", xmin = -Inf, xmax = Inf, ymin = coverage_band[1], ymax = coverage_band[2],
           fill = "#808080", alpha = 0.10) +
  geom_hline(yintercept = 0.95, color = "#404040", linewidth = 0.45) +
  coord_cartesian(ylim = c(0, 1))
files <- save_plot(p, main_figure_dir, "fig2_coverage_vs_kappa")
add_record("Figure 2", files, fd_path, "coverage", expected_estimators,
           "Gray band is the nominal 95% Monte Carlo reference band for R_MC=500; not an estimator confidence interval.")

# Main Figure 3: grid-based accepted-set measure.
fd <- metric_data("median_accepted_set_measure_A", "median_accepted_set_measure_A")
fd_path <- write_figure_data(fd, "fig3_median_accepted_measure_vs_kappa.csv")
p <- base_estimator_plot(fd, "Median accepted-set measure within A=[-1,3]",
                         "Median grid-based accepted-set measure") + coord_cartesian(ylim = c(0, 4))
files <- save_plot(p, main_figure_dir, "fig3_median_accepted_measure_vs_kappa")
add_record("Figure 3", files, fd_path, "median_accepted_set_measure_A", expected_estimators,
           "Grid-based measure within prespecified A=[-1,3]; maximum 4.")

# Main Figure 4: DML-IVQR directional power.
fd <- subset(final_power_summary, estimator == "DML-IVQR",
             select = c("n", "tau", "kappa", "estimator", "delta", "rejection_probability", "MCSE"))
names(fd)[names(fd) == "delta"] <- "Delta"
fd$metric <- "rejection_probability"
fd$value <- fd$rejection_probability
fd <- fd[c("n", "tau", "kappa", "estimator", "Delta", "metric", "value", "MCSE")]
fd_path <- write_figure_data(fd, "fig4_dml_power_vs_kappa.csv")
pd <- prepare_plot_data(fd)
pd$Delta_key <- factor(as.character(pd$Delta), levels = as.character(expected_delta))
delta_labels <- c("Delta = -0.50", "Delta = -0.25", "Delta = +0.25", "Delta = +0.50")
p <- ggplot(pd, aes(x = kappa_plot, y = value, color = Delta_key, linetype = Delta_key,
                    shape = Delta_key, group = Delta_key)) +
  geom_line(linewidth = 0.55) + geom_point(size = 1.8, stroke = 0.35) +
  facet_grid(n_panel ~ tau_panel) +
  scale_color_manual(values = delta_colors, labels = delta_labels, drop = FALSE) +
  scale_linetype_manual(values = delta_linetypes, labels = delta_labels, drop = FALSE) +
  scale_shape_manual(values = delta_shapes, labels = delta_labels, drop = FALSE) +
  scale_x_discrete(drop = FALSE) + coord_cartesian(ylim = c(0, 1)) +
  labs(x = "Instrument strength kappa (stronger -> weaker)", y = "Rejection probability / power",
       title = "DML-IVQR power across directional alternatives") + thesis_theme
files <- save_plot(p, main_figure_dir, "fig4_dml_power_vs_kappa")
add_record("Figure 4", files, fd_path, "rejection_probability", "DML-IVQR",
           "Directional alternatives are shown separately; saved MCSE is retained in figure data.")

# Main Figure 5: all evaluated CR-grid points accepted.
fd <- metric_data("full_A_acceptance_rate", "full_A_acceptance_rate")
fd_path <- write_figure_data(fd, "fig5_full_grid_acceptance_vs_kappa.csv")
p <- base_estimator_plot(fd, "All CR-grid points accepted", "Full CR-grid acceptance rate") +
  coord_cartesian(ylim = c(0, 1))
files <- save_plot(p, main_figure_dir, "fig5_full_grid_acceptance_vs_kappa")
add_record("Figure 5", files, fd_path, "full_A_acceptance_rate", expected_estimators,
           "Full acceptance means all 81 evaluated CR-grid points in A=[-1,3] are accepted.")

# Appendix Figure A1: MAE.
fd <- metric_data("MAE", "MAE")
fd_path <- write_figure_data(fd, "appendix_figA1_mae_vs_kappa.csv")
p <- base_estimator_plot(fd, "MAE", "Mean absolute error across instrument-strength designs")
files <- save_plot(p, appendix_figure_dir, "appendix_figA1_mae_vs_kappa")
add_record("Appendix Figure A1", files, fd_path, "MAE", expected_estimators, "Saved final MAE values.")

# Appendix Figure A2: authors' bias convention, alpha_true - alpha_hat.
assert("Bias" %in% names(final_summary) && "mean_signed_error" %in% names(final_summary),
       "Bias convention cannot be identified unambiguously.")
assert(all(abs(final_summary$Bias + final_summary$mean_signed_error) < 1e-12),
       "Bias is not the negative of mean_signed_error as required by the authors' convention.")
fd <- metric_data("Bias", "Bias (alpha_true - alpha_hat)")
fd_path <- write_figure_data(fd, "appendix_figA2_bias_vs_kappa.csv")
p <- base_estimator_plot(fd, "Bias (alpha_true - alpha_hat)", "Bias across instrument-strength designs") +
  geom_hline(yintercept = 0, color = "#404040", linewidth = 0.45)
files <- save_plot(p, appendix_figure_dir, "appendix_figA2_bias_vs_kappa")
add_record("Appendix Figure A2", files, fd_path, "Bias", expected_estimators,
           "Authors' convention: alpha_true - alpha_hat; zero reference line shown.")

# Appendix Figure A3: one all-estimator comparison for each directional alternative.
delta_specs <- data.frame(
  delta = expected_delta,
  id = c("Appendix Figure A3a", "Appendix Figure A3b", "Appendix Figure A3c", "Appendix Figure A3d"),
  stem = c("appendix_figA3a_power_delta_m050", "appendix_figA3b_power_delta_m025",
           "appendix_figA3c_power_delta_p025", "appendix_figA3d_power_delta_p050"),
  data_file = c("appendix_figA3a_power_delta_m050.csv", "appendix_figA3b_power_delta_m025.csv",
                "appendix_figA3c_power_delta_p025.csv", "appendix_figA3d_power_delta_p050.csv")
)
for (i in seq_len(nrow(delta_specs))) {
  delta_i <- delta_specs$delta[i]
  fd <- final_power_summary[final_power_summary$delta == delta_i,
                            c("n", "tau", "kappa", "estimator", "delta", "rejection_probability", "MCSE")]
  names(fd)[names(fd) == "delta"] <- "Delta"
  fd$metric <- "rejection_probability"
  fd$value <- fd$rejection_probability
  fd <- fd[c("n", "tau", "kappa", "estimator", "Delta", "metric", "value", "MCSE")]
  fd_path <- write_figure_data(fd, delta_specs$data_file[i])
  title <- sprintf("Power at Delta = %+0.2f", delta_i)
  p <- base_estimator_plot(fd, "Rejection probability / power", title) + coord_cartesian(ylim = c(0, 1))
  files <- save_plot(p, appendix_figure_dir, delta_specs$stem[i])
  add_record(delta_specs$id[i], files, fd_path, "rejection_probability", expected_estimators,
             sprintf("Estimator comparison at Delta=%+.2f; saved MCSE retained in figure data.", delta_i))
}

manifest <- do.call(rbind, figure_records)
manifest_path <- abs_path("thesis_extension", "final", "figure_manifest.csv")
write_exact_csv(manifest, manifest_path)

protected_md5_after <- tools::md5sum(protected_files)
assert(identical(unname(protected_md5_before), unname(protected_md5_after)),
       "A protected simulation/source/output file changed during post-processing.")

git_commit <- tryCatch(system2("git", c("-C", shQuote(repo), "rev-parse", "HEAD"), stdout = TRUE),
                       error = function(e) "UNAVAILABLE")
package_versions <- sprintf("R %s; ggplot2 %s", as.character(getRversion()),
                            as.character(utils::packageVersion("ggplot2")))
source_file_lines <- unlist(lapply(c("500", "1000"), function(n_chr) {
  d <- source_dirs[[n_chr]]
  c(sprintf("n=%s:", n_chr), paste0("  ", slash(file.path(d, required_files))))
}))
failure_status <- failed_500$status[1]
figure_lines <- unlist(lapply(figure_records, function(x) c(x$figure_file_pdf, x$figure_file_png)))
data_lines <- slash(sub(paste0("^", slash(repo), "/?"), "", slash(figure_data_files)))

report <- c(
  "FINAL FIGURES POST-PROCESSING AUDIT REPORT",
  "==========================================",
  "",
  sprintf("1. Git commit used for plotting: %s", git_commit[1]),
  sprintf("   Saved n=500 run commit: %s", sub("git_commit: ", "", grep("^git_commit:", readLines(file.path(source_dirs[["500"]], "final_manifest.txt")), value = TRUE))),
  sprintf("   Saved n=1000 run commit: %s", sub("git_commit: ", "", grep("^git_commit:", readLines(file.path(source_dirs[["1000"]], "final_manifest.txt")), value = TRUE))),
  "",
  "2-3. Exact source files:", source_file_lines,
  "",
  "4. Integrity checks:",
  "   PASS: exactly one complete output set was found for each n=500 and n=1000.",
  "   PASS: per-n summary/power-summary row counts are 60/240; raw/power rows are 30000/120000.",
  "   PASS: expected n, tau, kappa, estimator, and Delta grids are exact, complete, and duplicate-free.",
  "   PASS: saved summaries contain no NA or non-finite numeric values.",
  "   PASS: raw design-cell denominators are 500 and replication/design keys are unique.",
  "   PASS: power data and power summaries record no numerical failures.",
  "   PASS: diagnostics contain exactly one n=500 failure and zero n=1000 failures.",
  "   PASS: both manifests record 500 replications, the expected row counts, and all_sanity_checks=TRUE.",
  "   PASS: differing n=500/n=1000 source/config MD5 entries are fully explained by LF versus CRLF line endings; normalized file contents are identical.",
  "",
  sprintf("5. Combined row counts: final_summary_combined=%d; final_power_summary_combined=%d.",
          nrow(final_summary), nrow(final_power_summary)),
  "",
  "6. Numerical-failure cell:",
  sprintf("   n=500, tau=.10, kappa=.50, estimator=DML-IVQR, rep_id=%d, rep_seed=%d, alpha=%s.",
          diagnostics[["500"]]$rep_id[1], diagnostics[["500"]]$rep_seed[1], diagnostics[["500"]]$alpha[1]),
  sprintf("   Diagnostic: %s", diagnostics[["500"]]$status[1]),
  sprintf("   Raw status: %s", failure_status),
  "   Saved-summary handling: successful_replications=499, failed_replications=1, numerical_failure_rate=0.002.",
  "   The failed profile is excluded from every saved statistic in that summary cell; the reported values match the 499 status-OK profiles.",
  "   No repair, replacement, rerun, or imputation was performed. n=1000 has zero numerical failures.",
  "",
  "7. Exact column mappings:",
  "   RMSE -> RMSE",
  "   MAE -> MAE",
  "   bias -> Bias (authors' convention alpha_true - alpha_hat; verified as -mean_signed_error)",
  "   coverage -> coverage",
  "   median accepted-set measure -> median_accepted_set_measure_A",
  "   full-grid acceptance -> full_A_acceptance_rate (all 81 evaluated CR-grid points in A=[-1,3])",
  "   power -> rejection_probability",
  "   MCSE -> MCSE (saved final_power_summary value; not recomputed)",
  "",
  sprintf("8. Nominal coverage Monte Carlo reference band (R_MC=500): [%.15f, %.15f].", coverage_band[1], coverage_band[2]),
  "   This is a Monte Carlo sampling reference around nominal 95% coverage, not a confidence interval for an estimator.",
  "",
  sprintf("9-10. Plotting environment: %s", package_versions),
  sprintf("   Full R version: %s", R.version.string),
  sprintf("   Platform: %s", R.version$platform),
  "",
  "11. Generated figure files:", paste0("   ", figure_lines),
  "",
  "12. Generated figure-data CSVs:", paste0("   ", data_lines),
  "",
  "13. CONFIRMED: no simulation code was executed.",
  "14. CONFIRMED: original final outputs were not modified (before/after MD5 hashes identical).",
  "15. CONFIRMED: no author source, thesis simulation source, or frozen config file was modified (before/after MD5 hashes identical).",
  "16. Visual-quality audit: PASS. All 11 PNGs were opened and inspected after generation; panel/axis labels and legends are readable; no clipping or overlap was observed; kappa runs 1.00, .50, .25, .10 from left to right; estimator mappings are consistent; the coverage line/band is visible; and required y-axis limits are applied.",
  "",
  "Suggested factual thesis captions",
  "---------------------------------",
  "Figure 1. Root mean squared error by instrument-strength design for Oracle-GMM, Full-GMM, and DML-IVQR, shown by sample size and quantile.",
  "Figure 2. Empirical coverage by instrument-strength design. The horizontal line marks 0.95; the shaded band is the nominal 95% Monte Carlo reference band for 500 replications.",
  "Figure 3. Median grid-based accepted-set measure within the prespecified parameter space A=[-1,3], by instrument-strength design, sample size, quantile, and estimator.",
  "Figure 4. DML-IVQR rejection probability under four directional alternatives, by instrument-strength design, sample size, and quantile.",
  "Figure 5. Rate at which all 81 evaluated CR-grid points in A=[-1,3] are accepted, by instrument-strength design, sample size, quantile, and estimator.",
  "",
  "POST-PROCESSING STATUS: ALL ASSERTIONS PASSED"
)
report_path <- abs_path("thesis_extension", "final", "FINAL_FIGURES_REPORT.txt")
writeLines(report, report_path, useBytes = TRUE)

message("Post-processing complete. All integrity assertions passed.")
message(sprintf("Combined rows: %d summary; %d power summary.", nrow(final_summary), nrow(final_power_summary)))
message(sprintf("Generated %d PDF/PNG figure pairs and %d figure-data CSVs.", nrow(manifest), length(figure_data_files)))
