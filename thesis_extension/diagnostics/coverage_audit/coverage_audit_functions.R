required_result_columns <- c(
  "n", "replication", "tau", "kappa", "estimator", "alpha_true",
  "W_true", "covered", "rejected_true", "profile_failed",
  "coverage_failed", "failed")

required_summary_columns <- c(
  "n", "tau", "kappa", "estimator", "total_replications",
  "successful_coverage_evaluations", "failed_coverage_evaluations",
  "Coverage", "Size")

assert_columns <- function(data, required, label) {
  missing <- setdiff(required, names(data))
  if (length(missing)) {
    stop(label, " is missing required columns: ", paste(missing, collapse = ", "))
  }
  invisible(TRUE)
}

as_logical_strict <- function(x, label) {
  if (is.logical(x)) return(x)
  raw <- toupper(trimws(as.character(x)))
  allowed <- is.na(raw) | raw %in% c("TRUE", "FALSE", "")
  if (any(!allowed)) stop(label, " contains non-logical values.")
  out <- rep(NA, length(raw))
  out[raw == "TRUE"] <- TRUE
  out[raw == "FALSE"] <- FALSE
  out
}

wilson_interval <- function(successes, n, confidence = 0.95) {
  if (!is.finite(n) || n <= 0) return(c(lower = NA_real_, upper = NA_real_))
  p <- successes / n
  z <- qnorm(1 - (1 - confidence) / 2)
  z2 <- z^2
  denominator <- 1 + z2 / n
  center <- (p + z2 / (2 * n)) / denominator
  half <- z * sqrt(p * (1 - p) / n + z2 / (4 * n^2)) / denominator
  c(lower = max(0, center - half), upper = min(1, center + half))
}

finite_quantile <- function(x, probability) {
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  unname(quantile(x, probability, names = FALSE, type = 7))
}

finite_stat <- function(x, function_name) {
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  if (function_name == "mean") return(mean(x))
  if (function_name == "sd") return(if (length(x) > 1L) sd(x) else NA_real_)
  if (function_name == "min") return(min(x))
  if (function_name == "max") return(max(x))
  if (function_name == "var") return(if (length(x) > 1L) var(x) else NA_real_)
  stop("Unknown finite_stat function: ", function_name)
}

ecdf_chisq_distance <- function(x, df = 2) {
  x <- sort(x[is.finite(x)])
  n <- length(x)
  if (!n) return(NA_real_)
  theoretical <- pchisq(x, df = df)
  max(c(seq_len(n) / n - theoretical,
        theoretical - (seq_len(n) - 1L) / n))
}

summarise_coverage_cell <- function(group, critical_value, nominal = 0.95) {
  w <- group$W_true
  finite <- is.finite(w)
  usable <- w[finite]
  n_available <- length(usable)
  covered <- usable <= critical_value
  coverage <- if (n_available) mean(covered) else NA_real_
  successes <- if (n_available) sum(covered) else 0L
  interval <- wilson_interval(successes, n_available)
  empirical_variance <- finite_stat(usable, "var")

  data.frame(
    n = group$n[1], tau = group$tau[1], kappa = group$kappa[1],
    estimator = group$estimator[1],
    total_rows = nrow(group), R_available = n_available,
    number_missing = sum(is.na(w)),
    number_non_finite = sum(!is.finite(w)),
    empirical_coverage = coverage,
    empirical_size = if (is.finite(coverage)) 1 - coverage else NA_real_,
    coverage_mcse = if (n_available)
      sqrt(coverage * (1 - coverage) / n_available) else NA_real_,
    coverage_mc95_lower = interval["lower"],
    coverage_mc95_upper = interval["upper"],
    nominal_0p95_inside_mc_interval = if (all(is.finite(interval)))
      interval["lower"] <= nominal && nominal <= interval["upper"] else NA,
    mean_W_true = finite_stat(usable, "mean"),
    sd_W_true = finite_stat(usable, "sd"),
    min_W_true = finite_stat(usable, "min"),
    q10_W_true = finite_quantile(usable, 0.10),
    q25_W_true = finite_quantile(usable, 0.25),
    median_W_true = finite_quantile(usable, 0.50),
    q75_W_true = finite_quantile(usable, 0.75),
    q90_W_true = finite_quantile(usable, 0.90),
    q95_W_true = finite_quantile(usable, 0.95),
    q99_W_true = finite_quantile(usable, 0.99),
    max_W_true = finite_stat(usable, "max"),
    empirical_rejection_rate = if (n_available)
      mean(usable > critical_value) else NA_real_,
    q95_ratio_to_chisq2_q95 = finite_quantile(usable, 0.95) / critical_value,
    mean_minus_chisq2_mean = finite_stat(usable, "mean") - 2,
    variance_minus_chisq2_variance = empirical_variance - 4,
    max_abs_ecdf_difference_chisq2 = ecdf_chisq_distance(usable, 2),
    stringsAsFactors = FALSE)
}

