# 复现阶段性总审计报告

## 1. 当前复现阶段结论

当前工程已经形成论文复现骨架：paper inputs、paper benchmark、scenario comparison、P_L/P_wt/P_ge diagnostic、unified composite probability、stage-level severity 均已建立。

明确结论：不能声称严格复现。当前结果适合用于复现流程骨架、差距审计、敏感性分析和后续校准准备；不适合作为论文表4-2/4-4/4-5/4-6的严格数值复现。

## 2. 已完成内容

- Paper input data layer: implemented_diagnostic
- Paper benchmark tables: benchmark_ready
- Initial line outage probability Table 4-1: implemented_but_not_calibrated
- Topology comparison scenarios: implemented_engineering
- Penetration scan scenarios: implemented_engineering
- Engineering wind speed scan: implemented_engineering
- Paper Table 4-6 wind speed smoke: implemented_diagnostic
- Optimal load shedding OLS: implemented_diagnostic
- Line subsequent outage probability P_L: implemented_but_not_calibrated
- Wind trip probability P_wt: implemented_diagnostic
- Generator outage probability P_ge: implemented_diagnostic
- Composite state probability: implemented_diagnostic
- Stage-level severity: implemented_diagnostic
- Paper benchmark alignment: implemented_diagnostic

## 3. benchmark 录入情况

Table 4-2、Table 4-4、Table 4-5、Table 4-6 benchmark 已录入并用于对照。它们是论文原文 benchmark 输入，不是当前工程复现成功的证据。

## 4. 当前工程结果与论文 benchmark 的关系

当前 benchmark alignment 只能作为谨慎对照。模型中仍包含 engineering 或 diagnostic 假设，单位尺度、概率模型、状态转移和若干场景参数尚未完全统一。

## 5. OLS 诊断结论

OLS 已测试 positive-injection free_q、fixed_zero_q、dispatchable_load、DC preshed + AC polish 等变体。当前不建议用 OLS 替代 simple_load_shedding 进行正式 20-trial benchmark，除非获得原文 AC/DC 选择、求解器设置、约束边界和触发规则，并显著降低失败率。

## 6. P_L/P_wt/P_ge/composite probability 诊断结论

P_L、P_wt、P_ge 均已形成 diagnostic 框架。P_L 参数敏感性说明线路概率对结果影响显著；P_wt/P_ge 应激测试说明计算链路有效；unified composite smoke 已能在同一次 Markov stage 记录 P_line、P_wt、P_ge、P_total。

当前 unified smoke 中 P_wt=1 且 P_ge=1，因此 P_total 退化为 P_line。这是因为当前小样本未触发风机或传统机组风险区，不代表这些分量在原文模型中无影响。

## 7. stage-level severity 结论

stage-level severity 已接入 unified smoke，并生成 P_total × severity 的 diagnostic risk preview。该 preview 比旧 chain-summary repeated 版本更严谨，但仍不是正式 VaR，也没有进入 final_summary。

## 8. 当前不能声称的内容

- 已经严格复现论文表4-2/4-4/4-5/4-6：current results use engineering/diagnostic parameters and incomplete state transitions。需要：original parameters and formal benchmark reruns。
- OLS 已经替代 simple_load_shedding：OLS remains diagnostic and unstable for formal benchmark。需要：confirmed AC/DC OLS settings and acceptable failure rate。
- P_L 已按原文参数校准：P_L parameter sets are diagnostic-only。需要：paper-extracted or calibrated original P_L parameters。
- P_wt 已按原文概率函数实现：P_WT full probability function is missing。需要：paper P_WT function and transition rule。
- P_ge 已按原文概率函数实现：P_G thresholds/probabilities and dynamic frequency are missing。需要：paper P_G parameters and transition rule。
- 综合状态概率已经进入正式 paper_formula：composite probability is offline/unified diagnostic only。需要：formal integration after all component calibration。
- 当前结果可直接作为论文数值对照：unit/model/parameter bases are not aligned。需要：calibrated reruns and unit alignment。
- 当前静态潮流频率可代表真实动态频率：static power flow uses nominal 50 Hz only。需要：dynamic frequency model or paper-defined frequency approximation。
- diagnostic 参数集就是论文原文参数：diagnostic assumptions are placeholders。需要：user-confirmed original parameters。

## 9. 仍缺原文输入

需要用户提供的原文参数清单包括：

- line_P_L：P_L0 是否应等于表4-1或另有基础概率。
- line_P_L：L_Rated。
- line_P_L：L_max。
- line_P_L：P_W_D。
- line_P_L：Z_III。
- line_P_L：P_L_D。
- line_P_L：P_L_r。
- wind_P_wt：P_WT(h) 完整概率函数。
- wind_P_wt：LVRT/HVRT 持续时间到概率的映射。
- wind_P_wt：FRT 频率区间持续时间到概率的映射。
- wind_P_wt：实际风机脱网状态转移抽样规则。
- generator_P_ge：P_G_f0。
- generator_P_ge：P_G_U0。
- generator_P_ge：频率阈值。
- generator_P_ge：电压阈值。
- generator_P_ge：分段线性概率参数。
- generator_P_ge：传统机组实际停运状态转移抽样规则。
- scenario：集中式接入节点。
- scenario：渗透率定义。
- scenario：原文样本数或蒙特卡洛抽样次数。
- scenario：原始 IEEE39 修改数据。
- scenario：风电容量分配方式。

## 10. 推荐下一步路线

