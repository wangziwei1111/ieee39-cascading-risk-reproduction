# OLS Benchmark Smoke Report

## Purpose

This smoke experiment checks how the optional paper-style OLS load shedding path changes current risk indicators relative to the default `simple_load_shedding` path.

## Scope

The run uses 5 Markov trials per initial fault. It is intentionally small and must not be treated as a final thesis result.

Scenarios:

- `distributed_wind_3000mw_base`
- `distributed_wind_penetration_40pct`
- `paper_wind_speed_12_00mps`

Modes:

- `simple`: `load_shedding_mode=simple`, `load_shedding_trigger_mode=nonconverged_only`
- `paper_ols_violation`: `load_shedding_mode=paper_ols`, `load_shedding_trigger_mode=nonconverged_or_violation`

Both modes use the same Markov sample count and random seed.

## Outputs

Results are isolated under:

`results/loadshedding/ols_benchmark_smoke/`

Key tables:

- `tables/ols_benchmark_smoke_summary.csv`
- `tables/ols_vs_simple_delta.csv`
- `tables/ols_smoke_vs_paper_benchmark.csv`

Figures:

- `figures/ols_vs_simple_cri_comparison.png`
- `figures/ols_trigger_counts.png`
- `figures/ols_smoke_vs_paper_cri.png`

## Interpretation

If OLS lowers CRI, it indicates that constraint-aware corrective action reduced the current risk metric in this small sample. If OLS raises CRI, it may indicate additional load shedding or constraint repair increased the consequence term. Any fallback means the corresponding row is diagnostic only.

This experiment does not prove numerical alignment with the thesis. The model is still line-only, P_wt(E_k) and P_ge(E_k) are not implemented, units are not fully aligned, and benchmark scenarios have not been rerun at final sample counts.

## Smoke Results

The completed smoke run produced 230 chains per scenario and mode. In `paper_ols_violation` mode, OLS attempts were triggered by the stricter `nonconverged_or_violation` rule:

- `distributed_wind_3000mw_base`: 197 OLS attempts, 150 successful OLS solves, 47 failed OLS attempts recorded in `ols_stage_details.csv`, no fallback counted in the summary.
- `distributed_wind_penetration_40pct`: 139 OLS attempts, 114 successful OLS solves, 25 failed OLS attempts recorded, no fallback counted in the summary.
- `paper_wind_speed_12_00mps`: 197 OLS attempts, 150 successful OLS solves, 47 failed OLS attempts recorded, no fallback counted in the summary.

For this 5-trial smoke, `paper_ols_violation` lowered `basic_CRI_095` and `weighted_CRI_095` in all three representative scenarios. The `paper_formula` CRI moved in different directions: it increased for the 3000MW and 12.00m/s cases, and decreased for the penetration 40% case. These differences are diagnostic only.

## Next Step

Use this smoke result to decide whether a separate `paper_ols` benchmark batch is worthwhile. Do not overwrite existing simple or final summary outputs.
