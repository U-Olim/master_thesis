empty_failures_frame <- function() data.frame(
  n = integer(), replication = integer(), tau = numeric(), kappa = numeric(),
  estimator = character(), a = numeric(), stage = character(),
  error_message = character(), stringsAsFactors = FALSE)

safe_mean <- function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
safe_median <- function(x) if (all(is.na(x))) NA_real_ else median(x, na.rm = TRUE)

primitive_filename <- function(replication) sprintf("rep_%03d.rds", replication)

file_md5 <- function(path) unname(as.character(tools::md5sum(path)))

save_primitive <- function(primitives, replication, primitive_dir) {
  dir.create(primitive_dir, recursive = TRUE, showWarnings = FALSE)
  filename <- primitive_filename(replication)
  path <- file.path(primitive_dir, filename)
  saveRDS(primitives, path)
  if (!identical(readRDS(path), primitives)) stop("Primitive RDS round-trip mismatch: ", filename)
  data.frame(replication = replication, filename = filename, hash = file_md5(path),
             stringsAsFactors = FALSE)
}

verify_primitive_hashes <- function(hash_table, primitive_dir, expected_replications) {
  required_columns <- c("replication", "filename", "hash")
  if (!identical(names(hash_table), required_columns)) {
    return(list(ok = FALSE, message = "Primitive hash table schema mismatch."))
  }
  if (nrow(hash_table) != expected_replications ||
      !identical(as.integer(hash_table$replication), seq_len(expected_replications))) {
    return(list(ok = FALSE, message = "Primitive hash table replication count/order mismatch."))
  }
  expected_names <- vapply(seq_len(expected_replications), primitive_filename, character(1))
  if (!identical(as.character(hash_table$filename), expected_names)) {
    return(list(ok = FALSE, message = "Primitive filenames do not match the frozen convention."))
  }
  paths <- file.path(primitive_dir, hash_table$filename)
  missing <- !file.exists(paths)
  if (any(missing)) {
    return(list(ok = FALSE, message = paste("Missing primitive files:",
                                            paste(hash_table$filename[missing], collapse = ", "))))
  }
  actual <- vapply(paths, file_md5, character(1))
  mismatch <- actual != as.character(hash_table$hash)
  if (any(mismatch)) {
    return(list(ok = FALSE, message = paste("Primitive hash mismatch:",
                                            paste(hash_table$filename[mismatch], collapse = ", "))))
  }
  list(ok = TRUE, message = "All primitive hashes match.")
}

range_metrics_from_profile <- function(profile, ranges, h) {
  do.call(rbind, lapply(seq_len(nrow(ranges)), function(i) {
    keep <- profile$a >= ranges$range_lower[i] & profile$a <= ranges$range_upper[i]
    piece <- profile[keep, , drop = FALSE]
    failed <- any(!is.finite(piece$W))
    if (failed) {
      measure <- share <- accepted_count <- NA_real_
      left <- right <- either <- both <- all_points <- NA
    } else {
      accepted <- piece$accepted
      measure <- sum(h * (accepted[-length(accepted)] + accepted[-1L]) / 2)
      share <- mean(accepted)
      accepted_count <- sum(accepted)
      left <- accepted[1L]
      right <- accepted[length(accepted)]
      either <- left || right
      both <- left && right
      all_points <- all(accepted)
    }
    data.frame(
      n = profile$n[1L], replication = profile$replication[1L],
      tau = profile$tau[1L], kappa = profile$kappa[1L], estimator = profile$estimator[1L],
      range = ranges$range[i], range_lower = ranges$range_lower[i],
      range_upper = ranges$range_upper[i],
      range_width = ranges$range_upper[i] - ranges$range_lower[i],
      number_grid_points = nrow(piece), profile_failed = failed,
      grid_accepted_set_measure = measure, accepted_grid_share = share,
      number_accepted_grid_points = accepted_count,
      left_boundary_accepted = left, right_boundary_accepted = right,
      either_boundary_accepted = either, both_boundaries_accepted = both,
      all_grid_points_accepted = all_points, stringsAsFactors = FALSE)
  }))
}

three_valued_any <- function(x) {
  if (any(x %in% TRUE)) return(TRUE)
  if (any(is.na(x))) return(NA)
  FALSE
}

trigger_boundary_contact_from_profile <- function(profile) {
  at_boundary <- profile$a == -3 | profile$a == 5
  three_valued_any(profile$accepted[at_boundary])
}

