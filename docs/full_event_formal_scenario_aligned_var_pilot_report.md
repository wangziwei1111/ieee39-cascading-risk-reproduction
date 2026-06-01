# Full-Event Formal Scenario-Aligned VaR Pilot Report

This report documents the fixed-source formal pilot using Bernoulli full-event
chain transition probability.

## Purpose

The earlier selected-only chain probability used only probabilities for selected
subsequent outages. The full-event version uses:

`P(chain) = P(initial outage) * product(P_selected) * product(1 - P_unselected)`

Terminal-aware checks passed before this run, so terminal recording candidates
are excluded from complement products when appropriate.

## Scope

The pilot runs 7 paper-aligned scenarios:

- `concentrated_bus34`
- `distributed_30_39`
- `wind_speed_11_28`
- `wind_speed_12_00`
- `penetration_40pct`
- `penetration_60pct`
- `penetration_80pct`

It uses 4 fixed parameter sets:

- `low_hidden_failure`
- `medium_hidden_failure`
- `high_hidden_failure`
- `benchmark_calibrated_seed`

Each scenario uses 10 trials per initial line fault, or 460 accident-chain
samples per scenario.

## Outputs

Results are written under:

`results/calibration/full_event_formal_var_pilot/`

The main summary files are:

- `full_event_formal_var_metrics.csv`
- `full_event_formal_var_to_paper_gap.csv`
- `full_event_formal_var_score_summary.csv`
- `post_full_event_formal_var_action.csv`

## Interpretation

This is not a final benchmark and not a strict reproduction. The
`benchmark_calibrated` parameter set is not an original paper parameter set.

This run does not perform local search or parameter tuning. Its only purpose is
to determine whether the full-event transition probability mechanism improves
trend and scale alignment enough to justify a later limited refinement plan.

## Pilot Result

The full-event formal pilot completed for 4 parameter sets and 7 scenarios, with
10 trials per initial line fault.

All 28 scenario outputs have `bernoulli_full_event` stage probability mode and
non-selected-only chain probability status.

The score summary indicates that `high_hidden_failure` has the best rank among
the fixed sets, but its recommendation is `wrong_scale`, with only partial trend
agreement. The selected post-pilot action is therefore:

`fix_metric_or_scenario_first`

This means the current result should not proceed directly to local search. The
next work should review metric scale, scenario definitions, and residual
cascade-mechanism differences before any limited refinement plan.