cell_keys <- function(data) {
  keys <- unique(data[, c("n", "tau", "kappa", "estimator"), drop = FALSE])
  keys[order(keys$n, keys$tau, -keys$kappa, keys$estimator), , drop = FALSE]
}

select_cell <- function(data, key) {
  data[data$n == key$n & data$tau == key$tau &
         data$kappa == key$kappa & data$estimator == key$estimator,
       , drop = FALSE]
}

summarise_all_cells <- function(data, critical_value) {
  keys <- cell_keys(data)
  rows <- lapply(seq_len(nrow(keys)), function(index) {
    summarise_coverage_cell(select_cell(data, keys[index, , drop = FALSE]),
                            critical_value)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

consistency_checks <- function(data, critical_value, expected_replications = 500L) {
  keys <- cell_keys(data)
  rows <- lapply(seq_len(nrow(keys)), function(index) {
    group <- select_cell(data, keys[index, , drop = FALSE])
    w <- group$W_true
    finite <- is.finite(w)
    expected_reject <- w > critical_value
    expected_cover <- w <= critical_value
    rejected <- as_logical_strict(group$rejected_true, "rejected_true")
    covered <- as_logical_strict(group$covered, "covered")
    profile_failed <- as_logical_strict(group$profile_failed, "profile_failed")
    coverage_failed <- as_logical_strict(group$coverage_failed, "coverage_failed")
    failed <- as_logical_strict(group$failed, "failed")
    expected_ids <- seq_len(expected_replications)
    missing_ids <- setdiff(expected_ids, group$replication)
    unexpected_ids <- setdiff(unique(group$replication), expected_ids)
    truth_expected <- 1 + qnorm(group$tau)

    data.frame(
      n = group$n[1], tau = group$tau[1], kappa = group$kappa[1],
      estimator = group$estimator[1], rows = nrow(group),
      duplicate_replication_rows = sum(duplicated(group$replication)),
      missing_replication_count = length(missing_ids),
      missing_replication_ids = paste(missing_ids, collapse = ";"),
      unexpected_replication_count = length(unexpected_ids),
      unexpected_replication_ids = paste(unexpected_ids, collapse = ";"),
      na_W_true = sum(is.na(w) & !is.nan(w)),
      nan_W_true = sum(is.nan(w)),
      positive_inf_W_true = sum(is.infinite(w) & w > 0, na.rm = TRUE),
      negative_inf_W_true = sum(is.infinite(w) & w < 0, na.rm = TRUE),
      negative_finite_W_true = sum(finite & w < 0),
      above_chisq2_q99 = sum(finite & w > qchisq(0.99, 2)),
      above_chisq2_q999 = sum(finite & w > qchisq(0.999, 2)),
      profile_failed_true = sum(profile_failed %in% TRUE),
      coverage_failed_true = sum(coverage_failed %in% TRUE),
      any_failed_true = sum(failed %in% TRUE),
      rejection_indicator_mismatches = sum(
        finite & (is.na(rejected) | rejected != expected_reject)),
      coverage_indicator_mismatches = sum(
        finite & (is.na(covered) | covered != expected_cover)),
      coverage_rejection_complement_mismatches = sum(
        finite & (is.na(covered) | is.na(rejected) | covered == rejected)),
      alpha_true_formula_mismatches = sum(
        !is.finite(group$alpha_true) |
          abs(group$alpha_true - truth_expected) > 1e-12),
      stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

primary_outliers <- function(data, primary_taus, estimator_values, top_n = 10L) {
  rows <- list()
  row_index <- 0L
  for (tau_value in primary_taus) {
    for (estimator_value in estimator_values) {
      group <- data[data$n == 1000 & data$kappa == 1 &
                      data$tau == tau_value & data$estimator == estimator_value,
                    , drop = FALSE]
      group <- group[is.finite(group$W_true), , drop = FALSE]
      group <- group[order(group$W_true, decreasing = TRUE), , drop = FALSE]
      group <- head(group, top_n)
      if (nrow(group)) {
        row_index <- row_index + 1L
        rows[[row_index]] <- data.frame(
          n = group$n, tau = group$tau, kappa = group$kappa,
          estimator = group$estimator,
          upper_tail_rank = seq_len(nrow(group)),
          replication = group$replication, W_true = group$W_true,
          rejected_true = group$rejected_true,
          above_chisq2_q99 = group$W_true > qchisq(0.99, 2),
          above_chisq2_q999 = group$W_true > qchisq(0.999, 2),
          stringsAsFactors = FALSE)
      }
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

paired_estimator_comparisons <- function(data, critical_value) {
  pair_specs <- list(
    c("DML vs Oracle", "DML-IVQR-BC", "Oracle-GMM"),
    c("DML vs Full", "DML-IVQR-BC", "Full-GMM"),
    c("Oracle vs Full", "Oracle-GMM", "Full-GMM"))
  rows <- list()
  row_index <- 0L
  for (tau_value in sort(unique(data$tau))) {
    base <- data[data$n == 1000 & data$kappa == 1 & data$tau == tau_value,
                 c("replication", "estimator", "W_true"), drop = FALSE]
    for (spec in pair_specs) {
      a <- base[base$estimator == spec[2], c("replication", "W_true")]
      b <- base[base$estimator == spec[3], c("replication", "W_true")]
      names(a)[2] <- "W_a"
      names(b)[2] <- "W_b"
      paired <- merge(a, b, by = "replication", all = TRUE, sort = TRUE)
      usable <- is.finite(paired$W_a) & is.finite(paired$W_b)
      p <- paired[usable, , drop = FALSE]
      difference <- p$W_a - p$W_b
      reject_a <- p$W_a > critical_value
      reject_b <- p$W_b > critical_value
      denominator <- nrow(p)
      fraction <- function(condition) if (denominator) mean(condition) else NA_real_
      row_index <- row_index + 1L
      rows[[row_index]] <- data.frame(
        n = 1000, kappa = 1, tau = tau_value,
        comparison = spec[1], estimator_A = spec[2], estimator_B = spec[3],
        paired_R_available = denominator,
        missing_or_unmatched = nrow(paired) - denominator,
        correlation_W_true = if (denominator > 1L) cor(p$W_a, p$W_b) else NA_real_,
        mean_paired_W_difference_A_minus_B = finite_stat(difference, "mean"),
        median_paired_W_difference_A_minus_B = finite_quantile(difference, 0.50),
        q90_paired_W_difference_A_minus_B = finite_quantile(difference, 0.90),
        q95_paired_W_difference_A_minus_B = finite_quantile(difference, 0.95),
        fraction_A_rejects_B_accepts = fraction(reject_a & !reject_b),
        fraction_A_accepts_B_rejects = fraction(!reject_a & reject_b),
        fraction_both_reject = fraction(reject_a & reject_b),
        fraction_both_accept = fraction(!reject_a & !reject_b),
        stringsAsFactors = FALSE)
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

classify_distribution_pattern <- function(row) {
  broad <- is.finite(row$median_W_true) &&
    row$median_W_true > qchisq(0.50, 2) &&
    row$q75_W_true > qchisq(0.75, 2) &&
    row$q90_W_true > qchisq(0.90, 2)
  extreme <- is.finite(row$q99_W_true) &&
    (row$q99_W_true > 1.5 * qchisq(0.99, 2) ||
       row$max_W_true > 2 * qchisq(0.99, 2))
  if (broad && extreme) return("C: broad rightward shift and extreme-tail values")
  if (broad) return("A: broad rightward shift")
  if (extreme) return("B: extreme-tail values without the defined broad shift")
  "D: neither under the operational rule / unclear"
}

safe_slug <- function(estimator) {
  value <- tolower(gsub("[^A-Za-z0-9]+", "_", estimator))
  gsub("^_|_$", "", value)
}

tau_slug <- function(tau) sprintf("%0.2f", tau)

make_primary_figures <- function(data, figures_dir, critical_value,
                                 primary_taus, estimator_values) {
  files <- character(0)
  for (tau_value in primary_taus) {
    for (estimator_value in estimator_values) {
      group <- data[data$n == 1000 & data$kappa == 1 &
                      data$tau == tau_value & data$estimator == estimator_value,
                    , drop = FALSE]
      w <- group$W_true[is.finite(group$W_true)]
      if (!length(w)) stop("No finite W_true values for a primary cell.")
      stem <- paste0("tau_", gsub("\\.", "p", tau_slug(tau_value)), "_",
                     safe_slug(estimator_value))
      title <- paste0("n=1000, kappa=1, tau=", tau_slug(tau_value),
                      ", ", estimator_value)

      histogram_file <- file.path(figures_dir, paste0("histogram_", stem, ".png"))
      png(histogram_file, width = 900, height = 700, res = 120)
      hist(w, probability = TRUE, main = title,
           xlab = expression(W[N](alpha[0])))
      curve(dchisq(x, df = 2), add = TRUE, lty = 2)
      abline(v = critical_value, lty = 3)
      dev.off()
      files <- c(files, histogram_file)

      ecdf_file <- file.path(figures_dir, paste0("ecdf_", stem, ".png"))
      png(ecdf_file, width = 900, height = 700, res = 120)
      plot(ecdf(w), main = title, xlab = expression(W[N](alpha[0])),
           ylab = "Empirical CDF")
      curve(pchisq(x, df = 2), add = TRUE, lty = 2)
      abline(v = critical_value, lty = 3)
      dev.off()
      files <- c(files, ecdf_file)

      qq_file <- file.path(figures_dir, paste0("qq_", stem, ".png"))
      theoretical <- qchisq((seq_along(w) - 0.5) / length(w), df = 2)
      png(qq_file, width = 900, height = 700, res = 120)
      plot(theoretical, sort(w), main = title,
           xlab = "Theoretical chi-square(2) quantiles",
           ylab = "Empirical W_true quantiles")
      abline(0, 1, lty = 2)
      dev.off()
      files <- c(files, qq_file)
    }
  }
  files
}

make_q95_comparison_figure <- function(strong_cells, figures_dir, critical_value,
                                       estimator_values) {
  tau_values <- sort(unique(strong_cells$tau))
  matrix_values <- sapply(estimator_values, function(estimator_value) {
    rows <- strong_cells[strong_cells$estimator == estimator_value, ]
    rows$q95_W_true[match(tau_values, rows$tau)]
  })
  output <- file.path(figures_dir, "q95_comparison_n1000_kappa1.png")
  png(output, width = 900, height = 700, res = 120)
  matplot(tau_values, matrix_values, type = "b",
          xlab = "tau", ylab = "Empirical q95 of W_true",
          main = "n=1000, kappa=1")
  abline(h = critical_value, lty = 2)
  legend("topleft", legend = estimator_values,
         col = seq_along(estimator_values), lty = seq_along(estimator_values),
         pch = seq_along(estimator_values), bty = "n")
  dev.off()
  output
}

format_markdown_value <- function(value, digits = 4) {
  if (length(value) == 0L || is.na(value)) return("NA")
  if (is.logical(value)) return(if (value) "TRUE" else "FALSE")
  if (is.numeric(value)) return(formatC(value, digits = digits, format = "f"))
  gsub("\\|", "\\\\|", as.character(value))
}

markdown_table <- function(data, digits = 4) {
  if (!nrow(data)) return("(no rows)")
  header <- paste0("| ", paste(names(data), collapse = " | "), " |")
  divider <- paste0("|", paste(rep("---", ncol(data)), collapse = "|"), "|")
  body <- apply(data, 1, function(row) {
    paste0("| ", paste(vapply(row, format_markdown_value,
                               character(1), digits = digits),
                         collapse = " | "), " |")
  })
  c(header, divider, body)
}
