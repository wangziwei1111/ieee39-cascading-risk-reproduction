# 最小复现实验说明

## 第4章场景扫描框架

已新增独立的场景扫描框架。场景结果不再写入全局 `results/tables`、`results/logs` 或 `results/chains`，而是写入：

```text
results/scenarios/<scenario_id>/
  config/
  tables/
  logs/
  chains/
  figures/
```

每个场景会保存 `scenario_used.mat/json/csv` 和 `cfg_used.mat/csv`，用于复核本次实际使用的风电接入节点、容量、风速、调度模式和输出目录。

当前 smoke batch 只运行：

- `no_renewable_base`
- `distributed_wind_40pct`
- `centralized_wind_40pct`

smoke batch 将 `markov_num_trials_per_initial_fault` 临时设为 5，只用于检查场景框架、输出隔离和自检逻辑，不是最终论文结果。完整批量入口 `main_run_scenario_batch_full.m` 已创建，但不会默认运行。

当前集中式接入节点暂取 39 节点，渗透率按“风电装机容量 / 系统总负荷”换算，风速扫描点取 8/10/12/14/16 m/s。这些均为待校准设置，不能声称来自论文原始参数。新能源脱网对比场景目前只记录风机电压脱网概率，尚未实际触发风机脱网；paper_formula 仍为 line-only 版本，完整论文复现还需要接入 `P_wt(E_k)` 和 `P_ge(E_k)`。

## 场景扫描结果状态说明

场景汇总表现在区分程序运行状态和指标有效性：

- `run_status`：只表示场景流程是否完整跑完，可为 `success` 或 `failed`。
- `basic_result_status`：表示 basic VaR 是否可用，可为 `valid` 或 `failed`。
- `weighted_result_status`：表示表4-1加权 basic VaR 是否可用，可为 `valid` 或 `failed`。
- `paper_result_status`：表示 paper_formula VaR 是否可用于论文对照，可为 `valid`、`diagnostic_only`、`failed`、`not_available`。
- `overall_status`：综合状态，可为 `success_all_valid`、`success_with_diagnostic_paper` 或 `failed`。

`diagnostic_only` 表示场景程序运行成功，但 paper_formula 因无效阶段比例过高等原因不能作为有效论文对照。此时 `paper_CRI_095` 允许为 `NaN`，但 `overall_status` 必须为 `success_with_diagnostic_paper`，不能标记为 `success_all_valid`。smoke test 仍然只是框架检查结果；只有状态体系正确后，后续才适合运行 full batch。

## full batch 分组运行与断点续跑

完整第4章场景扫描不建议一次性运行。当前已新增通用入口 `main_run_scenario_batch(batch_mode, run_options)`，支持以下 `batch_mode`：

- `smoke`：无新能源、分散式40%、集中式40%。
- `topology_compare`：无新能源、分散式40%、集中式40%，用于接入方式对比。
- `penetration_scan`：分散式40%到80%渗透率扫描。
- `wind_speed_scan`：8/10/12/14/16 m/s风速扫描。
- `renewable_trip_record`：分散式40%与“仅记录新能源脱网概率”对比。
- `all_full`：全部场景。

`resume_existing=true` 时，如果场景目录已经包含完整结果并通过 `check_single_scenario_complete`，批处理会跳过该场景并在汇总表中写入 `execution_status=skipped_existing`。`force_rerun=true` 时会重新运行场景；它不能与 `resume_existing=true` 同时启用。

`diagnostic_only` 可以表示场景运行完整，因此断点续跑允许跳过这类场景；但它只代表 paper_formula 结果可用于诊断，不能作为有效论文对照。推荐运行顺序为：`smoke`、`topology_compare`、`penetration_scan`、`wind_speed_scan`、`renewable_trip_record`，最后在确认各组状态后再运行 `all_full`。

## 渗透率扫描与样本数一致性

smoke test 使用 `cfg.scenario_smoke_trials_per_initial_fault=5`，只用于快速检查流程。`penetration_scan` 使用 `cfg.markov_num_trials_per_initial_fault`，当前为 20。断点续跑时，`check_single_scenario_complete` 会同时检查已有场景的 `markov_num_trials_per_initial_fault` 是否等于当前批次期望值。

如果已有结果来自 5-trial smoke，而当前批次期望 20-trial，则该场景会被判定为 `incomplete_trial_count_mismatch`，不会被 `skipped_existing` 复用，必须重新运行。这样可以避免把 5-trial 的 `distributed_wind_40pct` 混入 20-trial 的 40%–80%渗透率曲线。当前渗透率仍按 `wind_capacity/base_load` 定义，属于待校准设置。

## 3000MW基准场景与渗透率扫描场景的区分

