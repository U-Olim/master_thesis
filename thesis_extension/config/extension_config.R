extension_config <- list(
  sample_sizes = c(500L, 1000L),
  R_MC = 500L,
  tau = c(0.10, 0.25, 0.50, 0.75, 0.90),
  kappa = c(1.00, 0.50, 0.25, 0.10),
  alpha_grid = seq(-1, 3, by = 0.1),
  grid_step = 0.1,
  power_delta = c(-1.00, -0.50, -0.25, 0.25, 0.50, 1.00),
  critical_value = qchisq(0.95, df = 2),
  seed = 675L,
  workers = 5L,
  p = 100L,
  s = 7L,
  R_BC = 1000L,
  bc_c = 2,
  bc_alpha = 0.1
)

stopifnot(
  length(extension_config$alpha_grid) == 41L,
  identical(extension_config$alpha_grid, seq(-1, 3, length = 41L)),
  extension_config$workers == 5L,
  extension_config$R_MC == 500L
)
