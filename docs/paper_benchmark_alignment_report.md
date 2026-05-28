# 论文 benchmark 与当前复现结果初步对照报告

本报告基于 `paper_inputs/filled/paper_result_benchmark.csv` 中已录入的论文原文 benchmark，以及 `results/final_summary/` 中当前工程复现汇总结果生成。它只做静态对照，不运行仿真，不修改 Markov 抽样逻辑，也不通过缩放让结果贴近论文。

## 已录入的论文 benchmark

- 表4-2：是否考虑新能源发电机组脱网的综合风险评估指标对比。
- 表4-4：集中式/分散式接入对比。
- 表4-5：40% 至 80% 新能源渗透率扫描结果。
- 表4-6：11.28、11.52、11.76、12.00 m/s 风速波动结果。

所有论文 benchmark 数值单位均为 `10^-4`。对照表中保留了原始 `paper_value`，并额外给出 `paper_value_dimensionless_candidate = paper_value * 1e-4`，但当前尚未确认工程输出与该候选换算量严格同量纲。

## 可谨慎对比的部分

- 表4-4 分散式 3000MW 场景可以与当前 `distributed_wind_3000mw_base` 做 CRI 的 raw comparison，但仍需注意当前工程是 line-only paper_formula 与工程参数版本。
- 表4-5 渗透率扫描可以用于趋势性对比，但当前渗透率定义采用 `wind_capacity/base_load`，论文分母仍需最终确认。

## 暂不可直接比较的部分

- 表4-2 当前不可比：工程中的新能源脱网仍是 `record_only`，未实际触发风机脱网，不能代表论文“计及新能源脱网”的结果。
- 表4-4 集中式场景不可作为有效 paper_formula 对照：集中接入节点仍未由原文确认，且当前集中式 paper_formula 为 `diagnostic_only`。
- 表4-6 当前不可比：工程尚未正式运行 11.28、11.52、11.76、12.00 m/s 这四个论文风速点。
- SLLR、SLFOR、SNVOR 暂不从 final_summary 直接比较，因为当前最终汇总表只稳定整理了 CRI_095。

## 当前差异主要来源

1. `P_wt(E_k)` 尚未纳入新能源实际脱网状态概率。
2. `P_ge(E_k)` 尚未纳入传统机组停运状态概率。
3. 线路后续停运概率模型参数尚未按论文校准。
4. 当前切负荷仍是简化模型，尚未实现论文式最优负荷削减。
5. Table 4-6 的论文风速点尚未重跑。
6. 集中式接入节点未知。
7. 论文 benchmark 单位为 `10^-4`，工程 raw value 的最终单位/尺度仍需确认。

## 不应如何解释当前误差

- 不应声称当前结果已经严格复现论文数值。
- 不应把 `diagnostic_only` 的 paper_formula 结果当作有效对照。
- 不应把 NaN 当作 0。
- 不应对工程结果做任意缩放以贴近论文。
- 不应把 record_only 新能源脱网概率记录解释为完整新能源脱网模型。

## 下一步模型修正顺序

建议优先查看：

- `results/paper_alignment/tables/paper_alignment_gap_diagnosis.csv`
- `results/paper_alignment/tables/next_model_fix_priority.csv`

推荐顺序为：先实现论文式最优负荷削减和线路后续停运概率参数化，再补跑表4-6风速点；之后实现新能源实际脱网状态转移与 `P_wt(E_k)`、传统机组停运与 `P_ge(E_k)`，最后对齐集中式接入节点和完整 IEEE39 参数。
