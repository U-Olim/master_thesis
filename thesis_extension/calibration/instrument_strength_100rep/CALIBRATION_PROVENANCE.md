# Instrument-strength calibration provenance

## Archived sources

The preserved outputs and comparison runner originated at:

- `archive/legacy_thesis_repo_20260825/thesis_extension/pilot/kappa_strength_raw.csv`
- `archive/legacy_thesis_repo_20260825/thesis_extension/pilot/kappa_strength_summary.csv`
- `archive/legacy_thesis_repo_20260825/thesis_extension/pilot/kappa_strength_report.txt`
- `archive/legacy_thesis_repo_20260825/thesis_extension/pilot/run_kappa_strength_pilot.R`

The first three files are byte-for-byte archived outputs. The old runner is preserved as `run_kappa_strength_pilot_legacy.R` for comparison only and is not canonical.

## Reason for migration

The archived calibration contains 100 replications for each sample size (`n=500,1000`) and the four instrument-strength values (`kappa=1,.5,.25,.1`). It is materially more informative than the one-draw `../tiny_calibration.csv` and is therefore retained as methodological provenance.

## DGP compatibility

The archived and current implementations use the same structural treatment equation:

`d(kappa) = kappa*(z1+z2) + sqrt(2*(1-kappa^2))*w + epsilon`

Both draw the authors' primitives first, draw `w` afterward, and reuse a common primitive object across all kappa values within a replication. At `kappa=1`, treatment is exactly the authors' baseline treatment.

The legacy runner calls the removed helper `make_treatment_kappa()` and cannot be treated as a current executable. The canonical `run_strength_calibration.R` instead calls `generate_kappa_primitives()` and `make_kappa_dataset()` from the current `thesis_extension/src/dgp_kappa.R`. It writes any future reproduction to a separate `current_reproduction_output/` directory so the archived outputs cannot be overwritten accidentally.

The current-compatible runner has not been executed as part of Cleanup Phase 1.

## Archived file hashes

| File | Bytes | SHA-256 |
|---|---:|---|
| `kappa_strength_raw.csv` | 187,763 | `8221d4439bae4df01ea510ac7ed042e9ec1f17707a6d235afe37e121818ae0b4` |
| `kappa_strength_summary.csv` | 2,355 | `9a0d511aab9e0eb5d950b8287f846d5e02df65cf34b8f2c09bd3075826126da4` |
| `kappa_strength_report.txt` | 1,970 | `6b1c3906a439a5cdc10d767c72a8f800df5fbb21101637fca87d734480536427` |
| `run_kappa_strength_pilot_legacy.R` | 11,593 | `a2597666d9887a0b2a0472543f4940060b3fcce084d17bec2492aae3d1e13056` |
