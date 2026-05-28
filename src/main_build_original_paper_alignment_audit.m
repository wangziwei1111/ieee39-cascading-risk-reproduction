function main_build_original_paper_alignment_audit()
%MAIN_BUILD_ORIGINAL_PAPER_ALIGNMENT_AUDIT 生成原文学位论文对齐审计与缺失资料清单。
% 输入：
%   无。仅读取当前配置、final_summary 和已有文档，不运行任何仿真。
% 输出：
%   docs/original_paper_alignment_audit.md
%   docs/required_original_paper_inputs.md
%   docs/next_reproduction_steps.md
%   results/final_summary/tables/original_paper_gap_audit.csv
%   results/final_summary/logs/original_paper_alignment_audit_log.txt
% 物理含义：
%   将当前工程与原文学位论文的风险模型、IEEE39算例和第4章场景逐项对齐，
%   明确哪些已实现、哪些是工程近似、哪些必须等待用户提供原文公式或参数。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();

docs_dir = fullfile(project_root, 'docs');
table_dir = fullfile(project_root, 'results', 'final_summary', 'tables');
log_dir = fullfile(project_root, 'results', 'final_summary', 'logs');
ensure_dir(docs_dir);
ensure_dir(table_dir);
ensure_dir(log_dir);

overview_path = fullfile(table_dir, 'final_scenario_overview.csv');
if exist(overview_path, 'file')
    overview = readtable(overview_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    scenario_count = height(overview);
else
    overview = table();
    scenario_count = 0;
end

audit_table = build_gap_audit_table();
save_result_table(audit_table, fullfile(table_dir, 'original_paper_gap_audit.csv'), true);

write_alignment_doc(fullfile(docs_dir, 'original_paper_alignment_audit.md'), cfg, scenario_count);
write_required_inputs_doc(fullfile(docs_dir, 'required_original_paper_inputs.md'));
write_next_steps_doc(fullfile(docs_dir, 'next_reproduction_steps.md'));

log_file = fullfile(log_dir, 'original_paper_alignment_audit_log.txt');
fid = fopen(log_file, 'w', 'n', 'UTF-8');
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, 'Original paper alignment audit generated.\n');
fprintf(fid, 'audit_rows=%d\n', height(audit_table));
fprintf(fid, 'final_summary_scenario_rows=%d\n', scenario_count);
fprintf(fid, 'allowed_status=matched,partially_matched,simplified,missing,unknown_need_paper\n');
fprintf('Original paper alignment audit generated: %s\n', log_file);
end

function audit_table = build_gap_audit_table()
rows = {};
rows = add_row(rows, "IEEE39 基础数据", "论文第4章应说明所用 IEEE39 基础系统及修改。", ...
    "使用 MATPOWER case39 作为基础系统。", "partially_matched", ...
    "基础模型已可运行，但未确认是否与论文修改版 IEEE39 完全一致。", ...
    "论文第4章 IEEE39 算例修改参数或附录算例。", "no", "P0", ...
    "对照论文算例参数，必要时建立 paper_case39。");
rows = add_row(rows, "原始 case39 是否与论文一致", "原文若修改负荷、机组或线路，应使用原文数据。", ...
    "当前未发现完整原文算例数据，仍使用 MATPOWER 标准 case39。", "unknown_need_paper", ...
    "无法判断标准 case39 与原文是否一致。", "原文 IEEE39 数据表、修改说明或算例文件。", "no", "P0", ...
    "等待用户提供原文算例参数后逐项校验。");
rows = add_row(rows, "负荷水平", "应匹配论文第4章负荷设置。", ...
    "当前总负荷来自 MATPOWER case39，并用于渗透率容量计算。", "partially_matched", ...
    "负荷水平可追溯，但未确认与论文一致。", "论文负荷水平或各节点负荷表。", "no", "P0", ...
    "核对各节点 Pd/Qd 和系统总负荷。");
