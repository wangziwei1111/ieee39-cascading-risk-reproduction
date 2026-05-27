function initial_fault_var_table = calc_markov_var_by_initial_fault(risk_samples, cfg)
%CALC_MARKOV_VAR_BY_INITIAL_FAULT 按初始线路故障计算条件VaR指标。
% 输入：
%   risk_samples - Markov事故链风险样本表。
%   cfg - 全局配置，当前按sigma=0.95输出分初始线路风险。
% 输出：
%   initial_fault_var_table - 每条初始线路一行的条件风险指标表。
% 物理含义：
%   分初始线路VaR表示“已知该线路为初始故障”时的条件风险。即使全局VaR启用
%   论文表4-1权重，组内分位数仍不再乘初始线路权重；这里仅展示该初始故障的
%   全局权重 initial_branch_weight，便于排序和解释。

sigma = 0.95;
branches = unique(risk_samples.initial_branch);
rows = cell(numel(branches), 1);

for i = 1:numel(branches)
    branch = branches(i);
    group = risk_samples(risk_samples.initial_branch == branch, :);
    SLLR = calc_empirical_var(group.chain_LLR, sigma, []);
    SLFOR = calc_empirical_var(group.chain_LFOR, sigma, []);
    SNVOR = calc_empirical_var(group.chain_NVOR, sigma, []);
    CRI = calc_cri(SLLR, SLFOR, SNVOR, cfg.risk_weights);
    sample_count = height(group);
    if ismember('initial_branch_weight', group.Properties.VariableNames)
        initial_branch_weight = group.initial_branch_weight(1);
    else
        initial_branch_weight = NaN;
    end
    rows{i} = table(branch, sigma, sample_count, initial_branch_weight, ...
        SLLR, SLFOR, SNVOR, CRI, ...
        'VariableNames', {'initial_branch', 'sigma', 'sample_count', ...
        'initial_branch_weight', 'SLLR', 'SLFOR', 'SNVOR', 'CRI'});
end

initial_fault_var_table = sortrows(vertcat(rows{:}), 'CRI', 'descend');
end
