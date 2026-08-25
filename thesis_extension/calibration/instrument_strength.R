instrument_strength_calibration <- function(dataset) {
  dat_full <- data.frame(D = dataset$D, dataset$X, Z1 = dataset$Z[, 1], Z2 = dataset$Z[, 2])
  dat_restricted <- dat_full[, !names(dat_full) %in% c("Z1", "Z2"), drop = FALSE]
  full <- lm(D ~ ., data = dat_full)
  restricted <- lm(D ~ ., data = dat_restricted)
  sse_full <- deviance(full)
  sse_restricted <- deviance(restricted)
  q <- 2
  df_full <- df.residual(full)
  data.frame(
    n = length(dataset$D), kappa = dataset$kappa,
    joint_first_stage_F = ((sse_restricted - sse_full) / q) / (sse_full / df_full),
    partial_R2 = (sse_restricted - sse_full) / sse_restricted
  )
}
