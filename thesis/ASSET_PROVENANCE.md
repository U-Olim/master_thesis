# Thesis asset provenance

All empirical sources remain under `thesis_extension/reporting/`. The grid-domain PNG is copied byte-for-byte from the frozen reporting layer. The other eight PNGs are deterministic, presentation-only renderings of already aggregated reporting CSVs. They do not estimate, simulate, interpolate, smooth, or otherwise alter empirical values. LaTeX tables are deterministic presentations of the named CSVs; no claim of byte identity between CSV and TeX is made.

## Copied frozen asset

| Thesis path | Frozen reporting PNG | PNG SHA-256 | Source reporting CSV | CSV SHA-256 | Role |
|---|---|---|---|---|---|
| `thesis/figures/grid_domain_expansion.png` | `thesis_extension/reporting/figures/grid_domain_expansion.png` | `da12204ce3c447229360d7a02585f5ee19c92ca1fe401a74b6ff68ff5e880133` | `thesis_extension/reporting/output/table_grid_domain_diagnostic.csv` | `86b99d4cee32fbbca6afc788153e17cc78c990bf13b63ad0be99bcf5c2f3010e` | Finite grid-domain expansion diagnostic |

## Deterministic thesis renderings

All files in this table are produced by `thesis/tools/build_thesis_figures.R` using base R 3.4.3. Each output uses five tau panels in a three-row by two-column layout at 3600 by 2200 pixels (400 dpi). The six selected main-text images use one shared estimator legend per paired figure, in the sixth cell of panel (b); panel (a) has no duplicate legend. The two RMSE images retain standalone legends for later appendix use. All use the same blue/orange/green palette, distinct markers and line types, and white background. Only coverage has the faint 0.95 reference line.

| Thesis output | Source reporting CSV | Source CSV SHA-256 | Metric | Subset | Output SHA-256 |
|---|---|---|---|---|---|
| `thesis/figures/generated/rmse_n500_thesis.png` | `thesis_extension/reporting/output/table_point_performance_full.csv` | `628912c3ff0395b8c9927b1ee40783c38b53770eafa488e9d70b8e808817c2de` | RMSE | `n=500`; all tau, kappa, and estimators | `9ac034a6b680a413ecf883d27d44bc25c007501400fb89d914c0da88cc933d5e` |
| `thesis/figures/generated/rmse_n1000_thesis.png` | `thesis_extension/reporting/output/table_point_performance_full.csv` | `628912c3ff0395b8c9927b1ee40783c38b53770eafa488e9d70b8e808817c2de` | RMSE | `n=1000`; all tau, kappa, and estimators | `0a2e7f1812b1622b29c09d7fc077cf6374c5088d1093066e9b1a04bb341bb4ed` |
| `thesis/figures/generated/accepted_measure_n500_thesis.png` | `thesis_extension/reporting/output/table_cr_informativeness_full.csv` | `153f90ddb02dbbc04de1476699d5aba131474a71de8ee945908ee2c106612ffa` | Median grid-based accepted-set measure in `A0=[-1,3]` | `n=500`; all tau, kappa, and estimators | `7793c8f60871367c9dfd16e00f1ef866b4fc5754ee4399bd7e5902ecb85b5118` |
| `thesis/figures/generated/accepted_measure_n1000_thesis.png` | `thesis_extension/reporting/output/table_cr_informativeness_full.csv` | `153f90ddb02dbbc04de1476699d5aba131474a71de8ee945908ee2c106612ffa` | Median grid-based accepted-set measure in `A0=[-1,3]` | `n=1000`; all tau, kappa, and estimators | `ac5b03adc075b9aac1be8466a24f176d9a3521052faa415cce1313a3a71339ba` |
| `thesis/figures/generated/power_minus050_n1000_thesis.png` | `thesis_extension/reporting/output/table_power_full.csv` | `85ad8ddf2d7b3f93135b89ee71ba57c025a719e85ec30d22ac578726270d4d32` | Empirical power | `n=1000`, `Delta=-0.50`; all tau, kappa, and estimators | `fc47871a16d9d86a279711481daf9ed97c46273ada6595fb2116d7c256efbc13` |
| `thesis/figures/generated/power_plus050_n1000_thesis.png` | `thesis_extension/reporting/output/table_power_full.csv` | `85ad8ddf2d7b3f93135b89ee71ba57c025a719e85ec30d22ac578726270d4d32` | Empirical power | `n=1000`, `Delta=+0.50`; all tau, kappa, and estimators | `370b9189861885d05f2302c8e149caf81d42ab2dbd13059eea33ae5866c19997` |
| `thesis/figures/generated/coverage_n500_thesis.png` | `thesis_extension/reporting/output/table_coverage_full.csv` | `f075d6c504cc67f0eb3023b3a540683d751cb4508e7385d6aa48452fc216938c` | Empirical coverage | `n=500`; all tau, kappa, and estimators | `0ca9739fa58601a31627782e4627b16ef690ccf687e8a49ac7fef858d53ecf6c` |
| `thesis/figures/generated/coverage_n1000_thesis.png` | `thesis_extension/reporting/output/table_coverage_full.csv` | `f075d6c504cc67f0eb3023b3a540683d751cb4508e7385d6aa48452fc216938c` | Empirical coverage | `n=1000`; all tau, kappa, and estimators | `655d59005c1bda0a79b1aa741d558c8c6df4a0a8cea8cadb5a009700db878d28` |

