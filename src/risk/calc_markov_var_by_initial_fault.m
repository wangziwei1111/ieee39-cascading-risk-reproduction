function initial_fault_var_table = calc_markov_var_by_initial_fault(risk_samples, cfg)
%CALC_MARKOV_VAR_BY_INITIAL_FAULT 按初始线路故障计算经验VaR指标。
% 输入：
%   risk_samples - Markov事故链风险样本表。
%   cfg - 全局配置，默认使用sigma=0.95。
% 输出：
%   initial_fault_var_table - 每条初始线路一行的风险指标表。
% 物理含义：
%   用于识别哪些初始线路故障更容易导致高风险事故链。当前每个初始故障
%   内的Monte Carlo样本等权，不引入论文表4-1初始停运概率。

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
    rows{i} = table(branch, sigma, sample_count, SLLR, SLFOR, SNVOR, CRI, ...
        'VariableNames', {'initial_branch', 'sigma', 'sample_count', ...
        'SLLR', 'SLFOR', 'SNVOR', 'CRI'});
end

initial_fault_var_table = sortrows(vertcat(rows{:}), 'CRI', 'descend');
end
