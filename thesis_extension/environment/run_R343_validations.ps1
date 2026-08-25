param([string]$ValidationNamespace = "R343")

$ErrorActionPreference = "Stop"
$R343 = "C:\Program Files\R\R-3.4.3\bin\x64\Rscript.exe"
$ExtensionRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$LegacyLibrary = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "legacy_R343_library")).Path
$env:R_LIBS_USER = $LegacyLibrary
$env:THESIS_VALIDATION_OUTPUT_DIR = Join-Path $ExtensionRoot ("validation\" + $ValidationNamespace)

& $R343 (Join-Path $PSScriptRoot "check_author_environment.R")
if ($LASTEXITCODE -ne 0) { throw "Environment check failed." }

foreach ($script in @(
  "validate_kappa1.R",
  "validate_author_estimators.R",
  "validate_bc_behavior.R",
  "validate_failure_policy.R",
  "validate_small_extension.R"
)) {
  & $R343 (Join-Path $ExtensionRoot "validation\$script")
  if ($LASTEXITCODE -ne 0) { throw "Validation failed: $script" }
}