rows = add_row(rows, "发电机参数", "应匹配论文机组容量、上下限、平衡机设置。", ...
    "使用 case39 机组参数，并在新能源调度中按比例重调度。", "partially_matched", ...
    "机组上下限和原文可能不同。", "原文机组参数、PMAX/PMIN、平衡机设定。", "no", "P0", ...
    "建立机组参数对照表。");
rows = add_row(rows, "线路容量", "应匹配论文线路热稳定容量或保护限值。", ...
    "当前使用 MATPOWER RATE_A；paper_formula 中 RATE_A 近似 active_limit_mw。", "simplified", ...
    "RATE_A 作为有功上限是工程近似，待校准。", "原文线路容量或 RATE_A 修改表。", "no", "P0", ...
    "用原文容量替换或校准 RATE_A。");
rows = add_row(rows, "表4-1线路初始停运概率", "应使用论文表4-1的46条线路初始停运概率。", ...
    "已录入 data/line_initial_outage_probability_paper_table_4_1.csv，并用于 weighted VaR。", "partially_matched", ...
    "已由用户提供并录入，但仍需最终核对每行是否与原文一致。", "原文表4-1截图或可复制表格。", "yes", "P1", ...
    "逐行复核 branch_index/from_bus/to_bus 与论文线路顺序。");
rows = add_row(rows, "线路后续停运概率模型", "应按论文线路后续停运概率公式和参数计算。", ...
    "当前使用分段式 loading_pu 概率模型，参数集中在 cfg 中标注待校准。", "simplified", ...
    "模型结构和参数均为工程近似。", "论文线路后续停运概率模型公式、参数和单位。", "no", "P0", ...
    "替换 line_outage_probability 并重跑 Markov。");
rows = add_row(rows, "Markov 状态转移机制", "应按论文 Markov 事故链搜索和状态转移定义。", ...
    "已实现线路驱动 N-1-1... Markov 事故链搜索，保留候选概率和随机数。", "partially_matched", ...
    "当前只考虑线路后续停运，未纳入机组状态转移。", "论文 Markov 状态定义、转移规则和终止条件。", "yes", "P1", ...
    "在现有 search_cascade_markov_line 基础上扩展状态集合。");
rows = add_row(rows, "新能源机组状态概率 P_wt(E_k)", "论文要求计算新能源机组运行/停运组合概率。", ...
    "当前 line-only paper_formula 中 P_wt(E_k)=1。", "simplified", ...
    "未真实计入新能源机组状态概率。", "P_wt(E_k) 完整公式、P_WT(h) 变量定义和保护模型。", "no", "P0", ...
    "实现新能源状态概率并并入 stage probability。");
rows = add_row(rows, "传统机组状态概率 P_ge(E_k)", "论文要求计算传统机组运行/停运组合概率。", ...
    "当前 line-only paper_formula 中 P_ge(E_k)=1。", "simplified", ...
    "未真实计入传统机组状态概率。", "P_ge(E_k) 完整公式、P_G(q) 参数或保护动作模型。", "no", "P0", ...
    "实现传统机组状态概率并并入 stage probability。");
rows = add_row(rows, "输电线路状态概率 P_line(E_k)", "论文要求计算线路状态组合概率。", ...
    "当前使用初始线路概率和候选线路逐级条件转移概率构造 line-only P_line。", "partially_matched", ...
    "P_line 是基于抽样记录的可复现近似，需确认是否符合原文定义。", "原文 P_line(E_k) 公式和状态集合定义。", "no", "P0", ...
    "核对后调整 stage_probability_details。");
rows = add_row(rows, "连锁故障状态概率计算", "每级状态概率应由 P_wt、P_ge、P_line 共同构成。", ...
    "当前 stage_cumulative_probability = P_initial * candidate transition product。", "simplified", ...
    "未乘入 P_wt 和 P_ge。", "原文状态概率完整公式和变量定义。", "no", "P0", ...
    "扩展 stage_probability_details 字段。");
