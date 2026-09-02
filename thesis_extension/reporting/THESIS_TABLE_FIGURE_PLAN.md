# Candidate Chapter 5 table and figure plan

The plan prioritizes a small main-text set compatible with the 40-page Bonn limit. Complete CSVs remain available for appendices and robustness documentation.

## Main-text tables

### 1. Instrument-strength calibration

- Research question: How does the designed `kappa` sequence translate into descriptive first-stage strength?
- Source: `output/table_strength_calibration.csv`.
- Main-text reason: It anchors interpretation of all later comparisons without treating F or partial R-squared as formal thresholds.
- Chapter 5 subsection: Simulation design and calibration.

### 2. Compact point-estimation performance

- Research question: How do Bias, MAE, and RMSE vary across estimators, strength, and representative central/tail quantiles?
- Source: `output/table_point_performance_main.csv`.
- Main-text reason: It retains all estimators and kappa values for `n=1000` at `tau=.10,.50,.90`, while the complete 120-cell table remains appendix-ready.
- Chapter 5 subsection: Point-estimation results.

### 3. Strong-design coverage and statistic distribution

- Research question: Where does strong-instrument coverage depart from nominal size, and is the departure visible beyond DML?
- Source: `output/table_coverage_strong_n1000.csv`.
- Main-text reason: It directly supports the accepted forensic finding with MC uncertainty and W-statistic quantiles.
- Chapter 5 subsection: Inference, coverage, and size.

## Main-text figures

### 1. RMSE versus kappa

- Research question: How quickly does point-estimation precision deteriorate as instruments weaken?
- Preferred source: `figures/rmse_n1000.png`; `rmse_n500.png` is an appendix/robustness companion.
- Main-text reason: The figure compresses many estimator/quantile comparisons more effectively than a large table.
- Chapter 5 subsection: Point-estimation results.

### 2. Accepted-set informativeness versus kappa

- Research question: How does finite-domain accepted-set informativeness deteriorate with weaker instruments?
- Preferred source: `figures/accepted_measure_n1000.png`; the n=500 companion is appendix-ready.
- Main-text reason: It displays the broad pattern while preserving exact boundary and all-grid rates in CSV tables.
- Chapter 5 subsection: Confidence-set informativeness.

### 3. Power versus kappa

- Research question: How does rejection of moderate false alternatives change with strength, and is there sign asymmetry?
- Sources: `figures/power_minus050_n1000.png` and `figures/power_plus050_n1000.png`.
- Main-text reason: The two separate figures avoid concealing asymmetry; they can later be placed together as one numbered figure if page layout permits.
- Chapter 5 subsection: Power.

### 4. Coverage versus kappa

- Research question: How does empirical coverage vary with instrument strength across estimators and quantiles?
- Preferred source: `figures/coverage_n1000.png`; the n=500 companion is appendix-ready.
- Main-text reason: It exposes both weak-design and strong/tail behavior without suppressing unfavorable cells.
- Chapter 5 subsection: Inference, coverage, and size.

### 5. Grid-domain sensitivity

- Research question: Does the accepted-set measure stabilize as the investigated computational domain expands?
- Source: `figures/grid_domain_expansion.png` and exact values in `output/table_grid_domain_diagnostic.csv`.
- Main-text reason: It concisely distinguishes near-stability at `kappa=1`, material expansion at `.25`, and non-stabilization within investigated domains at `.10`.
- Chapter 5 subsection: Computational-domain sensitivity.

## Appendix allocation

The complete point, confidence-set, power, coverage, and grid-domain CSVs are duplicated under the five `appendix_*.csv` outputs. The n=500 figures and full signed-Delta power tables are natural appendix assets. No reporting asset is copied into the LaTeX tree at this stage.