`distributed_wind_3000mw_base` 是当前工程的3000 MW分散式风电基准场景，用于 smoke、topology_compare 和基准复现。它不代表按 `base_load` 定义的40%渗透率点。

`distributed_wind_penetration_40pct` 是渗透率扫描中的40%点，其容量按 `0.40 * base_load_mw` 计算。后续 45% 到 80% 点也统一使用 `ratio * base_load_mw`。旧的 `distributed_wind_40pct` 仅保留为 legacy alias，指向3000 MW基准场景，不再用于 `penetration_scan`。

`penetration_scan` 自检会强制检查场景名必须为 `distributed_wind_penetration_*pct`，容量必须随渗透率单调递增，并且不得包含 legacy `distributed_wind_40pct`。当前渗透率定义仍待论文原文确认。

## 风速扫描与实际风电出力

`wind_speed_scan` 中风电装机容量固定为 3000 MW，扫描点为 8、10、12、14、16 m/s。实际风电出力不是装机容量本身，而是由 `wind_power_curve` 根据风速计算得到。

本轮已将 `total_wind_output_mw`、`wind_capacity_factor`、`basecase_slack_pg_mw`、`basecase_overloaded_line_count`、`basecase_voltage_violation_count` 写入场景 batch summary 和 result summary。当前结果显示 8 m/s、10 m/s、12 m/s 的实际出力逐步增加，12 m/s 及以上进入额定出力平台。

这些风速点仍属于工程扫描设置，待与论文参数进一步校准。`smoke`、`penetration_scan`、`wind_speed_scan` 的结果用途不同，不能混用或互相替代。

## 当前已实现内容

- 使用 MATLAB + MATPOWER 的 `case39` 作为 IEEE 10机39节点基础系统。
- 新增基础运行点校验脚本 `src/main_validate_basecase.m`，在无故障状态下检查新能源场景是否潮流收敛、机组PG是否越限、基础线路和节点电压是否越限。
- 枚举 46 条输电线路作为初始 N-1 开断故障。
- 对每个 N-1 故障运行 MATPOWER AC 潮流。
- 检查线路潮流越限和节点电压越限。
- 实现风电机组有功出力曲线。
- 实现风机电压穿越失败脱网概率模型。
- 新能源接入支持两种模式：`replace_pg_current` 和 `wind_plus_redispatch`。默认使用 `wind_plus_redispatch`。
- 实现简化按比例负荷削减，用于潮流不收敛后的校正尝试。
- 输出每个故障的负荷损失、越限数量、最大越限程度、风机电压脱网概率、简化 SLLR/SLFOR/SNVOR/CRI。
- 固定随机数种子，保证后续加入抽样时可重复。

## 基础运行点校验

在进入马尔可夫事故链搜索之前，必须先校验无故障基础运行点。原因是连锁故障风险评估的后续结果依赖初始潮流状态；如果基础状态已经存在机组PG越限、线路越限或节点电压越限，那么后续N-1结果会混入基础工况本身的不合理性，不能直接解释为故障造成的风险。

当前基础运行点校验脚本为：

```matlab
main_validate_basecase
```

该脚本输出：

- `results/tables/basecase_validation.csv`
- `results/logs/basecase_validation_log.txt`

校验内容包括：系统总负荷、总发电、总风电出力、平衡机出力、机组PG上下限、基础线路越限、基础节点电压越限。

第一版 `replace_pg_current` 只是将节点30-39的现有机组PG直接替换为300 MW风电出力。这种做法可以快速跑通流程，但物理意义较弱：它没有同步考虑常规机组再调度，也没有保证基础运行点与原始负荷/发电平衡关系一致。因此，不能直接拿 `replace_pg_current` 的数值结果和论文表格做对比。

当前默认模式改为 `wind_plus_redispatch`：将风电作为新增注入接入指定节点，同时按可下调裕度比例降低非平衡常规机组出力，并保留节点31常规机组作为平衡机。该方式仍是简化调度，但比直接替换PG更适合作为后续事故链搜索的基础运行点。

后续论文对照版将优先使用 `wind_plus_redispatch`，并进一步扩展为更严格的 OPF 调度：在满足发电机上下限、线路容量和节点电压约束的同时，确定新能源接入后的合理基础潮流点。

## 故障后孤岛识别与状态标准化

IEEE 39 节点系统中，部分发电机节点通过单回接入支路连接到主网。例如 2-30、6-31、10-32、19-33、20-34、22-35、23-36、25-37、29-38 等线路一旦作为 N-1 初始故障开断，相关发电机节点或局部区域会与主网形成电气孤岛。此时 MATPOWER AC 潮流可能出现不收敛或雅可比矩阵奇异，其原因不是普通线路过载或负荷过重，而是网络拓扑已经解列。

