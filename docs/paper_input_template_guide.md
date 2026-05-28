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

## 已从王威论文 PDF 录入的第一批信息

本轮已在 `paper_inputs/filled/` 中初步录入以下可明确确认的信息：

- `paper_system_summary.csv`：IEEE-10机39节点系统规模、46条线路、10个发电机节点、31节点平衡、总负荷6254.23 MW、总装机7500 MW。
- `paper_case39_bus.csv`、`paper_case39_gen.csv`、`paper_case39_branch.csv`：保留 MATPOWER case39 参考结构；`source_note` 明确说明 PDF 未提供完整 bus/gen/branch 数值表，不能视为原文已确认逐项参数。
- `paper_line_initial_outage_probability.csv`：由已录入的论文表4-1数据标准化复制，单位为 `*10^-4`。
- `paper_wind_power_curve.csv`：录入论文第2.3节式(2-2)和第4.1节风机参数 `v_in=2 m/s`、`v_r=12 m/s`、`v_out=20 m/s`。
- `paper_line_subsequent_outage_model.csv`：录入第3.1.1节线路后续停运概率公式结构；具体概率参数仍留空。
- `paper_generator_outage_model.csv`：录入第3.1.2节传统机组频率/电压保护停运模型结构；阈值和概率参数仍留空。
- `paper_wind_trip_probability_model.csv`：录入 LVRT/HVRT/FRT 区间规则；具体概率函数参数仍需人工确认。
- `paper_state_probability_formula.csv`：录入 P_wt、P_ge、P_line、P_stage 公式；P_chain 公式仍缺失，因此文件保持 incomplete。
- `paper_risk_severity_formula.csv`：录入 LLR、LFOR、NVOR、CRI、VaR 公式，后续仍需人工核对公式编号。
- `paper_load_shedding_model.csv`：录入第3.2.3节最优负荷削减目标和约束结构；数值参数仍留空。
- `paper_scenario_definition.csv`：录入第4章已明确的基础、分散式3000MW、渗透率40%-80%等场景信息；集中式接入节点保持 missing。
- `paper_result_benchmark.csv`：录入表4-4和表4-5中当前可确认的数据；80%渗透率行因 OCR 片段不完整保留空值并标记 needs_manual_check。

当前校验状态中，公式结构已录入但参数缺失的文件会保持 `incomplete`。这不是错误，而是为了防止把工程近似参数冒充为原文参数。
## 已补录的论文 benchmark 表

本轮继续只补录论文原文 benchmark，不写入任何当前工程复现结果：

- 表4-2：是否考虑新能源发电机组脱网的综合风险评估指标对比，包含两个场景、四个指标，置信水平为 0.95。
- 表4-4：集中式/分散式接入对比，包含集中式、分散式两个场景，在 0.90、0.95、0.98 三个置信水平下的 SLLR、SLFOR、SNVOR、CRI。
- 表4-5：新能源渗透率 40% 至 80% 的综合风险评估指标对比，已补齐 80% 行：SLLR=14.0526、SLFOR=12.5517、SNVOR=11.8034、CRI=13.3026。
- 表4-6：风速波动结果，已录入 11.28、11.52、11.76、12.00 m/s 四个风速点。

所有风险 benchmark 数值单位均为 `10^-4`。这些数据是论文原文 benchmark，用于后续对齐审计和结果对比，不代表当前复现工程已经达到这些数值。