outer_band_contact_from_profile <- function(profile, cfg) {
  in_outer_band <- (profile$a >= cfg$outer_band_left[1L] & profile$a <= cfg$outer_band_left[2L]) |
    (profile$a >= cfg$outer_band_right[1L] & profile$a <= cfg$outer_band_right[2L])
  three_valued_any(profile$accepted[in_outer_band])
}

stage1_expansion_from_ranges <- function(metrics, profile, cfg) {
  stopifnot(identical(as.character(metrics$range), c("A_0_-1_3", "A_1_-3_5")))
  L <- metrics$grid_accepted_set_measure
  data.frame(
    n = metrics$n[1L], replication = metrics$replication[1L], tau = metrics$tau[1L],
    kappa = metrics$kappa[1L], estimator = metrics$estimator[1L],
    L_A0 = L[1L], L_A1 = L[2L], added_measure_A0_to_A1 = L[2L] - L[1L],
    accepted_share_A0 = metrics$accepted_grid_share[1L],
    accepted_share_A1 = metrics$accepted_grid_share[2L],
    boundary_A0 = metrics$either_boundary_accepted[1L],
    boundary_A1 = metrics$either_boundary_accepted[2L],
    all_grid_A0 = metrics$all_grid_points_accepted[1L],
    all_grid_A1 = metrics$all_grid_points_accepted[2L],
    trigger_either_boundary = trigger_boundary_contact_from_profile(profile),
    outer_band_contact = outer_band_contact_from_profile(profile, cfg),
    stringsAsFactors = FALSE)
}

stage2_expansion_from_ranges <- function(metrics) {
  stopifnot(identical(as.character(metrics$range), c("A_0_-1_3", "A_1_-3_5", "A_2_-5_7")))
  L <- metrics$grid_accepted_set_measure
  data.frame(
    n = metrics$n[1L], replication = metrics$replication[1L], tau = metrics$tau[1L],
    kappa = metrics$kappa[1L], estimator = metrics$estimator[1L],
    L_A0 = L[1L], L_A1 = L[2L], L_A2 = L[3L],
    added_measure_A0_to_A1 = L[2L] - L[1L],
    added_measure_A1_to_A2 = L[3L] - L[2L],
    accepted_share_A0 = metrics$accepted_grid_share[1L],
    accepted_share_A1 = metrics$accepted_grid_share[2L],
    accepted_share_A2 = metrics$accepted_grid_share[3L],
    boundary_A0 = metrics$either_boundary_accepted[1L],
    boundary_A1 = metrics$either_boundary_accepted[2L],
    boundary_A2 = metrics$either_boundary_accepted[3L],
    all_grid_A0 = metrics$all_grid_points_accepted[1L],
    all_grid_A1 = metrics$all_grid_points_accepted[2L],
    all_grid_A2 = metrics$all_grid_points_accepted[3L], stringsAsFactors = FALSE)
}

evaluate_gmm_points <- function(dat, controls, tau, points) {
  W <- rep(NA_real_, length(points)); errors <- list()
  for (j in seq_along(points)) {
    attempt <- tryCatch(author_gmm_candidate(dat$y, dat$D, controls, dat$Z, tau, points[j]),
                        error = identity)
    if (inherits(attempt, "error")) {
      errors[[length(errors) + 1L]] <- list(a = points[j], message = conditionMessage(attempt))
    } else if (!is.finite(attempt)) {
      errors[[length(errors) + 1L]] <- list(a = points[j], message = "non-finite W")
    } else W[j] <- as.numeric(attempt)
  }
  list(W = W, errors = errors, whole_profile_error = FALSE)
}

evaluate_dml_points <- function(dat, tau, points, workers) {
  attempt <- tryCatch(author_bc_evaluate(dat$y, dat$D, dat$X, dat$Z, tau,
                                         points = points, core = workers), error = identity)
  if (inherits(attempt, "error")) {
    return(list(W = rep(NA_real_, length(points)),
                errors = list(list(a = NA_real_, message = conditionMessage(attempt))),
                whole_profile_error = TRUE))
  }
  list(W = attempt$W, errors = attempt$errors, whole_profile_error = FALSE)
}

evaluate_estimator_points <- function(dat, tau, estimator, points, workers) {
  if (estimator == "Oracle-GMM") return(evaluate_gmm_points(dat, dat$X1, tau, points))
  if (estimator == "Full-GMM") return(evaluate_gmm_points(dat, dat$X, tau, points))
  if (estimator == "DML-IVQR-BC") return(evaluate_dml_points(dat, tau, points, workers))
  stop("Unknown estimator: ", estimator)
}

