# OLS Benchmark Smoke Report

## DC-OLS preshed + dispatchable AC-OLS 两阶段诊断

本轮只在既有 `dispatchable_load` 5-trial smoke 的失败样本和独立 two-stage smoke 目录中做诊断，不覆盖 `free_q`、`fixed_q`、`dispatchable_load` 主结果，也不写入 `final_summary`。

对导出的 10 个 dispatchable-load 失败样本，`solve_dc_ols_preshed` 的 DC LP 全部成功。直接把 DC 预切负荷应用后运行 AC PF 时，10 个样本中 6 个收敛，说明不少剩余失败并不是有功网络层面的硬不可行，而与 AC 无功/电压约束、OPF 数值路径或后续 AC 可行化有关。进一步执行 `dc_preshed_ac_ols_polish` 时，AC-OLS polish 有 3 个 OPF 成功，但最终 PF 后验成功仍为 0/10，因此当前两阶段 polish 尚未形成稳定可用的 OLS 路径。

三组 5-trial two-stage smoke 结果也保持谨慎结论：`distributed_wind_3000mw_base`、`distributed_wind_penetration_40pct`、`paper_wind_speed_12_00mps` 的 two-stage failure rate 分别约为 0.269、0.204、0.269，均高于 0.1。`ols_formulation_comparison.csv` 因此将 `dispatchable_load_two_stage_dc_ac` 标记为 `still_not_ready_for_formal_benchmark`。

当前建议是不进入正式 20-trial OLS benchmark。DC-OLS preshed 可以保留为失败样本可行性筛查工具；若后续继续推进，应先研究为什么 DC preshed 后直接 AC PF 能解决部分样本，而 AC-OLS polish 反而无法稳定通过 PF 后验，再决定是否采用两阶段方法作为论文 OLS 的工程近似。

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

## OLS建模一致性与失败样本复核

本轮新增 OLS 建模一致性检查和失败样本导出，不运行新的 Markov 批次，也不覆盖 `results/scenarios` 或 `final_summary`。检查结果显示当前“正注入 generator 表示负荷削减变量 C_i”的 AC-OLS 建模存在重要诊断风险：

- shed generator 会作为在线发电机参与 OPF，可能被当作电压控制资源；
- shed generator 的 QMAX/QMIN 允许其在 OPF 中提供或吸收无功；
- 代表性样本中 `shed_gen_qg_sum=942.315`、`max_abs_shed_gen_qg=184`；
- OPF 中 shed generator QG 与实际按 constant power factor 应用的 `shed_Q` 不一致，`q_mismatch_between_opf_and_applied=1207.84`。

这说明 OPF 可行点和后续普通 PF 使用的削减后系统并不完全等价。当前不能把正注入 generator 建模视作严格等价于论文 OLS。更合理的下一步是优先尝试 MATPOWER dispatchable load / costed load 形式，或显式约束 shed 变量的无功行为，使 OPF 中的 Q 处理与应用到 Pd/Qd 的结果一致。

已导出 6 个典型失败样本到 `results/loadshedding/ols_benchmark_smoke/failure_cases/`，其中包括 3 个 `opf_nonconverged` 和 3 个 OPF 成功但 PF 后验失败候选样本。每个样本包含 `mpc_before_ols.mat`、`mpc_opf_with_shed_generators.mat`、`opf_result.mat`、`mpc_after_apply_load_only.mat`、`runpf_after_apply_result.mat` 和 `ols_detail.mat`。Replay 检查中 5 个样本复现了原失败类型，1 个样本复现了失败但 failure_type 从 `pf_after_apply_nonconverged` 变为 `opf_nonconverged`，因此后续逐例调试时应以导出文件中的 replay 记录为准。

DC-OLS 可行性预览只用于判断网络层面线性可行性，不替代 AC-OLS。当前 6 个导出失败样本的 DC LP 均找到线性可行解，提示部分 AC-OLS 失败可能来自 AC 无功/电压建模、OPF 数值稳定性或正注入 shed generator 建模，而不一定是有功网络层面完全不可行。

推荐下一步：

1. 优先实现一个诊断性的 `matpower_dispatchable_load` OLS 版本，消除正注入 generator 人工无功支撑问题；
2. 保留 DC-OLS 作为失败样本可行性筛查工具，不作为正式论文结果；
3. 在新建模通过 replay 后，再考虑小样本 OLS smoke 重跑；
4. 在失败率显著降低前，不进入正式 20-trial benchmark 重跑。

## fixed_zero_q OLS 诊断变体

