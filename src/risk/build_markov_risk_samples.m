function risk_samples = build_markov_risk_samples(chain_summary_table, cfg, initial_probability_table)
%BUILD_MARKOV_RISK_SAMPLES 从Markov事故链汇总表构造风险样本。
% 输入：
%   chain_summary_table - markov_chain_summary.csv读入后的表格。
%   cfg - 全局配置，包含风险权重和样本权重模式。
%   initial_probability_table - 可选，初始线路故障概率与归一化权重表。
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

if nargin < 3 || isempty(initial_probability_table)
    initial_branch_weight = ones(n, 1) / numel(unique(initial_branch));
    sample_weight = ones(n, 1) / n;
    sample_weight_source = repmat("uniform_chain_weight", n, 1);
else
    initial_branch_weight = zeros(n, 1);
    sample_weight = zeros(n, 1);
    for i = 1:n
        row = initial_probability_table(initial_probability_table.branch_index == initial_branch(i), :);
        if isempty(row)
            error('初始故障概率表中找不到branch %d。', initial_branch(i));
        end
        initial_branch_weight(i) = row.normalized_weight(1);
    end

    if isfield(cfg, 'var_use_chain_weights') && cfg.var_use_chain_weights
        branches = unique(initial_branch);
        for b = 1:numel(branches)
            mask = initial_branch == branches(b);
            sample_weight(mask) = initial_branch_weight(mask) / sum(mask);
        end
        sample_weight = sample_weight / sum(sample_weight);
        sample_weight_source = repmat("initial_fault_weight_per_trial", n, 1);
    else
        sample_weight = ones(n, 1) / n;
        sample_weight_source = repmat("uniform_chain_weight", n, 1);
    end
end

risk_samples = table(initial_branch, trial_id, total_load_shed_frac, ...
    max_line_loading_pu, max_voltage_deviation_pu, ...
    chain_LLR, chain_LFOR, chain_NVOR, chain_CRI, ...
    initial_branch_weight, sample_weight, sample_weight_source);
end
