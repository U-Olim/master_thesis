grid_sensitivity_config <- list(
  sample_size = 1000L,
  diagnostic_replications = 300L,
  tau_values = c(0.10, 0.25, 0.50, 0.75, 0.90),
  kappa_values = c(1.00, 0.25, 0.10),
  estimators = c("Oracle-GMM", "Full-GMM", "DML-IVQR-BC"),
  wide_grid = seq(-5, 7, by = 0.1),
  grid_step = 0.1,
  critical_value = qchisq(0.95, df = 2),
  seed = 675L,
  workers = 5L,
  p = 100L,
  s = 7L,
  ranges = data.frame(
    range = c("A_1_-1_3", "A_2_-3_5", "A_3_-5_7"),
    range_lower = c(-1, -3, -5),
    range_upper = c(3, 5, 7),
    stringsAsFactors = FALSE)
)

stopifnot(
  identical(grid_sensitivity_config$wide_grid, seq(-5, 7, by = 0.1)),
  length(grid_sensitivity_config$wide_grid) == 121L,
  grid_sensitivity_config$grid_step == 0.1,
  grid_sensitivity_config$critical_value == qchisq(0.95, df = 2),
  grid_sensitivity_config$seed == 675L,
  grid_sensitivity_config$workers == 5L,
  grid_sensitivity_config$diagnostic_replications == 300L
)
