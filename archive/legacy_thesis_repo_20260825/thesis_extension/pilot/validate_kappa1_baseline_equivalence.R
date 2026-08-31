# Permanent kappa=1 equivalence fixture for the frozen authors' baseline.
MASTER_SEED <- 20260819L
N_DATASETS <- 10L
N <- 500L
TAU <- 0.50
KAPPA <- 1.00
ALPHA_GRID <- seq(-1, 3, by = 0.10)
W_TOLERANCE <- 1e-12

root_dir <- getwd()
.libPaths(c(file.path(root_dir, "environment", "legacy_R343_library"), .Library))
pilot_dir <- file.path(root_dir, "thesis_extension", "pilot")
summary_path <- file.path(pilot_dir, "kappa1_equivalence_summary.csv")
detail_path <- file.path(pilot_dir, "kappa1_equivalence_detail.csv")
report_path <- file.path(pilot_dir, "kappa1_equivalence_report.txt")
author_files <- file.path(root_dir, c(
  "simulation/main.R",
  "simulation/fun_callback.R",
  "simulation/simulation_quantreg/quantreg_Belloni_cv.r"
))
author_md5_before <- unname(tools::md5sum(author_files))

if (getRversion() != "3.4.3") {
  stop("This validation must run under R 3.4.3; found ", R.version.string, ".")
}
required_versions <- c(
  quantreg = "5.34", hdm = "0.2.0", hqreg = "1.4",
  mvtnorm = "1.0-6", doSNOW = "1.0.16"
)
actual_versions <- vapply(names(required_versions), function(package) {
  packageDescription(package, fields = "Version")
}, character(1))
if (!identical(unname(actual_versions), unname(required_versions))) {
  stop("Historical package-version check failed: ", paste(
    names(required_versions), " expected=", required_versions,
    " actual=", actual_versions, collapse = "; "
  ))
}

suppressPackageStartupMessages({
  library(quantreg)
  library(hdm)
  library(hqreg)
  library(mvtnorm)
  library(doSNOW)
})
source(file.path(root_dir, "simulation", "fun_callback.R"))
source(file.path(root_dir, "thesis_extension", "src", "dgp_kappa.R"))
source(file.path(root_dir, "thesis_extension", "src", "wn_profiles.R"))

