# 继续完整复现所需原文资料清单

## P0：必须优先提供

1. 论文第3章风险评估模型完整公式截图。
2. P_wt(E_k)、P_ge(E_k)、P_line(E_k) 的完整变量定义。
3. 线路后续停运概率模型公式和参数。
4. 新能源机组脱网概率或保护动作模型。
5. 传统机组停运概率或保护动作模型。
6. 论文第4章 IEEE39 算例修改参数。
7. 原文第4章场景定义表。
8. 原文第4章主要结果表或图。

## P1：次优先级

1. 风电功率曲线参数。
2. 分散式接入节点。
3. 集中式接入节点。
4. 渗透率定义。
5. 风速扫描点。
6. 仿真样本数。
7. 置信水平。
8. 线路容量设置。
9. 切负荷模型或失负荷计算方法。

## P2：后续优化

1. 原文绘图样式。
2. 原文结果图数据点。
3. 论文中各类参数的单位说明。
4. 若有，附录中的 IEEE39 修改算例。

## 禁止自动补值

缺失资料不得用 uniform、平均值或经验猜测替代。paper_table_4_1、接入节点、保护参数和严重度函数均必须来自用户提供的原文资料或明确的人工确认。

## 对应模板文件

后续请将原文资料复制或人工录入到 `paper_inputs/filled/`，不要直接修改 `templates/`。

| 原文资料 | 对应模板 |
|---|---|
| 第3章风险状态概率公式 | `paper_state_probability_formula_template.csv` |
| LLR/LFOR/NVOR/CRI/VaR 严重度公式 | `paper_risk_severity_formula_template.csv` |
| 线路后续停运概率模型 | `paper_line_subsequent_outage_model_template.csv` |
| 新能源脱网模型 P_WT(h) | `paper_wind_trip_probability_model_template.csv` |
| 传统机组停运模型 P_G(q) | `paper_generator_outage_model_template.csv` |
| IEEE39 节点负荷和电压参数 | `paper_case39_bus_template.csv` |
| IEEE39 发电机参数 | `paper_case39_gen_template.csv` |
| IEEE39 线路参数和容量 | `paper_case39_branch_template.csv` |
| 表4-1线路初始停运概率 | `paper_line_initial_outage_probability_template.csv` |
| 第4章场景定义 | `paper_scenario_definition_template.csv` |
| 第4章结果表或图 | `paper_result_benchmark_template.csv` |
| 切负荷/失负荷模型 | `paper_load_shedding_model_template.csv` |

校验入口：

```matlab
main_validate_paper_inputs
main_update_alignment_audit_from_paper_inputs
main_check_paper_input_templates
```
