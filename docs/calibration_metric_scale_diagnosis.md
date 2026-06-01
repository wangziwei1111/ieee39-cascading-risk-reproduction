# Calibration Metric Scale Diagnosis

## Current Pilot Overview

The calibration pilot completed for four parameter sets: `low_hidden_failure`, `medium_hidden_failure`, `high_hidden_failure`, and `benchmark_calibrated_seed`. The framework check passed, and `low_hidden_failure` ranked first by the current weighted error score.

However, the four scores are very close. More importantly, most simulated CRI/SLLR/SLFOR/SNVOR values are far smaller than the paper targets. This means the next step should not be local parameter search. First we need to diagnose whether the compared quantities share the same metric definition, scale, and source.

## Why Not Continue Local Search

The pilot parameters mainly affect subsequent line outage probability. If the target metric itself is on a different scale or comes from a different severity definition, further parameter search would tune against the wrong objective.

do not proceed to parameter local search until the metric source and scale diagnosis is resolved.

## Paper Value vs Sim Value Scale

`results/calibration/diagnostics/calibration_metric_source_audit.csv` compares the pilot-used value against:

- raw `markov_var_metrics.csv`
- weighted `markov_var_metrics_weighted.csv`
- `markov_var_metrics_paper_severity.csv`
- a chain-summary-derived diagnostic value

Ratios are reported as `paper_value / sim_value`. Missing values are retained as missing and are not filled with zero.

Observed ratios are generally far larger than a simple 100x percent/per-unit conversion. Examples from `calibration_metric_scale_summary.csv`:

- CRI median ratio: about 131 for topology, 481 for penetration, and 601 for wind-speed targets.
- SLLR median ratio: about 191 for topology, 690 for penetration, and 742 for wind-speed targets.
- SNVOR median ratio can exceed 1000 in penetration and wind-speed groups.

This is not a clean, stable scale factor. It points to a metric source or metric definition mismatch, not just an adjustable probability-parameter issue.

## Raw / Weighted / Paper Severity Comparison

The source audit explicitly records which file the pilot used for each row. Some pilot rows use paper-severity metrics when valid, while diagnostic-only paper-severity rows fall back to weighted basic metrics. This source mixture is diagnostic and should be reviewed before any formal calibration.

## Percent vs Per-Unit Scale

`calibration_metric_scale_summary.csv` reports median and spread of paper-to-sim ratios. Ratios that are stable near 100 suggest a percent/per-unit scale issue. Ratios that vary strongly across scenarios suggest a metric definition or output-source mismatch.

## Metric Definition Risk

If all source variants remain far below paper values, the issue is probably not only probability-parameter calibration. It may indicate a severity aggregation difference, stage vs chain risk definition difference, or unit convention mismatch between current outputs and the paper benchmark.

## Trend Alignment

`calibration_trend_alignment.csv` checks whether topology, wind-speed, and penetration trends point in the same direction as the paper. If trends match but scale differs, scale-aware calibration may be considered later. If trends do not match, scenario and risk-definition checks should come first.

The current trend summary shows 7 matched directions out of 12 tests for each pilot parameter set, with 5 opposite-direction tests. This mixed trend result reinforces the conclusion that local parameter search should pause.

## Recommended Next Step

- If the diagnosis shows a stable scale factor, design a scale-aware diagnostic objective, but do not write the scale into formal results.
- If the diagnosis shows metric definition mismatch, reconstruct the paper-consistent SLLR/SLFOR/SNVOR/CRI first.
- If trends match but scale differs, a later scale-aware calibration may be reasonable.
- If trends also disagree, return to scenario definitions, severity definitions, and probability aggregation before parameter tuning.

Current recommendation: do not proceed to parameter local search. First reconstruct or verify a paper-consistent metric source, especially whether the calibration target should use raw VaR, weighted VaR, paper severity, stage-level risk, a 10^-4 unit conversion, or a different aggregation definition.