`thesis/figures/THESIS_FIGURE_DATA_CHECK.csv` records the exact key and y-value verification: 8/8 figures pass, each contains all 60 expected plotted observations, and every plotted y-value equals its frozen CSV value exactly. The output hashes above identify the current color renderings.

## Generated tables

| Thesis path | Reporting source | Source SHA-256 | Role | Placement |
|---|---|---|---|---|
| `thesis/tables/table_strength_calibration.tex` | `thesis_extension/reporting/output/table_strength_calibration.csv` | `fbdb63326886a449bd552dd1ef988a51111f02afc77770ec216e99b1b7781a7c` | Instrument-strength calibration | Main text |
| `thesis/tables/table_point_performance_main.tex` | `thesis_extension/reporting/output/table_point_performance_full.csv` | `628912c3ff0395b8c9927b1ee40783c38b53770eafa488e9d70b8e808817c2de` | Median-quantile point performance, n=1000 | Main text |
| `thesis/tables/table_coverage_strong_n1000.tex` | `thesis_extension/reporting/output/table_coverage_strong_n1000.csv` | `e39287aec70c78fb210d35bbd71c313f6c0b1a52b348913f24b2e1c4cdd2fe5c` | Strong-design coverage diagnostic | Non-main; later appendix candidate |
| `thesis/tables/generated/appendix_point_performance.tex` | `thesis_extension/reporting/output/appendix_point_performance.csv` | `628912c3ff0395b8c9927b1ee40783c38b53770eafa488e9d70b8e808817c2de` | Full point performance | Appendix A |
| `thesis/tables/generated/appendix_power.tex` | `thesis_extension/reporting/output/appendix_power.csv` | `85ad8ddf2d7b3f93135b89ee71ba57c025a719e85ec30d22ac578726270d4d32` | Full power | Appendix B |
| `thesis/tables/generated/appendix_grid_diagnostic.tex` | `thesis_extension/reporting/output/appendix_grid_diagnostic.csv` | `86b99d4cee32fbbca6afc788153e17cc78c990bf13b63ad0be99bcf5c2f3010e` | Full finite grid-domain diagnostic | Appendix C |
| `thesis/tables/generated/appendix_coverage.tex` | `thesis_extension/reporting/output/appendix_coverage.csv` | `f075d6c504cc67f0eb3023b3a540683d751cb4508e7385d6aa48452fc216938c` | Full coverage and size | Appendix D |
| `thesis/tables/generated/appendix_cr_informativeness.tex` | `thesis_extension/reporting/output/appendix_cr_informativeness.csv` | `153f90ddb02dbbc04de1476699d5aba131474a71de8ee945908ee2c106612ffa` | Full accepted-set informativeness | Appendix E |

## Prepared main-text selection

The final prepared set is two tables and three paired figures: calibration, median-quantile point performance, coverage, accepted-set measure, and power. See `thesis/tables/MAIN_TEXT_ASSETS.md` for the exact insertion order and non-main inventory. The new wrappers are prepared but are not inserted into `05_results.tex`; existing chapter text and inclusions are unchanged.

## Structural wrappers

The three `thesis/tables/figure_*_main.tex` wrappers each contain one figure environment, one shared caption and one shared label. Their two panels share the legend embedded in panel (b). The existing five `thesis/tables/generated/figure_*.tex` files remain preserved and contain only LaTeX figure environments, semantic labels, panel identifiers, captions, and finite-domain notes. They do not transform empirical values.