make_profile <- function(cfg, replication, tau, kappa, estimator, points, W) {
  data.frame(n = cfg$sample_size, replication = replication, tau = tau, kappa = kappa,
             estimator = estimator, a = points, W = W,
             accepted = ifelse(is.finite(W), W <= cfg$critical_value, NA),
             stringsAsFactors = FALSE)
}

run_stage1 <- function(cfg, replications, tau_values, kappa_values, primitive_dir) {
  profiles <- list(); range_metrics <- list(); expansions <- list(); failures <- list(); hashes <- list()
  add_failure <- function(replication, tau, kappa, estimator, a, stage, message) {
    failures[[length(failures) + 1L]] <<- data.frame(
      n = cfg$sample_size, replication = replication, tau = tau, kappa = kappa,
      estimator = estimator, a = a, stage = stage, error_message = message,
      stringsAsFactors = FALSE)
  }
  for (replication in seq_len(replications)) {
    primitives <- generate_kappa_primitives(n = cfg$sample_size, p = cfg$p)
    hashes[[replication]] <- save_primitive(primitives, replication, primitive_dir)
    for (kappa in kappa_values) {
      dat <- make_kappa_dataset(primitives, kappa, cfg$s)
      for (tau in tau_values) for (estimator in cfg$estimators) {
        evaluated <- evaluate_estimator_points(dat, tau, estimator, cfg$stage1_grid, cfg$workers)
        whole_error <- isTRUE(evaluated$whole_profile_error)
        for (err in evaluated$errors) add_failure(
          replication, tau, kappa, estimator, err$a,
          if (whole_error) "stage1_profile" else "stage1_candidate", err$message)
        profile <- make_profile(cfg, replication, tau, kappa, estimator,
                                cfg$stage1_grid, evaluated$W)
        metrics <- range_metrics_from_profile(profile, cfg$stage1_ranges, cfg$grid_step)
        profiles[[length(profiles) + 1L]] <- profile
        range_metrics[[length(range_metrics) + 1L]] <- metrics
        expansions[[length(expansions) + 1L]] <- stage1_expansion_from_ranges(metrics, profile, cfg)
      }
    }
  }
  list(profiles = do.call(rbind, profiles), range_metrics = do.call(rbind, range_metrics),
       expansion_metrics = do.call(rbind, expansions),
       failures = if (length(failures)) do.call(rbind, failures) else empty_failures_frame(),
       primitive_hashes = do.call(rbind, hashes))
}

trigger_cells_from_expansions <- function(expansions, cfg, expected_replications) {
  weak <- expansions[expansions$kappa %in% cfg$weak_trigger_kappa, , drop = FALSE]
  keys <- interaction(weak$tau, weak$kappa, weak$estimator, drop = TRUE, lex.order = TRUE)
  cells <- do.call(rbind, lapply(split(weak, keys), function(z) {
    boundary_count <- sum(z$trigger_either_boundary %in% TRUE)
    outer_count <- sum(z$outer_band_contact %in% TRUE)
    boundary_rate <- boundary_count / expected_replications
    outer_rate <- outer_count / expected_replications
    data.frame(
      n = z$n[1L], tau = z$tau[1L], kappa = z$kappa[1L], estimator = z$estimator[1L],
      total_replications = nrow(z),
      failed_profiles = sum(is.na(z$trigger_either_boundary) | is.na(z$outer_band_contact)),
      either_boundary_acceptance_count = boundary_count,
      either_boundary_acceptance_rate = boundary_rate,
      outer_band_contact_count = outer_count, outer_band_contact_rate = outer_rate,
      boundary_rule_triggered = boundary_rate >= cfg$boundary_trigger_threshold,
      outer_band_rule_triggered = outer_rate >= cfg$outer_band_trigger_threshold,
      cell_triggered = boundary_rate >= cfg$boundary_trigger_threshold |
        outer_rate >= cfg$outer_band_trigger_threshold,
      stringsAsFactors = FALSE)
  }))
  row.names(cells) <- NULL
  cells
}

summarize_ranges <- function(x) {
  keys <- interaction(x$n, x$tau, x$kappa, x$estimator, x$range, drop = TRUE, lex.order = TRUE)
  out <- do.call(rbind, lapply(split(x, keys), function(z) data.frame(
    n = z$n[1L], tau = z$tau[1L], kappa = z$kappa[1L], estimator = z$estimator[1L],
    range = z$range[1L], total_replications = nrow(z),
    successful_profiles = sum(!z$profile_failed), failed_profiles = sum(z$profile_failed),
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
    all_grid_points_acceptance_rate = safe_mean(z$all_grid_points_accepted),
    stringsAsFactors = FALSE)))
  row.names(out) <- NULL
  out
}

