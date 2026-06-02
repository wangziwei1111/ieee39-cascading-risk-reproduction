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
