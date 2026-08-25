# Author-faithful DML-IVQR kappa extension

This directory is an isolated thesis extension. No file in the authors' `simulation/` directory is sourced and modified at runtime; the estimator logic is copied into explicit wrappers so the original repository stays immutable.

The sole structural DGP change is

`d_kappa = kappa * (z1 + z2) + sqrt(2 * (1 - kappa^2)) * w + epsilon`,

with one common set of primitives per replication and `w` drawn only after all original primitive draws. The fixed treatment-effect grid is `seq(-1, 3, by=.1)`.

Validation scripts are under `validation/`. The final runner is deliberately guarded: it only runs when passed both a supported `--sample-size` and `--execute-final`. Outputs are separated by sample size.

Example for a later, authorized run:

`Rscript thesis_extension/final/run_final.R --sample-size=500 --execute-final`

Do not add replication seeds, RNG stream setup, checkpoint/restart, adaptive grids, or penalty caching. A restart-safe checkpoint scheme cannot reproduce the uninterrupted stochastic execution after a crash unless it stores/restores complete master and worker RNG/process state at exact call boundaries; this implementation therefore intentionally has no resume mechanism.

## Required historical runtime

Final execution is additionally guarded by `environment/check_author_environment.R`. It requires the explicit 64-bit R 3.4.3 executable and the isolated `environment/legacy_R343_library`. Run the historical validation suite with:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File thesis_extension/environment/run_R343_validations.ps1`

The authoritative historical artifacts are written to `validation/R343/`; modern-environment validation artifacts remain separate.