rows = add_row(rows, "负荷损失严重度 LLR", "按论文 C_c(E_k)/P_load*100% 计算并按状态概率加权。", ...
    "paper_formula 已实现 line-only LLR，并保留 basic_LLR。", "partially_matched", ...
    "负荷损失来源仍是简化切负荷和孤岛切除。", "原文 C_c(E_k) 计算方法、切负荷模型。", "no", "P1", ...
    "校准失负荷/切负荷模型。");
rows = add_row(rows, "线路潮流越限严重度 LFOR", "按论文指数效用函数对所有线路有功潮流越限求和。", ...
    "已输出 line_flow_details 并按有功潮流近似计算 paper_LFOR。", "partially_matched", ...
    "active_limit_mw 当前使用 RATE_A 近似。", "原文线路有功上限定义和容量表。", "no", "P1", ...
    "替换 active_limit_mw 来源。");
rows = add_row(rows, "节点电压越限严重度 NVOR", "按论文指数效用函数对所有节点电压越限求和。", ...
    "已输出 bus_voltage_details，使用 0.9/1.1 电压边界计算 paper_NVOR。", "partially_matched", ...
    "需确认论文电压阈值和是否包含全部节点。", "原文 NVOR 公式截图和电压阈值说明。", "yes", "P1", ...
    "核对阈值后调整 cfg.paper_voltage_*。");
rows = add_row(rows, "综合风险 CRI", "论文采用 0.6*SLLR+0.2*SLFOR+0.2*SNVOR。", ...
    "basic、weighted、paper_formula 均使用 0.6/0.2/0.2 权重。", "matched", ...
    "权重已按用户提供公式实现，仍需最终核对原文。", "原文 CRI 权重公式截图。", "yes", "P2", ...
    "在论文公式确认稿中引用。");
rows = add_row(rows, "VaR 计算方式", "论文定义右尾积分置信水平 VaR。", ...
    "当前使用 Monte Carlo 样本经验右尾分位数。", "partially_matched", ...
    "需确认原文是否使用经验分位数、概率密度拟合或其他估计。", "原文 VaR 计算实现描述。", "no", "P1", ...
    "必要时增加密度拟合或加权分位数方法。");
rows = add_row(rows, "事故链样本数量", "论文应给出样本数量或搜索规模。", ...
    "当前正式场景使用 46*20=920 条事故链。", "unknown_need_paper", ...
    "样本数是工程设置，未确认论文样本规模。", "论文仿真次数、采样规模或收敛准则。", "no", "P1", ...
    "按原文样本数重跑关键场景。");
rows = add_row(rows, "置信水平", "论文第4章应说明 VaR 置信水平。", ...
    "当前使用 0.90、0.95、0.98。", "partially_matched", ...
    "需确认与原文完全一致。", "原文 VaR 置信水平设置。", "yes", "P2", ...
    "若不同则调整 cfg.var_confidence_levels。");
rows = add_row(rows, "切负荷或失负荷模型", "论文可能使用最优负荷削减或失负荷计算模型。", ...
    "当前为孤岛切除 + 简化比例切负荷。", "simplified", ...
    "不是严格最优负荷削减。", "原文最优切负荷目标函数、约束和参数。", "no", "P0", ...
    "实现 OPF/OLS 模型或按原文替换 simple_load_shedding。");
rows = add_row(rows, "非收敛潮流处理", "原文应说明潮流不收敛或解列状态如何处理。", ...
    "当前严格禁止非收敛 PF/PT/VM 进入 LFOR/NVOR，并输出 invalid_stage 诊断。", "simplified", ...
    "这是工程安全机制，需确认原文处理方式。", "原文非收敛、孤岛和解列处理规则。", "no", "P1", ...
    "按原文规则调整 invalid stage policy。");
rows = add_row(rows, "新能源分散式接入场景", "论文第4章应给出分散接入节点和容量。", ...
    "当前使用 30:39 分散接入和 3000MW 基准/比例渗透率场景。", "partially_matched", ...
    "分散节点和容量定义仍需确认。", "原文分散式接入节点、容量和风速设置。", "no", "P0", ...
    "修正 scenario_library。");
