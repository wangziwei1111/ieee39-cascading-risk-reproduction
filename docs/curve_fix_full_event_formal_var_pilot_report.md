# Curve-Fix Full-Event Formal VaR Pilot Report

## Scope

This report records the post wind-power-curve-fix full-event formal VaR pilot.
It is a 10-trial diagnostic pilot, not a final paper benchmark and not a local
search run.

The pilot used:

- `wind_power_curve_profile = paper_2_12_20`
- `chain_transition_probability_mode = bernoulli_full_event`
- terminal-aware stage probability details
- paper-aligned wind penetration basis using total generation capacity
- 10 trials per initial branch

The output root is:

`results/calibration/full_event_formal_var_pilot_after_curve_fix/`

The previous `results/calibration/full_event_formal_var_pilot/` directory was
not overwritten.

## Scenarios And Parameter Sets

The pilot ran four diagnostic/calibration seed parameter sets:

- `low_hidden_failure`
- `medium_hidden_failure`
- `high_hidden_failure`
- `benchmark_calibrated_seed`

Each parameter set ran seven representative scenarios:

- `concentrated_bus34`
- `distributed_30_39`
- `wind_speed_11_28`
- `wind_speed_12_00`
- `penetration_40pct`
- `penetration_60pct`
- `penetration_80pct`

All 28 scenario runs produced `markov_chain_summary.csv`,
`stage_transition_probability_details.csv`, `candidate_probability_trace.csv`,
`scenario_config_snapshot.csv`, and `scenario_run_log.txt`.

## Main Outputs

The pilot generated:

- `full_event_var_metrics_after_curve_fix.csv`
- `full_event_var_to_paper_gap_after_curve_fix.csv`
- `full_event_var_score_summary_after_curve_fix.csv`
- `before_after_curve_fix_comparison.csv`
- `post_curve_fix_formal_pilot_action.csv`
- `curve_fix_full_event_formal_var_pilot_check_log.txt`

The check log passed and explicitly records that `final_summary` was not
written and no local search output was generated.

## Score Summary

The after-curve-fix score summary shows:

| parameter_set_id | valid targets | mean abs relative gap | trend match rate | recommendation |
|---|---:|---:|---:|---|
| low_hidden_failure | 28 | 0.5441 | 0.3333 | wrong_trend |
| medium_hidden_failure | 28 | 0.5709 | 0.3333 | wrong_trend |
| high_hidden_failure | 28 | 0.7891 | 0.6667 | wrong_scale |
| benchmark_calibrated_seed | 28 | 0.5709 | 0.3333 | wrong_trend |

`high_hidden_failure` ranks best by the current pilot score, but its
recommendation remains `wrong_scale`. The selected action is therefore:

`fix_metric_or_scenario_first`

No local search or parameter refinement was run.

## Before/After Curve Fix

The curve fix changed the wind-speed scenario case construction to the
paper-aligned 2/12/20 curve. The post-fix scenario snapshots confirm:

- `wind_speed_11_28` uses about 2489.388 MW wind output.
- `wind_speed_12_00` uses 3000 MW wind output.
- Both use `wind_power_curve_profile = paper_2_12_20`.

However, the wind-speed direction check still does not match the paper target
for the tested parameter sets. This means the old wind curve mismatch was a
real scenario-construction issue, but it was not the only cause of the
remaining wind-speed trend gap.

## Interpretation

The post-fix pilot is useful evidence for the next diagnostic step, but it is
not a final reproduction result.

The current result says:

- The paper-aligned wind curve is now active in the formal pilot scenarios.
- Full-event transition probabilities are being recorded and used.
- The 10-trial sample still does not justify parameter refinement.
- The dominant next issue is metric/scenario/probability-basis alignment, not
  another blind local search.

Benchmark-calibrated parameters remain benchmark-calibrated assumptions, not
original paper parameters.
