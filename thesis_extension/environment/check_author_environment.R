author_environment_paths <- function(extension_root) {
  list(
    extension_root = normalizePath(extension_root, winslash = "/", mustWork = TRUE),
    historical_library = normalizePath(
      file.path(extension_root, "environment", "legacy_R343_library"),
      winslash = "/", mustWork = TRUE)
  )
}

assert_author_environment <- function(extension_root, write_outputs = FALSE) {
  paths <- author_environment_paths(extension_root)
  .libPaths(c(paths$historical_library, .Library))

  expected_r <- "3.4.3"
  actual_r <- paste(R.version$major, R.version$minor, sep = ".")
  if (!identical(actual_r, expected_r)) {
    stop("AUTHOR ENVIRONMENT MISMATCH: R must be 3.4.3; found ", actual_r,
         ". No seed, DGP, cluster, or Monte Carlo work has started.")
  }

  expected_description <- c(
    quantreg = "5.34", hdm = "0.2.0", hqreg = "1.4",
    mvtnorm = "1.0-6", doSNOW = "1.0.16")
  expected_package_version <- c(
    quantreg = "5.34", hdm = "0.2.0", hqreg = "1.4",
    mvtnorm = "1.0.6", doSNOW = "1.0.16")

  if (!identical(normalizePath(.libPaths()[1], winslash = "/", mustWork = TRUE),
                 paths$historical_library)) {
    stop("AUTHOR ENVIRONMENT MISMATCH: historical library is not first in .libPaths().")
  }

  rows <- lapply(names(expected_description), function(pkg) {
    if (!requireNamespace(pkg, quietly = TRUE)) stop("Missing required package: ", pkg)
    lib <- normalizePath(dirname(find.package(pkg)), winslash = "/", mustWork = TRUE)
    if (!identical(lib, paths$historical_library)) {
      stop("AUTHOR ENVIRONMENT MISMATCH: ", pkg, " loaded from ", lib,
           " instead of ", paths$historical_library)
    }
    desc_version <- as.character(packageDescription(pkg, fields = "Version"))
    pv <- as.character(packageVersion(pkg))
    if (!identical(desc_version, unname(expected_description[pkg]))) {
      stop("AUTHOR ENVIRONMENT MISMATCH: ", pkg, " DESCRIPTION version is ",
           desc_version, "; expected ", expected_description[pkg])
    }
    if (!identical(pv, unname(expected_package_version[pkg]))) {
      stop("AUTHOR ENVIRONMENT MISMATCH: ", pkg, " packageVersion() is ",
           pv, "; expected ", expected_package_version[pkg])
    }
    suppressPackageStartupMessages(library(pkg, character.only = TRUE))
    data.frame(Package = pkg, DescriptionVersion = desc_version,
               packageVersion = pv, LibPath = lib, stringsAsFactors = FALSE)
  })
  required <- do.call(rbind, rows)

  cat("AUTHOR R343 ENVIRONMENT CHECK: PASS\n")
  cat("R:", R.version.string, "\n")
  cat("Historical library:", paths$historical_library, "\n")
  print(required, row.names = FALSE)
  cat(".libPaths():\n")
  print(.libPaths())
  print(sessionInfo())

  if (isTRUE(write_outputs)) {
    env_dir <- file.path(paths$extension_root, "environment")
    ip <- as.data.frame(installed.packages(lib.loc = .libPaths()), stringsAsFactors = FALSE)
    inventory <- ip[, c("Package", "Version", "LibPath", "Priority"), drop = FALSE]
    write.csv(inventory, file.path(env_dir, "installed_packages_R343.csv"), row.names = FALSE)
    writeLines(capture.output(sessionInfo()), file.path(env_dir, "sessionInfo_R343.txt"))
    important <- c(names(expected_description), "foreach", "snow", "iterators",
                   "SparseM", "MatrixModels", "Matrix", "Formula", "checkmate",
                   "glmnet", "ggplot2")
    recorded <- sort(unique(c(important, loadedNamespaces())))
    recorded <- recorded[vapply(recorded, function(pkg) length(find.package(pkg, quiet = TRUE)) > 0L, logical(1))]
    loaded_rows <- do.call(rbind, lapply(recorded, function(pkg) data.frame(
      Package = pkg,
      DescriptionVersion = as.character(packageDescription(pkg, fields = "Version")),
      packageVersion = as.character(packageVersion(pkg)),
      LibPath = normalizePath(dirname(find.package(pkg)), winslash = "/", mustWork = TRUE),
      stringsAsFactors = FALSE)))
    lines <- c(paste("R", actual_r, sep = "="), apply(loaded_rows, 1, function(x)
      paste(x["Package"], x["DescriptionVersion"], x["packageVersion"], x["LibPath"], sep = " | ")))
    writeLines(lines, file.path(env_dir, "package_versions_R343.txt"))
  }
  invisible(list(paths = paths, required = required, session = sessionInfo()))
}

if (sys.nframe() == 0L) {
  script_arg <- grep("^--file=", commandArgs(), value = TRUE)
  script_path <- normalizePath(sub("^--file=", "", script_arg[1]), winslash = "/", mustWork = TRUE)
  extension_root <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
  assert_author_environment(extension_root, write_outputs = TRUE)
}
