# 最终复现实验结果汇总说明

本文档对应 `results/final_summary/` 中的第4章结果包。该结果包只整理已经完成的分组场景结果，不重新运行仿真，不修改表4-1概率，也不修改 Markov 事故链抽样逻辑。

## 已完成内容

- 基于 MATPOWER `case39` 建立 IEEE 39 节点基础潮流模型。
- 接入论文表4-1线路初始停运概率，并生成加权 VaR 结果。
- 建立线路停运概率驱动的 Markov 多级事故链搜索流程。
- 输出 `basic`、`weighted`、`paper_formula` 三类 VaR/CRI 指标。
- 完成拓扑/接入方式对比、渗透率扫描、风速扫描和新能源脱网概率 record-only 诊断。
- 对 `paper_formula` 的非收敛阶段进行诊断，避免非收敛潮流结果污染 LFOR/NVOR。
- 对大明细表建立 manifest + chunks 归档，便于 GitHub 复核。

## 尚未完全复现内容

- `P_wt(E_k)` 尚未真正并入事故链状态概率。
- `P_ge(E_k)` 尚未实现。
- 新能源脱网仅记录电压脱网概率，不实际触发风电机组脱网。
- `centralized_wind_40pct` 的 `paper_formula` 当前为 `diagnostic_only`，不可作为有效论文对照。
- 线路容量、后续停运概率模型、保护参数和严重度函数仍需进一步按论文参数校准。
- 当前 `paper_formula` 是 line-only 近似，不应称为论文公式的完整复现。

## 第4章可使用结果建议

可用于论文正文展示的表：

- `results/final_summary/tables/final_scenario_overview.csv`
- `results/final_summary/tables/final_topology_comparison.csv`
- `results/final_summary/tables/final_penetration_scan.csv`
- `results/final_summary/tables/final_wind_speed_scan.csv`
- `results/final_summary/tables/final_renewable_trip_record.csv`
- `results/final_summary/tables/final_metric_validity_matrix.csv`
- `results/final_summary/tables/final_thesis_key_results.csv`

可用于论文正文或附录的图：

- `results/final_summary/figures/final_topology_cri_comparison.png`
- `results/final_summary/figures/final_penetration_cri_curve.png`
- `results/final_summary/figures/final_wind_speed_power_and_cri.png`
- `results/final_summary/figures/final_renewable_trip_probability.png`
- `results/final_summary/figures/final_invalid_stage_ratio.png`

建议在正文中明确写为：

> 本文完成了基于 IEEE 39 节点系统的连锁故障风险评估复现实验框架，并在当前参数和 line-only paper_formula 近似下获得趋势性结果。

不建议写为：

> 本文已完全复现原论文第4章全部数值。

## 使用限制

- `basic` 指标主要用于流程验证。
- `weighted` 指标用于展示表4-1初始停运概率加权后的影响。
- `paper_formula` 指标当前是 line-only 论文公式近似。
- `diagnostic_only` 场景只能用于诊断，不应用作论文有效对照。
- `record_only` 新能源脱网概率结果只记录 `P_WT(h)`，不代表完整新能源脱网仿真。

## final_summary 筛选规则

- `smoke` 结果仅用于流程检查，不进入 `results/final_summary/`。
- `final_summary` 只采用 `cfg.markov_num_trials_per_initial_fault=20` 的场景结果。
- `distributed_wind_40pct` 是历史 legacy alias，不进入最终汇总。
- `distributed_wind_3000mw_base` 是 3000 MW 分散式基准场景。
- `distributed_wind_penetration_40pct` 是按 `wind_capacity/base_load` 定义的 40% 渗透率扫描点。
- `topology_compare` 已重跑为正式 20-trial 结果；其中 `centralized_wind_40pct` 若仍为 `diagnostic_only`，只能作为诊断对照。

## 与原文完整复现的差距

当前 `final_summary` 是当前工程参数下的复现实验结果，不是原文数值的严格复现。最主要差距包括：

- `P_wt(E_k)` 尚未真实并入事故链状态概率，当前 line-only paper_formula 中等效为 1。
- `P_ge(E_k)` 尚未实现，传统机组停运概率和状态转移缺失。
- 新能源脱网当前为 `record_only`，只记录 `P_WT(h)`，不实际切除风电机组。
- 线路后续停运概率模型、线路容量、切负荷模型和风电功率曲线仍需原文参数校准。
- 集中式接入节点、渗透率定义、风速扫描点和第4章场景表仍需原文确认。
- `centralized_wind_40pct` 的 `paper_formula` 结果仍为 `diagnostic_only`，不可作为有效论文对照。

后续若要尽量完整复现原文，需要用户继续提供第3章完整公式、第4章算例参数、场景定义表和主要结果图表。新增审计文件如下：

- `docs/original_paper_alignment_audit.md`
- `docs/required_original_paper_inputs.md`
- `docs/next_reproduction_steps.md`
- `results/final_summary/tables/original_paper_gap_audit.csv`

## 与论文 benchmark 的初步对照状态

当前已新增 `results/paper_alignment/` 对照包，用于把论文表4-2、表4-4、表4-5、表4-6 benchmark 与当前工程结果放在同一套审计表中查看。

需要特别注意：

- 论文 benchmark 单位为 `10^-4`，工程结果保留为 final_summary raw value，单位/尺度仍需后续确认。
- 表4-4 分散式 3000MW 和表4-5 渗透率 CRI 可以做谨慎趋势对比，但不能解释为严格数值复现。
- 表4-2 暂不可比，因为当前新能源脱网只是 `record_only`，没有实际触发风电机组脱网。
- 表4-6 暂不可比，因为当前还没有运行论文风速点 11.28、11.52、11.76、12.00 m/s 的正式复现结果。
- 集中式接入场景因接入节点未确认且当前 `paper_formula` 为 `diagnostic_only`，不能作为有效论文对照。

对照输出包括：

- `results/paper_alignment/tables/paper_vs_reproduction_comparison.csv`
- `results/paper_alignment/tables/paper_alignment_gap_diagnosis.csv`
- `results/paper_alignment/tables/next_model_fix_priority.csv`
- `docs/paper_benchmark_alignment_report.md`
