# Wind-Speed VaR Tail Attribution Diagnosis

This note records the diagnostic-only attribution for the after-curve-fix wind-speed VaR reversal between `wind_speed_11_28` and `wind_speed_12_00`.

## Scope

Inputs were read only from:

- `results/calibration/full_event_formal_var_pilot_after_curve_fix/`
- `results/calibration/renewable_trip/`

No new Markov scenario, local search, formal benchmark, OLS run, `final_summary`, or P_WT integration was executed.

## Outputs

The diagnosis produced:

- `wind_speed_var_tail_attribution.csv`
- `wind_speed_tail_branch_contribution_summary.csv`
- `wind_speed_tail_branch_delta_11_28_vs_12_00.csv`
- `wind_speed_random_seed_pairing_audit.csv`
- `wind_speed_paired_chain_risk_delta.csv`
- `wind_speed_paired_chain_risk_delta_summary.csv`
- `wind_speed_tail_candidate_probability_driver.csv`
- `wind_speed_tail_candidate_probability_delta.csv`
- `wind_speed_common_random_rerun_readiness.csv`
- `post_wind_speed_tail_diagnosis_action.csv`
- `wind_speed_tail_attribution_diagnosis_check_log.txt`

## Main Findings

The random-seed and sample-pairing audit reports the two wind-speed scenarios as `fully_pairable` for this diagnostic comparison. This means the observed 12.00 m/s versus 11.28 m/s direction can be inspected through paired chain deltas without first requiring a new common-random rerun.

The paired CRI delta summary shows 12.00 m/s is higher than 11.28 m/s on average in the existing after-curve-fix samples. The dominant driver is not isolated to one simple component in the summary, so the next useful step is to inspect line probability and severity basis in the tail rather than start parameter search.

The P_WT smoke remains all zero for the wind-speed samples. Therefore wind trip probability recording works as a diagnostic chain, but it does not explain the current wind-speed VaR trend gap.

## Recommended Action

`post_wind_speed_tail_diagnosis_action.csv` recommends:

`increase_trials_for_wind_speed_only_after_driver_review`

This is only a small diagnostic rerun readiness recommendation. It is not approval to run a formal 20-trial benchmark, local search, or final summary update.

## Guardrails

These results must not be described as formal paper reproduction. They are a tail attribution and sampling-driver diagnostic over existing after-curve-fix outputs. P_WT remains record-only and is not multiplied into the chain probability.