单纯按比例切负荷不能代表孤岛处理。比例切负荷假设系统仍然是一个连通网络，只是负荷水平过高或潮流状态不易收敛；而孤岛问题首先需要判断哪些母线、负荷和机组已经与主网断开。若不先处理拓扑解列，切负荷会把孤岛造成的停电和连通系统内的校正控制混在一起，后续事故链概率和风险指标也会失去物理含义。

当前新增的标准化流程为：

```matlab
normalize_case_after_contingency
```

该流程在每条 N-1 故障后、潮流计算前执行：

- 使用 `detect_islands` 根据在线线路 `branch(:,11)>0` 识别电气连通分量。
- 使用 `select_main_island` 选择主岛。
- 将非主岛负荷 `Pd/Qd` 置零。
- 将非主岛在线机组 `GEN_STATUS` 置零。
- 将非主岛相关线路 `BR_STATUS` 置零。
- 使用 `ensure_slack_bus` 保证主岛内有且只有一个平衡节点。
- 记录孤岛切除负荷、切除发电、切除风电和新平衡节点。

主岛选择规则如下：

1. 优先选择包含原平衡节点、且同时具备有效负荷和在线发电能力的岛。
2. 如果原平衡节点所在岛没有有效负荷或发电能力，则选择总负荷最大的岛。
3. 如果没有有效负荷，则选择在线发电容量最大的岛。
4. 若仍无法判断，则选择母线数量最多的岛作为退化处理。

平衡节点处理规则如下：

- 若原平衡节点仍在主岛且有在线机组，则保留原平衡节点。
- 若原平衡节点不在主岛，则优先选择主岛内在线常规机组作为新的平衡节点。
- 只有当主岛内没有在线常规机组时，才退化选择在线风电机组作为平衡节点。
- 非主岛母线设置为 `NONE` 类型，不参与后续潮流求解。

当前方法仍是准静态处理，不是完整暂态解列仿真。它不模拟保护动作时序、频率动态、机组低频/高频脱网、低压穿越持续时间或孤岛内部动态稳定性。它的目的只是把故障后的拓扑状态整理成可进入静态潮流和后续事故链搜索的标准系统状态。

后续马尔可夫事故链搜索将以 `normalize_case_after_contingency` 输出的标准化系统作为每一级状态的输入。这样每一级故障后都先处理拓扑解列，再计算潮流、越限、脱网概率和风险指标。

孤岛诊断结果输出到：

- `results/tables/island_diagnostics.csv`
- `results/logs/island_diagnostics_log.txt`

## 主岛选择规则修正

初版主岛选择规则曾经无条件优先保留包含原平衡节点的孤岛。这在普通支路故障下通常可运行，但在发电机接入支路开断时会出现明显误判。例如线路 6-31 开断后，31 节点平衡机可能形成一个很小的发电机孤岛，而包含绝大部分负荷和网络结构的是另一个主网岛。如果机械保留原平衡节点孤岛，就会把主网负荷错误切除，导致 `disconnected_load_mw` 接近全系统负荷，污染 N-1 风险评估和后续事故链搜索。

当前规则已改为“最大负荷主网优先，原平衡节点只作为加分项”。具体做法是：

- 每个孤岛计算 `load_share = total_load_mw / total_system_load_mw` 和 `gen_share = online_generation_mw / total_system_online_generation_mw`。
- 原平衡节点所在岛只有在同时具备有效负荷、有效发电能力，并且 `load_share >= cfg.main_island_min_load_share` 时，才优先保留。
- `cfg.main_island_min_load_share` 当前设为 `0.5`，标注为待校准。
- 如果原平衡节点所在岛负荷占比很小，则认为它可能只是孤立发电机岛，此时选择有负荷、有在线发电能力且 `load_share` 最大的主网岛。
- 如果多个岛负荷接近，则优先选择在线常规机组容量更大的岛，便于后续设置平衡节点。
- 如果仍无法判断，则选择母线数最多的岛作为退化规则。

原平衡节点不能作为绝对优先项，原因是平衡节点是潮流计算参考节点，不等同于故障后必须保留的物理主网。故障导致原平衡机解列时，更合理的准静态处理是保留承载主要负荷和网络结构的主网，并在主网内重新选择在线常规机组作为新的平衡节点。

修正后，6-31 开断会选择主网岛作为主岛，原 31 节点小岛被切除，并在主网中重新选择平衡节点。该结果不是硬编码，而是由 `load_share` 和在线发电约束自然得到。