rows = add_row(rows, "新能源集中式接入场景", "论文第4章应给出集中接入节点和容量。", ...
    "当前 centralized_wind_40pct 暂用 39 节点，且 paper_formula 为 diagnostic_only。", "simplified", ...
    "集中节点是待校准假设，不能继续猜测。", "原文集中式接入节点和容量。", "no", "P0", ...
    "用户提供后替换 centralized scenario。");
rows = add_row(rows, "新能源渗透率定义", "论文应定义新能源渗透率。", ...
    "当前使用 风电装机容量/系统总负荷。", "simplified", ...
    "定义待原文确认。", "原文渗透率定义和基准容量。", "no", "P0", ...
    "确认后重算 penetration_scan 容量。");
rows = add_row(rows, "渗透率扫描场景", "论文第4章可能扫描 40% 到 80%。", ...
    "已实现 40/45/50/55/60/65/70/75/80% 20-trial。", "partially_matched", ...
    "扫描点已实现，但定义和容量需校准。", "原文渗透率场景表。", "yes", "P1", ...
    "按原文定义重跑扫描。");
rows = add_row(rows, "风速扫描场景", "论文第4章可能扫描多个风速/出力波动。", ...
    "已实现 8/10/12/14/16 m/s 20-trial，并记录实际风电出力。", "partially_matched", ...
    "风速点和功率曲线需原文确认。", "原文风速场景和风资源参数。", "no", "P1", ...
    "按原文风速点和曲线重跑。");
rows = add_row(rows, "风电功率曲线", "论文应给出风速-出力曲线或风机参数。", ...
    "当前使用工程风电功率曲线。", "simplified", ...
    "切入、额定、切出等参数待校准。", "原文风电功率曲线参数。", "no", "P1", ...
    "替换 wind_power_curve 参数。");
rows = add_row(rows, "新能源脱网概率模型", "论文应给出电压/频率脱网概率或保护模型。", ...
    "当前仅实现电压脱网概率诊断模型，参数待校准。", "simplified", ...
    "只记录概率，不代表完整保护模型。", "原文新能源脱网概率函数和参数。", "no", "P0", ...
    "校准 wind_voltage_trip_probability。");
rows = add_row(rows, "新能源实际脱网状态转移", "论文若考虑新能源脱网，应实际改变状态并进入事故链。", ...
    "当前 renewable_trip_record 仅 record_only，不切除风机，不调用随机数。", "missing", ...
    "尚未实现实际风机状态转移。", "原文新能源脱网触发、恢复和状态概率耦合规则。", "no", "P0", ...
    "实现风机状态转移并验证随机序列隔离。");
rows = add_row(rows, "传统机组停运模型", "论文应给出传统机组停运概率或保护动作模型。", ...
    "当前未实现传统机组停运概率模型。", "missing", ...
    "P_G(q) 无来源。", "原文传统机组停运概率模型和参数。", "no", "P0", ...
    "新增 conventional generator outage module。");
rows = add_row(rows, "传统机组实际停运状态转移", "论文若考虑传统机组停运，应实际改变机组状态。", ...
    "当前未实现传统机组实际停运状态转移。", "missing", ...
    "事故链状态集合缺少传统机组维度。", "原文传统机组状态转移规则。", "no", "P0", ...
    "扩展 Markov state 和 normalize 流程。");
rows = add_row(rows, "topology_compare", "第4章应包含无新能源/分散/集中等拓扑对比。", ...
    "已重跑正式 20-trial topology_compare，并区分 diagnostic_only。", "partially_matched", ...
    "集中节点和场景定义仍待论文确认。", "原文拓扑对比场景定义。", "yes", "P1", ...
    "按原文场景修正后重跑。");
rows = add_row(rows, "penetration_scan", "第4章应展示渗透率变化影响。", ...
    "已生成 40% 到 80% 的 20-trial final_summary。", "partially_matched", ...
    "当前渗透率定义待校准。", "原文渗透率定义和场景表。", "yes", "P1", ...
    "校准后重跑 final scan。");
