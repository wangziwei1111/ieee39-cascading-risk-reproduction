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

## OLS Failure Diagnosis

The follow-up failure diagnosis reads only the existing `paper_ols_violation` smoke details and does not rerun benchmark scenarios. The current failure rates are:

- `distributed_wind_3000mw_base`: 47 failed attempts out of 197, failure rate 0.2386.
- `distributed_wind_penetration_40pct`: 25 failed attempts out of 139, failure rate 0.1799.
- `paper_wind_speed_12_00mps`: 47 failed attempts out of 197, failure rate 0.2386.

The dominant categories are `opf_nonconverged` and `pf_after_apply_nonconverged`. No failed sample was silently removed. The detailed rows are in `results/loadshedding/ols_benchmark_smoke/tables/ols_failure_diagnosis.csv`.

The robustness test replayed the first five failed samples with four diagnostic settings: baseline, relaxed voltage limits, 1.05x line-rate relaxation, and both relaxations. Some samples became solvable under relaxed settings, but several cases still had post-OLS AC PF nonconvergence. This means the current OLS path is not yet robust enough for a formal 20-trial benchmark rerun.

Recommendation: do not proceed to formal OLS benchmark reruns until the OPF-to-PF handoff and infeasible/nonconverged cases are further reduced or explained. Relaxed settings are diagnostic only and are not formal benchmark results.

## OPF成功但PF失败的状态应用诊断

针对 `pf_after_apply_nonconverged` 类失败，本轮新增 `paper_ols_apply_solution_mode` 诊断，比较三种 OPF 解应用方式：

- `load_only`：只应用 OLS 得到的 Pd/Qd 削减量；
- `load_and_dispatch`：同步应用 OPF 中原始发电机 Pg/Qg/Vg；
- `load_dispatch_and_voltage_init`：进一步把 OPF bus Vm/Va 作为后续 AC PF 初值。

测试对象为既有 OLS smoke 中前 10 个失败样本，不放松电压或线路容量约束，也不改写主 benchmark 结果。结果显示三种模式均为 10 个样本中 OPF 成功 2 个、应用后 AC PF 成功 0 个、OPF 成功但 PF 失败 2 个。也就是说，仅补充发电机调度和电压初值没有提高这批失败样本的 PF 收敛率。

当前建议是：暂不进入正式 OLS benchmark 重跑。失败原因更可能与故障后网络约束、孤岛/平衡机状态、无功约束或普通 PF 可行域有关，而不只是 OPF 解没有完整应用到后续潮流初值。后续若继续推进 OLS，应优先做主岛标准化、平衡机/无功裕度诊断和可行化策略，而不是直接采用 relaxed solver 或把 OPF 成功视作正式 PF 成功。