后续马尔可夫事故链搜索将基于修正后的主岛标准化结果展开。每一级事故发生后都先进行孤岛识别、主岛选择、非主岛切除和平衡节点重设，再进入潮流计算与停运概率更新。

## 第二阶段：线路停运概率与马尔可夫事故链搜索

当前已新增独立入口：

```matlab
main_run_markov_line
```

该入口实现线路停运概率驱动的最小马尔可夫事故链搜索。流程为：枚举每条线路作为初始 N-1 故障；对每个初始故障运行若干次蒙特卡洛样本；每一级事故后先执行孤岛识别与状态标准化，再运行 AC 潮流；根据线路当前负载率计算后续线路停运概率；通过随机数抽样决定下一阶段新增停运线路；直到无新增停运、达到最大深度、负荷损失超过阈值或潮流不收敛。

当前只考虑线路后续停运。传统机组停运、风机实际脱网、频率脱网仍未触发：风机电压穿越概率仍仅用于记录，系统频率固定为 50 Hz。这样做是为了先把“线路概率模型 + 多级事故链搜索 + 状态记录”闭环跑通。

线路停运概率函数为：

```matlab
line_outage_probability
```

它是论文线路潮流相关停运概率模型的简化版，只使用线路负载率 `loading_pu`。当前参数包括基础停运概率、额定负载阈值、极限负载阈值、强制跳闸负载阈值等，均集中放在 `config/base_config.m` 中，并标注为待校准。该版本不包含完整的距离保护隐性故障、潮流越限保护隐性故障、断路器拒动/误动等保护参数。

马尔可夫输出文件为：

- `results/tables/markov_chain_summary.csv`
- `results/tables/markov_chain_stages.csv`
- `results/chains/markov_chain_records.mat`
- `results/logs/markov_line_run_log.txt`

当前结果中的风险字段使用：

- `basic_LLR`
- `basic_LFOR`
- `basic_NVOR`
- `basic_CRI`

这些字段不是论文中的 VaR 型 `SLLR/SLFOR/SNVOR/CRI`，只是基于当前事故链后果的简化风险值。后续论文对照版将基于全部事故链样本分布计算 VaR 型系统风险指标，再命名为 `SLLR`、`SLFOR`、`SNVOR` 和论文意义下的 `CRI`。

## 第三阶段：基于 Markov 事故链样本的经验 VaR 风险指标

当前新增独立入口：

```matlab
main_run_markov_risk
```

该入口读取 `results/tables/markov_chain_summary.csv`，将每条 Markov 事故链转换为一条风险样本，然后在 `sigma = 0.90, 0.95, 0.98` 三个置信水平下计算经验 VaR 型风险指标。

当前 VaR 使用 Monte Carlo 样本的经验分位数：

- 风险越大越严重，因此取右尾 `sigma` 分位数。
- 当前每条事故链等权。
- 尚未引入论文表4-1中的初始线路故障概率。
- 当前不做 Logistic、指数分布或其他概率密度拟合。

当前风险样本定义为：

- `chain_LLR = total_load_shed_frac`
- `chain_LFOR = max(max_line_loading_pu - 1, 0)`
- `chain_NVOR = max_voltage_deviation_pu`
- `chain_CRI = 0.6*chain_LLR + 0.2*chain_LFOR + 0.2*chain_NVOR`

其中 `chain_LFOR` 和 `chain_NVOR` 仍是最小版严重度定义，不是论文中完整的效用函数形式；后续论文对照版需要进一步引入越限线路数量、电压越限节点数量和效用严重度函数。

第三阶段输出文件：

- `results/tables/markov_risk_samples.csv`
- `results/tables/markov_var_metrics.csv`
- `results/tables/markov_var_by_initial_fault.csv`
- `results/logs/markov_risk_log.txt`
- `results/figures/markov_var_metrics.png`
- `results/figures/markov_initial_fault_cri_top10.png`

同时，第二阶段入口已增加候选线路抽样明细：

- `results/tables/markov_candidate_details.csv`

该表记录每一级候选线路的 `loading_pu`、`outage_probability`、`random_u` 和 `trip_selected`，用于检查高负载率线路是否对应更高停运概率。

当前结果可用于验证“Markov事故链样本 -> 风险样本 -> 经验VaR指标 -> 全局和分初始故障风险表”的计算流程，但不能直接声称复现论文第4章数值。下一步将接入论文表4-1初始线路停运概率，并补充更接近论文公式的 LLR/LFOR/NVOR 严重度函数。

## 候选线路抽样明细与初始故障概率接口

`markov_candidate_details.csv` 是检查马尔可夫线路抽样是否可信的关键文件。它逐行记录每条事故链、每一级状态下每条候选线路的：