summarize_stage1_expansions <- function(x) {
  keys <- interaction(x$n, x$tau, x$kappa, x$estimator, drop = TRUE, lex.order = TRUE)
  out <- do.call(rbind, lapply(split(x, keys), function(z) data.frame(
    n = z$n[1L], tau = z$tau[1L], kappa = z$kappa[1L], estimator = z$estimator[1L],
    total_replications = nrow(z),
    median_added_measure_A0_to_A1 = safe_median(z$added_measure_A0_to_A1),
    mean_added_measure_A0_to_A1 = safe_mean(z$added_measure_A0_to_A1),
    median_accepted_share_A0 = safe_median(z$accepted_share_A0),
    mean_accepted_share_A0 = safe_mean(z$accepted_share_A0),
    median_accepted_share_A1 = safe_median(z$accepted_share_A1),
    mean_accepted_share_A1 = safe_mean(z$accepted_share_A1),
    boundary_acceptance_rate_A0 = safe_mean(z$boundary_A0),
    boundary_acceptance_rate_A1 = safe_mean(z$boundary_A1),
    all_grid_acceptance_rate_A0 = safe_mean(z$all_grid_A0),
    all_grid_acceptance_rate_A1 = safe_mean(z$all_grid_A1),
    outer_band_contact_rate = safe_mean(z$outer_band_contact), stringsAsFactors = FALSE)))
  row.names(out) <- NULL
  out
}

summarize_stage2_expansions <- function(x) {
  keys <- interaction(x$n, x$tau, x$kappa, x$estimator, drop = TRUE, lex.order = TRUE)
  out <- do.call(rbind, lapply(split(x, keys), function(z) data.frame(
    n = z$n[1L], tau = z$tau[1L], kappa = z$kappa[1L], estimator = z$estimator[1L],
    total_replications = nrow(z),
    median_added_measure_A0_to_A1 = safe_median(z$added_measure_A0_to_A1),
    mean_added_measure_A0_to_A1 = safe_mean(z$added_measure_A0_to_A1),
    median_added_measure_A1_to_A2 = safe_median(z$added_measure_A1_to_A2),
    mean_added_measure_A1_to_A2 = safe_mean(z$added_measure_A1_to_A2),
    median_accepted_share_A0 = safe_median(z$accepted_share_A0), mean_accepted_share_A0 = safe_mean(z$accepted_share_A0),
    median_accepted_share_A1 = safe_median(z$accepted_share_A1), mean_accepted_share_A1 = safe_mean(z$accepted_share_A1),
    median_accepted_share_A2 = safe_median(z$accepted_share_A2), mean_accepted_share_A2 = safe_mean(z$accepted_share_A2),
    boundary_acceptance_rate_A0 = safe_mean(z$boundary_A0), boundary_acceptance_rate_A1 = safe_mean(z$boundary_A1),
    boundary_acceptance_rate_A2 = safe_mean(z$boundary_A2), all_grid_acceptance_rate_A0 = safe_mean(z$all_grid_A0),
    all_grid_acceptance_rate_A1 = safe_mean(z$all_grid_A1), all_grid_acceptance_rate_A2 = safe_mean(z$all_grid_A2),
    stringsAsFactors = FALSE)))
  row.names(out) <- NULL
  out
}

profile_key <- function(replication, tau, kappa, estimator) {
  paste(replication, sprintf("%.2f", as.numeric(tau)), sprintf("%.2f", as.numeric(kappa)),
        estimator, sep = "|")
}

