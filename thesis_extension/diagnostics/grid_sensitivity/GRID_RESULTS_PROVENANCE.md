# Grid-sensitivity result provenance

## Diagnostic design

- Stage 1 evaluates the parameter domain `[-3,5]` on a 0.1 grid (81 candidate values).
- Stage 2 extends the domain to `[-5,7]` by adding `[-5,-3.1]` and `[5.1,7]` on the same 0.1 grid (40 added candidates).
- Stage 2 reads the saved Stage 1 profiles and reuses the 100 saved Stage 1 primitive sets. It does not regenerate the underlying Monte Carlo primitives or recompute the Stage 1 candidate values.
- The design contains 100 replications, five quantiles, three kappa values, and three estimators: 4,500 replication-quantile-kappa-estimator profiles.

## Completed outputs

| Output | Data rows |
|---|---:|
| Stage 1 candidate profiles | 364,500 |
| Stage 1 range metrics | 9,000 |
| Stage 1 expansion metrics | 4,500 |
| Stage 2 added-tail profiles | 180,000 |
| Combined `[-5,7]` candidate profiles | 544,500 |
| Stage 2 range metrics | 13,500 |
| Stage 2 expansion metrics | 4,500 |

The complete per-file size, SHA-256, Git status, stage, and purpose inventory is in `GRID_RESULTS_MANIFEST.csv`. It includes all 100 files under `output/stage1/primitives/`.

## Failures and warnings

Both stage run logs report `RUN_STATUS=COMPLETE` and no warnings.

Stage 1 records one numerical candidate failure: replication 35, tau 0.9, kappa 0.1, DML-IVQR-BC, candidate `a=-2.1`, with `Error info = 95 in stepy2: singular design`. Consequently, the Stage 1 summaries contain 8,999 successful and one failed profile-range record across their two reported domains. Stage 2 records no new tail-evaluation failures. Its combined three-domain summaries contain 13,498 successful and two failed profile-range records because the one Stage 1 candidate failure affects the `[-3,5]` and `[-5,7]` ranges, but not `[-1,3]`.

## Preservation requirement

These files are essential diagnostic provenance. Several large CSVs and all saved primitive RDS files are intentionally ignored by Git and therefore will not be included in an ordinary clone, GitHub source archive, or ZIP created from tracked files. They require an external backup that preserves the paths and hashes in `GRID_RESULTS_MANIFEST.csv`.