- `loading_pu`：线路当前负载率；
- `outage_probability`：由 `line_outage_probability` 计算得到的后续停运概率；
- `random_u`：本次抽样使用的随机数；
- `trip_selected`：该线路是否在本级被抽中停运。

这个文件可以用来检查概率模型是否符合直觉：高 `loading_pu` 的线路应对应更高 `outage_probability`；当 `outage_probability >= random_u` 时，线路被选为下一阶段停运候选。若该文件为空，而 `markov_chain_stages.csv` 中存在候选线路数量，则说明事故链记录或表格导出存在问题，应停止后续风险分析。

当前初始故障概率仍使用 `uniform` 模式，即每条初始线路故障等权。为了后续接入论文表4-1，工程已新增模板：

```text
data/line_initial_outage_probability_template.csv
```

该模板包含：

- `branch_index`
- `from_bus`
- `to_bus`
- `paper_prob_times_1e_minus_4`
- `initial_outage_probability`
- `source_note`

其中概率列暂时为 `NaN`，不会自动填充任何臆造数据。用户需要根据论文表4-1手动填写 `paper_prob_times_1e_minus_4` 和/或 `initial_outage_probability`。只有填写完成后，才能将配置切换为：

```matlab
cfg.initial_fault_probability_mode = 'paper_table_4_1';
cfg.var_use_chain_weights = true;
```

在 `paper_table_4_1` 模式下，`load_initial_line_probabilities` 会检查46条线路是否齐全、线路编号和两端母线是否匹配、概率是否非NaN且非负。若数据缺失，会直接报错提示先根据论文表4-1填写数据，不会退回默认值。

当前 VaR 默认等权。后续启用 `cfg.var_use_chain_weights = true` 后，每条事故链样本权重将按“初始线路归一化权重 / 该初始线路下Monte Carlo样本数”分配，用于加权经验VaR。

## 当前简化内容

- 系统频率固定为 50 Hz。
- 本阶段禁用频率脱网。
- 风机电压脱网概率只计算和记录，不触发后续线路/机组停运。
- 当前事故链只包含初始 N-1 故障，不进行多级马尔可夫链扩展。
- 负荷削减采用全系统负荷按比例削减，不是论文中的 AC 最优负荷削减模型。
- SLLR、SLFOR、SNVOR 使用 N-1 后果的简化统计值，不是基于全部事故链概率分布的 VaR 指标。
- 论文未给出的线路容量缺省值、切负荷步长、等容量风电分配、基础调度方式均在 `config` 中标注或说明为“待校准”。

## 当前未实现内容

- 输电线路保护隐性故障概率模型。
- 传统发电机组频率/电压保护停运概率模型。
- 风机频率穿越失败脱网概率模型。
- 多级马尔可夫事故链搜索。
- 事故链状态概率计算。
- 论文中的 AC 最优负荷削减模型。
- 基于概率密度拟合或经验分布的 VaR 风险价值计算。
- 论文第4章全部场景批量对照实验。

## 与论文方法的差距

论文方法的核心是“元件停运概率模型 + 马尔可夫链事故链搜索 + 潮流计算 + 最优负荷削减 + VaR风险价值指标”。当前最小版只实现了其中的静态潮流闭环和部分新能源电压脱网概率，因此结果只能用于检查工程流程是否跑通，不能直接声称复现论文数值。

当前输出的 SLLR、SLFOR、SNVOR、CRI 是简化指标，用于跟踪每个 N-1 初始故障的直接后果。论文中的 SLLR、SLFOR、SNVOR 是在全部事故链风险样本上按置信度计算得到的 VaR 指标，两者定义不同。

## 后续扩展方向

1. 在 `src/outage/` 中补充线路停运概率、传统机组停运概率、风机频率脱网概率。
2. 在 `src/cascade/` 中实现马尔可夫链事故链搜索：每一级潮流计算后更新元件停运概率，用随机数或枚举分支生成下一级故障集。
3. 将 `simple_load_shedding.m` 替换为基于 MATPOWER OPF 的最优负荷削减模型，目标函数为最小化总切负荷。
4. 在 `src/risk/` 中新增单事故链 LLR/LFOR/NVOR 和多事故链 VaR 计算函数。
5. 在 `experiments/` 中增加论文第4章场景脚本，包括无新能源、40%分散式、集中式接入、渗透率扫描和风速扫描。
6. 保留所有未明确参数在 `config` 中集中管理，并在校准前继续标注“待校准”。
## 表4-1源数据与加权VaR可复现性

论文表4-1线路初始停运概率的唯一源数据文件是：

```text
data/line_initial_outage_probability_paper_table_4_1.csv
```

该文件中的 `paper_prob_times_1e_minus_4` 使用论文表4-1原始单位 `×10^-4`，实际概率列满足：

