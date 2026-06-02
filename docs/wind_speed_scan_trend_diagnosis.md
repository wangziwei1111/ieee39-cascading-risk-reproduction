# Wind Speed Scan Trend Diagnosis

## Scope

This diagnostic investigates why the full-event formal pilot still gives the
opposite wind-speed trend from the paper benchmark for `wind_speed_11_28` and
`wind_speed_12_00`.

No local search, parameter tuning, new Markov simulation, OLS benchmark, or
`final_summary` update was performed.

## Full-Event Pilot Context

The full-event formal pilot successfully generated chain-risk VaR samples with
`bernoulli_full_event` transition probabilities. The scale is improved compared
with earlier severity-only and selected-only previews, but the post-pilot action
remains `fix_metric_or_scenario_first`.

The dominant visible issue is the wind-speed scan:

- Paper direction: risk at 12.00 m/s is lower than risk at 11.28 m/s.
- Current full-event pilot direction: risk at 12.00 m/s is higher than risk at
  11.28 m/s for all tested parameter sets.

## Scenario Configuration Audit

`wind_speed_scenario_config_audit.csv` confirms that the two scenarios are
correctly labeled and use 3000 MW total wind capacity on distributed buses
30:39. This means the trend issue is not caused by a swapped scenario label or
an obvious capacity/bus mapping error.

## Wind Power Curve Audit

`wind_power_curve_speed_scan_audit.csv` compares the requested paper formula
with the current engineering function. At 3000 MW:

- Paper formula at 11.28 m/s: 2489.388 MW.
- Current engineering function at 11.28 m/s: 2483.685 MW.
- Paper formula at 12.00 m/s: 3000 MW.
- Current engineering function at 12.00 m/s: 3000 MW.

The mismatch comes from wind-curve boundary assumptions. The requested paper
audit formula uses cut-in/rated/cut-out = 2/12/20, while the current scenario
default is effectively 3/12/25 unless explicitly overridden.

## Case Power Snapshot

`wind_speed_case_power_snapshot.csv` confirms that wind speed is applied to the
constructed base case:

- `wind_speed_11_28`: actual wind PG total is about 2483.685 MW.
- `wind_speed_12_00`: actual wind PG total is 3000 MW.

The base-case AC power flow converges for both snapshots. This was a base-case
diagnostic only, not a cascade or Markov run.

## Wind Trip Probability Availability

`wind_trip_probability_speed_scan_audit.csv` reports
`missing_wind_trip_records` for the full-event formal pilot. The pilot does not
contain actual wind trip probability records or actual renewable trip events.

Therefore the current wind-speed trend is driven by wind active-power dispatch,
line/cascade severity, and line candidate probability behavior, not by a
calibrated P_wt wind-trip mechanism.

## Chain-Risk And Candidate Probability Distributions

`wind_speed_11_28_vs_12_00_distribution_delta.csv` shows that for all parameter
sets, severity-only `basic_CRI` p95 and full-event `CRI_display` p95 are higher
at 12.00 m/s than at 11.28 m/s.

`wind_speed_candidate_probability_summary.csv` shows that candidate probability
is also higher at 12.00 m/s across all parameter sets.

## Root Cause

The consolidated diagnosis is written to
`wind_speed_trend_root_cause_diagnosis.csv`.

Current likely root cause is:

`wind_power_curve_mismatch`

The broader evidence also shows that severity and candidate probability
distributions both move opposite to the paper benchmark. Because wind trip
records are missing, the current line-only mechanism cannot explain the paper's
lower-risk-at-rated-speed trend through renewable trip probability.

## Next Action

`post_wind_speed_diagnosis_action.csv` recommends:

`fix_wind_power_curve`

This means the next step is to audit and decide whether the calibration
wind-speed aliases should use the paper 2/12/20 wind curve before any parameter
refinement.

Parameter local search should not start until the wind-speed trend issue is
explained.

## Paper-Aligned Wind Power Curve Fix

The wind-speed case builder has now been updated to use the paper-aligned
`paper_2_12_20` wind power curve for benchmark/calibration scenarios. The
legacy engineering curve `engineering_3_12_25` is retained as an explicit
comparison profile and is not deleted.

The paper-aligned formula is:

`P_w = P_wr * (v^3 - 8) / 1720`, for `2 <= v <= 12`.

After the fix, dry-run and base-case-only diagnostics show:

- `wind_speed_11_28`: expected and actual wind PG are about 2489.388 MW.
- `wind_speed_12_00`: expected and actual wind PG are 3000 MW.
- Both snapshots use `wind_power_curve_profile=paper_2_12_20`.
- Base-case AC power flow converges for both snapshots.

The previous full-event formal pilot has not been rerun, so its wind-speed
trend tables are now stale with respect to the curve fix. They should not be
used as parameter-refinement evidence.

`post_wind_curve_fix_readiness.csv` reports:

- `ready_for_full_event_formal_pilot_rerun=1`
- `blocking_issue_count=0`
- `warning_issue_count=1`
- `recommended_next_step=rerun_full_event_formal_pilot_after_curve_fix_with_wind_trip_warning`

The warning is that wind trip probability records are still unavailable in the
formal pilot. A rerun may be used to check whether the paper-aligned wind curve
fix resolves the wind-speed trend, but it is still not a local search and still
does not make P_wt a calibrated paper probability.

## After-Curve-Fix Full-Event Formal VaR Pilot

The post-fix full-event formal VaR pilot has now been run in the independent
output root:

`results/calibration/full_event_formal_var_pilot_after_curve_fix/`

This rerun used:

- `wind_power_curve_profile=paper_2_12_20`
- `chain_transition_probability_mode=bernoulli_full_event`
- terminal-aware stage probability details
- 10 trials per initial branch

All 28 combinations of four parameter sets and seven representative scenarios
completed. The scenario snapshots confirm that the wind-speed cases now use the
paper-aligned curve:

- `wind_speed_11_28`: about 2489.388 MW
- `wind_speed_12_00`: 3000 MW

The rerun generated:

- `full_event_var_metrics_after_curve_fix.csv`
- `full_event_var_to_paper_gap_after_curve_fix.csv`
- `full_event_var_score_summary_after_curve_fix.csv`
- `before_after_curve_fix_comparison.csv`
- `post_curve_fix_formal_pilot_action.csv`

The check log passed and records that no `final_summary` update and no local
search were performed.

The key outcome is that the wind-speed direction still does not match the
paper benchmark after the curve fix. `high_hidden_failure` ranks best in the
current 10-trial pilot, but its recommendation is `wrong_scale`, and the
selected post-fix action is:

`fix_metric_or_scenario_first`

Therefore, the old wind curve mismatch has been fixed as a scenario-construction
issue, but the remaining wind-speed trend gap should not be treated as a
parameter-search problem yet. The next diagnostic should focus on metric,
scenario, and probability-basis alignment.
