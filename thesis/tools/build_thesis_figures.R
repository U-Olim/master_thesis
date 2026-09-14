#!/usr/bin/env Rscript

# Deterministic, presentation-only renderings for the thesis manuscript.
# Compatible with R 3.4.3 and intentionally limited to base R plus the four
# frozen, already aggregated reporting CSVs named below. No estimation,
# simulation, calibration, raw-replication processing, or randomness occurs.

options(stringsAsFactors = FALSE, warn = 1)

stop_cleanly <- function(...) stop(..., call. = FALSE)

command <- commandArgs(trailingOnly = FALSE)
file_argument <- grep("^--file=", command, value = TRUE)
if (length(file_argument) != 1L) stop_cleanly("Cannot locate this script.")
script_path <- normalizePath(sub("^--file=", "", file_argument),
                             winslash = "/", mustWork = TRUE)
thesis_dir <- dirname(dirname(script_path))
repo_root <- dirname(thesis_dir)
reporting_dir <- file.path(repo_root, "thesis_extension", "reporting", "output")
output_dir <- file.path(thesis_dir, "figures", "generated")
check_path <- file.path(thesis_dir, "figures", "THESIS_FIGURE_DATA_CHECK.csv")

if (!dir.exists(output_dir)) {
  if (!dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)) {
    stop_cleanly("Cannot create output directory: ", output_dir)
  }
}

source_paths <- c(
  point = file.path(reporting_dir, "table_point_performance_full.csv"),
  accepted = file.path(reporting_dir, "table_cr_informativeness_full.csv"),
  power = file.path(reporting_dir, "table_power_full.csv"),
  coverage = file.path(reporting_dir, "table_coverage_full.csv")
)

read_frozen_csv <- function(path, required) {
  if (!file.exists(path)) stop_cleanly("Missing frozen reporting CSV: ", path)
  value <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  missing_columns <- setdiff(required, names(value))
  if (length(missing_columns) > 0L) {
    stop_cleanly("Missing columns in ", path, ": ",
                 paste(missing_columns, collapse = ", "))
  }
  value
}

point_data <- read_frozen_csv(source_paths["point"],
  c("n", "tau", "kappa", "estimator", "RMSE"))
accepted_data <- read_frozen_csv(source_paths["accepted"],
  c("n", "tau", "kappa", "estimator",
    "median_grid_accepted_set_measure", "computational_domain"))
power_data <- read_frozen_csv(source_paths["power"],
  c("n", "tau", "kappa", "estimator", "delta", "power"))
coverage_data <- read_frozen_csv(source_paths["coverage"],
  c("n", "tau", "kappa", "estimator", "coverage"))

tau_order <- c(0.10, 0.25, 0.50, 0.75, 0.90)
kappa_order <- c(1.00, 0.50, 0.25, 0.10)
estimator_order <- c("Oracle-GMM", "Full-GMM", "DML-IVQR-BC")
line_types <- c(1, 2, 4)
marker_types <- c(16, 15, 17)
estimator_colors <- c("#1F77B4", "#D62728", "#2CA02C")
tolerance <- 1e-14

format_set <- function(x, digits = 2L) {
  paste(sprintf(paste0("%.", digits, "f"), x), collapse = ";")
}

cell_key <- function(x, include_delta = FALSE) {
  result <- paste(as.integer(x$n), sprintf("%.2f", as.numeric(x$tau)),
                  sprintf("%.2f", as.numeric(x$kappa)),
                  as.character(x$estimator), sep = "|")
  if (include_delta) {
    result <- paste(result, sprintf("%+.2f", as.numeric(x$delta)), sep = "|")
  }
  result
}

expected_grid <- expand.grid(
  tau = tau_order,
  kappa = kappa_order,
  estimator = estimator_order,
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)