```text
initial_outage_probability = paper_prob_times_1e_minus_4 × 10^-4
```

`results/tables/paper_table_4_1_probability_validated.csv` 是由 `main_validate_paper_table_4_1` 生成的校验输出，不是唯一数据源。weighted VaR 的初始故障权重来自 data 源文件，经校验后得到 `normalized_weight`，再映射到 `markov_risk_samples_weighted.csv` 中的 `initial_branch_weight`。

为了保证复现性，工程新增：

```matlab
main_check_paper_table_4_1_consistency
```

该脚本会检查 data 源文件、validated 结果和 weighted 风险样本权重是否一致。如果 data 源文件仍为 NaN，或与 validated 文件、weighted 样本权重不一致，则直接报错。若 data 源文件为 NaN，则 `paper_table_4_1` 模式和 weighted VaR 均不可运行。

## 论文表4-1初始停运概率与加权VaR接口

当前默认配置仍为：

```matlab
cfg.initial_fault_probability_mode = 'uniform';
cfg.var_use_chain_weights = false;
```

因此已有 `main_run_markov_risk` 结果仍表示每条 Monte Carlo 事故链等权，不会因为新增表4-1接口而改变。论文表4-1概率需要用户手动填写：

```text
data/line_initial_outage_probability_paper_table_4_1.csv
```

该文件中的 `paper_prob_times_1e_minus_4` 表示论文表4-1中以 `1e-4` 为单位的数值；如果用户只填写这一列，程序会自动计算 `initial_outage_probability = paper_prob_times_1e_minus_4 * 1e-4`。如果同时填写 `paper_prob_times_1e_minus_4` 和 `initial_outage_probability`，两者必须一致，否则会报错。若两列仍为 `NaN`，`paper_table_4_1` 模式必须停止，不能自动编造或回退到 uniform。

表4-1数据录入后，先运行：

```matlab
main_validate_paper_table_4_1
```

校验通过后才可以运行：

```matlab
main_run_markov_risk_weighted
main_compare_uniform_vs_weighted_var
```

加权VaR的样本权重定义为：

```text
sample_weight = 初始线路normalized_weight / 该初始线路下的Monte Carlo样本数
```

其中 `normalized_weight` 由表4-1线路初始停运概率归一化得到。`uniform` 结果表示事故链样本等权，用于验证风险指标计算闭环；`weighted` 结果表示考虑论文表4-1初始故障概率分布后的全局风险分位数。两者差异反映“哪些初始故障更可能发生”对全局风险指标的影响。

当前加权VaR框架仍不代表论文数值完全复现，因为后续还需要校准线路容量、线路停运概率模型、保护参数和 LLR/LFOR/NVOR 严重度函数。

目前已经根据论文表4-1录入 IEEE-10机39节点系统46条输电线路的初始停运概率。论文表头单位为 `停运概率(*10^-4)`，因此工程只在
`data/line_initial_outage_probability_paper_table_4_1.csv` 中填写 `paper_prob_times_1e_minus_4`，由
`main_validate_paper_table_4_1` 自动换算：

```text
initial_outage_probability = paper_prob_times_1e_minus_4 * 1e-4
```

校验后的概率文件输出为：

```text
results/tables/paper_table_4_1_probability_validated.csv
```

加权VaR结果输出为：

```text
results/tables/markov_risk_samples_weighted.csv
results/tables/markov_var_metrics_weighted.csv
results/tables/markov_var_by_initial_fault_weighted.csv
results/tables/var_uniform_vs_weighted_comparison.csv
results/figures/var_uniform_vs_weighted_cri.png
```

`uniform` VaR表示每条事故链样本等权，适合检查算法闭环；`paper_table_4_1 weighted` VaR表示按照论文表4-1中不同初始线路故障概率对事故链样本加权，反映“初始故障发生可能性”对全局风险分位数的影响。

需要注意，当前结果仍不是论文数值的完全复现：线路容量参数、后续线路停运概率模型、保护隐性故障参数、负荷削减模型以及 LLR/LFOR/NVOR 严重度函数仍处于最小可运行版或待校准状态。

## 候选线路明细分块归档

为避免完整候选线路明细 `markov_candidate_details.csv` 因文件较大或在线读取环境差异而表现为空，本工程保留 full CSV 的同时，新增了可追溯的分块归档机制。后续论文复现审查建议优先检查 manifest 和 chunk 文件，而不是只依赖 full CSV。

当前候选线路抽样结果同时输出四类文件：