rows = add_row(rows, "wind_speed_scan", "第4章应展示风速或出力波动影响。", ...
    "已生成 8/10/12/14/16 m/s 20-trial final_summary。", "partially_matched", ...
    "风速点和功率曲线参数待校准。", "原文风速场景表。", "yes", "P1", ...
    "按原文风速点重跑。");
rows = add_row(rows, "renewable_trip_record", "论文新能源脱网模型应影响状态概率和事故链。", ...
    "当前只输出 P_WT(h) 记录，不实际触发脱网。", "simplified", ...
    "record_only 不是完整新能源脱网模型。", "原文新能源脱网状态转移和概率耦合公式。", "no", "P0", ...
    "升级 record_only 为实际状态转移。");
rows = add_row(rows, "final_summary", "应汇总可用于论文的当前结果并标注有效性。", ...
    "已过滤 5-trial smoke 和 legacy 场景，仅保留 20-trial final_summary。", "matched", ...
    "结果是当前参数下复现实验，不是原文数值严格对齐。", "原文结果表用于后续数值对照。", "yes", "P2", ...
    "作为论文复现实验框架阶段性结果。");
rows = add_row(rows, "原文第4章结果图表对照", "应与原文第4章表格和曲线逐项对照。", ...
    "当前只生成工程图表，尚未与原文数值逐点对齐。", "missing", ...
    "缺少原文图表数据点或清晰截图。", "原文第4章主要结果表、图和数值。", "no", "P0", ...
    "建立 paper_vs_reproduction_comparison 表。");

audit_table = table(string(rows(:,1)), string(rows(:,2)), string(rows(:,3)), ...
    string(rows(:,4)), string(rows(:,5)), string(rows(:,6)), string(rows(:,7)), ...
    string(rows(:,8)), string(rows(:,9)), ...
    'VariableNames', {'module', 'paper_requirement', 'current_implementation', ...
    'alignment_status', 'simplification_or_gap', 'required_user_input', ...
    'can_codex_continue_without_input', 'priority', 'next_action'});
end

function rows = add_row(rows, module, paper_requirement, current_implementation, alignment_status, ...
    simplification_or_gap, required_user_input, can_continue, priority, next_action)
rows(end + 1, :) = {module, paper_requirement, current_implementation, alignment_status, ...
    simplification_or_gap, required_user_input, can_continue, priority, next_action};
end

