# Operational configuration for the frozen final Monte Carlo.
FINAL_MC_REPS_PER_SAMPLE_SIZE <- 500L
FINAL_MASTER_SEED <- 20260820L
FINAL_SCHEMA_VERSION <- "1.0"
DEFAULT_WORKERS <- 12L

EXPECTED_RAW_ROWS_PER_SAMPLE_SIZE <- 30000L
EXPECTED_POWER_ROWS_PER_SAMPLE_SIZE <- 120000L
EXPECTED_SUMMARY_ROWS_PER_SAMPLE_SIZE <- 60L
EXPECTED_POWER_SUMMARY_ROWS_PER_SAMPLE_SIZE <- 240L
EXPECTED_BC_PENALTIES_PER_SAMPLE_SIZE <- 2500L
EXPECTED_RAW_ROWS_COMBINED <- 60000L
EXPECTED_POWER_ROWS_COMBINED <- 240000L
EXPECTED_SUMMARY_ROWS_COMBINED <- 120L
EXPECTED_POWER_SUMMARY_ROWS_COMBINED <- 480L
EXPECTED_BC_PENALTIES_COMBINED <- 5000L

FINAL_PROJECT_ROOT <- getwd()
FINAL_EXTENSION_DIR <- file.path(FINAL_PROJECT_ROOT, "thesis_extension")
FINAL_RUN_DIR <- file.path(FINAL_EXTENSION_DIR, "final")
FINAL_CHECKPOINT_DIR <- file.path(FINAL_RUN_DIR, "checkpoints")
FINAL_OUTPUT_DIR <- file.path(FINAL_RUN_DIR, "output")

source(file.path(FINAL_EXTENSION_DIR, "config", "kappa_candidates.R"))
source(file.path(FINAL_EXTENSION_DIR, "config", "inference_config.R"))

if (!identical(SAMPLE_SIZES, c(500, 1000)) ||
    !identical(TAUS, c(0.10, 0.25, 0.50, 0.75, 0.90)) ||
    !identical(KAPPA_CANDIDATES, c(1.00, 0.50, 0.25, 0.10)) ||
    !identical(POINT_GRID, seq(-1, 3, by = 0.10)) ||
    !identical(CR_GRID, seq(-1, 3, by = 0.05)) ||
    !identical(POWER_DELTAS, c(-0.50, -0.25, 0.25, 0.50)) ||
    !identical(PARAMETER_LOWER, -1) ||
    !identical(PARAMETER_UPPER, 3) ||
    !identical(CRITICAL_VALUE, qchisq(0.95, df = 2))) {
  stop("Frozen inference configuration differs from the final specification.")
}

if (!identical(FINAL_MC_REPS_PER_SAMPLE_SIZE, 500L) ||
    !identical(FINAL_MASTER_SEED, 20260820L) ||
    !identical(FINAL_SCHEMA_VERSION, "1.0") ||
    !identical(DEFAULT_WORKERS, 12L) ||
    !identical(EXPECTED_RAW_ROWS_PER_SAMPLE_SIZE, 30000L) ||
    !identical(EXPECTED_POWER_ROWS_PER_SAMPLE_SIZE, 120000L) ||
    !identical(EXPECTED_SUMMARY_ROWS_PER_SAMPLE_SIZE, 60L) ||
    !identical(EXPECTED_POWER_SUMMARY_ROWS_PER_SAMPLE_SIZE, 240L) ||
    !identical(EXPECTED_BC_PENALTIES_PER_SAMPLE_SIZE, 2500L) ||
    !identical(EXPECTED_RAW_ROWS_COMBINED, 60000L) ||
    !identical(EXPECTED_POWER_ROWS_COMBINED, 240000L) ||
    !identical(EXPECTED_SUMMARY_ROWS_COMBINED, 120L) ||
    !identical(EXPECTED_POWER_SUMMARY_ROWS_COMBINED, 480L) ||
    !identical(EXPECTED_BC_PENALTIES_COMBINED, 5000L)) {
  stop("Final operational configuration has changed.")
}