- `results/tables/markov_candidate_details.csv`：完整候选线路抽样明细，用于本地完整追溯每条事故链、每一级、每条候选线路的 `loading_pu`、`outage_probability`、`random_u` 和 `trip_selected`。
- `results/tables/markov_candidate_summary.csv`：轻量统计汇总，用于快速确认候选总行数、抽中行数、最大负载率、最大停运概率、95%分位统计等。
- `results/tables/markov_candidate_details_sample.csv`：人工快速查看样本，包含所有 `trip_selected=1` 的记录，以及未抽中候选中停运概率最高的前500条记录。
- `results/tables/candidate_chunks/` 与 `results/tables/markov_candidate_details_manifest.csv`：稳定复核大表的分块归档。manifest 记录每个 chunk 的文件名、起止行、行数和文件大小；每个 chunk 写出后都会立即 `readtable` 读回校验。

当前默认配置为：

```matlab
cfg.candidate_detail_chunk_size = 10000;
cfg.export_candidate_detail_chunks = true;
cfg.export_candidate_detail_full_csv = true;
cfg.export_candidate_detail_sample = true;
```

`main_run_markov_line` 会在写出 full CSV、sample、summary、chunk 和 manifest 后进行落盘校验；`main_check_markov_outputs` 会逐个读取 manifest 中的 chunk 文件，检查行数、字段、文件大小、`random_u` 范围、`outage_probability` 范围、`loading_pu` 非负性，以及是否存在 `trip_selected=1`。如果 full CSV 读取异常但所有 chunk 均通过检查，会打印 warning；如果 chunk 也失败，则直接报错并停止后续分析。
## 风险严重度函数：basic版与论文公式版

当前工程已经把风险严重度拆分为两个层次：

- `basic_*`：当前最小可运行版严重度，用于验证 Markov 事故链样本、uniform VaR 和表4-1加权VaR 的计算闭环。
- `paper_*`：论文公式版严重度接口，等待人工核对论文 LLR/LFOR/NVOR 公式后再启用。

当前 `build_markov_risk_samples` 会输出：

```text
basic_LLR, basic_LFOR, basic_NVOR, basic_CRI
chain_LLR, chain_LFOR, chain_NVOR, chain_CRI
```

其中 `chain_*` 为兼容旧流程，当前明确等同于 `basic_*`。表4-1加权VaR已经接入，但严重度函数仍使用 basic 指标，因此这些结果不能直接声称为论文完整复现。

论文公式版的记录文件为：

```text
docs/paper_severity_formula_notes.md
```

在 `cfg.paper_severity_formula_confirmed=false` 时，`paper_formula` 模式不会输出有效 `paper_CRI`；接口测试脚本 `main_test_paper_severity_interface` 会捕获预期错误，并生成：

```text
results/tables/severity_formula_status.csv
results/logs/paper_severity_interface_log.txt
```

后续一旦补充并核对论文公式，应同时报告 basic 流程验证结果、paper_formula 对照结果，以及与原论文结果的差异来源，例如线路容量、后续停运概率模型、保护参数和严重度函数校准差异。
## 论文严重度函数实现状态

本阶段新增了 `paper_formula` 严重度函数，并继续保留原有 `basic_*` 指标。二者含义不同：

- `basic_*` 是流程验证指标，直接使用总切负荷比例、最大线路负载越限和最大电压偏差。
- `paper_formula` 使用用户提供的论文式负荷损失、线路潮流越限、节点电压越限严重度函数，以及经验右尾 VaR。

当前 `paper_formula` 对应论文式 LLR、LFOR、NVOR 和 CRI 框架：

- 负荷损失：`sev_ev_llr(E_k)=C_c(E_k)/P_load*100%`。
- 线路越限：对每级所有线路求和 `[(exp(max(P_li-P_li,max,0))-1)/(e-1)]*100`。
- 电压越限：对每级所有节点求和 `[(exp(max(0.9-U_m,U_m-1.1,0))-1)/(e-1)]*100`。
- 综合风险：`CRI=0.6*SLLR+0.2*SLFOR+0.2*SNVOR`。

当前版本仍是 `line-only paper severity approximation`：

- `P_wt(E_k)=1`，暂未计入新能源机组实际脱网状态概率。
- `P_ge(E_k)=1`，暂未计入传统机组停运状态概率。
- `P_line(E_k)` 由表4-1初始线路停运概率与每级候选线路抽样转移概率构造。
- 线路有功上限当前使用 MATPOWER `RATE_A` 近似，仍待校准。

为避免用摘要最大值代替论文全量求和，工程新增三张可检查明细表：

- `results/tables/markov_line_flow_details.csv`：每条事故链、每一级、每条线路的 `PF/PT`、有功潮流标幺值和线路越限严重度分量。
- `results/tables/markov_bus_voltage_details.csv`：每条事故链、每一级、每个节点的电压和电压越限严重度分量。
- `results/tables/markov_stage_probability_details.csv`：每条事故链、每一级的初始概率、候选线路转移概率、累计状态概率和阶段负荷损失。