function write_alignment_doc(path, cfg, scenario_count)
content = [
"# 原文学位论文对齐审计"
""
"## 1. 当前工程复现范围"
""
"当前工程已经完成 IEEE39 + MATPOWER 基础潮流、N-1 和 Markov 线路事故链、表4-1初始停运概率、basic/weighted/paper_formula VaR、分组场景扫描以及 final_summary 汇总。当前 final_summary 场景行数为 " + string(scenario_count) + "，正式 Markov 样本数为每条初始线路 " + string(cfg.markov_num_trials_per_initial_fault) + " 次。"
""
"## 2. 与原文第3章风险模型的对齐情况"
""
"已实现 LLR、LFOR、NVOR、CRI 的 line-only paper_formula 框架，并基于候选线路转移概率构造 P_line(E_k)。但是 P_wt(E_k) 和 P_ge(E_k) 当前仍简化为 1，新能源和传统机组实际状态转移尚未实现，因此不能声称完整复现原文第3章风险模型。"
""
"## 3. 与原文第4章 IEEE39 算例的对齐情况"
""
"当前使用 MATPOWER case39 作为基础系统，并构建 3000MW 基准、拓扑对比、渗透率扫描、风速扫描和新能源脱网概率记录场景。尚未确认原文是否修改了 IEEE39 的负荷、机组、线路容量、接入节点和风电功率曲线。"
""
"## 4. 当前已完成的模块"
""
"- IEEE39 基础潮流和新能源重调度。"
"- 故障后孤岛识别和主岛标准化。"
"- 线路停运概率驱动的 Markov 事故链搜索。"
"- 表4-1初始停运概率接口和加权 VaR。"
"- line-only paper_formula 严重度函数和非收敛阶段诊断。"
"- topology_compare、penetration_scan、wind_speed_scan、renewable_trip_record 和 final_summary。"
""
"## 5. 当前简化假设清单"
""
"- P_wt(E_k)=1。"
"- P_ge(E_k)=1。"
"- 新能源脱网仅 record_only，不实际切除风机。"
"- 传统机组停运尚未实现。"
"- 线路后续停运概率模型为工程近似。"
"- LFOR 的 active_limit_mw 使用 RATE_A 近似。"
"- 切负荷策略仍为简化切负荷。"
"- 非收敛阶段处理为工程安全机制，需确认原文规则。"
""
"## 6. diagnostic_only 与 record_only 的含义"
""
"diagnostic_only 表示程序运行完成，但 paper_formula 因无效阶段比例等原因不能作为有效论文对照。record_only 表示只记录新能源脱网概率 P_WT(h)，不改变风机状态、不影响线路事故链随机序列。"
""
"## 7. 必须补充的原文资料清单"
""
"详见 `docs/required_original_paper_inputs.md`。"
""
"## 8. 下一阶段实现优先级"
""
"详见 `docs/next_reproduction_steps.md`。优先级最高的是补齐 P_wt、P_ge、线路后续停运概率、IEEE39 修改参数和第4章场景定义。"
""
"## 9. 不允许继续猜测的参数和公式"
""
"集中式接入节点、渗透率定义、线路后续停运概率参数、新能源脱网模型、传统机组停运模型、最优切负荷模型和原文第4章结果数据不得继续猜测。"
""
"## 10. 当前结果可以如何用于硕士论文"
""
"可以表述为：完成了基于 IEEE39 的连锁故障风险评估复现实验框架，并在当前参数和 line-only paper_formula 近似下获得趋势性结果。"
""
"## 11. 当前结果不能如何表述"
""
"不能表述为：已完全复现原文学位论文第4章全部数值；也不能把 record_only 说成完整新能源脱网模型，不能把 diagnostic_only 作为有效 paper_formula 对照。"
""];
write_lines(path, content);
end

function write_required_inputs_doc(path)
content = [
"# 继续完整复现所需原文资料清单"
""
"## P0：必须优先提供"
""
"1. 论文第3章风险评估模型完整公式截图。"
"2. P_wt(E_k)、P_ge(E_k)、P_line(E_k) 的完整变量定义。"
"3. 线路后续停运概率模型公式和参数。"
"4. 新能源机组脱网概率或保护动作模型。"
"5. 传统机组停运概率或保护动作模型。"
"6. 论文第4章 IEEE39 算例修改参数。"
"7. 原文第4章场景定义表。"
"8. 原文第4章主要结果表或图。"
""
"## P1：次优先级"
""
"1. 风电功率曲线参数。"
"2. 分散式接入节点。"
"3. 集中式接入节点。"
"4. 渗透率定义。"
"5. 风速扫描点。"
"6. 仿真样本数。"
"7. 置信水平。"
"8. 线路容量设置。"
"9. 切负荷模型或失负荷计算方法。"
""
"## P2：后续优化"
""
"1. 原文绘图样式。"
"2. 原文结果图数据点。"
"3. 论文中各类参数的单位说明。"
"4. 若有，附录中的 IEEE39 修改算例。"
""
"## 禁止自动补值"
""
"缺失资料不得用 uniform、平均值或经验猜测替代。paper_table_4_1、接入节点、保护参数和严重度函数均必须来自用户提供的原文资料或明确的人工确认。"
""];
write_lines(path, content);
end

