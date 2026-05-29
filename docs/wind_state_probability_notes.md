# 新能源状态概率 P_WT(h) / P_wt(E_k) 诊断说明

## 目标

本阶段建立论文第3章中新能源机组脱网概率的工程接口：

- 单台风机脱网概率 `P_WT(h)`：由 `src/renewable/compute_wind_trip_probability.m` 统一计算；
- 风电集合状态概率 `P_wt(E_k)`：由 `src/renewable/compute_wind_state_probability.m` 按 stage 聚合；
- Markov 阶段记录：`search_cascade_markov_line.m` 在生成 `wind_trip_table` 后记录 `wind_state_probability_detail`。

这些功能均为 diagnostic / record-only。当前不实际切除风机，不改变 `mpc.gen` 状态，不调用随机数，也不改变线路 Markov 抽样逻辑。

## 参数集

参数集位于 `paper_inputs/filled/paper_wind_trip_probability_parameter_sets.csv`。

| parameter_set_id | 含义 | 状态 |
|---|---|---|
| `strict_missing` | 概率函数和参数保持缺失，用于检查 missing 逻辑 | `missing_original_probability_function` |
| `lvrt_hvrt_threshold_record` | 只记录 LVRT/HVRT/FRT 阈值命中，不补概率函数 | `paper_thresholds_extracted_probability_missing` |
| `diagnostic_linear_voltage_probability` | 使用线性电压概率作诊断 | `diagnostic_assumption_not_paper` |

频率穿越阈值单独记录在 `paper_inputs/filled/paper_wind_frequency_ride_through_rules.csv`。这些阈值来自论文表述，但完整概率曲线仍未校准。

## 当前实现

`compute_wind_trip_probability` 支持：

- `none`：禁用，返回 0；
- `paper_threshold_record`：只判断是否进入阈值区；阈值命中但缺概率函数时返回 `NaN`；
- `diagnostic_voltage_piecewise`：使用 0.2/0.9/1.1/1.3 p.u. 的诊断线性概率；
- `paper_formula`：预留，缺公式参数时返回 `NaN`。

`compute_wind_state_probability` 在 record-only 模式下假定所有风机仍在线，因此：

```text
P_wt(E_k) = product_h [1 - P_WT(h)]
```

这只是“当前在线状态保持概率”的诊断值，不代表实际风机状态转移。

## 诊断输出

小规模 smoke 输出位于：

```text
results/renewable/wind_state_probability_diagnostic_smoke/<parameter_set_id>/
```

每个参数集包含：

- `markov_chain_summary.csv`
- `wind_trip_probability_details.csv`
- `wind_state_probability_stage_details.csv`
- `wind_state_probability_summary.csv`
- `diagnostic_log.txt`

离线影响对照位于：

- `results/renewable/wind_state_probability_effect_comparison.csv`
- `results/renewable/wind_state_probability_effect_summary.csv`

该对照只计算 `P_line(E_k) * P_wt(E_k)` 的诊断差异，不替换正式 `paper_formula` 结果。

## 当前结论

当前 `diagnostic_linear_voltage_probability` smoke 中，风电节点电压未进入诊断脱网概率区间，因此 `P_wt(E_k)=1`，对 line-only 阶段概率没有产生削减。`strict_missing` 正确输出 missing probability；`threshold_record` 在未命中阈值时输出 0 概率。

这不能说明论文中的 `P_wt(E_k)` 影响为零，只说明当前小样本与当前参数下没有触发诊断概率区间。

## 后续缺口

后续若要把 `P_wt(E_k)` 并入正式 paper formula，仍需：

- 原文 `P_WT(h)` 完整概率函数；
- LVRT/HVRT/FRT 与概率曲线的对应关系；
- 实际风机脱网状态转移规则；
- 风机脱网后对潮流、机组状态和后续事故链的影响；
- 与 `P_line(E_k)`、未来 `P_ge(E_k)` 的状态概率耦合方式。

在这些信息补齐前，不应把 diagnostic 线性概率称为论文原文概率函数，也不应将 `P_wt(E_k)` 写入正式 benchmark 或 final_summary。
