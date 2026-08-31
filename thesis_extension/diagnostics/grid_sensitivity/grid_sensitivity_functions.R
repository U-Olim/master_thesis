empty_failures_frame <- function() data.frame(
  n = integer(), replication = integer(), tau = numeric(), kappa = numeric(),
  estimator = character(), a = numeric(), stage = character(),
  error_message = character(), stringsAsFactors = FALSE)

safe_mean <- function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
safe_median <- function(x) if (all(is.na(x))) NA_real_ else median(x, na.rm = TRUE)

range_metrics_from_profile <- function(profile, ranges, h) {
  do.call(rbind, lapply(seq_len(nrow(ranges)), function(i) {
    keep <- profile$a >= ranges$range_lower[i] & profile$a <= ranges$range_upper[i]
    piece <- profile[keep, , drop = FALSE]
    failed <- any(!is.finite(piece$W))
    accepted <- piece$accepted
    if (failed) {
      measure <- share <- count <- left <- right <- either <- both <- all_points <- NA
    } else {
      measure <- sum(h * (accepted[-length(accepted)] + accepted[-1L]) / 2)
      share <- mean(accepted)
      count <- sum(accepted)
      left <- accepted[1L]
      right <- accepted[length(accepted)]
      either <- left || right
      both <- left && right
      all_points <- all(accepted)
    }
    data.frame(
      n = profile$n[1L], replication = profile$replication[1L],
      tau = profile$tau[1L], kappa = profile$kappa[1L],
      estimator = profile$estimator[1L], range = ranges$range[i],
      range_lower = ranges$range_lower[i], range_upper = ranges$range_upper[i],
      range_width = ranges$range_upper[i] - ranges$range_lower[i],
      number_grid_points = nrow(piece), profile_failed = failed,
      grid_accepted_set_measure = measure, accepted_grid_share = share,
      number_accepted_grid_points = count,
      left_boundary_accepted = left, right_boundary_accepted = right,
      either_boundary_accepted = either, both_boundaries_accepted = both,
      all_grid_points_accepted = all_points, stringsAsFactors = FALSE)
  }))
}

expansion_metrics_from_ranges <- function(metrics) {
  stopifnot(identical(as.character(metrics$range), c("A_1_-1_3", "A_2_-3_5", "A_3_-5_7")))
  L <- metrics$grid_accepted_set_measure
  shares <- metrics$accepted_grid_share
  boundaries <- metrics$either_boundary_accepted
  all_grid <- metrics$all_grid_points_accepted
  data.frame(
    n = metrics$n[1L], replication = metrics$replication[1L],
    tau = metrics$tau[1L], kappa = metrics$kappa[1L], estimator = metrics$estimator[1L],
    L_A1 = L[1L], L_A2 = L[2L], L_A3 = L[3L],
    added_measure_A1_to_A2 = L[2L] - L[1L],
    added_measure_A2_to_A3 = L[3L] - L[2L],
    accepted_share_A1 = shares[1L], accepted_share_A2 = shares[2L], accepted_share_A3 = shares[3L],
    boundary_A1 = boundaries[1L], boundary_A2 = boundaries[2L], boundary_A3 = boundaries[3L],
    all_grid_A1 = all_grid[1L], all_grid_A2 = all_grid[2L], all_grid_A3 = all_grid[3L],
    stringsAsFactors = FALSE)
}

evaluate_gmm_wide <- function(dat, controls, tau, grid) {
  W <- rep(NA_real_, length(grid)); errors <- list()
  for (j in seq_along(grid)) {
    attempt <- tryCatch(
      author_gmm_candidate(dat$y, dat$D, controls, dat$Z, tau, grid[j]),
      error = identity)
    if (inherits(attempt, "error")) {
      errors[[length(errors) + 1L]] <- list(a = grid[j], message = conditionMessage(attempt))
    } else if (!is.finite(attempt)) {
      errors[[length(errors) + 1L]] <- list(a = grid[j], message = "non-finite W")
    } else W[j] <- as.numeric(attempt)
  }
  list(W = W, errors = errors)
}

