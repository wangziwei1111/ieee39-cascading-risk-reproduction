# 下一阶段复现路线图

## 阶段 A：补齐原文公式和参数
- 用户输入：第3章公式、表4-1核对、IEEE39 修改参数、第4章场景表。
- 代码修改：建立 paper_config 和 paper_case39 数据层。
- 输出结果：原文参数录入模板和一致性校验表。
- 通过标准：所有 P0 输入项不再为 unknown_need_paper。
- 不可猜测：任何保护参数、接入节点、渗透率定义。

## 阶段 B：实现 P_wt(E_k) 新能源状态概率
- 用户输入：P_WT(h) 公式和新能源保护模型。
- 代码修改：扩展 renewable 状态概率模块。
- 输出结果：wind_state_probability_details.csv。
- 通过标准：stage_probability_details 中包含 P_wt。
- 不可猜测：脱网概率曲线和保护阈值。

## 阶段 C：实现 P_ge(E_k) 传统机组状态概率
- 用户输入：P_G(q) 公式、机组停运概率和保护动作规则。
- 代码修改：新增 conventional outage/state probability 模块。
- 输出结果：generator_state_probability_details.csv。
- 通过标准：stage_probability_details 中包含 P_ge。
- 不可猜测：机组停运概率。

## 阶段 D：把 record_only 新能源脱网升级为实际状态转移
- 用户输入：新能源脱网触发规则、是否随机抽样、恢复规则。
- 代码修改：扩展 Markov 状态集合和 mpc.gen 状态更新。
- 输出结果：wind_trip_state_transition_details.csv。
- 通过标准：风机脱网改变后续潮流且随机序列可复现。
- 不可猜测：脱网触发与恢复规则。

## 阶段 E：实现传统机组停运状态转移
- 用户输入：传统机组停运触发规则。
- 代码修改：扩展 Markov 搜索和 slack 重选逻辑。
- 输出结果：generator_trip_state_transition_details.csv。
- 通过标准：传统机组停运可追溯且不破坏潮流标准化。
- 不可猜测：机组保护动作条件。

## 阶段 F：校准线路后续停运概率模型
- 用户输入：论文线路后续停运概率公式与参数。
- 代码修改：替换 line_outage_probability。
- 输出结果：line_outage_probability_audit.csv。
- 通过标准：候选线路概率与论文公式逐项一致。
- 不可猜测：分段阈值和概率上限。

## 阶段 G：校准切负荷/失负荷模型
- 用户输入：最优切负荷目标函数、约束和参数。
- 代码修改：替换 simple_load_shedding 或引入 OPF/OLS。
- 输出结果：load_shedding_optimization_details.csv。
- 通过标准：C_c(E_k) 与论文定义一致。
- 不可猜测：负荷优先级和惩罚系数。

## 阶段 H：对齐第4章场景
- 用户输入：分散/集中接入、渗透率、风速和样本数设置。
- 代码修改：更新 scenario_library。
- 输出结果：paper_aligned_scenario_batch_summary.csv。
- 通过标准：每个场景参数均可追溯到原文。
- 不可猜测：集中接入节点。

## 阶段 I：对齐第4章结果图表
- 用户输入：原文结果表和图。
- 代码修改：新增 paper_vs_reproduction_comparison。
- 输出结果：paper_result_alignment_table.csv 和对照图。
- 通过标准：逐图逐表说明误差来源。
- 不可猜测：原文图中未读出的数据点。

## 阶段 J：形成论文可用复现实验说明
- 用户输入：最终采用参数和论文写作口径。
- 代码修改：生成最终报告和附录表。
- 输出结果：复现实验方法说明、限制说明和可复现实验包。
- 通过标准：所有结论均可由代码和数据复核。
- 不可猜测：与原文不一致时的解释。

