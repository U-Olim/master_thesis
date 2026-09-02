# Canonical project structure

This document defines the permanent role of each active repository area.

| Path | Canonical role |
|---|---|
| `Empirical_work/` | Authors' original empirical material; preserve unchanged. |
| `example/` | Authors' original examples; preserve unchanged. |
| `simulation/` | Authors' original simulation and baseline material; preserve unchanged. |
| `docs/` | Provenance and reference material, including the university template and baseline-replication report. |
| `thesis/` | Current thesis manuscript, bibliography, figures, tables, appendices, and deliverable PDF. |
| `thesis_extension/config/` | Final extension configuration. |
| `thesis_extension/src/` | Current executable thesis-extension implementation. |
| `thesis_extension/environment/` | Canonical historical R 3.4.3 environment and reproducibility records. |
| `thesis_extension/validation/R343_final_audit/` | Canonical final pre-run validation output. |
| `thesis_extension/calibration/instrument_strength_100rep/` | Preserved and current-compatible instrument-strength calibration. |
| `thesis_extension/final/` | Completed R=500 main Monte Carlo implementation and results. |
| `thesis_extension/diagnostics/grid_sensitivity/` | Completed grid-domain diagnostic, including Stage 1 and Stage 2 provenance. |
| `thesis_extension/diagnostics/coverage_audit/` | Completed coverage/size forensic audit and provenance. |

## Current canonical state

The legacy `archive/` and repository-root `environment/` trees were removed after their unique material was preserved and verified. They are not active project components.

- The authors' three original directories—`Empirical_work/`, `example/`, and `simulation/`—are preserved unchanged.
- `thesis_extension/environment/` is the canonical historical R 3.4.3 environment.
- `thesis_extension/final/` is the canonical completed R=500 Monte Carlo simulation.
- `thesis_extension/diagnostics/grid_sensitivity/output/stage1/` and `output/stage2/` are the canonical grid-domain diagnostic results.
- `thesis_extension/diagnostics/coverage_audit/` is the canonical completed coverage/size forensic audit.
- `thesis_extension/validation/R343_final_audit/` is the canonical validation output.
- `thesis_extension/calibration/instrument_strength_100rep/` contains the preserved 100-replication instrument-strength calibration and its current-compatible runner.
- `thesis/` is the canonical manuscript directory.
