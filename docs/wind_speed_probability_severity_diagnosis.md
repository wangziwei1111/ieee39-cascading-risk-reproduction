# Wind-Speed Probability / Severity Basis Diagnosis

This diagnostic follows the wind-speed VaR tail attribution step. It explains why the workflow should not directly rerun the wind-speed formal pilot or start local search.

## Why Not Rerun Directly

The previous tail attribution showed that `wind_speed_11_28` and `wind_speed_12_00` are already pairable, but the paired CRI delta remains opposite to the expected wind-speed trend. Since paired samples already expose the reversal, the immediate question is not random seed mismatch. The next question is whether the line-outage probability model inputs or the severity model inputs are driving the tail.

## Field Availability

`wind_speed_probability_severity_field_availability.csv` audits the existing after-curve-fix outputs.

Available fields include:

- candidate branch, candidate probability, selected flag, random number, and line loading proxy;
- stage transition probability products;
- chain-level basic LLR/LFOR/NVOR/CRI and max loading / voltage deviation.

Missing fields include the line probability formula components:

- `P_flow`
- `P_HF_D`
- `P_HF_L`
- `P_mis_r`
- `P1`
- `P2`
- `P_L`

Because these fields are missing, the current diagnosis cannot fully attribute the wind-speed reversal to a specific subterm of the line-outage formula.

## Line Probability Diagnosis

`wind_speed_line_probability_component_summary.csv` and `wind_speed_line_probability_component_delta.csv` summarize the available candidate probability and loading basis. The component status is `need_probability_component_trace_smoke` where formula subterms are absent.

The component trace smoke exported a minimal diagnostic directory under:

`results/calibration/full_event_formal_var_pilot_after_curve_fix/wind_speed_probability_component_trace_smoke/`

This smoke is not a formal pilot rerun. It copies a tiny subset of existing traces and preserves missing component fields as `NaN` with explicit notes.

## Severity Diagnosis

`wind_speed_severity_component_summary.csv` and `wind_speed_severity_component_delta.csv` compare paired chain-level basic severity inputs between 11.28 m/s and 12.00 m/s. Several tail rows show line-overload or mixed severity increases, but the dominant root-cause action remains blocked by missing probability component fields.

## Tail Driver

`wind_speed_tail_probability_severity_driver_summary.csv` currently identifies the dominant tail driver as:

`insufficient_component_fields`

This means the existing result is enough to say that the reversal is not explained by P_WT or random seed pairing alone, but not enough to isolate whether the line probability formula or severity formula is the primary model issue.

## Next Action

`post_wind_speed_probability_severity_diagnosis_action.csv` recommends:

`run_wind_speed_only_more_trials_with_component_logging`

This is a diagnostic-only next step. It does not authorize:

- local search;
- parameter refinement;
- formal wind-speed benchmark rerun;
- `final_summary` update;
- P_WT integration into chain probability.

## Component Diagnostic Rerun Completed

The recommended wind-speed-only component diagnostic rerun has now been
executed in a separate output directory:

`results/calibration/wind_speed_component_diagnostic_rerun/`

It used only:

- `high_hidden_failure`
- `benchmark_calibrated_seed`
- `wind_speed_11_28`
- `wind_speed_12_00`

with 30 trials per initial fault and common random numbers by
`initial_branch + trial_id`.

The new diagnostic includes line probability component traces and severity
component traces. The selected post-rerun action is:

`inspect_line_outage_probability_formula`

The dominant root cause is currently:

`line_probability_formula_response`

This remains diagnostic-only. It is not a local search result, not parameter
refinement, not a full formal pilot, and not final reproduction.