diagnostics <- character(0)
capture_conditions <- function(label, expression) {
  warnings <- character(0)
  value <- tryCatch(
    withCallingHandlers(
      expression,
      warning = function(condition) {
        warnings <<- c(warnings, conditionMessage(condition))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(condition) condition
  )
  if (length(warnings)) {
    diagnostics <<- c(diagnostics, paste0(label, " WARNING: ", unique(warnings)))
  }
  if (inherits(value, "error")) {
    diagnostics <<- c(diagnostics, paste0(label, " ERROR: ", conditionMessage(value)))
    stop(label, " failed: ", conditionMessage(value))
  }
  value
}

# Literal transcription of simulation/fun_callback.R::gmm_quantile(), extended
# only to return the authors' alpha-level criterion as required by this test.
author_gmm_profile <- function(y, D, X, Z, tau) {
  alpha=seq(-1,3,length=41)
  gmm=rep(0,length(alpha))
  for (i in 1:length(alpha)) {
    beta<- rq(y-(alpha[i]*D) ~ X, tau = tau)
    beta=matrix(beta$coefficients,nrow = 1)
    e=y-alpha[i]*D-cbind(1,X)%*%t(beta)
    distribition=c(dnorm(e,mean(e),var(e)))
    distribition=diag(distribition)
    M=t(Z)%*%distribition%*%X
    J=t(X)%*%distribition%*%X
    delta=M%*%solve(J)
    psi=t(Z)-delta%*%t(X)
    indicator=ifelse(e<=0,1,0)
    g=(psi%*%(tau-indicator))
    invsigma=(solve(psi%*%diag(diag((tau-indicator)%*%t(tau-indicator)))%*%t(psi)))
    gmm[i]=(t(g)%*%invsigma%*%g)
    i=i+1
  }
  I=which.min(gmm)
  list(grid = alpha, W = gmm, alpha_hat = alpha[I], min_W = gmm[I])
}

# Literal transcription of simulation/fun_callback.R::hdm_quantile(), extended
# only to return the full criterion and selected lambda at each alpha.
author_dml_cv_profile <- function(y, D, X, Z, tau) {
  alpha=seq(-1,3,length=41)
  gmm=rep(0,length(alpha))
  selected_lambda=rep(NA_real_,length(alpha))
  for (i in 1:length(alpha)) {
    lasso=cv.hqreg(X,y-alpha[i]*D,method=c("quantile"),tau=tau,FUN = c("hqreg"),nfolds = 5,type.measure = c("mae"))
    cv.beta=as.matrix(lasso$fit$beta)
    kfold=which(lasso$lambda==lasso$lambda.min, arr.ind=T )
    selected_lambda[i]=lasso$lambda.min
    kfold.beta=cv.beta[,kfold]
    beta=matrix(kfold.beta,nrow = 1)
    e=y-alpha[i]*D-cbind(1,X)%*%t(beta)
    distribition=c(dnorm(e,mean(e),var(e)))
    distribition=diag(distribition)
    distribition=sqrt(distribition)
    psi=matrix(0,nrow = length(Z[1,]),ncol=length(Z[,1]))
    for (j in 1:length(Z[1,])) {
      delta=rlasso(distribition%*%Z[,j] ~ distribition%*%X, post = FALSE)
      delta=matrix(delta$coefficients,ncol=1)
      delta=Z[,j]-cbind(1,X)%*%delta
      psi[j,]=t(delta)
      j=j+1
    }
    indicator=ifelse(e<=0,1,0)
    g=(psi%*%(tau-indicator))
    invsigma=(solve(psi%*%diag(diag((tau-indicator)%*%t(tau-indicator)))%*%t(psi)))
    gmm[i]=(t(g)%*%invsigma%*%g)
    i=i+1
  }
  I=which.min(gmm)
  list(
    grid = alpha, W = gmm, alpha_hat = alpha[I], min_W = gmm[I],
    selected_lambda = selected_lambda
  )
}

# Conditional Table-3 author-BC evaluator. The pivotal lambda draw is replaced
# only by the supplied, already-generated vector; all beta/score calculations
# are the literal POST=FALSE and penalty=TRUE implementation.
author_dml_bc_profile <- function(y, D, X, Z, tau, alpha, supplied_lambda_bc) {
  gmm=rep(0,length(alpha))
  for (ii in 1:length(alpha)) {
    i=alpha[ii]
    lasso=quantreg::rq(y-i*D ~ X,tau=tau, method="lasso",lambda = supplied_lambda_bc)
    beta=matrix(lasso$coefficients,ncol = 1)
    e=y-i*D-cbind(1,X)%*%beta
    distribition=c(dnorm(e,mean(e),var(e)))
    distribition=diag(distribition)
    distribition=sqrt(distribition)
    psi=matrix(0,nrow = length(Z[1,]),ncol=length(Z[,1]))
    for (j in 1:length(Z[1,])) {
      delta=hdm::rlasso(distribition%*%Z[,j] ~ distribition%*%X, post = FALSE)
      delta=matrix(delta$coefficients,ncol=1)
      delta=Z[,j]-cbind(1,X)%*%delta
      psi[j,]=t(delta)
      j=j+1
    }
    indicator=ifelse(e<=0,1,0)
    g=(psi%*%(tau-indicator))
    invsigma=(solve(psi%*%diag(diag((tau-indicator)%*%t(tau-indicator)))%*%t(psi)))
    gmm[ii]=(t(g)%*%invsigma%*%g)
  }
  I=which.min(gmm)
  list(
    grid = alpha, W = gmm, alpha_hat = alpha[I], min_W = gmm[I],
    lambda_bc = supplied_lambda_bc
  )
}

set.seed(MASTER_SEED)
datasets <- vector("list", N_DATASETS)
sigma <- matrix(c(1, 0.3, 0.3, 1), ncol = 2)
b <- matrix(c(rep(5, 7), rep(0, 93)))
for (dataset_id in seq_len(N_DATASETS)) {
  # Authors' complete primitive order: (u, epsilon), x, z1, z2, v1, v2.
  error_draws <- mvtnorm::rmvnorm(n = N, mean = c(0, 0), sigma = sigma)
  x <- matrix(rnorm(N * 100), ncol = 100)
  X100 <- matrix(pnorm(x), ncol = 100)
  z1 <- rnorm(N, 0, 1)
  z2 <- rnorm(N, 0, 1)
  v1 <- rnorm(N, 0, 1)
  v2 <- rnorm(N, 0, 1)
  # The thesis-only primitive is drawn after every original primitive.
  w <- rnorm(N, 0, 1)
  d_original <- z1 + z2 + error_draws[, 2]
  D_original <- pnorm(d_original)
  treatment <- make_treatment_kappa(z1, z2, error_draws[, 2], w, KAPPA)
  Z1 <- z1 + v1 + X100[, 2] + X100[, 3] + X100[, 4]
  Z2 <- z2 + v2 + X100[, 7] + X100[, 8] + X100[, 9] + X100[, 10]
  D <- treatment$D
  y <- c(1 + D + X100 %*% b + error_draws[, 1] * D)
  datasets[[dataset_id]] <- list(
    y = y, D = D, d_original = d_original, D_original = D_original,
    d_kappa1 = treatment$d_latent, D_kappa1 = treatment$D,
    X10 = X100[, 1:10], X100 = X100,
    Z = matrix(cbind(Z1, Z2), nrow = N)
  )
}

empty_detail_row <- function() {
  data.frame(
    row_type = NA_character_, dataset_id = NA_integer_, estimator = NA_character_,
    comparison = NA_character_, alpha = NA_real_, max_abs_latent_d_difference = NA_real_,
    max_abs_D_difference = NA_real_, exact_latent_d_identity = NA,
    exact_D_identity = NA, max_abs_W_difference = NA_real_,
    W_reference = NA_real_, W_thesis = NA_real_, difference = NA_real_,
    alpha_hat_reference = NA_real_, alpha_hat_thesis = NA_real_,
    min_W_reference = NA_real_, min_W_thesis = NA_real_,
    alpha_hat_exact_match = NA, W_tolerance_match = NA,
    selected_lambda_reference = NA_real_, lambda_vector_exact_match = NA,
    status = NA_character_, stringsAsFactors = FALSE
  )
}
detail_rows <- list()
dataset_results <- list()
append_detail <- function(row) {
  detail_rows[[length(detail_rows) + 1L]] <<- row
}

add_dgp_result <- function(dataset_id, dat) {
  max_d <- max(abs(dat$d_kappa1 - dat$d_original))
  max_D <- max(abs(dat$D_kappa1 - dat$D_original))
  exact_d <- identical(dat$d_kappa1, dat$d_original)
  exact_D <- identical(dat$D_kappa1, dat$D_original)
  row <- empty_detail_row()
  row$row_type <- "dataset_summary"
  row$dataset_id <- dataset_id
  row$estimator <- "Treatment DGP"
  row$comparison <- "DGP_KAPPA1"
  row$max_abs_latent_d_difference <- max_d
  row$max_abs_D_difference <- max_D
  row$exact_latent_d_identity <- exact_d
  row$exact_D_identity <- exact_D
  row$status <- if (max_d == 0 && max_D == 0 && exact_d && exact_D) "PASS" else "FAIL"
  append_detail(row)
  dataset_results[[length(dataset_results) + 1L]] <<- row
  if (row$status != "PASS") {
    first_d <- which(dat$d_kappa1 != dat$d_original)[1]
    first_D <- which(dat$D_kappa1 != dat$D_original)[1]
    stop("DGP_KAPPA1 first divergence: dataset=", dataset_id,
         "; d observation=", first_d, "; D observation=", first_D,
         "; max_abs_latent_d_difference=", format(max_d, digits = 17),
         "; max_abs_D_difference=", format(max_D, digits = 17))
  }
}

add_profile_result <- function(dataset_id, estimator, comparison, reference,
                               thesis, selected_lambda = NULL,
                               lambda_exact = NA, expected_difference = FALSE) {
  if (!identical(reference$grid, thesis$grid)) {
    stop(comparison, " grid divergence in dataset ", dataset_id, ".")
  }
  differences <- abs(reference$W - thesis$W)
  max_W <- max(differences)
  alpha_exact <- identical(as.numeric(reference$alpha_hat),
                           as.numeric(thesis$alpha_hat))
  min_difference <- abs(reference$min_W - thesis$min_W)
  W_match <- all(is.finite(differences)) && max_W <= W_TOLERANCE
  status <- if (expected_difference) {
    "EXPECTED METHOD DIFFERENCE"
  } else if (W_match && alpha_exact && min_difference <= W_TOLERANCE &&
             (is.na(lambda_exact) || lambda_exact)) {
    "PASS"
  } else {
    "FAIL"
  }
  row <- empty_detail_row()
  row$row_type <- "dataset_summary"
  row$dataset_id <- dataset_id
  row$estimator <- estimator
  row$comparison <- comparison
  row$max_abs_W_difference <- max_W
  row$alpha_hat_reference <- reference$alpha_hat
  row$alpha_hat_thesis <- thesis$alpha_hat
  row$min_W_reference <- reference$min_W
  row$min_W_thesis <- thesis$min_W
  row$alpha_hat_exact_match <- alpha_exact
  row$W_tolerance_match <- W_match
  row$lambda_vector_exact_match <- lambda_exact
  row$status <- status
  append_detail(row)
  dataset_results[[length(dataset_results) + 1L]] <<- row

  for (alpha_index in seq_along(reference$grid)) {
    alpha_row <- empty_detail_row()
    alpha_row$row_type <- "alpha_detail"
    alpha_row$dataset_id <- dataset_id
    alpha_row$estimator <- estimator
    alpha_row$comparison <- comparison
    alpha_row$alpha <- reference$grid[alpha_index]
    alpha_row$W_reference <- reference$W[alpha_index]
    alpha_row$W_thesis <- thesis$W[alpha_index]
    alpha_row$difference <- thesis$W[alpha_index] - reference$W[alpha_index]
    if (!is.null(selected_lambda)) {
      alpha_row$selected_lambda_reference <- selected_lambda[alpha_index]
    }
    alpha_row$status <- if (expected_difference) {
      "EXPECTED METHOD DIFFERENCE"
    } else if (is.finite(differences[alpha_index]) &&
               differences[alpha_index] <= W_TOLERANCE) "PASS" else "FAIL"
    append_detail(alpha_row)
  }

  if (!expected_difference && status != "PASS") {
    first_bad <- which(!is.finite(differences) | differences > W_TOLERANCE)[1]
    component <- if (!is.na(first_bad)) {
      paste0("W at alpha=", format(reference$grid[first_bad], nsmall = 1),
             ", reference=", format(reference$W[first_bad], digits = 17),
             ", thesis=", format(thesis$W[first_bad], digits = 17),
             ", abs_difference=", format(differences[first_bad], digits = 17))
    } else if (!alpha_exact) {
      paste0("alpha_hat, reference=", reference$alpha_hat,
             ", thesis=", thesis$alpha_hat)
    } else if (min_difference > W_TOLERANCE) {
      paste0("min_W, abs_difference=", format(min_difference, digits = 17))
    } else {
      "lambda vector exact equality"
    }
    stop(comparison, " first divergence: dataset=", dataset_id,
         "; component=", component)
  }
}

# DGP identity is a gate: no estimator is evaluated unless all ten pass.
for (dataset_id in seq_len(N_DATASETS)) {
  add_dgp_result(dataset_id, datasets[[dataset_id]])
}

for (dataset_id in seq_len(N_DATASETS)) {
  cat("Evaluating fixed dataset", dataset_id, "of", N_DATASETS, "\n")
  dat <- datasets[[dataset_id]]

  author_oracle_alpha <- capture_conditions(
    paste0("ORACLE_TABLE2 dataset=", dataset_id, " original"),
    gmm_quantile(dat$y, dat$D, dat$X10, dat$Z, TAU)
  )
  oracle_reference <- capture_conditions(
    paste0("ORACLE_TABLE2 dataset=", dataset_id, " reference"),
    author_gmm_profile(dat$y, dat$D, dat$X10, dat$Z, TAU)
  )
  if (!identical(as.numeric(author_oracle_alpha),
                 as.numeric(oracle_reference$alpha_hat))) {
    stop("ORACLE_TABLE2 original/reference alpha_hat divergence: dataset=", dataset_id)
  }
  oracle_thesis <- oracle_wn_profile(
    dat$y, dat$D, dat$X10, dat$Z, TAU, ALPHA_GRID
  )
  add_profile_result(dataset_id, "Oracle-GMM", "ORACLE_TABLE2",
                     oracle_reference, oracle_thesis)

  author_full_alpha <- capture_conditions(
    paste0("FULL_TABLE2 dataset=", dataset_id, " original"),
    gmm_quantile(dat$y, dat$D, dat$X100, dat$Z, TAU)
  )
  full_reference <- capture_conditions(
    paste0("FULL_TABLE2 dataset=", dataset_id, " reference"),
    author_gmm_profile(dat$y, dat$D, dat$X100, dat$Z, TAU)
  )
  if (!identical(as.numeric(author_full_alpha),
                 as.numeric(full_reference$alpha_hat))) {
    stop("FULL_TABLE2 original/reference alpha_hat divergence: dataset=", dataset_id)
  }
  full_thesis <- full_wn_profile(
    dat$y, dat$D, dat$X100, dat$Z, TAU, ALPHA_GRID
  )
  add_profile_result(dataset_id, "Full-GMM", "FULL_TABLE2",
                     full_reference, full_thesis)

  saved_cv_seed <- .Random.seed
  author_cv_alpha <- capture_conditions(
    paste0("DML_TABLE2_CV dataset=", dataset_id, " original"),
    hdm_quantile(dat$y, dat$D, dat$X100, dat$Z, TAU)
  )
  rng_after_author_cv <- .Random.seed
  .Random.seed <- saved_cv_seed
  cv_reference <- capture_conditions(
    paste0("DML_TABLE2_CV dataset=", dataset_id, " reference"),
    author_dml_cv_profile(dat$y, dat$D, dat$X100, dat$Z, TAU)
  )
  rng_after_reference_cv <- .Random.seed
  .Random.seed <- saved_cv_seed
  cv_thesis <- dml_wn_profile(
    dat$y, dat$D, dat$X100, dat$Z, TAU, ALPHA_GRID
  )
  rng_after_thesis_cv <- .Random.seed
  if (!identical(as.numeric(author_cv_alpha), as.numeric(cv_reference$alpha_hat)) ||
      !identical(rng_after_author_cv, rng_after_reference_cv) ||
      !identical(rng_after_author_cv, rng_after_thesis_cv)) {
    stop("DML_TABLE2_CV original/reference RNG or alpha_hat divergence: dataset=",
         dataset_id)
  }
  add_profile_result(dataset_id, "DML-CV", "DML_TABLE2_CV",
                     cv_reference, cv_thesis,
                     selected_lambda = cv_reference$selected_lambda)
  .Random.seed <- rng_after_author_cv

  lambda_bc <- bc_pivotal_lambda(
    dat$X100, R = 1000, c = 2, alpha = 0.1, tau = TAU
  )
  bc_reference <- capture_conditions(
    paste0("DML_BC_CONDITIONAL dataset=", dataset_id, " reference"),
    author_dml_bc_profile(
      dat$y, dat$D, dat$X100, dat$Z, TAU, ALPHA_GRID, lambda_bc
    )
  )
  bc_thesis <- dml_wn_profile_bc(
    dat$y, dat$D, dat$X100, dat$Z, TAU, ALPHA_GRID,
    lambda_bc = lambda_bc
  )
  lambda_exact <- identical(bc_reference$lambda_bc, lambda_bc) &&
    identical(bc_thesis$lambda_bc, lambda_bc)
  add_profile_result(dataset_id, "DML-BC", "DML_BC_CONDITIONAL",
                     bc_reference, bc_thesis, lambda_exact = lambda_exact)

  # Documentation-only comparison: deliberately different penalty methods.
  cv_as_reference <- cv_thesis
  bc_as_thesis <- bc_thesis
  add_profile_result(
    dataset_id, "DML-CV vs DML-BC",
    "DML_CV_VS_BC_EXPECTED_DIFFERENCE",
    cv_as_reference, bc_as_thesis, expected_difference = TRUE
  )
}

detail <- do.call(rbind, detail_rows)
dataset_detail <- do.call(rbind, dataset_results)
rownames(detail) <- NULL
rownames(dataset_detail) <- NULL

required_comparisons <- c(
  "DGP_KAPPA1", "ORACLE_TABLE2", "FULL_TABLE2",
  "DML_TABLE2_CV", "DML_BC_CONDITIONAL"
)
summary_rows <- list()
for (comparison in required_comparisons) {
  rows <- dataset_detail[dataset_detail$comparison == comparison, ]
  alpha_differences <- abs(rows$alpha_hat_thesis - rows$alpha_hat_reference)
  summary_rows[[length(summary_rows) + 1L]] <- data.frame(
    comparison = comparison,
    n_datasets = nrow(rows),
    n_pass = sum(rows$status == "PASS"),
    n_fail = sum(rows$status == "FAIL"),
    maximum_D_difference = if (comparison == "DGP_KAPPA1")
      max(rows$max_abs_D_difference) else NA_real_,
    maximum_W_difference = if (comparison == "DGP_KAPPA1") NA_real_ else
      max(rows$max_abs_W_difference),
    maximum_alpha_hat_difference = if (comparison == "DGP_KAPPA1") NA_real_ else
      max(alpha_differences),
    exact_alpha_hat_match_rate = if (comparison == "DGP_KAPPA1") NA_real_ else
      mean(rows$alpha_hat_exact_match),
    number_identical = NA_integer_, number_different = NA_integer_,
    mean_absolute_alpha_hat_difference = NA_real_,
    maximum_absolute_alpha_hat_difference = NA_real_,
    status = if (all(rows$status == "PASS")) "PASS" else "FAIL",
    stringsAsFactors = FALSE
  )
}
expected_rows <- dataset_detail[
  dataset_detail$comparison == "DML_CV_VS_BC_EXPECTED_DIFFERENCE", ]
expected_alpha_difference <- abs(
  expected_rows$alpha_hat_thesis - expected_rows$alpha_hat_reference
)
summary_rows[[length(summary_rows) + 1L]] <- data.frame(
  comparison = "DML_CV_VS_BC_EXPECTED_DIFFERENCE",
  n_datasets = nrow(expected_rows), n_pass = NA_integer_, n_fail = NA_integer_,
  maximum_D_difference = NA_real_, maximum_W_difference = NA_real_,
  maximum_alpha_hat_difference = NA_real_, exact_alpha_hat_match_rate = NA_real_,
  number_identical = sum(expected_alpha_difference == 0),
  number_different = sum(expected_alpha_difference != 0),
  mean_absolute_alpha_hat_difference = mean(expected_alpha_difference),
  maximum_absolute_alpha_hat_difference = max(expected_alpha_difference),
  status = "EXPECTED METHOD DIFFERENCE", stringsAsFactors = FALSE
)
summary <- do.call(rbind, summary_rows)
rownames(summary) <- NULL

overall_pass <- all(summary$status[summary$comparison %in% required_comparisons] == "PASS")
author_md5_after <- unname(tools::md5sum(author_files))
author_integrity <- identical(author_md5_before, author_md5_after)
if (!author_integrity) {
  stop("Authors' frozen source-file integrity check failed.")
}

write.csv(summary, summary_path, row.names = FALSE)
write.csv(detail, detail_path, row.names = FALSE)

package_lines <- paste(names(actual_versions), actual_versions, sep = ": ")
required_summary <- summary[summary$comparison %in% required_comparisons, ]
report <- c(
  "FINAL KAPPA=1 BASELINE EQUIVALENCE / REGRESSION TEST",
  "",
  paste("R version:", R.version.string),
  package_lines,
  paste("Master diagnostic seed:", MASTER_SEED),
  paste("Datasets:", N_DATASETS),
  paste("n:", N),
  paste("tau:", format(TAU, nsmall = 2)),
  paste("kappa:", format(KAPPA, nsmall = 2)),
  paste("alpha grid:", paste(format(ALPHA_GRID, nsmall = 1), collapse = ", ")),
  paste("W tolerance:", format(W_TOLERANCE, scientific = TRUE)),
  "",
  "At kappa=1, the variance-preserving treatment extension reproduces the authors' original treatment exactly.",
  "Oracle-GMM and Full-GMM are required to reproduce the authors' Table 2 criterion on identical data.",
  "The Table-2-style CV DML profile is required to reproduce the authors' Table 2 DML implementation when the same CV randomness is supplied.",
  "The current thesis DML uses the authors' Belloni-Chernozhukov penalty rather than Table 2 cross-validation.",
  "Conditional on the same BC penalty vector, the current thesis BC profile is required to reproduce the authors' BC beta/score implementation.",
  "BC versus CV differences are expected method differences and are not validation failures.",
  "",
  "Kappa=1 treatment identity results:",
  paste("max_abs_d_difference:", max(dataset_detail$max_abs_latent_d_difference[
    dataset_detail$comparison == "DGP_KAPPA1"])),
  paste("max_abs_D_difference:", max(dataset_detail$max_abs_D_difference[
    dataset_detail$comparison == "DGP_KAPPA1"])),
  paste("exact_d_identity:", all(dataset_detail$exact_latent_d_identity[
    dataset_detail$comparison == "DGP_KAPPA1"])),
  paste("exact_D_identity:", all(dataset_detail$exact_D_identity[
    dataset_detail$comparison == "DGP_KAPPA1"])),
  "",
  "Required comparison summary:",
  capture.output(print(required_summary, row.names = FALSE, digits = 16)),
  "",
  "Expected method difference (Table 2 DML-CV versus current thesis DML-BC):",
  paste("number identical:", summary$number_identical[summary$comparison ==
    "DML_CV_VS_BC_EXPECTED_DIFFERENCE"]),
  paste("number different:", summary$number_different[summary$comparison ==
    "DML_CV_VS_BC_EXPECTED_DIFFERENCE"]),
  paste("mean absolute alpha_hat difference:",
        format(mean(expected_alpha_difference), digits = 16)),
  paste("maximum absolute alpha_hat difference:",
        format(max(expected_alpha_difference), digits = 16)),
  "",
  paste("Authors' source integrity:", if (author_integrity) "PASS" else "FAIL"),
  paste(basename(author_files), author_md5_after, sep = ": "),
  "",
  "Warnings/errors:",
  if (length(diagnostics)) unique(diagnostics) else "None.",
  "",
  paste("Overall validation:", if (overall_pass) "PASS" else "FAIL")
)
writeLines(report, report_path)

git_status <- system2("git", c("status", "--short"), stdout = TRUE, stderr = TRUE)
git_diff_stat <- system2("git", c("diff", "--stat"), stdout = TRUE, stderr = TRUE)
git_cached_stat <- system2(
  "git", c("diff", "--cached", "--stat"), stdout = TRUE, stderr = TRUE
)
report <- c(
  report, "", "git status --short:",
  if (length(git_status)) git_status else "<clean>",
  "", "git diff --stat:",
  if (length(git_diff_stat)) git_diff_stat else "<empty>",
  "", "git diff --cached --stat:",
  if (length(git_cached_stat)) git_cached_stat else "<empty>"
)
writeLines(report, report_path)
cat(paste(report, collapse = "\n"), "\n")

if (!overall_pass) {
  stop("Required kappa=1 baseline equivalence validation failed.")
}