1. 向用户索要或从 PDF 精读提取第3.1.1、3.1.2、3.1.3完整参数。Go/No-Go：parameters are readable and mapped to template fields。
2. 建立 original_paper_extracted 参数集。Go/No-Go：all P0 probability parameters resolved。
3. 用 original_paper_extracted 参数集重跑 unified diagnostic smoke。Go/No-Go：fallback/missing count is zero or explicitly justified。
4. 选择一个最小正式 benchmark 场景做 20-trial diagnostic rerun。Go/No-Go：stable and interpretable against paper benchmark。
5. 扩展到 Table 4-6 风速点。Go/No-Go：errors explainable and no diagnostic_only status。
6. 扩展到 Table 4-5 渗透率扫描。Go/No-Go：definition matches paper and parameters calibrated。
7. 最后才考虑 OLS 正式化。Go/No-Go：failure rate acceptable and paper settings confirmed。
8. 如仍无法获得参数，转向“复现骨架 + 敏感性分析”写法。Go/No-Go：all diagnostic assumptions clearly labeled。

## 11. 给用户的明确问题清单

请用户优先提供或确认：

- 论文第3.1.1节线路停运概率模型中各参数数值；
- 论文第3.1.2节传统机组频率/电压保护概率参数；
- 论文第3.1.3节新能源机组脱网概率函数；
- 集中式接入节点；
- 原文样本数或蒙特卡洛抽样次数；
- 原始 IEEE39 数据是否为 MATPOWER case39 或经过修改；
- OLS 是 AC 还是 DC，以及求解器约束设置。

## 12. 缺失统计参数的反向校准策略

当前路线调整为：公式结构按原文固化，公开参数固定，未公开的继电保护、断路器和隐性故障统计参数进入 benchmark calibration 框架。

这些反向校准参数不得写成 `original_paper_extracted`，只能标记为 `benchmark_calibrated_not_original_paper` 或 `diagnostic_assumption_not_paper`。校准目标是使趋势和量级接近原文 benchmark，而不是追求完全相同，也不能据此声称严格复现。

新增校准框架输出包括：

- `paper_inputs/filled/public_fixed_parameters.csv`
- `paper_inputs/filled/missing_calibrated_parameters_register.csv`
- `paper_inputs/filled/benchmark_calibration_parameter_sets.csv`
- `paper_inputs/filled/calibration_target_benchmark.csv`
- `results/calibration/pilot/calibration_pilot_score_summary.csv`
- `results/calibration/local_search_plan.csv`

## 输入文件可用性

- `paper_inputs/validated/paper_input_validation_summary.csv`: available
- `paper_inputs/validated/paper_result_benchmark_summary.csv`: available
- `results/paper_alignment/tables/paper_vs_reproduction_comparison.csv`: available
- `results/paper_alignment/tables/paper_alignment_gap_diagnosis.csv`: available
- `results/loadshedding/ols_benchmark_smoke/tables/ols_formulation_comparison.csv`: available
- `results/outage/line_probability_parameter_smoke_summary.csv`: available
- `results/renewable/wind_state_probability_model_check_log.txt`: available
- `results/generator/generator_state_probability_model_check_log.txt`: available
- `results/composite/unified_state_probability_diagnostic_check_log.txt`: available
- `results/composite/unified_stage_level_risk_preview.csv`: available
- `results/composite/stage_level_vs_chain_summary_risk_preview_comparison.csv`: available

## 当前可用结果索引

- `paper_inputs/filled/paper_result_benchmark.csv`: Original paper benchmark values entered from paper。用途：paper benchmark comparison。注意：manual final verification still required。
- `results/paper_alignment/tables/paper_vs_reproduction_comparison.csv`: paper vs current reproduction comparison。用途：gap diagnosis and cautious comparison。注意：not strict numeric reproduction。
- `results/paper_alignment/tables/table46_wind_speed_paper_vs_reproduction.csv`: Table 4-6 wind-speed comparison。用途：paper Table 4-6 diagnostic comparison。注意：line-only and uncalibrated。
- `results/loadshedding/ols_benchmark_smoke/tables/ols_benchmark_smoke_summary.csv`: simple vs OLS smoke summary。用途：OLS directionality study。注意：5-trial smoke only, high failure rates。
- `docs/ols_stage_conclusion.md`: OLS staged conclusion。用途：methodology write-up。注意：OLS not ready for formal benchmark。
- `results/outage/line_probability_parameter_smoke_summary.csv`: P_L diagnostic parameter-set smoke summary。用途：sensitivity analysis。注意：diagnostic assumptions only。
- `results/renewable/wind_state_probability_effect_summary.csv`: P_wt effect summary。用途：wind probability diagnostic。注意：current Markov smoke has P_wt=1。
- `results/generator/generator_state_probability_effect_summary.csv`: P_ge effect summary。用途：generator probability diagnostic。注意：static frequency and P_ge=1 in smoke。
- `results/composite/unified_state_probability_diagnostic_smoke/unified_state_probability_stage_details.csv`: same-run P_line/P_wt/P_ge/P_total stage table。用途：primary composite diagnostic。注意：diagnostic only。
- `results/composite/unified_state_probability_diagnostic_smoke/stage_severity_details.csv`: same-run stage severity detail。用途：stage-level risk preview。注意：not formal VaR。
- `results/composite/unified_stage_level_risk_preview.csv`: P_total times stage severity preview。用途：diagnostic risk preview。注意：not final benchmark。