specifications <- list(
  list(id = "rmse_n500", filename = "rmse_n500_thesis.png",
       source_name = "table_point_performance_full.csv", data = point_data,
       metric = "RMSE", ylab = "RMSE", n = 500, delta = NULL,
       ylim = c(0, max(point_data$RMSE) * 1.05), reference = NULL),
  list(id = "rmse_n1000", filename = "rmse_n1000_thesis.png",
       source_name = "table_point_performance_full.csv", data = point_data,
       metric = "RMSE", ylab = "RMSE", n = 1000, delta = NULL,
       ylim = c(0, max(point_data$RMSE) * 1.05), reference = NULL),
  list(id = "accepted_measure_n500", filename = "accepted_measure_n500_thesis.png",
       source_name = "table_cr_informativeness_full.csv", data = accepted_data,
       metric = "median_grid_accepted_set_measure",
       ylab = expression("Median accepted-set measure in " * A[0]), n = 500, delta = NULL,
       ylim = c(0, max(accepted_data$median_grid_accepted_set_measure) * 1.05),
       reference = NULL),
  list(id = "accepted_measure_n1000", filename = "accepted_measure_n1000_thesis.png",
       source_name = "table_cr_informativeness_full.csv", data = accepted_data,
       metric = "median_grid_accepted_set_measure",
       ylab = expression("Median accepted-set measure in " * A[0]), n = 1000, delta = NULL,
       ylim = c(0, max(accepted_data$median_grid_accepted_set_measure) * 1.05),
       reference = NULL),
  list(id = "power_minus050_n1000", filename = "power_minus050_n1000_thesis.png",
       source_name = "table_power_full.csv", data = power_data,
       metric = "power", ylab = "Empirical power", n = 1000, delta = -0.50,
       ylim = c(0, 1), reference = NULL),
  list(id = "power_plus050_n1000", filename = "power_plus050_n1000_thesis.png",
       source_name = "table_power_full.csv", data = power_data,
       metric = "power", ylab = "Empirical power", n = 1000, delta = 0.50,
       ylim = c(0, 1), reference = NULL),
  list(id = "coverage_n500", filename = "coverage_n500_thesis.png",
       source_name = "table_coverage_full.csv", data = coverage_data,
       metric = "coverage", ylab = "Empirical coverage", n = 500, delta = NULL,
       ylim = c(0, 1), reference = 0.95),
  list(id = "coverage_n1000", filename = "coverage_n1000_thesis.png",
       source_name = "table_coverage_full.csv", data = coverage_data,
       metric = "coverage", ylab = "Empirical coverage", n = 1000, delta = NULL,
       ylim = c(0, 1), reference = 0.95)
)

prepare_plot_data <- function(specification) {
  source <- specification$data
  keep <- as.numeric(source$n) == specification$n
  include_delta <- !is.null(specification$delta)
  if (include_delta) {
    keep <- keep & abs(as.numeric(source$delta) - specification$delta) < tolerance
  }
  selected <- source[keep, , drop = FALSE]

  expected <- expected_grid
  expected$n <- specification$n
  if (include_delta) expected$delta <- specification$delta
  expected_keys <- cell_key(expected, include_delta)
  selected_keys <- cell_key(selected, include_delta)
  positions <- match(expected_keys, selected_keys)

  if (nrow(selected) != 60L || any(is.na(positions)) ||
      anyDuplicated(selected_keys) != 0L ||
      !setequal(selected_keys, expected_keys)) {
    stop_cleanly("Incomplete, duplicated, or unexpected design cells for ",
                 specification$id)
  }

  selected <- selected[positions, , drop = FALSE]
  plotted_values <- as.numeric(selected[[specification$metric]])
  source_positions <- match(cell_key(selected, include_delta),
                            cell_key(source, include_delta))
  source_values <- as.numeric(source[[specification$metric]][source_positions])
  if (any(is.na(plotted_values)) || any(!is.finite(plotted_values)) ||
      !identical(unname(plotted_values), unname(source_values))) {
    stop_cleanly("Plotted values do not exactly match the frozen source for ",
                 specification$id)
  }

  if (identical(specification$metric, "median_grid_accepted_set_measure")) {
    if (!all(selected$computational_domain == "A0=[-1,3]")) {
      stop_cleanly("Accepted-set measure is not restricted to A0=[-1,3] for ",
                   specification$id)
    }
  }

  list(
    data = selected,
    check = data.frame(
      figure = file.path("thesis", "figures", "generated", specification$filename),
      source_csv = file.path("thesis_extension", "reporting", "output",
                             specification$source_name),
      metric = specification$metric,
      expected_n = as.character(specification$n),
      actual_n = paste(sort(unique(as.integer(selected$n))), collapse = ";"),
      expected_tau = format_set(tau_order),
      actual_tau = format_set(tau_order[tau_order %in% unique(as.numeric(selected$tau))]),
      expected_kappa = format_set(kappa_order),
      actual_kappa = format_set(kappa_order[kappa_order %in% unique(as.numeric(selected$kappa))]),
      expected_estimators = paste(estimator_order, collapse = ";"),
      actual_estimators = paste(estimator_order[estimator_order %in%
        unique(as.character(selected$estimator))], collapse = ";"),
      expected_delta = if (include_delta) sprintf("%+.2f", specification$delta) else "",
      actual_delta = if (include_delta) paste(sprintf("%+.2f",
        sort(unique(as.numeric(selected$delta)))), collapse = ";") else "",
      expected_points = 60L,
      actual_points = length(plotted_values),
      missing_points = 0L,
      duplicate_points = 0L,
      nonfinite_y_values = 0L,
      max_abs_y_difference = 0,
      result = "PASS",
      stringsAsFactors = FALSE
    )
  )
}

