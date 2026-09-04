# Thesis asset provenance

All empirical sources remain under `thesis_extension/reporting/`. The grid-domain PNG is copied byte-for-byte from the frozen reporting layer. The other eight main-text PNGs are deterministic, presentation-only renderings of already aggregated reporting CSVs. They do not estimate, simulate, interpolate, smooth, or otherwise alter empirical values. LaTeX tables are deterministic presentations of the named CSVs; no claim of byte identity between CSV and TeX is made.

## Copied frozen asset

| Thesis path | Frozen reporting PNG | PNG SHA-256 | Source reporting CSV | CSV SHA-256 | Role |
|---|---|---|---|---|---|
| `thesis/figures/grid_domain_expansion.png` | `thesis_extension/reporting/figures/grid_domain_expansion.png` | `da12204ce3c447229360d7a02585f5ee19c92ca1fe401a74b6ff68ff5e880133` | `thesis_extension/reporting/output/table_grid_domain_diagnostic.csv` | `86b99d4cee32fbbca6afc788153e17cc78c990bf13b63ad0be99bcf5c2f3010e` | Finite grid-domain expansion diagnostic |

## Deterministic thesis renderings

All files in this table are produced by `thesis/tools/build_thesis_figures.R` using base R 3.4.3. Each output uses five tau panels in a three-row by two-column layout, with the sixth cell reserved for a shared legend.

| Thesis output | Source reporting CSV | Source CSV SHA-256 | Metric | Subset | Output SHA-256 |
|---|---|---|---|---|---|
| `thesis/figures/generated/rmse_n500_thesis.png` | `thesis_extension/reporting/output/table_point_performance_full.csv` | `628912c3ff0395b8c9927b1ee40783c38b53770eafa488e9d70b8e808817c2de` | RMSE | `n=500`; all tau, kappa, and estimators | `f8dd73bbb2aafb6c1cbc70add571049a49b735a2d92426e0e7f9cd25a91b2e0e` |
| `thesis/figures/generated/rmse_n1000_thesis.png` | `thesis_extension/reporting/output/table_point_performance_full.csv` | `628912c3ff0395b8c9927b1ee40783c38b53770eafa488e9d70b8e808817c2de` | RMSE | `n=1000`; all tau, kappa, and estimators | `a09ad7fbdad045bca101e110a04a1be3971243af5de471ea7b81ed31c47bd4be` |
| `thesis/figures/generated/accepted_measure_n500_thesis.png` | `thesis_extension/reporting/output/table_cr_informativeness_full.csv` | `153f90ddb02dbbc04de1476699d5aba131474a71de8ee945908ee2c106612ffa` | Median grid-based accepted-set measure in `A0=[-1,3]` | `n=500`; all tau, kappa, and estimators | `f1caf5d53eb91f6193612dc4500e582898dfa965a5b4ee41b566f8929020ed29` |
| `thesis/figures/generated/accepted_measure_n1000_thesis.png` | `thesis_extension/reporting/output/table_cr_informativeness_full.csv` | `153f90ddb02dbbc04de1476699d5aba131474a71de8ee945908ee2c106612ffa` | Median grid-based accepted-set measure in `A0=[-1,3]` | `n=1000`; all tau, kappa, and estimators | `82d57351c9bd31c53a1fbc0f761e1ea17001b02994ff6a5e73f8011ce3b0659e` |
| `thesis/figures/generated/power_minus050_n1000_thesis.png` | `thesis_extension/reporting/output/table_power_full.csv` | `85ad8ddf2d7b3f93135b89ee71ba57c025a719e85ec30d22ac578726270d4d32` | Empirical power | `n=1000`, `Delta=-0.50`; all tau, kappa, and estimators | `507f4a0046be625967e5c4b216febcf23574c92fb6af726e8553514e494e4252` |
| `thesis/figures/generated/power_plus050_n1000_thesis.png` | `thesis_extension/reporting/output/table_power_full.csv` | `85ad8ddf2d7b3f93135b89ee71ba57c025a719e85ec30d22ac578726270d4d32` | Empirical power | `n=1000`, `Delta=+0.50`; all tau, kappa, and estimators | `f4c7686e1635b07b67c931b337989dc43f76588a9b6021c3359a4da6fe52c0c1` |
| `thesis/figures/generated/coverage_n500_thesis.png` | `thesis_extension/reporting/output/table_coverage_full.csv` | `f075d6c504cc67f0eb3023b3a540683d751cb4508e7385d6aa48452fc216938c` | Empirical coverage | `n=500`; all tau, kappa, and estimators | `3be81820b34643c4c1b7e30e2f1df310a9a1690a06b9fda4b8e713ce83cef6b4` |
| `thesis/figures/generated/coverage_n1000_thesis.png` | `thesis_extension/reporting/output/table_coverage_full.csv` | `f075d6c504cc67f0eb3023b3a540683d751cb4508e7385d6aa48452fc216938c` | Empirical coverage | `n=1000`; all tau, kappa, and estimators | `28c3f5b26883f0390c4081341ce7bd5f7cede9f0cdc79bd01e2041b09499c3fb` |

