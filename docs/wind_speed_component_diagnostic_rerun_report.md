# Wind-Speed Component Diagnostic Rerun Report

## Purpose

This run was created because the after-curve-fix wind-speed tail diagnosis showed that the 11.28 m/s and 12.00 m/s samples were pairable, but the 12.00 m/s CRI remained higher than 11.28 m/s. The prior trace did not contain enough line-probability formula components to identify whether the reversal came from probability response, severity response, or tail composition.

This is not a full formal pilot, not local search, and not a final benchmark.

## Run Scope

Only two wind-speed scenarios were run:

- `wind_speed_11_28`
- `wind_speed_12_00`

Only two parameter sets were run:

- `high_hidden_failure`
- `benchmark_calibrated_seed`

Each scenario used 30 trials per initial fault, giving 1380 chain samples per scenario. The random seed policy was:

`common_random_numbers_by_initial_branch_trial`

The wind power curve was fixed to:

`paper_2_12_20`

The scenario snapshots confirm:

- 11.28 m/s expected wind output: about 2489.388 MW
- 12.00 m/s expected wind output: 3000 MW

## Component Logging

The rerun writes:

- `line_probability_component_trace.csv`
- `severity_component_trace.csv`
- `candidate_probability_trace.csv`
- `stage_transition_probability_details.csv`
- `wind_trip_probability_trace.csv`

The line trace includes `P_flow`, `P_HF_D`, `P_HF_L`, `P_mis_r`, `P1`, `P2`, `P3`, and `P_L`. These values are diagnostic reconstructions from the current benchmark-calibrated or diagnostic parameter sets, not original paper parameters.

## VaR Direction

The diagnostic VaR table shows that the 12.00 m/s case remains higher than 11.28 m/s for the main tail metrics in this small common-random rerun. This confirms the trend issue is not explained only by unpaired random samples.

## Root Cause

`post_wind_speed_component_diagnostic_action.csv` selects:

`line_probability_formula_response`

with:

`go_no_go = inspect_line_outage_probability_formula`

The severity delta table does not dominate the diagnosis. The line probability component response is the primary next inspection target.

## Paper Comparison

`wind_speed_component_diagnostic_to_paper_gap.csv` is a raw diagnostic comparison against paper wind-speed targets where available. It must not be treated as final reproduction.

## Guardrails

This run did not:

- run local search;
- tune protection or hidden-failure parameters;
- write `final_summary`;
- overwrite `full_event_formal_var_pilot_after_curve_fix`;
- run all seven formal benchmark scenarios;
- integrate P_WT into chain probability.

P_WT remains diagnostic-only.

## Next Step

Inspect the line outage probability formula response, especially how `P_flow`, `P_HF_L`, `P_mis_r`, `P1`, `P2`, and `P_L` change between 11.28 m/s and 12.00 m/s under the same chain sample keys.