新增入口：

```matlab
main_run_markov_risk_paper_severity
main_compare_basic_vs_paper_severity
```

输出：

- `results/tables/markov_risk_samples_paper_severity.csv`
- `results/tables/markov_var_metrics_paper_severity.csv`
- `results/tables/markov_var_by_initial_fault_paper_severity.csv`
- `results/tables/basic_vs_paper_severity_comparison.csv`
- `results/figures/basic_vs_paper_cri_comparison.png`

当前结果不能声称与论文数值完全一致。后续需要补充新能源机组脱网概率、传统机组停运概率、更严格的线路容量校准和最优负荷削减模型，才能接近完整论文复现。

## paper_formula 明细表可追溯归档

`paper_formula` 需要逐级全线路有功潮流、全节点电压和阶段状态概率。由于 `markov_line_flow_details.csv` 与 `markov_bus_voltage_details.csv` 行数较多，GitHub 页面或连接器可能出现大CSV显示异常。因此，本工程不只依赖 full CSV，而是为 paper 明细表建立与候选线路明细相同的 manifest + chunks 归档机制。

核心源码：

```matlab
src/paper/build_markov_paper_detail_tables.m
src/paper/summarize_paper_detail_tables.m
src/paper/build_paper_detail_samples.m
```

其中 `build_markov_paper_detail_tables.m` 负责从 `markov_chain_records.mat` 回放已记录的每一级停运线路集合，重新运行故障后标准化潮流，提取：

- `line_flow_details`：用于 LFOR，包含每级所有线路的 `PF/PT`、`P_li_pu` 和线路严重度分量。
- `bus_voltage_details`：用于 NVOR，包含每级所有节点电压和电压严重度分量。
- `stage_probability_details`：用于 LLR/LFOR/NVOR 的状态概率加权，包含初始停运概率、候选线路转移概率和累计状态概率。

归档文件：

- `results/tables/markov_line_flow_details.csv`
- `results/tables/markov_line_flow_details_sample.csv`
- `results/tables/markov_line_flow_details_summary.csv`
- `results/tables/markov_line_flow_details_manifest.csv`
- `results/tables/markov_bus_voltage_details.csv`
- `results/tables/markov_bus_voltage_details_sample.csv`
- `results/tables/markov_bus_voltage_details_summary.csv`
- `results/tables/markov_bus_voltage_details_manifest.csv`
- `results/tables/paper_detail_chunks/*.csv`
- `results/tables/markov_stage_probability_details.csv`
- `results/tables/markov_stage_probability_summary.csv`

后续复核 paper_formula 明细时，应优先检查 manifest 和 `paper_detail_chunks`，再查看 full CSV。`sample` 文件仅用于快速人工浏览高风险行，不能替代完整明细。

## paper_formula 非收敛阶段处理

上一版 paper_formula 明细曾把非收敛潮流的最后迭代 `PF/PT/VM` 写入线路和电压严重度，导致 `P_li_pu`、节点电压和指数严重度出现非物理极值，甚至出现 `Inf`。这类结果不能作为论文 LFOR/NVOR 的输入。

当前采用严格收敛策略：

- `cfg.paper_strict_convergence = true`。
- 只有收敛潮流且数值通过合理性检查的 stage 才能写入 `markov_line_flow_details.csv` 和 `markov_bus_voltage_details.csv`。
- 非收敛 stage 仍保留 `stage_load_shed_mw`、`stage_cumulative_probability`，因此可用于 LLR 诊断。
- 非收敛 stage 不再用于 LFOR/NVOR，不把最后迭代 `PF/PT/VM` 当作有效物理状态。
- 指数严重度通过 `src/paper/safe_exponential_severity.m` 计算，若自变量过大或产生 `Inf/NaN`，会标记无效或报错。

新增诊断表：

- `results/tables/markov_paper_invalid_stage_details.csv`：逐条记录无效 stage 的初始线路、样本编号、级数、收敛状态、无效原因、阶段切负荷和累计概率。
- `results/tables/markov_paper_invalid_stage_summary.csv`：汇总总 stage 数、有效 stage 数、无效 stage 数、非收敛 stage 数和无效比例。

paper_formula VaR 只有在无效事故链比例不超过 `cfg.paper_max_invalid_chain_ratio_for_var` 时才标记为 `valid`。若超过阈值，结果会标记为 `diagnostic_only`，不能作为论文对照结果。当前策略仍不回退 basic，也不修改 Markov 抽样结果。