`thesis/figures/THESIS_FIGURE_DATA_CHECK.csv` records the exact key and y-value verification: 8/8 figures pass, each contains all 60 expected plotted observations, and every plotted y-value equals its frozen CSV value exactly. Repeated rendering produced identical SHA-256 values for all eight outputs.

## Generated tables

| Thesis path | Reporting source | Source SHA-256 | Role | Placement |
|---|---|---|---|---|
| `thesis/tables/table_strength_calibration.tex` | `thesis_extension/reporting/output/table_strength_calibration.csv` | `fbdb63326886a449bd552dd1ef988a51111f02afc77770ec216e99b1b7781a7c` | Instrument-strength calibration | Main text |
| `thesis/tables/table_point_performance_main.tex` | `thesis_extension/reporting/output/table_point_performance_full.csv` | `628912c3ff0395b8c9927b1ee40783c38b53770eafa488e9d70b8e808817c2de` | Median-quantile point performance, n=1000 | Main text |
| `thesis/tables/table_coverage_strong_n1000.tex` | `thesis_extension/reporting/output/table_coverage_strong_n1000.csv` | `e39287aec70c78fb210d35bbd71c313f6c0b1a52b348913f24b2e1c4cdd2fe5c` | Strong-design coverage diagnostic | Main text |
| `thesis/tables/generated/appendix_point_performance.tex` | `thesis_extension/reporting/output/appendix_point_performance.csv` | `628912c3ff0395b8c9927b1ee40783c38b53770eafa488e9d70b8e808817c2de` | Full point performance | Appendix A |
| `thesis/tables/generated/appendix_power.tex` | `thesis_extension/reporting/output/appendix_power.csv` | `85ad8ddf2d7b3f93135b89ee71ba57c025a719e85ec30d22ac578726270d4d32` | Full power | Appendix B |
| `thesis/tables/generated/appendix_grid_diagnostic.tex` | `thesis_extension/reporting/output/appendix_grid_diagnostic.csv` | `86b99d4cee32fbbca6afc788153e17cc78c990bf13b63ad0be99bcf5c2f3010e` | Full finite grid-domain diagnostic | Appendix C |
| `thesis/tables/generated/appendix_coverage.tex` | `thesis_extension/reporting/output/appendix_coverage.csv` | `f075d6c504cc67f0eb3023b3a540683d751cb4508e7385d6aa48452fc216938c` | Full coverage and size | Appendix D |
| `thesis/tables/generated/appendix_cr_informativeness.tex` | `thesis_extension/reporting/output/appendix_cr_informativeness.csv` | `153f90ddb02dbbc04de1476699d5aba131474a71de8ee945908ee2c106612ffa` | Full accepted-set informativeness | Appendix E |

## Structural wrappers

The five `thesis/tables/generated/figure_*.tex` files contain only LaTeX figure environments, semantic labels, panel identifiers, captions, and finite-domain notes. They do not transform empirical values.
