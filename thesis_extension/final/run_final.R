script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script_dir <- dirname(normalizePath(sub("^--file=", "", script_arg[1])))
root <- normalizePath(file.path(script_dir, ".."))
source(file.path(root, "environment", "check_author_environment.R"))
assert_author_environment(root, write_outputs = FALSE)

args <- commandArgs(trailingOnly = TRUE)
source(file.path(root, "config", "extension_config.R"))
for (f in c("dgp_kappa.R", "author_oracle_wrapper.R", "author_full_wrapper.R",
            "author_bc_dml_wrapper.R", "metrics.R", "run_extension.R")) source(file.path(root, "src", f))

read_arg <- function(flag) {
  hit <- grep(paste0("^", flag, "="), args, value = TRUE)
  if (length(hit)) return(sub(paste0("^", flag, "="), "", hit[1]))
  pos <- match(flag, args)
  if (is.na(pos) || pos == length(args)) NA_character_ else args[pos + 1L]
}
n <- as.integer(read_arg("--sample-size"))
if (!n %in% extension_config$sample_sizes) stop("--sample-size must be 500 or 1000")
if (!"--execute-final" %in% args) stop("Final R=500 run is guarded. Add --execute-final only when formally authorized.")
set.seed(extension_config$seed)
output_dir <- file.path(root, "final", "output", paste0("n", n))
run_extension(n, extension_config$R_MC, extension_config$tau, extension_config$kappa,
              core = extension_config$workers, output_dir = output_dir)
