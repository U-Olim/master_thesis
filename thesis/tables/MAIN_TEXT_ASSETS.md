# Prepared main-text tables and figures

Status: ready for later insertion; `05_results.tex` and all chapter text remain unchanged. The current thesis still uses its existing inclusions. This inventory selects the future main-text set; it does not alter that structure.

## Insertion order

| Future number | Source | Label |
|---|---|---|
| Table 1 | `table_strength_calibration.tex` | `tab:strength-calibration` |
| Table 2 | `table_point_performance_main.tex` | `tab:point-performance-main` |
| Figure 1 | `figure_coverage_main.tex` | `fig:coverage-main` |
| Figure 2 | `figure_accepted_measure_main.tex` | `fig:accepted-measure-main` |
| Figure 3 | `figure_power_main.tex` | `fig:power-main` |

Each new figure wrapper has one figure environment, one caption, one shared label and panels (a)/(b). Numbering is automatic; no caption contains a hard-coded figure/table number. Each PNG retains the five quantile panels in the original three-row by two-column arrangement. One legend in panel (b) applies to both panels; panel (a) intentionally omits the duplicate legend.

The selected tables were reviewed and are unchanged. Their captions, labels, notes and numerical entries are suitable for this selection.

## Figure assets

All paths below are under `thesis/figures/generated/`.

- Coverage: `coverage_n500_thesis.png`, `coverage_n1000_thesis.png`.
- Accepted-set measure: `accepted_measure_n500_thesis.png`, `accepted_measure_n1000_thesis.png`.
- Power: `power_minus050_n1000_thesis.png`, `power_plus050_n1000_thesis.png`.

Rendering uses `thesis/tools/build_thesis_figures.R`, the same frozen aggregated reporting CSVs, and base R 3.4.3. Images are 3600 x 2200 pixels at 400 dpi with a white background. Oracle-GMM is blue, Full-GMM orange, and DML-IVQR-BC green; marker shapes and line types also differ. Only coverage has the faint 0.95 reference line. No simulations, estimation, smoothing, interpolation, fitted trends or uncertainty bands are added. The data check retains 60 exact source values per image with zero missing, duplicate or nonfinite values and zero numerical difference.

The two RMSE PNGs are also restyled for consistency, but are not selected for the main text. The frozen grid-domain PNG is unchanged.

## Non-main artifacts retained for possible later appendices

These are excluded from the prepared final set. No files have been moved or deleted, and existing Results inclusions have not been changed.

- `thesis/tables/table_coverage_strong_n1000.tex`
- `thesis/tables/generated/appendix_point_performance.tex`
- `thesis/tables/generated/appendix_coverage.tex`
- `thesis/tables/generated/appendix_cr_informativeness.tex`
- `thesis/tables/generated/appendix_power.tex`
- `thesis/tables/generated/appendix_grid_diagnostic.tex`
- `thesis/tables/generated/figure_rmse.tex`
- `thesis/tables/generated/figure_grid_domain.tex`
- `thesis/figures/generated/rmse_n500_thesis.png`
- `thesis/figures/generated/rmse_n1000_thesis.png`
- `thesis/figures/grid_domain_expansion.png`

## Preview

`thesis/figures/main_text_assets_preview.pdf` displays only the selected two tables and three figures, in order, using the current thesis preamble. It is a separate review artifact and does not change the thesis chapter structure.
