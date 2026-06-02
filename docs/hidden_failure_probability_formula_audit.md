# Hidden Failure Probability Formula Audit

## Why This Audit Followed P_flow

The previous line probability audit showed that paper-mode `P_flow` is already constant below `L_Rated`; `below_rated_Pflow_variation_audit.csv` reported `issue_confirmed = 0`. The wind-speed risk reversal therefore should not be attributed to the below-rated `P_flow` term. This audit turns to the hidden-failure and downstream terms: `P_HF_L`, `P_mis_r`, `P2`, and final `P_L`.

## Paper P_HF_L Formula

The paper-consistent loading hidden-failure term is:

- if `L < L_max`, then `P_HF_L = P_L_D`;
- if `L_max <= L <= 1.4 L_max`, then `P_HF_L = P_L_D + (L - L_max) * (P_L_r - P_L_D) / (0.4 L_max)`;
- if `L > 1.4 L_max`, then `P_HF_L = P_L_r`.

With normalized `line_loading_pu = L / L_max`, this means `P_HF_L` must stay constant for `line_loading_pu < 1.0`. The linear interval starts at `L_max`, not at `L_Rated`.

## Source Audit

`hidden_failure_probability_formula_implementation_audit.csv` statically checks `compute_paper_line_outage_probability.m` for the expected formula terms:

- `P_HF_L` below, between, and above the paper thresholds;
- `P_mis_r = P_HF_D + P_HF_L - P_HF_D * P_HF_L`;
- `P2 = P_mis_c + P_mis_r * (1 - P_in_c)`;
- `P_L = P1 + P2 + P3`.

The implementation now records an explicit diagnostic field:

`cfg.hidden_failure_loading_probability_mode = 'paper_piecewise_constant_below_Lmax'`

The legacy loading-scaled mode is retained only as an explicit diagnostic option and is not the paper benchmark default.

## Offline Recompute

`hidden_failure_component_recompute_audit.csv` recomputes `P_HF_L`, `P_mis_r`, `P2`, and `P_L` from existing wind-speed component diagnostic traces for:

- `high_hidden_failure`;
- `benchmark_calibrated_seed`;
- `wind_speed_11_28`;
- `wind_speed_12_00`.

The recompute uses the paper-consistent `P_HF_L` piecewise expression and compares it with the recorded trace values.

## Below-Lmax P_HF_L Audit

`below_Lmax_PHFL_variation_audit.csv` specifically checks samples with `line_loading_pu < 1.0`. If recorded `P_HF_L` varies below `L_max` while the paper recompute remains constant, the issue is marked as confirmed.

## Formula Smoke

`hidden_failure_formula_fix_smoke.csv` checks loading points `0.50`, `0.80`, `0.99`, `1.00`, `1.20`, `1.40`, and `1.50`. It only evaluates formula outputs and does not run Markov.

Expected behavior:

- `0.50`, `0.80`, and `0.99`: `P_HF_L = P_L_D`;
- `1.00` to `1.40`: linear interval;
- `1.50`: `P_HF_L = P_L_r`.

## Wind-Speed Rerun Policy

The after-`P_HF_L` wind-speed diagnostic rerun is allowed only if:

- the below-Lmax audit confirms an issue; and
- the formula smoke passes.

If no issue is confirmed, the rerun is skipped and the comparison table records `PHFL_fix_not_run_no_issue_confirmed`.

## Guardrails

This audit is not local search, does not tune protection or hidden-failure parameters, does not write `final_summary`, does not run the full seven-scenario formal pilot, and does not make benchmark-calibrated parameters original paper parameters.
