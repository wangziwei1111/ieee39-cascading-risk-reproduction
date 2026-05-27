function risk_samples = build_markov_risk_samples(chain_summary_table, cfg)
%BUILD_MARKOV_RISK_SAMPLES 从Markov事故链汇总表构造风险样本。
% 输入：
%   chain_summary_table - markov_chain_summary.csv读入后的表格。
%   cfg - 全局配置，包含风险权重和样本权重模式。
% 输出：
%   risk_samples - 每条事故链一行的风险样本表。
% 物理含义：
%   当前样本严重度是最小版定义：负荷损失用总失负荷比例，线路越限用
%   全链最大负载率超过1的部分，电压越限用全链最大电压偏差。它不是
%   论文完整效用函数，也没有引入初始故障概率权重。

n = height(chain_summary_table);
initial_branch = chain_summary_table.initial_branch;
trial_id = chain_summary_table.trial_id;
total_load_shed_frac = chain_summary_table.total_load_shed_frac;
max_line_loading_pu = chain_summary_table.max_line_loading_pu;
max_voltage_deviation_pu = chain_summary_table.max_voltage_deviation_pu;

chain_LLR = total_load_shed_frac;
line_excess = max(max_line_loading_pu - 1, 0);
chain_LFOR = line_excess;
chain_NVOR = max_voltage_deviation_pu;
chain_CRI = calc_cri(chain_LLR, chain_LFOR, chain_NVOR, cfg.risk_weights);

if isfield(cfg, 'var_use_chain_weights') && cfg.var_use_chain_weights
    % 预留接口：后续可接入论文表4-1初始故障概率。
    sample_weight = ones(n, 1) / n;
else
    sample_weight = ones(n, 1) / n;
end

risk_samples = table(initial_branch, trial_id, total_load_shed_frac, ...
    max_line_loading_pu, max_voltage_deviation_pu, ...
    chain_LLR, chain_LFOR, chain_NVOR, chain_CRI, sample_weight);
end