run_stage2 <- function(cfg, stage1_profiles, primitive_dir) {
  tails <- list(); combined_profiles <- list(); range_metrics <- list(); expansions <- list(); failures <- list()
  stage1_keys <- profile_key(stage1_profiles$replication, stage1_profiles$tau,
                             stage1_profiles$kappa, stage1_profiles$estimator)
  stage1_index <- split(seq_len(nrow(stage1_profiles)), stage1_keys)
  add_failure <- function(replication, tau, kappa, estimator, a, stage, message) {
    failures[[length(failures) + 1L]] <<- data.frame(
      n = cfg$sample_size, replication = replication, tau = tau, kappa = kappa,
      estimator = estimator, a = a, stage = stage, error_message = message,
      stringsAsFactors = FALSE)
  }
  for (replication in seq_len(cfg$diagnostic_replications)) {
    primitives <- readRDS(file.path(primitive_dir, primitive_filename(replication)))
    for (kappa in cfg$kappa_values) {
      dat <- make_kappa_dataset(primitives, kappa, cfg$s)
      for (tau in cfg$tau_values) for (estimator in cfg$estimators) {
        key <- profile_key(replication, tau, kappa, estimator)
        interior <- stage1_profiles[stage1_index[[key]], , drop = FALSE]
        if (nrow(interior) != 81L) stop("Stage-1 interior profile is missing or malformed.")
        evaluated <- evaluate_estimator_points(dat, tau, estimator, cfg$stage2_tail_grid, cfg$workers)
        whole_error <- isTRUE(evaluated$whole_profile_error)
        for (err in evaluated$errors) add_failure(
          replication, tau, kappa, estimator, err$a,
          if (whole_error) "stage2_tail_profile" else "stage2_tail_candidate", err$message)
        tail <- make_profile(cfg, replication, tau, kappa, estimator,
                             cfg$stage2_tail_grid, evaluated$W)
        combined <- rbind(tail, interior)
        combined <- combined[order(combined$a), , drop = FALSE]
        row.names(combined) <- NULL
        if (nrow(combined) != 121L || anyDuplicated(combined$a)) {
          stop("Combined Stage-2 profile is not the required 121-point [-5,7] profile.")
        }
        preserved <- combined[combined$a >= -3 & combined$a <= 5, , drop = FALSE]
        row.names(preserved) <- NULL; row.names(interior) <- NULL
        if (!identical(preserved, interior)) stop("Stage-1 interior values were not preserved exactly.")
        metrics <- range_metrics_from_profile(combined, cfg$stage2_ranges, cfg$grid_step)
        tails[[length(tails) + 1L]] <- tail
        combined_profiles[[length(combined_profiles) + 1L]] <- combined
        range_metrics[[length(range_metrics) + 1L]] <- metrics
        expansions[[length(expansions) + 1L]] <- stage2_expansion_from_ranges(metrics)
      }
    }
  }
  list(tail_profiles = do.call(rbind, tails), combined_profiles = do.call(rbind, combined_profiles),
       range_metrics = do.call(rbind, range_metrics), expansion_metrics = do.call(rbind, expansions),
       failures = if (length(failures)) do.call(rbind, failures) else empty_failures_frame())
}

validate_stage1_subsetting <- function(profiles, cfg) {
  keys <- interaction(profiles$replication, profiles$tau, profiles$kappa,
                      profiles$estimator, drop = TRUE)
  all(vapply(split(profiles, keys), function(profile) {
    if (nrow(profile) != 81L || anyDuplicated(profile$a)) return(FALSE)
    a0 <- profile[profile$a >= -1 & profile$a <= 3, c("a", "W"), drop = FALSE]
    source <- profile[match(a0$a, profile$a), c("a", "W"), drop = FALSE]
    row.names(a0) <- NULL; row.names(source) <- NULL
    nrow(a0) == 41L && identical(a0, source)
  }, logical(1)))
}

validate_failure_scope <- function(cfg) {
  base1 <- data.frame(n = 1000L, replication = 1L, tau = 0.5, kappa = 1,
                      estimator = "test", a = cfg$stage1_grid, W = rep(0, 81L),
                      accepted = rep(TRUE, 81L), stringsAsFactors = FALSE)
  at_four <- base1; at_four$W[at_four$a == 4] <- NA_real_; at_four$accepted[at_four$a == 4] <- NA
  stage1_ok <- identical(range_metrics_from_profile(at_four, cfg$stage1_ranges, 0.1)$profile_failed,
                         c(FALSE, TRUE))
  full_grid <- seq(-5, 7, by = 0.1)
  base2 <- data.frame(n = 1000L, replication = 1L, tau = 0.5, kappa = 1,
                      estimator = "test", a = full_grid, W = rep(0, 121L),
                      accepted = rep(TRUE, 121L), stringsAsFactors = FALSE)
  at_six <- base2; at_six$W[at_six$a == 6] <- NA_real_; at_six$accepted[at_six$a == 6] <- NA
  stage2_ok <- identical(range_metrics_from_profile(at_six, cfg$stage2_ranges, 0.1)$profile_failed,
                         c(FALSE, FALSE, TRUE))
  stage1_ok && stage2_ok
}