evaluate_dml_wide <- function(dat, tau, grid, workers) {
  attempt <- tryCatch(
    author_bc_evaluate(dat$y, dat$D, dat$X, dat$Z, tau, points = grid, core = workers),
    error = identity)
  if (inherits(attempt, "error")) {
    return(list(W = rep(NA_real_, length(grid)),
                errors = list(list(a = NA_real_, message = conditionMessage(attempt))),
                whole_profile_error = TRUE))
  }
  list(W = attempt$W, errors = attempt$errors, whole_profile_error = FALSE)
}

run_grid_sensitivity <- function(cfg, replications, tau_values, kappa_values) {
  profiles <- list(); range_metrics <- list(); expansion_metrics <- list(); failures <- list()
  add_failure <- function(replication, tau, kappa, estimator, a, stage, message) {
    failures[[length(failures) + 1L]] <<- data.frame(
      n = cfg$sample_size, replication = replication, tau = tau, kappa = kappa,
      estimator = estimator, a = a, stage = stage, error_message = message,
      stringsAsFactors = FALSE)
  }
  for (replication in seq_len(replications)) {
    primitives <- generate_kappa_primitives(n = cfg$sample_size, p = cfg$p)
    for (kappa in kappa_values) {
      dat <- make_kappa_dataset(primitives, kappa, cfg$s)
      for (tau in tau_values) for (estimator in cfg$estimators) {
        evaluated <- if (estimator == "Oracle-GMM") {
          evaluate_gmm_wide(dat, dat$X1, tau, cfg$wide_grid)
        } else if (estimator == "Full-GMM") {
          evaluate_gmm_wide(dat, dat$X, tau, cfg$wide_grid)
        } else if (estimator == "DML-IVQR-BC") {
          evaluate_dml_wide(dat, tau, cfg$wide_grid, cfg$workers)
        } else stop("Unknown estimator: ", estimator)
        whole_error <- isTRUE(evaluated$whole_profile_error)
        for (err in evaluated$errors) add_failure(
          replication, tau, kappa, estimator, err$a,
          if (whole_error) "profile" else "profile_candidate", err$message)
        accepted <- ifelse(is.finite(evaluated$W), evaluated$W <= cfg$critical_value, NA)
        profile <- data.frame(
          n = cfg$sample_size, replication = replication, tau = tau, kappa = kappa,
          estimator = estimator, a = cfg$wide_grid, W = evaluated$W,
          accepted = accepted, stringsAsFactors = FALSE)
        metrics <- range_metrics_from_profile(profile, cfg$ranges, cfg$grid_step)
        profiles[[length(profiles) + 1L]] <- profile
        range_metrics[[length(range_metrics) + 1L]] <- metrics
        expansion_metrics[[length(expansion_metrics) + 1L]] <- expansion_metrics_from_ranges(metrics)
      }
    }
  }
  list(
    profiles = do.call(rbind, profiles),
    range_metrics = do.call(rbind, range_metrics),
    expansion_metrics = do.call(rbind, expansion_metrics),
    failures = if (length(failures)) do.call(rbind, failures) else empty_failures_frame())
}

summarize_ranges <- function(x) {
  keys <- interaction(x$n, x$tau, x$kappa, x$estimator, x$range, drop = TRUE, lex.order = TRUE)
  do.call(rbind, lapply(split(x, keys), function(z) data.frame(
    n = z$n[1L], tau = z$tau[1L], kappa = z$kappa[1L], estimator = z$estimator[1L], range = z$range[1L],
    total_replications = nrow(z), successful_profiles = sum(!z$profile_failed), failed_profiles = sum(z$profile_failed),
    median_grid_accepted_set_measure = safe_median(z$grid_accepted_set_measure),
    mean_grid_accepted_set_measure = safe_mean(z$grid_accepted_set_measure),
    median_accepted_grid_share = safe_median(z$accepted_grid_share),
    mean_accepted_grid_share = safe_mean(z$accepted_grid_share),
    median_number_accepted_grid_points = safe_median(z$number_accepted_grid_points),
    mean_number_accepted_grid_points = safe_mean(z$number_accepted_grid_points),
    left_boundary_acceptance_rate = safe_mean(z$left_boundary_accepted),
    right_boundary_acceptance_rate = safe_mean(z$right_boundary_accepted),
    either_boundary_acceptance_rate = safe_mean(z$either_boundary_accepted),
    both_boundaries_acceptance_rate = safe_mean(z$both_boundaries_accepted),
    all_grid_points_acceptance_rate = safe_mean(z$all_grid_points_accepted), stringsAsFactors = FALSE)))
}

