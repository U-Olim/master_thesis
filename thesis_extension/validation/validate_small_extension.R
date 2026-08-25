script_arg <- grep("^--file=", commandArgs(), value = TRUE)
root <- normalizePath(file.path(dirname(normalizePath(sub("^--file=", "", script_arg[1]))), ".."))
source(file.path(root,"environment","check_author_environment.R"))
assert_author_environment(root, write_outputs = FALSE)
output_dir <- Sys.getenv("THESIS_VALIDATION_OUTPUT_DIR", unset = file.path(root,"validation"))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
source(file.path(root,"config","extension_config.R"))
for(f in c("dgp_kappa.R","author_oracle_wrapper.R","author_full_wrapper.R","author_bc_dml_wrapper.R","metrics.R","run_extension.R")) source(file.path(root,"src",f))
set.seed(extension_config$seed)
out <- run_extension(500L,2L,c(.10,.50,.90),extension_config$kappa,
                     c("Oracle-GMM","Full-GMM","DML-IVQR-BC"),5L,
                     file.path(output_dir,"smoke_output"))
stopifnot(nrow(out$results)==72L,nrow(out$profiles)==72L*41L,nrow(out$power)==72L*6L,
          all(c("alpha_hat","W_true","covered","rejected_true","grid_accepted_set_measure",
                "accepted_grid_share","left_boundary_accepted","right_boundary_accepted","failed") %in% names(out$results)))
cat("Smoke rows:",nrow(out$results),"; failures:",nrow(out$failures),"\n")
