# 论文严重度变量映射表

| paper_variable | meaning | required_for | current_source_file | current_column_or_field | available_now | action_needed |
|---|---|---|---|---|---|---|
| `E_k` | 事故链第 k 级系统状态 | LLR/LFOR/NVOR/P_stage | `results/chains/markov_chain_records.mat` | `stage_records(stage_id)` | true | 当前通过已停运线路集合回放准静态潮流，暂非暂态仿真状态 |
| `K` | 单条事故链级数 | LLR/LFOR/NVOR | `results/tables/markov_chain_summary.csv` | `chain_depth` | true | 无 |
| `C_c(E_k)` | 状态 E_k 下负荷损失 | LLR | `results/tables/markov_stage_probability_details.csv` | `stage_load_shed_mw` | true | 当前来自简化切负荷和孤岛切除，后续替换为最优负荷削减 |
| `P_load` | 系统基准总负荷 | LLR | `results/tables/markov_stage_probability_details.csv` | `base_load_mw` | true | 无 |
| `sev_ev_llr(E_k)` | 第 k 级负荷损失严重度 | LLR | 代码计算 | `stage_load_shed_mw/base_load_mw*100` | true | 无 |
| `P_wt(E_k)` | 新能源机组集合状态概率 | state probability | 当前配置 | 固定为 1 | true | line-only近似；完整版本需接入风机实际脱网状态概率 |
| `P_ge(E_k)` | 传统机组集合状态概率 | state probability | 当前配置 | 固定为 1 | true | line-only近似；完整版本需接入传统机组停运概率 |
| `P_line(E_k)` | 输电线路集合状态概率 | state probability | `results/tables/markov_stage_probability_details.csv` | `stage_cumulative_probability` | true | 当前用初始概率乘候选转移概率近似 |
| `P_initial` | 初始线路故障概率 | state probability | `data/line_initial_outage_probability_paper_table_4_1.csv` | `initial_outage_probability` | true | 若切换uniform，则为 `1/46` |
| `P_trans(k)` | 第 k 级候选线路条件转移概率 | state probability | `results/tables/markov_candidate_details.csv` 和 chunks | `outage_probability`, `trip_selected` | true | 当前由候选抽样明细重算并写入stage_probability表 |
| `R_LLR` | 单条事故链负荷损失风险值 | VaR SLLR | `results/tables/markov_risk_samples_paper_severity.csv` | `paper_LLR` | true | 当前为line-only概率近似 |
| `P_li(n)` | 第 n 条线路有功功率标幺值 | LFOR | full CSV + `markov_line_flow_details_manifest.csv` + `results/tables/paper_detail_chunks/markov_line_flow_details_part*.csv` | `P_li_pu` | true | chunks 是稳定复核依据；基于 `max(abs(PF),abs(PT))/RATE_A` |
| `P_li_max(n)` | 第 n 条线路最大有功功率标幺值 | LFOR | full CSV + `markov_line_flow_details_manifest.csv` + `results/tables/paper_detail_chunks/markov_line_flow_details_part*.csv` | `P_li_max_pu` | true | 当前设为1；`RATE_A`作为有功上限近似，待校准 |
| `sev_ev_lfor(E_k)` | 第 k 级线路越限严重度 | LFOR | full CSV + `markov_line_flow_details_manifest.csv` + `results/tables/paper_detail_chunks/markov_line_flow_details_part*.csv` | `line_severity_component` 按stage求和 | true | chunks 是稳定复核依据 |
| `R_LFOR` | 单条事故链线路越限风险值 | VaR SLFOR | `results/tables/markov_risk_samples_paper_severity.csv` | `paper_LFOR` | true | 当前为line-only概率近似 |
| `U_m` | 第 m 个节点电压标幺值 | NVOR | full CSV + `markov_bus_voltage_details_manifest.csv` + `results/tables/paper_detail_chunks/markov_bus_voltage_details_part*.csv` | `voltage_pu` | true | chunks 是稳定复核依据 |
| `sev_ev_nvor(E_k)` | 第 k 级节点电压越限严重度 | NVOR | full CSV + `markov_bus_voltage_details_manifest.csv` + `results/tables/paper_detail_chunks/markov_bus_voltage_details_part*.csv` | `voltage_severity_component` 按stage求和 | true | chunks 是稳定复核依据 |
| `R_NVOR` | 单条事故链节点电压越限风险值 | VaR SNVOR | `results/tables/markov_risk_samples_paper_severity.csv` | `paper_NVOR` | true | 当前为line-only概率近似 |
| `R_SLLR` | 负荷损失VaR风险指标 | VaR | `results/tables/markov_var_metrics_paper_severity.csv` | `SLLR` | true | 使用经验右尾分位数 |
| `R_SLFOR` | 线路越限VaR风险指标 | VaR | `results/tables/markov_var_metrics_paper_severity.csv` | `SLFOR` | true | 使用经验右尾分位数 |
| `R_SNVOR` | 电压越限VaR风险指标 | VaR | `results/tables/markov_var_metrics_paper_severity.csv` | `SNVOR` | true | 使用经验右尾分位数 |
| `CRI` | 综合风险指标 | CRI | `results/tables/markov_var_metrics_paper_severity.csv` | `CRI` | true | 当前权重为0.6/0.2/0.2 |
