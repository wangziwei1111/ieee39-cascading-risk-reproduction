# Line Outage Probability Formula Audit

## Why This Audit Was Needed

The wind-speed component diagnostic rerun localized the 12.00 m/s versus 11.28 m/s risk increase to `line_probability_formula_response`. The next question was whether the paper-mode line-flow probability term `P_flow` was incorrectly varying with line loading below `L_Rated`.

## Paper P_flow Formula

The paper-consistent piecewise formula is:

- if `0 < L <= L_Rated`, then `P_flow = P_L0`;
- if `L_Rated < L <= L_max`, then `P_flow = P_L0 + (1 - P_L0) * (L - L_Rated) / (L_max - L_Rated)`;
- if `L > L_max`, then `P_flow = 1`.

In the current normalized implementation:

- `L = line_loading_pu * L_max`;
- `L_Rated = L_rated_factor * L_max`;
- with `L_max = 1` in p.u. traces, `line_loading_pu <= L_rated_factor` must keep `P_flow` constant at `P_L0`.

## Source Audit

`line_outage_probability_formula_implementation_audit.csv` reports that `compute_paper_line_outage_probability.m` matches the paper piecewise structure. A new explicit config was added:

`cfg.line_outage_flow_probability_mode = 'paper_piecewise_constant_below_rated'`

The legacy option `legacy_loading_scaled` is retained only as explicit diagnostic mode and is not the paper benchmark default.

## Offline Recompute

`line_probability_component_recompute_audit.csv` recomputes `P_flow`, `P_HF_L`, `P_mis_r`, `P1`, `P2`, and `P_L` from the existing wind-speed component diagnostic traces.

The recompute matches the recorded values under paper mode.

## Below-Rated P_flow Audit

`below_rated_Pflow_variation_audit.csv` groups below-rated samples by parameter set, scenario, and candidate branch. It found:

- `issue_confirmed = 0` for all grouped rows;
- recorded `P_flow` is constant within each candidate branch below `L_Rated`;
- paper recompute is also constant below `L_Rated`.

Therefore the suspected below-rated `P_flow` implementation bug is not confirmed.

## Formula Smoke

`line_probability_formula_fix_smoke.csv` checks loading points `0.50`, `0.80`, `0.90`, `0.95`, `1.00`, and `1.20`.

The smoke passes:

- `0.50`, `0.80`, and `0.90` keep `P_flow = P_L0`;
- `0.95` and `1.00` enter the linear interval;
- `1.20` forces `P_flow = 1`.

No Markov run is performed by the smoke.

## After-Fix Rerun Decision

Because the below-rated issue was not confirmed, the after-Pflow-fix wind-speed Markov rerun was skipped. `wind_speed_before_after_Pflow_fix_comparison.csv` records `skipped_no_issue_confirmed`.

The selected next action is:

`inspect_hidden_failure_probability_formula`

This means the next inspection target is the hidden-failure and downstream terms such as `P_HF_L`, `P_mis_r`, `P1`, and `P2`, not a `P_flow` below-rated fix.

## Follow-On Hidden-Failure Audit

The follow-on audit is documented in `docs/hidden_failure_probability_formula_audit.md`. It checks that paper-mode `P_HF_L` is constant for `L < L_max`, that its linear interval starts at `L_max` rather than `L_Rated`, and that `P_mis_r`, `P2`, and `P_L` follow the paper-consistent downstream formulas.

## Guardrails

This audit did not run local search, did not tune parameters, did not write `final_summary`, and did not run the full seven-scenario formal pilot. The benchmark-calibrated parameters remain not original paper parameters.
