function severity_table = calc_basic_chain_severity(chain_summary_table, cfg)
%CALC_BASIC_CHAIN_SEVERITY 计算当前最小版事故链严重度。
% 输入：
%   chain_summary_table - Markov事故链汇总表，至少包含失负荷比例、最大线路负载率和最大电压偏差。
%   cfg - 全局配置，包含CRI权重。
% 输出：
%   severity_table - 包含 basic_LLR/basic_LFOR/basic_NVOR/basic_CRI 的表。
% 物理含义：
%   basic严重度仅用于流程验证：负荷损失取总失负荷比例，线路风险取最大负载率超过1的部分，
%   电压风险取最大电压偏差。它不是论文完整严重度函数。

basic_LLR = chain_summary_table.total_load_shed_frac;
basic_LFOR = max(chain_summary_table.max_line_loading_pu - 1, 0);
basic_NVOR = chain_summary_table.max_voltage_deviation_pu;
basic_CRI = calc_cri(basic_LLR, basic_LFOR, basic_NVOR, cfg.risk_weights);

severity_table = table(basic_LLR, basic_LFOR, basic_NVOR, basic_CRI);
end
