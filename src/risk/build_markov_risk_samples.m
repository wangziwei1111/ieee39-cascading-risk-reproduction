function risk_samples = build_markov_risk_samples(chain_summary_table, cfg, initial_probability_table)
%BUILD_MARKOV_RISK_SAMPLES 从Markov事故链汇总表构造风险样本。
% 输入：
%   chain_summary_table - markov_chain_summary.csv 读入后的表格。
%   cfg - 全局配置，包含风险权重、严重度模式和样本权重模式。
%   initial_probability_table - 可选，初始线路故障概率与归一化权重表。
% 输出：
%   risk_samples - 每条事故链一行的风险样本表。
% 物理含义：
%   当前 chain_* 字段为了兼容既有VaR流程，仍指向 basic_* 严重度。
%   paper_formula 只有在公式人工确认后才会并列输出，不会替代或伪装basic结果。

n = height(chain_summary_table);
initial_branch = chain_summary_table.initial_branch;
trial_id = chain_summary_table.trial_id;
total_load_shed_frac = chain_summary_table.total_load_shed_frac;
max_line_loading_pu = chain_summary_table.max_line_loading_pu;
max_voltage_deviation_pu = chain_summary_table.max_voltage_deviation_pu;

severity_table = calc_chain_severity(chain_summary_table, cfg);
basic_LLR = severity_table.basic_LLR;
basic_LFOR = severity_table.basic_LFOR;
basic_NVOR = severity_table.basic_NVOR;
basic_CRI = severity_table.basic_CRI;

% 兼容字段：当前 chain_* 明确等同于 basic_*。论文公式确认后再并列使用 paper_* 字段。
chain_LLR = basic_LLR;
chain_LFOR = basic_LFOR;
chain_NVOR = basic_NVOR;
chain_CRI = basic_CRI;

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
    basic_LLR, basic_LFOR, basic_NVOR, basic_CRI, ...
    chain_LLR, chain_LFOR, chain_NVOR, chain_CRI, ...
    initial_branch_weight, num_trials_for_initial_branch, sample_weight, sample_weight_source);

if all(ismember({'paper_LLR', 'paper_LFOR', 'paper_NVOR', 'paper_CRI'}, severity_table.Properties.VariableNames))
    risk_samples = [risk_samples, severity_table(:, {'paper_LLR', 'paper_LFOR', 'paper_NVOR', 'paper_CRI'})];
end
end
