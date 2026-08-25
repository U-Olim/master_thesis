script_arg <- grep("^--file=", commandArgs(), value = TRUE)
root <- normalizePath(file.path(dirname(normalizePath(sub("^--file=", "", script_arg[1]))), ".."))
source(file.path(root, "environment", "check_author_environment.R"))
assert_author_environment(root, write_outputs = FALSE)
output_dir <- Sys.getenv("THESIS_VALIDATION_OUTPUT_DIR", unset = file.path(root, "validation"))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
source(file.path(root, "config", "extension_config.R"))
source(file.path(root, "src", "dgp_kappa.R"))
source(file.path(root, "calibration", "instrument_strength.R"))

set.seed(9917)
p <- generate_kappa_primitives(500L)
d_original <- p$z1 + p$z2 + p$epsilon
D_original <- pnorm(d_original)
d1 <- make_kappa_dataset(p, 1)
stopifnot(max(abs(d1$d - d_original)) == 0, max(abs(d1$D - D_original)) == 0)

set.seed(77123)
diagnostic_p <- generate_kappa_primitives(100000L)
moments <- do.call(rbind, lapply(extension_config$kappa, function(k) {
  d <- make_kappa_dataset(diagnostic_p, k)$d
  data.frame(kappa = k, variance_d = var(d), cov_z1_d = cov(diagnostic_p$z1, d),
             cov_z2_d = cov(diagnostic_p$z2, d), cov_u_d = cov(diagnostic_p$u, d))
}))
write.csv(moments, file.path(output_dir, "kappa_moment_validation.csv"), row.names = FALSE)

set.seed(8171)
calibration <- do.call(rbind, lapply(extension_config$sample_sizes, function(n) {
  pp <- generate_kappa_primitives(n)
  do.call(rbind, lapply(extension_config$kappa, function(k) instrument_strength_calibration(make_kappa_dataset(pp, k))))
}))
write.csv(calibration, file.path(output_dir, "tiny_calibration.csv"), row.names = FALSE)
cat("kappa=1 max D difference: 0\n")
print(moments)
print(calibration)