summarize_expansions <- function(x) {
  keys <- interaction(x$n, x$tau, x$kappa, x$estimator, drop = TRUE, lex.order = TRUE)
  do.call(rbind, lapply(split(x, keys), function(z) data.frame(
    n = z$n[1L], tau = z$tau[1L], kappa = z$kappa[1L], estimator = z$estimator[1L],
    total_replications = nrow(z),
    median_added_measure_A1_to_A2 = safe_median(z$added_measure_A1_to_A2),
    mean_added_measure_A1_to_A2 = safe_mean(z$added_measure_A1_to_A2),
    median_added_measure_A2_to_A3 = safe_median(z$added_measure_A2_to_A3),
    mean_added_measure_A2_to_A3 = safe_mean(z$added_measure_A2_to_A3),
    median_accepted_share_A1 = safe_median(z$accepted_share_A1), mean_accepted_share_A1 = safe_mean(z$accepted_share_A1),
    median_accepted_share_A2 = safe_median(z$accepted_share_A2), mean_accepted_share_A2 = safe_mean(z$accepted_share_A2),
    median_accepted_share_A3 = safe_median(z$accepted_share_A3), mean_accepted_share_A3 = safe_mean(z$accepted_share_A3),
    boundary_acceptance_rate_A1 = safe_mean(z$boundary_A1), boundary_acceptance_rate_A2 = safe_mean(z$boundary_A2),
    boundary_acceptance_rate_A3 = safe_mean(z$boundary_A3), all_grid_acceptance_rate_A1 = safe_mean(z$all_grid_A1),
    all_grid_acceptance_rate_A2 = safe_mean(z$all_grid_A2), all_grid_acceptance_rate_A3 = safe_mean(z$all_grid_A3),
    stringsAsFactors = FALSE)))
}

validate_failure_scope <- function(cfg) {
  base <- data.frame(n = 1000L, replication = 1L, tau = 0.5, kappa = 1,
                     estimator = "test", a = cfg$wide_grid, W = rep(0, 121L),
                     accepted = rep(TRUE, 121L), stringsAsFactors = FALSE)
  at_six <- base; at_six$W[at_six$a == 6] <- NA_real_; at_six$accepted[at_six$a == 6] <- NA
  at_four <- base; at_four$W[at_four$a == 4] <- NA_real_; at_four$accepted[at_four$a == 4] <- NA
  at_zero <- base; at_zero$W[at_zero$a == 0] <- NA_real_; at_zero$accepted[at_zero$a == 0] <- NA
  identical(range_metrics_from_profile(at_six, cfg$ranges, 0.1)$profile_failed, c(FALSE, FALSE, TRUE)) &&
    identical(range_metrics_from_profile(at_four, cfg$ranges, 0.1)$profile_failed, c(FALSE, TRUE, TRUE)) &&
    identical(range_metrics_from_profile(at_zero, cfg$ranges, 0.1)$profile_failed, c(TRUE, TRUE, TRUE))
}

validate_single_wide_profile_subsetting <- function(profiles, cfg) {
  keys <- interaction(profiles$replication, profiles$tau, profiles$kappa,
                      profiles$estimator, drop = TRUE)
  all(vapply(split(profiles, keys), function(profile) {
    if (nrow(profile) != 121L || anyDuplicated(profile$a)) return(FALSE)
    all(vapply(seq_len(nrow(cfg$ranges)), function(i) {
      keep <- profile$a >= cfg$ranges$range_lower[i] & profile$a <= cfg$ranges$range_upper[i]
      nested <- profile[keep, c("a", "W"), drop = FALSE]
      source_rows <- profile[match(nested$a, profile$a), c("a", "W"), drop = FALSE]
      row.names(nested) <- NULL
      row.names(source_rows) <- NULL
      identical(nested, source_rows)
    }, logical(1)))
  }, logical(1)))
}
