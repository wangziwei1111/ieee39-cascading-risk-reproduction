# paper_inputs 原文参数录入模板指南

`paper_inputs/` 是后续录入原文学位论文公式、参数、场景和结果表的数据层。本阶段只建立模板和校验框架，不填任何未知原文数据。

目录含义：

- `paper_inputs/templates/`：空模板或 MATPOWER case39 参考结构，不代表原文参数已确认。
- `paper_inputs/filled/`：用户根据论文截图或表格手动填写后的文件。
- `paper_inputs/validated/`：校验通过后的标准化汇总。
- `paper_inputs/logs/`：模板生成和校验日志。

## 模板用途

| 模板文件 | 用途 | 推荐来源 |
|---|---|---|
| `paper_case39_bus_template.csv` | 录入原文 IEEE39 节点负荷、电压上下限等 | 第4章算例表或附录 |
| `paper_case39_gen_template.csv` | 录入机组参数、平衡机、传统机组容量上下限 | 第4章算例表或附录 |
| `paper_case39_branch_template.csv` | 录入线路参数和容量，后续用于 LFOR | 第4章线路参数表 |
| `paper_line_initial_outage_probability_template.csv` | 录入表4-1线路初始停运概率 | 表4-1 |
| `paper_line_subsequent_outage_model_template.csv` | 录入线路后续停运概率模型 | 第3章线路停运概率公式 |
| `paper_wind_trip_probability_model_template.csv` | 录入新能源机组脱网概率 P_WT(h) 或保护动作概率 | 第3章新能源脱网模型 |
| `paper_generator_outage_model_template.csv` | 录入传统机组停运概率 P_G(q) | 第3章传统机组模型 |
| `paper_state_probability_formula_template.csv` | 录入 P_wt、P_ge、P_line、P_stage、P_chain 公式 | 第3章状态概率公式 |
| `paper_risk_severity_formula_template.csv` | 录入 LLR、LFOR、NVOR、CRI、VaR 公式 | 第3章风险严重度和 VaR 公式 |
| `paper_scenario_definition_template.csv` | 录入第4章场景定义 | 第4章场景表 |
| `paper_result_benchmark_template.csv` | 录入第4章图表中的原文数值 | 第4章结果表或曲线 |
| `paper_load_shedding_model_template.csv` | 录入切负荷/失负荷模型 | 第3章或第4章相关公式 |

## 填写方式

1. 不要直接修改 `templates/`，请复制到 `paper_inputs/filled/` 后填写。
2. 文件名去掉 `_template`，例如：
   - 模板：`paper_inputs/templates/paper_state_probability_formula_template.csv`
   - 填写：`paper_inputs/filled/paper_state_probability_formula.csv`
3. 截图中的公式可人工录入到 `formula_text`。
4. 表格中的参数必须逐项录入 `parameter_name`、`parameter_value`、`unit` 和 `source_equation`。
5. 读不清或论文未给出的字段保持空白，不要猜。

## 禁止事项

- 不要把当前工程近似参数当作原文参数。
- 不要把空模板标记为 complete。
- 不要用 uniform、平均值或经验阈值补齐缺失参数。
- 不要把集中式接入节点、渗透率定义、风电功率曲线参数写成“已确认”，除非原文明确给出。

## 校验命令

填写后运行：

```matlab
main_validate_paper_inputs
main_update_alignment_audit_from_paper_inputs
main_check_paper_input_templates
```

校验结果：

- `paper_inputs/validated/paper_input_validation_summary.csv`
- `results/final_summary/tables/original_paper_gap_audit_with_input_status.csv`

只有当相关输入状态为 `complete` 或 `validated`，后续才应进入模型实现阶段。
