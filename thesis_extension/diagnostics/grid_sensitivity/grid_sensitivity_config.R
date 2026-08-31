grid_sensitivity_config <- list(
  sample_size = 1000L,
  diagnostic_replications = 100L,
  tau_values = c(0.10, 0.25, 0.50, 0.75, 0.90),
  kappa_values = c(1.00, 0.25, 0.10),
  estimators = c("Oracle-GMM", "Full-GMM", "DML-IVQR-BC"),
  stage1_grid = seq(-3, 5, by = 0.1),
  stage2_tail_grid = c(seq(-5, -3.1, by = 0.1), seq(5.1, 7, by = 0.1)),
  grid_step = 0.1,
  critical_value = qchisq(0.95, df = 2),
  boundary_trigger_threshold = 0.05,
  outer_band_trigger_threshold = 0.10,
  weak_trigger_kappa = c(0.25, 0.10),
  outer_band_left = c(-3, -2.5),
  outer_band_right = c(4.5, 5),
  seed = 675L,
  workers = 5L,
  p = 100L,
  s = 7L,
  stage1_ranges = data.frame(
    range = c("A_0_-1_3", "A_1_-3_5"),
    range_lower = c(-1, -3),
    range_upper = c(3, 5),
    stringsAsFactors = FALSE),
  stage2_ranges = data.frame(
    range = c("A_0_-1_3", "A_1_-3_5", "A_2_-5_7"),
    range_lower = c(-1, -3, -5),
    range_upper = c(3, 5, 7),
    stringsAsFactors = FALSE)
)

stopifnot(
  identical(grid_sensitivity_config$stage1_grid, seq(-3, 5, by = 0.1)),
  length(grid_sensitivity_config$stage1_grid) == 81L,
  length(grid_sensitivity_config$stage2_tail_grid) == 40L,
  identical(grid_sensitivity_config$stage2_tail_grid,
            c(seq(-5, -3.1, by = 0.1), seq(5.1, 7, by = 0.1))),
  grid_sensitivity_config$grid_step == 0.1,
  grid_sensitivity_config$critical_value == qchisq(0.95, df = 2),
  grid_sensitivity_config$boundary_trigger_threshold == 0.05,
  grid_sensitivity_config$outer_band_trigger_threshold == 0.10,
  grid_sensitivity_config$seed == 675L,
  grid_sensitivity_config$workers == 5L,
  grid_sensitivity_config$diagnostic_replications == 100L
)