为验证 free-Q shed generator 的人工无功支撑是否是主要失败来源，本轮新增 `cfg.paper_ols_shed_gen_q_mode='fixed_zero_q'`。该模式仍使用正注入 generator 表示负荷削减变量，但把 shed generator 的 QMAX/QMIN 固定为 0，禁止它在 OPF 中提供或吸收无功。它是诊断变体，不是原文最终 OLS。

在已导出的 6 个失败 case 上，`fixed_zero_q` 的效果很明确：

- `free_q`：OPF 成功 2/6，PF 后验成功 0/6，平均 Q mismatch 约 1207.84；
- `fixed_zero_q`：OPF 成功 3/6，PF 后验成功 3/6，平均 Q mismatch 约 0.000946；
- `fixed_zero_q` 将 shed generator QG 压到接近 0，显著降低了 OPF 与实际应用到负荷侧的无功不一致。

但 5-trial Markov smoke 的整体结果并不支持直接采用该变体：

- `distributed_wind_3000mw_base` 的 failed OLS count 从 47 增至 67；
- `distributed_wind_penetration_40pct` 的 failed OLS count 从 25 增至 64；
- `paper_wind_speed_12_00mps` 的 failed OLS count 从 47 增至 67。

因此结论是：`fixed_zero_q` 证明了 free-Q 建模中的无功 mismatch 是真实问题，也能修复一部分导出失败样本；但在完整 5-trial smoke 中，它会让更多 OLS 尝试失败。当前不建议把 `fixed_zero_q` 作为正式 benchmark 默认方案。下一步更合适的方向仍是实现 `matpower_dispatchable_load` 或其它不会引入人工电压支撑、同时能一致处理有功/无功削减的建模方式。

## dispatchable load OLS 诊断变体

本轮新增 `cfg.paper_ols_formulation='dispatchable_load'`，使用 MATPOWER 负发电机/可调负荷形式表示可削减负荷，而不是继续把切负荷变量建成正注入发电机。符号约定为：`PG=-Pd` 表示该节点可调负荷全部保留，`PG=0` 表示全部切除，因此 `shed_P = Pd + PG`。本轮默认诊断组合为 `paper_ols_dispatchable_load_q_mode='variable_absorption'`，只允许可调负荷吸收无功，不允许提供正无功支撑。

sign convention 自检结果写入 `results/loadshedding/ols_benchmark_smoke/tables/dispatchable_load_sign_convention_test.csv`。无约束用例 OPF 成功，切负荷约为 0.0012 MW，相对 6254.23 MW 总负荷可视为数值容差内的零切负荷，且 `max_positive_q_injection=0`。人工收紧线路和 Q absorption 用例仍为 diagnostic_warning，说明该 formulation 在更紧约束下仍存在 OPF 数值难点，但没有出现硬性符号错误。

导出失败样本测试显示，`dispatchable_load + variable_absorption` 在 6 个典型失败样本中 OPF 成功 5 个、应用后 PF 成功 5 个，平均 Q mismatch 为 0，明显好于 `positive_injection_generator/free_q`，也优于 `fixed_zero_q`。这说明 dispatchable-load 形式确实修复了相当一部分正注入建模造成的 OPF/PF 不一致。

但是完整 5-trial smoke 的结论更保守：`dispatchable_load + variable_absorption` 在三个代表场景中的 OLS 失败数分别为 52、30、52；原 `free_q` 分别为 47、25、47；`fixed_zero_q` 分别为 67、64、67。因此 dispatchable-load 改善了典型失败样本，但尚未在完整 smoke 中降低整体失败率。当前推荐为：可作为下一阶段诊断候选，不建议直接进入正式 20-trial benchmark，也不能写入 final_summary 或称为原文最终 OLS。

## OLS 阶段性归档结论

截至当前阶段，OLS 仍为 `diagnostic_only`。`free_q` 存在人工无功支撑和 Q mismatch，`fixed_zero_q` 降低 mismatch 但提高了完整 smoke 失败率，`dispatchable_load` 修复正无功支撑问题但失败率仍高于 0.1，`dc_preshed_ac_ols_polish` 也没有达到正式 benchmark 稳定性要求。

因此当前不进入正式 20-trial OLS benchmark，不写入 `final_summary`，也不替代默认 `simple_load_shedding`。后续如需继续 OLS，应先确认原文第3.2.3节采用 AC-OLS、DC-OLS 或其他 OPF 设置，并获得求解器、约束软化和潮流可行化细节。
