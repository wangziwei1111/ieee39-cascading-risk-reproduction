function risk_samples = build_markov_risk_samples(chain_summary_table, cfg, initial_probability_table)
%BUILD_MARKOV_RISK_SAMPLES 从Markov事故链汇总表构造风险样本。
% 输入：
%   chain_summary_table - markov_chain_summary.csv 读入后的表格。
%   cfg - 全局配置，包含风险权重和样本权重模式。
%   initial_probability_table - 可选，初始线路故障概率与归一化权重表。
% 输出：
%   risk_samples - 每条事故链一行的风险样本表。
% 物理含义：
%   当前严重度是最小版定义：负荷损失用总失负荷比例，线路风险用全链最大
%   负载率超过1的部分，电压风险用全链最大电压偏差。若启用表4-1权重，则
%   每条事故链样本权重 = 初始线路归一化权重 / 该初始线路下的Monte Carlo样本数。

n = height(chain_summary_table);
initial_branch = chain_summary_table.initial_branch;
trial_id = chain_summary_table.trial_id;
total_load_shed_frac = chain_summary_table.total_load_shed_frac;
max_line_loading_pu = chain_summary_table.max_line_loading_pu;
max_voltage_deviation_pu = chain_summary_table.max_voltage_deviation_pu;

chain_LLR = total_load_shed_frac;
chain_LFOR = max(max_line_loading_pu - 1, 0);
chain_NVOR = max_voltage_deviation_pu;
chain_CRI = calc_cri(chain_LLR, chain_LFOR, chain_NVOR, cfg.risk_weights);

use_weighted = nargin >= 3 && ~isempty(initial_probability_table) && ...
    isfield(cfg, 'var_use_chain_weights') && cfg.var_use_chain_weights;

if use_weighted
    initial_branch_weight = zeros(n, 1);
    sample_weight = zeros(n, 1);
    num_trials_for_initial_branch = zeros(n, 1);

    for i = 1:n
        row = initial_probability_table(initial_probability_table.branch_index == initial_branch(i), :);
        if isempty(row)
            error('初始故障概率表中找不到 branch %d。', initial_branch(i));
        end
        initial_branch_weight(i) = row.normalized_weight(1);
    end

    branches = unique(initial_branch);
    for b = 1:numel(branches)
        mask = initial_branch == branches(b);
        n_i = sum(mask);
        num_trials_for_initial_branch(mask) = n_i;
        sample_weight(mask) = initial_branch_weight(mask) / n_i;
    end
    sample_weight_source = repmat("paper_table_4_1_initial_fault_weight", n, 1);
else
    unique_branch_count = numel(unique(initial_branch));
    initial_branch_weight = ones(n, 1) / unique_branch_count;
    sample_weight = ones(n, 1) / n;
    num_trials_for_initial_branch = zeros(n, 1);
    branches = unique(initial_branch);
    for b = 1:numel(branches)
        mask = initial_branch == branches(b);
        num_trials_for_initial_branch(mask) = sum(mask);
    end
    sample_weight_source = repmat("uniform_chain_weight", n, 1);
end

weight_sum = sum(sample_weight);
if abs(weight_sum - 1) > 1e-10
    error('风险样本权重总和应为1，实际为%.16f。', weight_sum);
end

risk_samples = table(initial_branch, trial_id, total_load_shed_frac, ...
    max_line_loading_pu, max_voltage_deviation_pu, ...
    chain_LLR, chain_LFOR, chain_NVOR, chain_CRI, ...
    initial_branch_weight, num_trials_for_initial_branch, sample_weight, sample_weight_source);
end
