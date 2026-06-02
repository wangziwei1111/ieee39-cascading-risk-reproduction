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

## Wind-Speed Trend Follow-Up

A dedicated wind-speed trend diagnosis has been added after the full-event
pilot. It focuses on `wind_speed_11_28` and `wind_speed_12_00` without running
new Markov simulations or changing calibration parameters.

The diagnosis confirms that the scenario labels, 3000 MW capacity, and
distributed buses 30:39 are consistent. The constructed base cases also show
that 12.00 m/s produces 3000 MW wind output while 11.28 m/s produces a lower
wind output.

However, the current wind-speed pilot still has the opposite risk direction
from the paper: full-event `CRI_display` and severity-only `basic_CRI` p95 are
higher at 12.00 m/s than at 11.28 m/s. Candidate probabilities are also higher
at 12.00 m/s.

The wind power curve audit flags a formula mismatch: the requested paper audit
formula uses cut-in/rated/cut-out speeds of 2/12/20, while the current
engineering scenario default is 3/12/25. The full-event pilot also has no
available wind-trip probability records, so the current trend is still
line/cascade driven rather than P_wt driven.

The post-diagnosis action is `fix_wind_power_curve`. This keeps the work out of
local search until the wind-speed trend mechanism is explained.

## Wind-Curve Fix Status

The paper-aligned wind power curve entry has been fixed for benchmark and
calibration scenario construction. These scenarios now use
`wind_power_curve_profile=paper_2_12_20`, corresponding to cut-in/rated/cut-out
speeds of 2/12/20. The legacy engineering profile 3/12/25 remains available as
an explicit comparison profile.

Dry-run and base-case-only checks now show that `wind_speed_11_28` produces
about 2489.388 MW and `wind_speed_12_00` produces 3000 MW. No Markov or formal
pilot rerun was performed during this fix.

Because the old full-event formal pilot was produced before the curve fix, its
wind-speed trend should no longer be used as parameter-refinement evidence.
The readiness table recommends a post-fix full-event formal pilot rerun with an
explicit wind-trip-probability warning. This is still not local search and not a
final benchmark.