render_plot <- function(specification, plot_data) {
  output_path <- file.path(output_dir, specification$filename)
  # Preserve the five quantile panels in their original 3-by-2 arrangement.
  # The sixth cell supplies one shared line-and-marker legend for each image.
  png(output_path, width = 3600, height = 2200, res = 400,
      pointsize = 14, bg = "white", type = "cairo")
  par(mfrow = c(3, 2), cex = 1,
      mar = c(1.8, 3.0, 1.25, 0.65),
      oma = c(1.5, 2.0, 1.8, 0.1), mgp = c(1.7, 0.5, 0),
      tcl = -0.22, cex.axis = 0.98, cex.lab = 1.05,
      cex.main = 1.05, las = 1, family = "sans",
      col.axis = "black", col.lab = "black", col.main = "black")

  for (tau_value in tau_order) {
    panel <- plot_data[abs(as.numeric(plot_data$tau) - tau_value) < tolerance,
                       , drop = FALSE]
    plot(1:4, rep(NA_real_, 4), type = "n", axes = FALSE,
         xlim = c(0.9, 4.1), ylim = specification$ylim,
         xlab = "", ylab = "",
         main = bquote(tau == .(sprintf("%.2f", tau_value))))
    axis(1, at = 1:4, labels = c("1", "0.50", "0.25", "0.10"),
         col = "black", col.ticks = "black")
    y_ticks <- pretty(specification$ylim, n = 2)
    y_ticks <- y_ticks[y_ticks >= specification$ylim[1] &
                       y_ticks <= specification$ylim[2]]
    axis(2, at = y_ticks, col = "black", col.ticks = "black")
    if (!is.null(specification$reference)) {
      abline(h = specification$reference, lty = 2, lwd = 1.1,
             col = "#B0B0B0")
    }
    for (estimator_index in seq_along(estimator_order)) {
      estimator_name <- estimator_order[estimator_index]
      series <- panel[panel$estimator == estimator_name, , drop = FALSE]
      positions <- match(kappa_order, as.numeric(series$kappa))
      if (any(is.na(positions))) {
        dev.off()
        stop_cleanly("Missing kappa value while plotting ", specification$id,
                     ", tau=", tau_value, ", estimator=", estimator_name)
      }
      y_values <- as.numeric(series[[specification$metric]][positions])
      lines(1:4, y_values, type = "o", pch = marker_types[estimator_index], cex = 1.15, lty = line_types[estimator_index],
            lwd = 2.0,
            col = estimator_colors[estimator_index])
    }
  }

  plot.new()
  legend("center", legend = estimator_order, lty = line_types,
         col = estimator_colors, pch = marker_types, pt.cex = 1.15, lwd = 2.0, bty = "n", cex = 1.0,
         seg.len = 2.6, y.intersp = 1.35, xpd = NA)
  outer_title <- paste0("n = ", specification$n)
  if (!is.null(specification$delta)) {
    outer_title <- bquote(n == .(specification$n) * ", " ~
                          Delta == .(sprintf("%+.2f", specification$delta)))
  }
  mtext(outer_title, outer = TRUE, side = 3, line = 0.15,
        font = 2, cex = 1.08)
  mtext(expression(kappa), outer = TRUE, side = 1, line = 0.25,
        cex = 1.10)
  mtext(specification$ylab, outer = TRUE, side = 2, line = 0.55,
        cex = 1.05, las = 0)
  dev.off()
  if (!file.exists(output_path) || file.info(output_path)$size <= 0) {
    stop_cleanly("PNG was not created correctly: ", output_path)
  }
  invisible(output_path)
}

checks <- vector("list", length(specifications))
for (index in seq_along(specifications)) {
  prepared <- prepare_plot_data(specifications[[index]])
  render_plot(specifications[[index]], prepared$data)
  checks[[index]] <- prepared$check
}

check_table <- do.call(rbind, checks)
if (nrow(check_table) != 8L || !all(check_table$result == "PASS")) {
  stop_cleanly("Figure-data verification did not pass for all eight figures.")
}
write.table(check_table, file = check_path, sep = ",", row.names = FALSE,
            col.names = TRUE, quote = TRUE, qmethod = "double", na = "")

message("Created 8 deterministic thesis figures.")
message("Figure-data checks: 8/8 PASS.")