function write_next_steps_doc(path)
content = [
"# 下一阶段复现路线图"
""
"## 阶段 A：补齐原文公式和参数"
"- 用户输入：第3章公式、表4-1核对、IEEE39 修改参数、第4章场景表。"
"- 代码修改：建立 paper_config 和 paper_case39 数据层。"
"- 输出结果：原文参数录入模板和一致性校验表。"
"- 通过标准：所有 P0 输入项不再为 unknown_need_paper。"
"- 不可猜测：任何保护参数、接入节点、渗透率定义。"
""
"## 阶段 B：实现 P_wt(E_k) 新能源状态概率"
"- 用户输入：P_WT(h) 公式和新能源保护模型。"
"- 代码修改：扩展 renewable 状态概率模块。"
"- 输出结果：wind_state_probability_details.csv。"
"- 通过标准：stage_probability_details 中包含 P_wt。"
"- 不可猜测：脱网概率曲线和保护阈值。"
""
"## 阶段 C：实现 P_ge(E_k) 传统机组状态概率"
"- 用户输入：P_G(q) 公式、机组停运概率和保护动作规则。"
"- 代码修改：新增 conventional outage/state probability 模块。"
"- 输出结果：generator_state_probability_details.csv。"
"- 通过标准：stage_probability_details 中包含 P_ge。"
"- 不可猜测：机组停运概率。"
""
"## 阶段 D：把 record_only 新能源脱网升级为实际状态转移"
"- 用户输入：新能源脱网触发规则、是否随机抽样、恢复规则。"
"- 代码修改：扩展 Markov 状态集合和 mpc.gen 状态更新。"
"- 输出结果：wind_trip_state_transition_details.csv。"
"- 通过标准：风机脱网改变后续潮流且随机序列可复现。"
"- 不可猜测：脱网触发与恢复规则。"
""
"## 阶段 E：实现传统机组停运状态转移"
"- 用户输入：传统机组停运触发规则。"
"- 代码修改：扩展 Markov 搜索和 slack 重选逻辑。"
"- 输出结果：generator_trip_state_transition_details.csv。"
"- 通过标准：传统机组停运可追溯且不破坏潮流标准化。"
"- 不可猜测：机组保护动作条件。"
""
"## 阶段 F：校准线路后续停运概率模型"
"- 用户输入：论文线路后续停运概率公式与参数。"
"- 代码修改：替换 line_outage_probability。"
"- 输出结果：line_outage_probability_audit.csv。"
"- 通过标准：候选线路概率与论文公式逐项一致。"
"- 不可猜测：分段阈值和概率上限。"
""
"## 阶段 G：校准切负荷/失负荷模型"
"- 用户输入：最优切负荷目标函数、约束和参数。"
"- 代码修改：替换 simple_load_shedding 或引入 OPF/OLS。"
"- 输出结果：load_shedding_optimization_details.csv。"
"- 通过标准：C_c(E_k) 与论文定义一致。"
"- 不可猜测：负荷优先级和惩罚系数。"
""
"## 阶段 H：对齐第4章场景"
"- 用户输入：分散/集中接入、渗透率、风速和样本数设置。"
"- 代码修改：更新 scenario_library。"
"- 输出结果：paper_aligned_scenario_batch_summary.csv。"
"- 通过标准：每个场景参数均可追溯到原文。"
"- 不可猜测：集中接入节点。"
""
"## 阶段 I：对齐第4章结果图表"
"- 用户输入：原文结果表和图。"
"- 代码修改：新增 paper_vs_reproduction_comparison。"
"- 输出结果：paper_result_alignment_table.csv 和对照图。"
"- 通过标准：逐图逐表说明误差来源。"
"- 不可猜测：原文图中未读出的数据点。"
""
"## 阶段 J：形成论文可用复现实验说明"
"- 用户输入：最终采用参数和论文写作口径。"
"- 代码修改：生成最终报告和附录表。"
"- 输出结果：复现实验方法说明、限制说明和可复现实验包。"
"- 通过标准：所有结论均可由代码和数据复核。"
"- 不可猜测：与原文不一致时的解释。"
""];
write_lines(path, content);
end

function write_lines(path, lines)
fid = fopen(path, 'w', 'n', 'UTF-8');
if fid < 0
    error('无法写入文件：%s', path);
end
cleaner = onCleanup(@() fclose(fid));
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines(i));
end
end

function ensure_dir(path)
if ~exist(path, 'dir')
    mkdir(path);
end
end
